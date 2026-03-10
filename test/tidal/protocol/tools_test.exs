defmodule Tidal.Protocol.ToolsTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC
  alias Tidal.Protocol.Tools

  @tool_modules [Tidal.TestTools.Echo, Tidal.TestTools.Math]

  defp ready_state(tool_modules \\ @tool_modules) do
    %{
      lifecycle: :ready,
      capabilities: %{"tools" => %{}},
      server_info: %{},
      client_info: %{},
      client_capabilities: %{},
      assigns: %{},
      timeout_ms: 30_000,
      subscribers: MapSet.new(),
      tool_modules: tool_modules
    }
  end

  # ── tools/list ────────────────────────────────────────────────────

  describe "handle_list/2" do
    test "returns all tools from all modules" do
      request = %JSONRPC.Request{id: 1, method: "tools/list", params: %{}}
      {response, _state} = Tools.handle_list(request, ready_state())

      assert %JSONRPC.Response{id: 1, result: %{"tools" => tools}} = response
      names = Enum.map(tools, & &1["name"])
      assert "echo" in names
      assert "add" in names
      assert "noop" in names
      assert length(tools) == 3
    end

    test "includes description and inputSchema when present" do
      request = %JSONRPC.Request{id: 2, method: "tools/list", params: %{}}
      {response, _state} = Tools.handle_list(request, ready_state())

      tools = response.result["tools"]
      echo = Enum.find(tools, &(&1["name"] == "echo"))

      assert echo["description"] == "Echoes back the provided message"
      assert echo["inputSchema"]["type"] == "object"
      assert echo["inputSchema"]["required"] == ["message"]
    end

    test "omits inputSchema when not defined" do
      request = %JSONRPC.Request{id: 3, method: "tools/list", params: %{}}
      {response, _state} = Tools.handle_list(request, ready_state())

      tools = response.result["tools"]
      noop = Enum.find(tools, &(&1["name"] == "noop"))

      assert noop["name"] == "noop"
      refute Map.has_key?(noop, "inputSchema")
    end

    test "returns empty list when no tool modules configured" do
      request = %JSONRPC.Request{id: 4, method: "tools/list", params: %{}}
      {response, _state} = Tools.handle_list(request, ready_state([]))

      assert response.result["tools"] == []
    end
  end

  # ── tools/call ────────────────────────────────────────────────────

  describe "handle_call/2" do
    test "invokes correct tool handler and returns result" do
      request = %JSONRPC.Request{
        id: 10,
        method: "tools/call",
        params: %{"name" => "echo", "arguments" => %{"message" => "hello"}}
      }

      {response, _state} = Tools.handle_call(request, ready_state())

      assert %JSONRPC.Response{id: 10} = response
      assert [%{"type" => "text", "text" => "hello"}] = response.result["content"]
      refute Map.has_key?(response.result, "isError")
    end

    test "invokes tool from second module" do
      request = %JSONRPC.Request{
        id: 11,
        method: "tools/call",
        params: %{"name" => "add", "arguments" => %{"a" => 3, "b" => 4}}
      }

      {response, _state} = Tools.handle_call(request, ready_state())

      assert %JSONRPC.Response{id: 11} = response
      assert [%{"type" => "text", "text" => "7"}] = response.result["content"]
    end

    test "returns error for unknown tool" do
      request = %JSONRPC.Request{
        id: 12,
        method: "tools/call",
        params: %{"name" => "nonexistent", "arguments" => %{}}
      }

      {error, _state} = Tools.handle_call(request, ready_state())

      assert %JSONRPC.Error{id: 12, code: -32_601} = error
      assert error.data =~ "unknown tool"
    end

    test "returns InvalidParams for missing required arguments" do
      request = %JSONRPC.Request{
        id: 13,
        method: "tools/call",
        params: %{"name" => "echo", "arguments" => %{}}
      }

      {error, _state} = Tools.handle_call(request, ready_state())

      assert %JSONRPC.Error{id: 13, code: -32_602} = error
      assert error.data =~ "missing required arguments"
      assert error.data =~ "message"
    end

    test "tool that returns error wraps in ToolResult with isError" do
      request = %JSONRPC.Request{
        id: 14,
        method: "tools/call",
        params: %{"name" => "fail", "arguments" => %{}}
      }

      state = ready_state([Tidal.TestTools.Failing])
      {response, _state} = Tools.handle_call(request, state)

      assert %JSONRPC.Response{id: 14} = response
      assert response.result["isError"] == true
      assert [%{"type" => "text", "text" => "something went wrong"}] = response.result["content"]
    end

    test "tool with no input_schema accepts any arguments" do
      request = %JSONRPC.Request{
        id: 15,
        method: "tools/call",
        params: %{"name" => "noop", "arguments" => %{"extra" => "value"}}
      }

      {response, _state} = Tools.handle_call(request, ready_state())

      assert %JSONRPC.Response{id: 15} = response
      assert [%{"type" => "text", "text" => "done"}] = response.result["content"]
    end

    test "defaults to empty arguments when not provided" do
      request = %JSONRPC.Request{
        id: 16,
        method: "tools/call",
        params: %{"name" => "noop"}
      }

      {response, _state} = Tools.handle_call(request, ready_state())

      assert %JSONRPC.Response{id: 16} = response
    end
  end
end
