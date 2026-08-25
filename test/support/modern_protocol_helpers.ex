defmodule Tidal.ModernProtocolHelpers do
  @moduledoc false

  import Plug.Conn
  import Plug.Test

  @version "2026-07-28"

  def request(method, params \\ %{}, id \\ 1, opts \\ []) do
    version = Keyword.get(opts, :body_version, @version)

    meta = %{
      "io.modelcontextprotocol/protocolVersion" => version,
      "io.modelcontextprotocol/clientCapabilities" => Keyword.get(opts, :capabilities, %{}),
      "io.modelcontextprotocol/clientInfo" => %{"name" => "tidal-test", "version" => "1.0.0"}
    }

    params = Map.put(params, "_meta", Map.merge(meta, Keyword.get(opts, :meta, %{})))
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end

  def call(message, plug_opts \\ [], request_opts \\ []) do
    body = if is_binary(message), do: message, else: Jason.encode!(message)
    method = if is_map(message), do: message["method"], else: nil

    conn =
      conn(:post, "/", body)
      |> put_req_header("content-type", "application/json")
      |> maybe_put_accept(request_opts)
      |> maybe_put_header(
        "mcp-protocol-version",
        Keyword.get(request_opts, :header_version, @version)
      )
      |> maybe_put_header("mcp-method", Keyword.get(request_opts, :method_header, method))
      |> maybe_put_name(message, request_opts)
      |> maybe_put_extra_headers(Keyword.get(request_opts, :headers, []))
      |> maybe_assign_test_pid(Keyword.get(request_opts, :test_pid))

    Tidal.Plug.call(conn, Tidal.Plug.init(plug_opts))
  end

  def decode(%Plug.Conn{resp_body: body}) when is_binary(body) and body != "",
    do: Jason.decode!(body)

  def decode(%Plug.Conn{}), do: nil

  defp maybe_put_accept(conn, opts) do
    case Keyword.get(opts, :accept, "application/json, text/event-stream") do
      nil -> conn
      value -> put_req_header(conn, "accept", value)
    end
  end

  defp maybe_put_name(conn, message, opts) do
    default =
      case message do
        %{"method" => method, "params" => params}
        when method in ["tools/call", "resources/read", "prompts/get"] ->
          params["name"] || params["uri"]

        _ ->
          nil
      end

    maybe_put_header(conn, "mcp-name", Keyword.get(opts, :name_header, default))
  end

  defp maybe_put_extra_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, conn -> put_req_header(conn, name, value) end)
  end

  defp maybe_put_header(conn, _name, nil), do: conn
  defp maybe_put_header(conn, name, value), do: put_req_header(conn, name, value)

  defp maybe_assign_test_pid(conn, nil), do: conn
  defp maybe_assign_test_pid(conn, pid), do: assign(conn, :test_pid, pid)
end

defmodule Tidal.ModernProtocolFixtures.Tools do
  @moduledoc false

  @behaviour Tidal.Tool

  alias Tidal.Protocol.{TextContent, Tool, ToolResult}

  @impl true
  def define_tools do
    [
      Tool.new!(
        name: "route",
        input_schema: %{
          "type" => "object",
          "properties" => %{
            "region" => %{"type" => "string", "x-mcp-header" => "Region"},
            "shard" => %{"type" => "integer", "x-mcp-header" => "Shard"}
          },
          "required" => ["region"]
        }
      ),
      Tool.new!(
        name: "echo",
        description: "Echo a message",
        input_schema: %{
          "type" => "object",
          "properties" => %{"message" => %{"type" => "string"}},
          "required" => ["message"]
        }
      ),
      Tool.new!(name: "confirm", input_schema: %{"type" => "object"}),
      Tool.new!(name: "parallel", input_schema: %{"type" => "object"}),
      Tool.new!(name: "crash", input_schema: %{"type" => "object"})
    ]
  end

  @impl true
  def handle_tool_call("echo", %{"message" => message}, context) do
    notify_test(context, {:tool_context, context})
    {:ok, %ToolResult{content: [%TextContent{text: message}]}}
  end

  def handle_tool_call("route", %{"region" => region}, _context) do
    {:ok, %ToolResult{content: [%TextContent{text: region}]}}
  end

  def handle_tool_call("parallel", _arguments, context) do
    test_pid = context.assigns.test_pid
    send(test_pid, {:parallel_tool_entered, self()})

    receive do
      :continue -> {:ok, %ToolResult{content: [%TextContent{text: "done"}]}}
    end
  end

  def handle_tool_call("confirm", _arguments, %{input_responses: nil} = context) do
    {:ok, request_state} = Tidal.RequestState.sign(context, %{"operation" => "confirm"})

    {:ok,
     Tidal.Protocol.InputRequiredResult.new!(
       input_requests: %{
         "confirmation" => %{
           "method" => "elicitation/create",
           "params" => %{
             "message" => "Continue?",
             "requestedSchema" => %{"type" => "boolean"}
           }
         }
       },
       request_state: request_state
     )}
  end

  def handle_tool_call("confirm", _arguments, context) do
    with {:ok, %{"operation" => "confirm"}} <-
           Tidal.RequestState.verify(context, context.request_state) do
      accepted = get_in(context.input_responses, ["confirmation", "result", "content"])
      {:ok, %ToolResult{content: [%TextContent{text: "confirmed=#{accepted}"}]}}
    else
      {:error, reason} -> {:error, "invalid continuation: #{reason}"}
    end
  end

  def handle_tool_call("crash", _arguments, context) do
    notify_test(context, :crash_tool_called)
    raise "boom"
  end

  defp notify_test(%Tidal.RequestContext{assigns: %{test_pid: pid}}, message), do: send(pid, message)
  defp notify_test(_context, _message), do: :ok
end

defmodule Tidal.ModernProtocolFixtures.Resources do
  @moduledoc false

  @behaviour Tidal.Resource

  alias Tidal.Protocol.{Resource, ResourceTemplate, TextResourceContents}

  @impl true
  def define_resources do
    [
      %Resource{uri: "tidal://zebra", name: "Zebra"},
      %ResourceTemplate{uri_template: "tidal://items/{id}", name: "Item"},
      %Resource{uri: "tidal://alpha", name: "Alpha"}
    ]
  end

  @impl true
  def handle_read_resource("tidal://alpha", context) do
    send(context.assigns.test_pid, {:resource_context, context})

    {:ok,
     [
       %TextResourceContents{
         uri: "tidal://alpha",
         text: "alpha",
         mime_type: "text/plain"
       }
     ]}
  end

  def handle_read_resource(_uri, _context), do: {:error, "resource not found"}
end
