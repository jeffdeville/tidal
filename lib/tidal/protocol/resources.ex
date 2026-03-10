defmodule Tidal.Protocol.Resources do
  @moduledoc """
  Handles MCP resource protocol methods:

    * `resources/list` — returns all defined resources
    * `resources/read` — reads resource content by URI
    * `resources/templates/list` — returns resource templates
    * `resources/subscribe` — subscribes the session to resource changes
    * `resources/unsubscribe` — unsubscribes the session from resource changes

  Resource handlers are implemented by modules using the `Tidal.Resource` behaviour.
  The list of handler modules is configured in the session state under
  the `:resource_handlers` key.
  """

  alias Tidal.JSONRPC
  alias Tidal.Protocol.{BlobResourceContents, Resource, ResourceTemplate, TextResourceContents}

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @doc """
  Handles `resources/list` — returns all defined resources.
  """
  def handle_list(%JSONRPC.Request{} = request, state) do
    resources =
      state
      |> get_handlers()
      |> Enum.flat_map(&call_define_resources/1)
      |> Enum.filter(&match?(%Resource{}, &1))
      |> Enum.map(&Resource.to_protocol/1)

    response = %JSONRPC.Response{id: request.id, result: %{"resources" => resources}}
    {response, state}
  end

  @doc """
  Handles `resources/read` — fetches resource content by URI.
  """
  def handle_read(%JSONRPC.Request{} = request, state) do
    with {:ok, uri} <- require_uri_param(request),
         {:ok, handler} <- find_handler_for_uri(uri, state),
         {:ok, contents} <- handler.handle_read_resource(uri, state) do
      serialized = Enum.map(contents, &serialize_content/1)
      response = %JSONRPC.Response{id: request.id, result: %{"contents" => serialized}}
      {response, state}
    else
      {:error, :missing_uri} ->
        {missing_uri_error(request.id), state}

      :not_found ->
        uri = get_uri_param(request)

        error = %JSONRPC.Error{
          id: request.id,
          code: ErrorCodes.invalid_params(),
          message: "Invalid params",
          data: "resource not found: #{uri}"
        }

        {error, state}

      {:error, reason} ->
        error = %JSONRPC.Error{
          id: request.id,
          code: ErrorCodes.internal_error(),
          message: "Internal error",
          data: to_string(reason)
        }

        {error, state}
    end
  end

  @doc """
  Handles `resources/templates/list` — returns resource templates.
  """
  def handle_templates_list(%JSONRPC.Request{} = request, state) do
    templates =
      state
      |> get_handlers()
      |> Enum.flat_map(&call_define_resources/1)
      |> Enum.filter(&match?(%ResourceTemplate{}, &1))
      |> Enum.map(&ResourceTemplate.to_protocol/1)

    response = %JSONRPC.Response{
      id: request.id,
      result: %{"resourceTemplates" => templates}
    }

    {response, state}
  end

  @doc """
  Handles `resources/subscribe` — tracks the subscription per-session.
  """
  def handle_subscribe(%JSONRPC.Request{} = request, state) do
    with {:ok, uri} <- require_uri_param(request),
         :ok <- invoke_handler_subscribe(uri, state) do
      subscriptions = Map.get(state, :resource_subscriptions, MapSet.new())
      new_state = Map.put(state, :resource_subscriptions, MapSet.put(subscriptions, uri))
      response = %JSONRPC.Response{id: request.id, result: %{}}
      {response, new_state}
    else
      {:error, :missing_uri} ->
        {missing_uri_error(request.id), state}

      {:error, reason} ->
        error = %JSONRPC.Error{
          id: request.id,
          code: ErrorCodes.internal_error(),
          message: "Internal error",
          data: to_string(reason)
        }

        {error, state}
    end
  end

  @doc """
  Handles `resources/unsubscribe` — removes the subscription for this session.
  """
  def handle_unsubscribe(%JSONRPC.Request{} = request, state) do
    case require_uri_param(request) do
      {:ok, uri} ->
        subscriptions = Map.get(state, :resource_subscriptions, MapSet.new())
        new_state = Map.put(state, :resource_subscriptions, MapSet.delete(subscriptions, uri))
        response = %JSONRPC.Response{id: request.id, result: %{}}
        {response, new_state}

      {:error, :missing_uri} ->
        {missing_uri_error(request.id), state}
    end
  end

  # ── Private helpers ────────────────────────────────────────────────

  defp get_handlers(state) do
    Map.get(state, :resource_handlers, [])
  end

  defp call_define_resources(handler) do
    handler.define_resources()
  rescue
    _ -> []
  end

  defp find_handler_for_uri(uri, state) do
    state
    |> get_handlers()
    |> Enum.find_value(:not_found, fn handler ->
      definitions = call_define_resources(handler)

      has_match? =
        Enum.any?(definitions, fn
          %Resource{uri: ^uri} -> true
          %ResourceTemplate{} = tmpl -> uri_matches_template?(uri, tmpl.uri_template)
          _ -> false
        end)

      if has_match?, do: {:ok, handler}
    end)
  end

  defp invoke_handler_subscribe(uri, state) do
    case find_handler_for_uri(uri, state) do
      {:ok, handler} ->
        if function_exported?(handler, :handle_subscribe, 2) do
          handler.handle_subscribe(uri, state)
        else
          :ok
        end

      :not_found ->
        :ok
    end
  end

  defp require_uri_param(request) do
    case get_uri_param(request) do
      uri when is_binary(uri) and uri != "" -> {:ok, uri}
      _ -> {:error, :missing_uri}
    end
  end

  defp get_uri_param(request) do
    (request.params || %{})["uri"]
  end

  defp missing_uri_error(id) do
    %JSONRPC.Error{
      id: id,
      code: ErrorCodes.invalid_params(),
      message: "Invalid params",
      data: "missing required parameter: uri"
    }
  end

  defp uri_matches_template?(uri, template) do
    pattern =
      template
      |> Regex.escape()
      |> String.replace(~r/\\\{[^}]+\\\}/, "[^/]+")

    Regex.match?(~r/^#{pattern}$/, uri)
  end

  defp serialize_content(%TextResourceContents{} = c), do: TextResourceContents.to_protocol(c)
  defp serialize_content(%BlobResourceContents{} = c), do: BlobResourceContents.to_protocol(c)
end
