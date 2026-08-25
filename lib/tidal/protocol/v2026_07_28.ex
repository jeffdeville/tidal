defmodule Tidal.Protocol.V20260728 do
  @moduledoc """
  Stateless MCP `2026-07-28` request dispatcher.

  Each call receives an immutable `Tidal.Server` through a fresh
  `Tidal.RequestContext`. It never reads or mutates `Tidal.Session`.
  """

  alias Tidal.JSONRPC.{Error, Request, Response}
  alias Tidal.Protocol.{BlobResourceContents, Resource, ResourceTemplate, TextResourceContents}
  alias Tidal.Protocol.{InputRequiredResult, TextContent, Tool, ToolResult}
  alias Tidal.RequestContext
  alias Tidal.Server
  alias Tidal.Tool.Pipeline

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @spec handle(Request.t(), RequestContext.t()) :: {pos_integer(), Response.t() | Error.t()}
  def handle(%Request{method: "server/discover"} = request, context) do
    result = %{
      "supportedVersions" => context.server.supported_versions,
      "capabilities" => context.server.capabilities
    }

    result = maybe_put(result, "instructions", context.server.instructions)
    success(request.id, result, context, cacheable: true)
  end

  def handle(%Request{method: "tools/list"} = request, context) do
    tools = Enum.map(context.server.tools, &serialize_tool/1)
    success(request.id, %{"tools" => tools}, context, cacheable: true)
  end

  def handle(%Request{method: "tools/call"} = request, context) do
    params = request.params
    name = params["name"]
    arguments = params["arguments"] || %{}

    case Map.fetch(context.server.tool_handlers, name) do
      {:ok, module} -> call_tool(request.id, module, name, arguments, context)
      :error -> error(200, request.id, ErrorCodes.invalid_params(), "Invalid params", "unknown tool: #{name}")
    end
  end

  def handle(%Request{method: "resources/list"} = request, context) do
    resources = Enum.map(context.server.resources, &Resource.to_protocol/1)
    success(request.id, %{"resources" => resources}, context, cacheable: true)
  end

  def handle(%Request{method: "resources/templates/list"} = request, context) do
    templates = Enum.map(context.server.resource_templates, &ResourceTemplate.to_protocol/1)
    success(request.id, %{"resourceTemplates" => templates}, context, cacheable: true)
  end

  def handle(%Request{method: "resources/read"} = request, context) do
    uri = request.params["uri"]

    with {:ok, handler} <- find_resource_handler(uri, context.server),
         {:ok, contents} <- safely_read_resource(handler, uri, context) do
      result = %{"contents" => Enum.map(contents, &serialize_resource_content/1)}
      success(request.id, result, context, cacheable: true)
    else
      :not_found ->
        error(200, request.id, ErrorCodes.invalid_params(), "Invalid params", "resource not found: #{uri}")

      {:error, reason} ->
        error(200, request.id, ErrorCodes.internal_error(), "Internal error", inspect(reason))
    end
  end

  def handle(
        %Request{method: "subscriptions/listen"} = request,
        %RequestContext{server: %Server{subscription_bus: bus}} = context
      )
      when not is_nil(bus) do
    success(
      request.id,
      %{
        "_meta" => %{
          "io.modelcontextprotocol/subscriptionId" => request.id
        }
      },
      context
    )
  end

  def handle(%Request{} = request, _context) do
    error(404, request.id, ErrorCodes.method_not_found(), "Method not found", "unknown method: #{request.method}")
  end

  defp call_tool(id, module, name, arguments, context) when is_map(arguments) do
    tool = Enum.find(context.server.tools, &(&1.name == name))

    with :ok <- validate_required(tool, arguments),
         {:ok, result} <- safely_run_pipeline(module, name, arguments, context) do
      serialize_tool_result(id, result, context)
    else
      {:error, :validation, detail} ->
        error(200, id, ErrorCodes.invalid_params(), "Invalid params", detail)

      {:error, reason} when is_binary(reason) ->
        result = %ToolResult{content: [%TextContent{text: reason}], is_error: true}
        success(id, ToolResult.to_map(result), context)

      {:error, reason} ->
        error(200, id, ErrorCodes.internal_error(), "Internal error", inspect(reason))
    end
  end

  defp call_tool(id, _module, _name, _arguments, _context) do
    error(200, id, ErrorCodes.invalid_params(), "Invalid params", "arguments must be an object")
  end

  defp safely_run_pipeline(module, name, arguments, context) do
    handler = fn _name, args, request_context ->
      case module.handle_tool_call(name, args, request_context) do
        {:ok, result} when is_struct(result, ToolResult) or is_struct(result, InputRequiredResult) ->
          {:ok, result, request_context}

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, {:invalid_tool_result, other}}
      end
    end

    case Pipeline.call(context.server.middleware, name, arguments, context, handler) do
      {:ok, result, _context}
      when is_struct(result, ToolResult) or is_struct(result, InputRequiredResult) ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:invalid_middleware_result, other}}
    end
  rescue
    exception -> {:error, {:tool_exception, exception}}
  catch
    kind, reason -> {:error, {:tool_exit, kind, reason}}
  end

  defp serialize_tool_result(id, %ToolResult{} = result, context) do
    success(id, ToolResult.to_map(result), context)
  end

  defp serialize_tool_result(id, %InputRequiredResult{} = result, context) do
    required = required_capabilities(result.input_requests)

    if capabilities_present?(context.client_capabilities, required) do
      success(id, InputRequiredResult.to_map(result), context)
    else
      error(
        400,
        id,
        -32_021,
        "Missing required client capability",
        %{"requiredCapabilities" => required}
      )
    end
  end

  defp required_capabilities(nil), do: %{}

  defp required_capabilities(input_requests) do
    Enum.reduce(input_requests, %{}, fn
      {_id, %{"method" => "elicitation/create"}}, capabilities ->
        Map.put(capabilities, "elicitation", %{})

      {_id, %{"method" => "sampling/createMessage"}}, capabilities ->
        Map.put(capabilities, "sampling", %{})

      {_id, %{"method" => "roots/list"}}, capabilities ->
        Map.put(capabilities, "roots", %{})

      _, capabilities ->
        capabilities
    end)
  end

  defp capabilities_present?(client_capabilities, required) do
    Enum.all?(required, fn {name, _settings} -> Map.has_key?(client_capabilities, name) end)
  end

  defp validate_required(%Tool{input_schema: %{"required" => required}}, arguments)
       when is_list(required) do
    case Enum.reject(required, &Map.has_key?(arguments, &1)) do
      [] -> :ok
      missing -> {:error, :validation, "missing required arguments: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_required(_tool, _arguments), do: :ok

  defp find_resource_handler(uri, server) when is_binary(uri) do
    Enum.find_value(server.resource_handlers, :not_found, fn handler ->
      if Enum.any?(handler.define_resources(), &resource_matches?(&1, uri)) do
        {:ok, handler}
      end
    end)
  rescue
    _exception -> :not_found
  end

  defp find_resource_handler(_uri, _server), do: :not_found

  defp resource_matches?(%Resource{uri: uri}, uri), do: true

  defp resource_matches?(%ResourceTemplate{uri_template: template}, uri) do
    pattern = template |> Regex.escape() |> String.replace(~r/\\\{[^}]+\\\}/, "[^/]+")
    Regex.match?(~r/^#{pattern}$/, uri)
  end

  defp resource_matches?(_definition, _uri), do: false

  defp safely_read_resource(handler, uri, context) do
    handler.handle_read_resource(uri, context)
  rescue
    exception -> {:error, {:resource_exception, exception}}
  catch
    kind, reason -> {:error, {:resource_exit, kind, reason}}
  end

  defp serialize_tool(%Tool{} = tool) do
    tool
    |> Tool.to_map()
    |> Map.put_new("inputSchema", %{"type" => "object"})
  end

  defp serialize_resource_content(%TextResourceContents{} = content),
    do: TextResourceContents.to_protocol(content)

  defp serialize_resource_content(%BlobResourceContents{} = content),
    do: BlobResourceContents.to_protocol(content)

  defp success(id, result, context, opts \\ []) do
    result =
      result
      |> Map.put_new("resultType", "complete")
      |> put_server_info(context.server)
      |> maybe_put_cache(context.server, Keyword.get(opts, :cacheable, false))

    {200, %Response{id: id, result: result}}
  end

  defp put_server_info(result, server) do
    metadata =
      result
      |> Map.get("_meta", %{})
      |> Map.put_new("io.modelcontextprotocol/serverInfo", server.server_info)

    Map.put(result, "_meta", metadata)
  end

  defp maybe_put_cache(result, %Server{cache: cache}, true) do
    result
    |> Map.put_new("ttlMs", cache.ttl_ms)
    |> Map.put_new("cacheScope", cache.scope)
  end

  defp maybe_put_cache(result, _server, false), do: result

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp error(status, id, code, message, data) do
    {status, %Error{id: id, code: code, message: message, data: data}}
  end
end
