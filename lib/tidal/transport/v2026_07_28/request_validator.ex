defmodule Tidal.Transport.V20260728.RequestValidator do
  @moduledoc false

  alias Tidal.JSONRPC
  alias Tidal.JSONRPC.{Error, Notification, Request}
  alias Tidal.Server
  alias Tidal.Transport.V20260728.ValueEncoding

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @header_mismatch -32_020
  @unsupported_protocol_version -32_022
  @protocol_version_key "io.modelcontextprotocol/protocolVersion"
  @client_capabilities_key "io.modelcontextprotocol/clientCapabilities"
  @client_info_key "io.modelcontextprotocol/clientInfo"
  @log_level_key "io.modelcontextprotocol/logLevel"
  @trace_keys ["traceparent", "tracestate", "baggage"]
  @named_methods ["tools/call", "resources/read", "prompts/get"]

  @type validation_error :: {:error, pos_integer(), Error.t()}

  @spec validate(Plug.Conn.t(), term(), Server.t()) :: {:ok, map()} | validation_error()
  def validate(_conn, messages, _server) when is_list(messages) do
    {:error, 400, invalid_request(nil, "JSON-RPC batches are not supported")}
  end

  def validate(_conn, %JSONRPC.Response{id: id}, _server) do
    {:error, 400, invalid_request(id, "clients must not send JSON-RPC responses")}
  end

  def validate(_conn, %Error{id: id}, _server) do
    {:error, 400, invalid_request(id, "clients must not send JSON-RPC responses")}
  end

  def validate(conn, %Request{} = request, %Server{} = server) do
    with {:ok, params, meta} <- validate_params(request),
         {:ok, metadata} <- validate_metadata(meta, request.id),
         {:ok, retry_metadata} <- validate_retry_metadata(params, request.id),
         :ok <- validate_method_params(request.method, params, request.id),
         :ok <- validate_protocol_headers(conn, request, metadata, server),
         :ok <- validate_standard_headers(conn, request),
         :ok <- validate_tool_headers(conn, request, params, server) do
      {:ok,
       metadata
       |> Map.merge(retry_metadata)
       |> Map.put(:request_fingerprint, request_fingerprint(request.method, params))}
    end
  end

  def validate(_conn, %Notification{} = notification, _server) do
    case validate_params(notification) do
      {:ok, _params, meta} -> validate_metadata(meta, nil)
      error -> error
    end
  end

  def validate(_conn, _message, _server) do
    {:error, 400, invalid_request(nil, "body must be a JSON-RPC request or notification")}
  end

  defp validate_params(%{id: id, params: params}) when is_map(params) do
    case params["_meta"] do
      meta when is_map(meta) -> {:ok, params, meta}
      _ -> {:error, 400, invalid_params(id, "params._meta is required")}
    end
  end

  defp validate_params(%{params: params}) when is_map(params) do
    case params["_meta"] do
      meta when is_map(meta) -> {:ok, params, meta}
      _ -> {:error, 400, invalid_params(nil, "params._meta is required")}
    end
  end

  defp validate_params(%{id: id}),
    do: {:error, 400, invalid_params(id, "params must be an object")}

  defp validate_params(_message),
    do: {:error, 400, invalid_params(nil, "params must be an object")}

  defp validate_metadata(meta, id) do
    version = meta[@protocol_version_key]
    capabilities = meta[@client_capabilities_key]

    cond do
      not (is_binary(version) and version != "") ->
        {:error, 400, invalid_params(id, "request protocol version is required")}

      not is_map(capabilities) ->
        {:error, 400, invalid_params(id, "client capabilities must be an object")}

      true ->
        {:ok,
         %{
           protocol_version: version,
           client_capabilities: capabilities,
           client_info: normalize_client_info(meta[@client_info_key]),
           log_level: meta[@log_level_key],
           trace_context: Map.take(meta, @trace_keys)
         }}
    end
  end

  defp validate_retry_metadata(params, id) do
    input_responses = Map.get(params, "inputResponses")
    request_state = Map.get(params, "requestState")

    cond do
      not (is_nil(input_responses) or is_map(input_responses)) ->
        {:error, 400, invalid_params(id, "inputResponses must be an object")}

      not (is_nil(request_state) or is_binary(request_state)) ->
        {:error, 400, invalid_params(id, "requestState must be a string")}

      true ->
        {:ok, %{input_responses: input_responses, request_state: request_state}}
    end
  end

  defp validate_method_params("tools/call", params, id) do
    cond do
      not (is_binary(params["name"]) and params["name"] != "") ->
        {:error, 400, invalid_params(id, "name must be a non-empty string")}

      not (is_nil(params["arguments"]) or is_map(params["arguments"])) ->
        {:error, 400, invalid_params(id, "arguments must be an object")}

      true ->
        :ok
    end
  end

  defp validate_method_params("resources/read", params, id) do
    if is_binary(params["uri"]) and params["uri"] != "" do
      :ok
    else
      {:error, 400, invalid_params(id, "uri must be a non-empty string")}
    end
  end

  defp validate_method_params("subscriptions/listen", params, id) do
    case params["notifications"] do
      notifications when is_map(notifications) -> validate_subscription_filter(notifications, id)
      _ -> {:error, 400, invalid_params(id, "notifications must be an object")}
    end
  end

  defp validate_method_params(_method, _params, _id), do: :ok

  defp validate_subscription_filter(filter, id) do
    booleans_valid? =
      Enum.all?(["toolsListChanged", "resourcesListChanged", "promptsListChanged"], fn key ->
        is_nil(filter[key]) or is_boolean(filter[key])
      end)

    resources = filter["resourceSubscriptions"]
    resources_valid? = is_nil(resources) or (is_list(resources) and Enum.all?(resources, &is_binary/1))

    if booleans_valid? and resources_valid? do
      :ok
    else
      {:error, 400, invalid_params(id, "notifications contains an invalid filter")}
    end
  end

  defp request_fingerprint(method, params) do
    semantic_params = Map.drop(params, ["_meta", "inputResponses", "requestState"])

    {method, semantic_params}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp validate_protocol_headers(conn, request, metadata, server) do
    header = first_header(conn, "mcp-protocol-version")
    body = metadata.protocol_version

    cond do
      is_nil(header) ->
        header_mismatch(request.id, "MCP-Protocol-Version header is required")

      header != body ->
        header_mismatch(request.id, "MCP-Protocol-Version header does not match request metadata")

      body not in server.supported_versions ->
        {:error, 400,
         %Error{
           id: request.id,
           code: @unsupported_protocol_version,
           message: "Unsupported protocol version",
           data: %{"requested" => body, "supported" => server.supported_versions}
         }}

      body != Server.modern_protocol_version() ->
        header_mismatch(request.id, "modern request metadata requires protocol version 2026-07-28")

      true ->
        :ok
    end
  end

  defp validate_standard_headers(conn, request) do
    case matching_header(conn, "mcp-method", request.method, request.id) do
      :ok -> validate_name_header(conn, request)
      error -> error
    end
  end

  defp validate_name_header(conn, %{method: method, params: params, id: id})
       when method in @named_methods do
    expected = params["name"] || params["uri"]
    matching_encoded_header(conn, "mcp-name", expected, id)
  end

  defp validate_name_header(_conn, _request), do: :ok

  defp matching_header(conn, name, expected, id) do
    case first_header(conn, name) do
      nil -> header_mismatch(id, "#{canonical_header(name)} header is required")
      ^expected -> :ok
      _ -> header_mismatch(id, "#{canonical_header(name)} header does not match request body")
    end
  end

  defp matching_encoded_header(conn, name, expected, id) when is_binary(expected) do
    with value when is_binary(value) <- first_header(conn, name),
         {:ok, decoded} <- ValueEncoding.decode(value),
         true <- decoded == expected do
      :ok
    else
      nil -> header_mismatch(id, "#{canonical_header(name)} header is required")
      _ -> header_mismatch(id, "#{canonical_header(name)} header does not match request body")
    end
  end

  defp matching_encoded_header(_conn, name, _expected, id) do
    header_mismatch(id, "#{canonical_header(name)} source field is missing")
  end

  defp validate_tool_headers(_conn, %{method: method}, _params, _server)
       when method != "tools/call",
       do: :ok

  defp validate_tool_headers(conn, request, params, server) do
    case Enum.find(server.tools, &(&1.name == params["name"])) do
      nil -> :ok
      tool -> validate_annotated_headers(conn, request.id, tool.input_schema || %{}, params["arguments"] || %{})
    end
  end

  defp validate_annotated_headers(conn, id, schema, arguments) do
    schema
    |> annotated_headers()
    |> Enum.reduce_while(:ok, fn {path, header_name, type}, :ok ->
      case fetch_path(arguments, path) do
        :missing -> validate_absent_header(conn, header_name, id, "an absent value")
        {:ok, nil} -> validate_absent_header(conn, header_name, id, "a null value")
        {:ok, value} -> validate_param_header(conn, header_name, type, value, id)
      end
      |> case do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp annotated_headers(schema), do: collect_annotations(schema, [])

  defp collect_annotations(%{"properties" => properties}, prefix) when is_map(properties) do
    Enum.flat_map(properties, fn {property, property_schema} ->
      path = prefix ++ [property]

      current =
        case property_schema do
          %{"x-mcp-header" => name, "type" => type}
          when is_binary(name) and type in ["string", "integer", "boolean"] ->
            [{path, name, type}]

          _ ->
            []
        end

      current ++ collect_annotations(property_schema, path)
    end)
  end

  defp collect_annotations(_schema, _prefix), do: []

  defp fetch_path(value, []), do: {:ok, value}

  defp fetch_path(map, [key | rest]) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> fetch_path(value, rest)
      :error -> :missing
    end
  end

  defp fetch_path(_value, _path), do: :missing

  defp validate_absent_header(conn, name, id, reason) do
    case first_header(conn, "mcp-param-#{name}") do
      nil -> :ok
      _ -> header_mismatch(id, "Mcp-Param-#{name} must be omitted for #{reason}")
    end
  end

  defp validate_param_header(conn, name, type, body_value, id) do
    header_name = "mcp-param-#{name}"

    with value when is_binary(value) <- first_header(conn, header_name),
         {:ok, decoded} <- ValueEncoding.decode(value),
         true <- parameter_matches?(type, decoded, body_value) do
      :ok
    else
      nil -> header_mismatch(id, "Mcp-Param-#{name} header is required")
      _ -> header_mismatch(id, "Mcp-Param-#{name} header does not match request body")
    end
  end

  defp parameter_matches?("string", header, body), do: is_binary(body) and header == body
  defp parameter_matches?("boolean", "true", true), do: true
  defp parameter_matches?("boolean", "false", false), do: true

  defp parameter_matches?("integer", header, body)
       when is_integer(body) and body >= -9_007_199_254_740_991 and
              body <= 9_007_199_254_740_991 do
    case Integer.parse(header) do
      {value, ""} -> value == body
      _ -> false
    end
  end

  defp parameter_matches?(_type, _header, _body), do: false

  defp normalize_client_info(info) when is_map(info), do: info
  defp normalize_client_info(_info), do: nil

  defp first_header(conn, name) do
    case Plug.Conn.get_req_header(conn, String.downcase(name)) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp canonical_header("mcp-method"), do: "Mcp-Method"
  defp canonical_header("mcp-name"), do: "Mcp-Name"
  defp canonical_header(name), do: name

  defp header_mismatch(id, detail) do
    {:error, 400, %Error{id: id, code: @header_mismatch, message: "Header mismatch", data: detail}}
  end

  defp invalid_request(id, detail) do
    %Error{id: id, code: ErrorCodes.invalid_request(), message: "Invalid Request", data: detail}
  end

  defp invalid_params(id, detail) do
    %Error{id: id, code: ErrorCodes.invalid_params(), message: "Invalid params", data: detail}
  end
end
