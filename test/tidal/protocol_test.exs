defmodule Tidal.ProtocolTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC
  alias Tidal.Protocol

  defp base_state(lifecycle \\ :ready) do
    %{
      lifecycle: lifecycle,
      capabilities: %{},
      server_info: %{"name" => "test", "version" => "0.1"},
      client_info: %{},
      client_capabilities: %{}
    }
  end

  describe "handle_request/2 lifecycle enforcement" do
    test "allows initialize in :created state" do
      request = %JSONRPC.Request{
        id: 1,
        method: "initialize",
        params: %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
      }

      {response, new_state} = Protocol.handle_request(request, base_state(:created))
      assert %JSONRPC.Response{} = response
      assert new_state.lifecycle == :initializing
    end

    test "rejects initialize in :ready state" do
      request = %JSONRPC.Request{
        id: 1,
        method: "initialize",
        params: %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
      }

      {response, _state} = Protocol.handle_request(request, base_state(:ready))
      assert %JSONRPC.Error{} = response
      assert response.data =~ "already initialized"
    end

    test "rejects ping in :created state" do
      request = %JSONRPC.Request{id: 1, method: "ping"}

      {response, _state} = Protocol.handle_request(request, base_state(:created))
      assert %JSONRPC.Error{} = response
      assert response.data =~ "not initialized"
    end

    test "rejects ping in :initializing state" do
      request = %JSONRPC.Request{id: 1, method: "ping"}

      {response, _state} = Protocol.handle_request(request, base_state(:initializing))
      assert %JSONRPC.Error{} = response
      assert response.data =~ "not ready"
    end

    test "allows ping in :ready state" do
      request = %JSONRPC.Request{id: 1, method: "ping"}

      {response, _state} = Protocol.handle_request(request, base_state(:ready))
      assert %JSONRPC.Response{result: %{}} = response
    end

    test "rejects requests in :shutting_down state" do
      request = %JSONRPC.Request{id: 1, method: "ping"}

      {response, _state} = Protocol.handle_request(request, base_state(:shutting_down))
      assert %JSONRPC.Error{} = response
      assert response.data =~ "shutting down"
    end
  end

  describe "handle_notification/2 lifecycle enforcement" do
    test "allows initialized notification in :initializing state" do
      notification = %JSONRPC.Notification{method: "notifications/initialized"}

      {:ok, new_state} = Protocol.handle_notification(notification, base_state(:initializing))
      assert new_state.lifecycle == :ready
    end

    test "rejects initialized notification in :created state" do
      notification = %JSONRPC.Notification{method: "notifications/initialized"}

      {:error, reason, _state} = Protocol.handle_notification(notification, base_state(:created))
      assert reason =~ "must send initialize request first"
    end

    test "rejects initialized notification in :ready state" do
      notification = %JSONRPC.Notification{method: "notifications/initialized"}

      {:error, reason, _state} = Protocol.handle_notification(notification, base_state(:ready))
      assert reason =~ "already initialized"
    end
  end

  describe "handle_request/2 initialize" do
    test "returns protocol version, capabilities, and server info" do
      request = %JSONRPC.Request{
        id: 1,
        method: "initialize",
        params: %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
      }

      state = base_state(:created)
      {response, _new_state} = Protocol.handle_request(request, state)

      assert response.result["protocolVersion"] == "2024-11-05"
      assert is_map(response.result["capabilities"])
      assert response.result["serverInfo"] == %{"name" => "test", "version" => "0.1"}
    end

    test "rejects incompatible protocol version" do
      request = %JSONRPC.Request{
        id: 1,
        method: "initialize",
        params: %{"protocolVersion" => "0000-00-00", "capabilities" => %{}}
      }

      {response, state} = Protocol.handle_request(request, base_state(:created))
      assert %JSONRPC.Error{} = response
      assert response.code == -32_602
      assert response.data =~ "unsupported protocol version"
      # State should not change on error
      assert state.lifecycle == :created
    end

    test "rejects nil protocol version" do
      request = %JSONRPC.Request{
        id: 1,
        method: "initialize",
        params: %{"capabilities" => %{}}
      }

      {response, _state} = Protocol.handle_request(request, base_state(:created))
      assert %JSONRPC.Error{} = response
      assert response.data =~ "unsupported protocol version"
    end
  end

  describe "handle_request/2 ping" do
    test "returns empty result" do
      request = %JSONRPC.Request{id: 42, method: "ping"}

      {response, _state} = Protocol.handle_request(request, base_state())
      assert %JSONRPC.Response{id: 42, result: %{}} = response
    end
  end

  describe "handle_request/2 shutdown" do
    test "transitions to shutting_down state" do
      request = %JSONRPC.Request{id: 5, method: "shutdown"}

      {response, new_state} = Protocol.handle_request(request, base_state())
      assert %JSONRPC.Response{id: 5, result: %{}} = response
      assert new_state.lifecycle == :shutting_down
    end
  end

  describe "handle_request/2 unknown method" do
    test "returns method not found error" do
      request = %JSONRPC.Request{id: 1, method: "nonexistent/method"}

      {response, _state} = Protocol.handle_request(request, base_state())
      assert %JSONRPC.Error{} = response
      assert response.code == -32_601
      assert response.data =~ "nonexistent/method"
    end
  end
end
