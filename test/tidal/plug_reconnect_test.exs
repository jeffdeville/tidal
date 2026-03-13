defmodule Tidal.PlugReconnectTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup_all do
    :inets.start()
    :ssl.start()

    {:ok, server} =
      Bandit.start_link(
        plug: {Tidal.Plug, [init_assigns: %{role: :admin}]},
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    %{port: port}
  end

  describe "auto-reconnect on expired session" do
    test "POST to expired session auto-reconnects and returns new session ID", %{port: port} do
      # Create and initialize a session
      session_id = create_initialized_session(port)

      # Verify it works
      body = jsonrpc_request("ping", %{}, 2)
      {200, _headers, _resp_body} = post(port, body, session_id)

      # Kill the session process to simulate timeout
      {:ok, pid} = Tidal.Session.get(session_id)
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

      # Wait for registry cleanup
      wait_for_registry_cleanup(session_id)

      # Now POST with the old session_id - should auto-reconnect
      body = jsonrpc_request("ping", %{}, 3)
      {status, headers, resp_body} = post(port, body, session_id)

      assert status == 200
      new_session_id = header_value(headers, ~c"mcp-session-id")
      assert new_session_id != nil
      assert new_session_id != session_id

      # The response should be a valid ping response
      decoded = Jason.decode!(resp_body)
      assert decoded["id"] == 3
      assert decoded["result"] == %{}

      # Verify the new session has the same init_assigns
      {:ok, state} = Tidal.Session.get_state(new_session_id)
      assert state.assigns[:role] == :admin
    end

    test "POST to unknown session still returns 404", %{port: port} do
      body = jsonrpc_request("ping", %{}, 1)
      {status, _headers, resp_body} = post(port, body, "completely-unknown-session")

      assert status == 404
      assert Jason.decode!(resp_body)["error"] =~ "session not found"
    end

    test "notification to expired session auto-reconnects", %{port: port} do
      session_id = create_initialized_session(port)

      # Kill the session
      {:ok, pid} = Tidal.Session.get(session_id)
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      wait_for_registry_cleanup(session_id)

      # Send notification to expired session
      body = jsonrpc_notification("notifications/cancelled", %{})
      {status, headers, _resp_body} = post(port, body, session_id)

      assert status == 202
      new_session_id = header_value(headers, ~c"mcp-session-id")
      assert new_session_id != nil
      assert new_session_id != session_id
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp create_initialized_session(port) do
    body =
      jsonrpc_request(
        "initialize",
        %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
        1
      )

    {200, headers, _resp_body} = post(port, body)
    session_id = header_value(headers, ~c"mcp-session-id")

    initialized = jsonrpc_notification("notifications/initialized", %{})
    {202, _headers, _resp_body} = post(port, initialized, session_id)

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

  defp wait_for_registry_cleanup(session_id, attempts \\ 50) do
    case Registry.lookup(Tidal.SessionRegistry, session_id) do
      [] ->
        :ok

      _entries when attempts > 0 ->
        Process.sleep(1)
        wait_for_registry_cleanup(session_id, attempts - 1)

      _entries ->
        flunk("Registry did not clean up session #{session_id} in time")
    end
  end
end
