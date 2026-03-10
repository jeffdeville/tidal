defmodule Tidal.PlugTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup_all do
    # Ensure :inets is started for :httpc
    :inets.start()
    :ssl.start()

    # Start Bandit on a random available port
    {:ok, server} =
      Bandit.start_link(
        plug: Tidal.Plug,
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    %{port: port, base_url: "http://127.0.0.1:#{port}"}
  end

  # ── POST endpoint tests ─────────────────────────────────────────────

  describe "POST / (initialize)" do
    test "creates a new session and returns JSON response", %{port: port} do
      body = jsonrpc_request("initialize", %{}, 1)
      {status, headers, resp_body} = post(port, body)

      assert status == 200
      assert content_type(headers) =~ "application/json"
      assert session_id = header_value(headers, ~c"mcp-session-id")
      assert byte_size(session_id) > 0

      decoded = Jason.decode!(resp_body)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["id"] == 1
      assert decoded["result"]["method"] == "initialize"
    end

    test "returns unique session IDs for each initialize", %{port: port} do
      body = jsonrpc_request("initialize", %{}, 1)
      {200, headers1, _} = post(port, body)
      {200, headers2, _} = post(port, body)

      id1 = header_value(headers1, ~c"mcp-session-id")
      id2 = header_value(headers2, ~c"mcp-session-id")
      assert id1 != id2
    end
  end

  describe "POST / (established session)" do
    test "routes messages to the correct session", %{port: port} do
      session_id = create_session(port)

      body = jsonrpc_request("tools/list", %{}, 2)
      {status, headers, resp_body} = post(port, body, session_id)

      assert status == 200
      assert header_value(headers, ~c"mcp-session-id") == session_id

      decoded = Jason.decode!(resp_body)
      assert decoded["id"] == 2
      assert decoded["result"]["method"] == "tools/list"
    end

    test "returns 400 for non-initialize POST without session ID", %{port: port} do
      body = jsonrpc_request("tools/list", %{}, 1)
      {status, _headers, _resp_body} = post(port, body)

      assert status == 400
    end

    test "returns 404 for invalid session ID", %{port: port} do
      body = jsonrpc_request("tools/list", %{}, 1)
      {status, _headers, resp_body} = post(port, body, "nonexistent-session-id")

      assert status == 404
      assert Jason.decode!(resp_body)["error"] =~ "session not found"
    end

    test "accepts notifications (no response body)", %{port: port} do
      session_id = create_session(port)

      body = jsonrpc_notification("notifications/initialized", %{})
      {status, _headers, _resp_body} = post(port, body, session_id)

      assert status == 202
    end

    test "handles batch requests", %{port: port} do
      session_id = create_session(port)

      batch =
        Jason.encode!([
          %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 1, "params" => %{}},
          %{"jsonrpc" => "2.0", "method" => "resources/list", "id" => 2, "params" => %{}}
        ])

      {status, _headers, resp_body} = post(port, batch, session_id)

      assert status == 200
      decoded = Jason.decode!(resp_body)
      assert is_list(decoded)
      assert length(decoded) == 2
    end
  end

  describe "POST / (error cases)" do
    test "returns 400 for malformed JSON", %{port: port} do
      {status, _headers, _resp_body} = post(port, "not json")

      assert status == 400
    end

    test "returns 400 for invalid JSON-RPC", %{port: port} do
      {status, _headers, _resp_body} = post(port, ~s({"invalid": "message"}))

      assert status == 400
    end

    test "returns 400 for missing Content-Type", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"
      headers = [{~c"accept", ~c"application/json, text/event-stream"}]
      body = jsonrpc_request("initialize", %{}, 1)

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:post, {url, headers, ~c"text/plain", body}, [], [])

      assert status == 400
    end

    test "returns 406 for missing Accept header", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"
      body = jsonrpc_request("initialize", %{}, 1)

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(
          :post,
          {url, [{~c"accept", ~c"text/html"}], ~c"application/json", body},
          [],
          []
        )

      assert status == 406
    end
  end

  # ── GET endpoint tests (SSE) ─────────────────────────────────────────

  describe "GET / (SSE stream)" do
    test "opens SSE stream with correct headers", %{port: port} do
      session_id = create_session(port)

      # Use raw TCP to test SSE since :httpc doesn't support streaming
      {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])

      request =
        "GET / HTTP/1.1\r\n" <>
          "Host: 127.0.0.1:#{port}\r\n" <>
          "Accept: application/json, text/event-stream\r\n" <>
          "Mcp-Session-Id: #{session_id}\r\n" <>
          "\r\n"

      :ok = :gen_tcp.send(socket, request)

      # Read the response headers
      {:ok, data} = :gen_tcp.recv(socket, 0, 2_000)

      assert data =~ "HTTP/1.1 200"
      assert data =~ "text/event-stream"
      assert data =~ "cache-control: no-cache"

      :gen_tcp.close(socket)
    end

    test "delivers server-initiated notifications via SSE", %{port: port} do
      session_id = create_session(port)

      {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])

      request =
        "GET / HTTP/1.1\r\n" <>
          "Host: 127.0.0.1:#{port}\r\n" <>
          "Accept: application/json, text/event-stream\r\n" <>
          "Mcp-Session-Id: #{session_id}\r\n" <>
          "\r\n"

      :ok = :gen_tcp.send(socket, request)

      # Read response headers
      {:ok, _header_data} = :gen_tcp.recv(socket, 0, 2_000)

      # Send a notification to the session
      notification = %Tidal.JSONRPC.Notification{
        method: "test/event",
        params: %{"key" => "value"}
      }

      :ok = Tidal.Session.notify(session_id, notification)

      # Read the SSE event
      {:ok, event_data} = :gen_tcp.recv(socket, 0, 2_000)

      assert event_data =~ "event: message"
      assert event_data =~ "data: "
      assert event_data =~ "test/event"

      :gen_tcp.close(socket)
    end

    test "returns 400 without session header", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"
      headers = [{~c"accept", ~c"application/json, text/event-stream"}]

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:get, {url, headers}, [], [])

      assert status == 400
    end

    test "returns 404 for invalid session ID on GET", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"

      headers = [
        {~c"accept", ~c"application/json, text/event-stream"},
        {~c"mcp-session-id", ~c"nonexistent-session-id"}
      ]

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:get, {url, headers}, [], [])

      assert status == 404
    end
  end

  # ── DELETE endpoint tests ────────────────────────────────────────────

  describe "DELETE / (session termination)" do
    test "terminates session and returns 204", %{port: port} do
      session_id = create_session(port)

      # Verify session exists
      body = jsonrpc_request("ping", %{}, 1)
      {200, _headers, _resp_body} = post(port, body, session_id)

      # DELETE the session
      {status, _headers, _resp_body} = delete(port, session_id)
      assert status == 204

      # Subsequent requests should return 404
      {status, _headers, _resp_body} = post(port, body, session_id)
      assert status == 404
    end

    test "returns 404 for non-existent session", %{port: port} do
      {status, _headers, resp_body} = delete(port, "nonexistent-session-id")
      assert status == 404
      assert Jason.decode!(resp_body)["error"] =~ "session not found"
    end

    test "returns 400 without session header", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:delete, {url, []}, [], [])

      assert status == 400
    end
  end

  # ── Content negotiation tests ────────────────────────────────────────

  describe "content negotiation" do
    test "accepts wildcard Accept header", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"
      headers = [{~c"accept", ~c"*/*"}]
      body = jsonrpc_request("initialize", %{}, 1)

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:post, {url, headers, ~c"application/json", body}, [], [])

      assert status == 200
    end

    test "rejects Accept with only application/json", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"
      headers = [{~c"accept", ~c"application/json"}]
      body = jsonrpc_request("initialize", %{}, 1)

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:post, {url, headers, ~c"application/json", body}, [], [])

      assert status == 406
    end

    test "rejects Accept with only text/event-stream", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"
      headers = [{~c"accept", ~c"text/event-stream"}]
      body = jsonrpc_request("initialize", %{}, 1)

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:post, {url, headers, ~c"application/json", body}, [], [])

      assert status == 406
    end
  end

  # ── Method not allowed ───────────────────────────────────────────────

  describe "unsupported methods" do
    test "returns 405 for PUT", %{port: port} do
      url = ~c"http://127.0.0.1:#{port}/"

      {:ok, {{_, status, _}, _headers, _body}} =
        :httpc.request(:put, {url, [], ~c"application/json", ~c"{}"}, [], [])

      assert status == 405
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp create_session(port) do
    body = jsonrpc_request("initialize", %{}, 1)
    {200, headers, _resp_body} = post(port, body)
    header_value(headers, ~c"mcp-session-id")
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

  defp content_type(headers), do: header_value(headers, ~c"content-type")
end
