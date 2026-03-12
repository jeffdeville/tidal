defmodule Tidal.Protocol.LifecycleTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup_all do
    :inets.start()
    :ssl.start()

    {:ok, server} =
      Bandit.start_link(
        plug: Tidal.Plug,
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    %{port: port}
  end

  # ── Initialize handshake ────────────────────────────────────────────

  describe "initialize handshake" do
    test "full initialize → initialized flow", %{port: port} do
      # Step 1: Send initialize request
      init_body =
        jsonrpc_request(
          "initialize",
          %{
            "protocolVersion" => "2025-11-25",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "test-client", "version" => "1.0"}
          },
          1
        )

      {200, headers, resp_body} = post(port, init_body)
      session_id = header_value(headers, ~c"mcp-session-id")
      assert session_id

      result = Jason.decode!(resp_body)
      assert result["id"] == 1
      assert result["result"]["protocolVersion"] == "2025-11-25"
      assert is_map(result["result"]["capabilities"])
      assert is_map(result["result"]["serverInfo"])

      # Step 2: Send initialized notification
      initialized_body = jsonrpc_notification("notifications/initialized", %{})
      {202, _headers, _resp_body} = post(port, initialized_body, session_id)

      # Step 3: Session should now be ready — ping should work
      ping_body = jsonrpc_request("ping", %{}, 2)
      {200, _headers, ping_resp} = post(port, ping_body, session_id)
      assert Jason.decode!(ping_resp)["result"] == %{}
    end

    test "initialize stores client info in session state", %{port: port} do
      init_body =
        jsonrpc_request(
          "initialize",
          %{
            "protocolVersion" => "2025-11-25",
            "capabilities" => %{"tools" => %{}},
            "clientInfo" => %{"name" => "my-client", "version" => "2.0"}
          },
          1
        )

      {200, headers, _resp_body} = post(port, init_body)
      session_id = header_value(headers, ~c"mcp-session-id")

      {:ok, state} = Tidal.Session.get_state(session_id)
      assert state.client_info == %{"name" => "my-client", "version" => "2.0"}
      assert state.client_capabilities == %{"tools" => %{}}
    end
  end

  # ── Capability negotiation ──────────────────────────────────────────

  describe "capability negotiation" do
    test "server declares capabilities in InitializeResult", %{port: port} do
      init_body =
        jsonrpc_request(
          "initialize",
          %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
          1
        )

      {200, _headers, resp_body} = post(port, init_body)
      result = Jason.decode!(resp_body)["result"]

      assert is_map(result["capabilities"])
      assert is_map(result["serverInfo"])
    end
  end

  # ── Protocol version validation ─────────────────────────────────────

  describe "protocol version validation" do
    test "rejects unsupported protocol version", %{port: port} do
      init_body =
        jsonrpc_request(
          "initialize",
          %{"protocolVersion" => "1999-01-01", "capabilities" => %{}},
          1
        )

      {200, _headers, resp_body} = post(port, init_body)
      decoded = Jason.decode!(resp_body)

      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["message"] == "Invalid params"
      assert decoded["error"]["data"] =~ "unsupported protocol version"
    end

    test "rejects missing protocol version", %{port: port} do
      init_body = jsonrpc_request("initialize", %{"capabilities" => %{}}, 1)

      {200, _headers, resp_body} = post(port, init_body)
      decoded = Jason.decode!(resp_body)

      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "unsupported protocol version"
    end
  end

  # ── Ping/Pong ───────────────────────────────────────────────────────

  describe "ping/pong" do
    test "ping returns empty result", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("ping", %{}, 42)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["id"] == 42
      assert decoded["result"] == %{}
    end

    test "ping with no params returns empty result", %{port: port} do
      session_id = create_initialized_session(port)

      body = Jason.encode!(%{"jsonrpc" => "2.0", "method" => "ping", "id" => 7})
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["result"] == %{}
    end
  end

  # ── State machine enforcement ───────────────────────────────────────

  describe "state machine" do
    test "rejects requests before initialization", %{port: port} do
      # Create session via initialize but DON'T send initialized notification
      init_body =
        jsonrpc_request(
          "initialize",
          %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
          1
        )

      {200, headers, _resp_body} = post(port, init_body)
      session_id = header_value(headers, ~c"mcp-session-id")

      # Try to send ping before initialized notification
      ping_body = jsonrpc_request("ping", %{}, 2)
      {200, _headers, resp_body} = post(port, ping_body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_600
      assert decoded["error"]["data"] =~ "not ready"
    end

    test "rejects double initialization", %{port: port} do
      session_id = create_initialized_session(port)

      # Try to initialize again
      init_body =
        jsonrpc_request(
          "initialize",
          %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
          2
        )

      {200, _headers, resp_body} = post(port, init_body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_600
      assert decoded["error"]["data"] =~ "already initialized"
    end

    test "session lifecycle transitions through correct states", %{port: port} do
      # Step 1: Start session — lifecycle is :created
      init_body =
        jsonrpc_request(
          "initialize",
          %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
          1
        )

      {200, headers, _resp_body} = post(port, init_body)
      session_id = header_value(headers, ~c"mcp-session-id")

      # After initialize, lifecycle should be :initializing
      {:ok, state} = Tidal.Session.get_state(session_id)
      assert state.lifecycle == :initializing

      # Step 2: Send initialized notification
      initialized_body = jsonrpc_notification("notifications/initialized", %{})
      {202, _headers, _resp_body} = post(port, initialized_body, session_id)

      # After initialized, lifecycle should be :ready
      {:ok, state} = Tidal.Session.get_state(session_id)
      assert state.lifecycle == :ready
    end
  end

  # ── Graceful shutdown ───────────────────────────────────────────────

  describe "graceful shutdown" do
    test "shutdown request returns success and terminates session", %{port: port} do
      session_id = create_initialized_session(port)

      # Send shutdown request
      body = jsonrpc_request("shutdown", %{}, 10)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["id"] == 10
      assert decoded["result"] == %{}

      # Wait briefly for the session to terminate
      Process.sleep(50)

      # Session should be gone
      ping_body = jsonrpc_request("ping", %{}, 11)
      {status, _headers, _resp_body} = post(port, ping_body, session_id)
      assert status == 404
    end

    test "DELETE terminates session", %{port: port} do
      session_id = create_initialized_session(port)

      {204, _headers, _resp_body} = delete(port, session_id)

      # Session should be gone
      ping_body = jsonrpc_request("ping", %{}, 1)
      {404, _headers, _resp_body} = post(port, ping_body, session_id)
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp create_initialized_session(port) do
    init_body =
      jsonrpc_request(
        "initialize",
        %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
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

  defp delete(port, session_id) do
    url = ~c"http://127.0.0.1:#{port}/"
    headers = [{~c"mcp-session-id", to_charlist(session_id)}]

    {:ok, {{_, status, _}, resp_headers, resp_body}} =
      :httpc.request(:delete, {url, headers}, [], [])

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
