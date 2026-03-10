defmodule Tidal.Protocol.ToolsIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup_all do
    :inets.start()
    :ssl.start()

    {:ok, server} =
      Bandit.start_link(
        plug: {Tidal.Plug, [tool_modules: [Tidal.TestTools.Echo, Tidal.TestTools.Math]]},
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    %{port: port}
  end

  # ── tools/list over HTTP ──────────────────────────────────────────

  describe "tools/list over HTTP" do
    test "returns all defined tools", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("tools/list", %{}, 10)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["id"] == 10
      tools = decoded["result"]["tools"]

      names = Enum.map(tools, & &1["name"])
      assert "echo" in names
      assert "add" in names
      assert "noop" in names
    end

    test "tools include description and inputSchema", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("tools/list", %{}, 11)
      {200, _headers, resp_body} = post(port, body, session_id)

      tools = Jason.decode!(resp_body)["result"]["tools"]
      echo = Enum.find(tools, &(&1["name"] == "echo"))

      assert echo["description"] == "Echoes back the provided message"
      assert echo["inputSchema"]["type"] == "object"
    end
  end

  # ── tools/call over HTTP ──────────────────────────────────────────

  describe "tools/call over HTTP" do
    test "invokes echo tool and returns text content", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "echo", "arguments" => %{"message" => "hello world"}},
          20
        )

      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["id"] == 20
      assert [%{"type" => "text", "text" => "hello world"}] = decoded["result"]["content"]
    end

    test "invokes add tool from second module", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "add", "arguments" => %{"a" => 10, "b" => 20}},
          21
        )

      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert [%{"type" => "text", "text" => "30"}] = decoded["result"]["content"]
    end

    test "returns MethodNotFound for unknown tool", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "nonexistent", "arguments" => %{}},
          22
        )

      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_601
      assert decoded["error"]["data"] =~ "unknown tool"
    end

    test "returns InvalidParams for missing required arguments", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "echo", "arguments" => %{}},
          23
        )

      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "missing required arguments"
    end

    test "tool with no schema accepts any arguments", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "noop", "arguments" => %{"anything" => "goes"}},
          24
        )

      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert [%{"type" => "text", "text" => "done"}] = decoded["result"]["content"]
    end
  end

  # ── capabilities ──────────────────────────────────────────────────

  describe "capabilities" do
    test "server advertises tools capability when tool modules configured", %{port: port} do
      init_body =
        jsonrpc_request(
          "initialize",
          %{"protocolVersion" => "2024-11-05", "capabilities" => %{}},
          1
        )

      {200, _headers, resp_body} = post(port, init_body)

      result = Jason.decode!(resp_body)["result"]
      assert is_map(result["capabilities"]["tools"])
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp create_initialized_session(port) do
    init_body =
      jsonrpc_request(
        "initialize",
        %{"protocolVersion" => "2024-11-05", "capabilities" => %{}},
        1
      )

    {200, headers, _resp_body} = post(port, init_body)
    session_id = header_value(headers, ~c"mcp-session-id")

    initialized_body = jsonrpc_notification("notifications/initialized", %{})
    {202, _headers, _resp_body} = post(port, initialized_body, session_id)

    session_id
  end

  defp post(port, body, session_id \\ nil) do
    url = ~c"http://127.0.0.1:#{port}/"

    headers =
      [{~c"accept", ~c"application/json, text/event-stream"}] ++
        if session_id, do: [{~c"mcp-session-id", to_charlist(session_id)}], else: []

    {:ok, {{_, status, _}, resp_headers, resp_body}} =
      :httpc.request(:post, {url, headers, ~c"application/json", to_charlist(body)}, [], [])

    {status, resp_headers, to_string(resp_body)}
  end

  defp jsonrpc_request(method, params, id) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => method,
      "id" => id,
      "params" => params
    })
  end

  defp jsonrpc_notification(method, params) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    })
  end

  defp header_value(headers, key) do
    case List.keyfind(headers, key, 0) do
      {_, value} -> to_string(value)
      nil -> nil
    end
  end
end
