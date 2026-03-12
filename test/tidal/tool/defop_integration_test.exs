defmodule Tidal.Tool.DefopIntegrationTest do
  @moduledoc """
  Integration test: defop-defined tools work through the full Tidal HTTP pipeline.
  Verifies that tools defined with `defop` are discoverable via tools/list and
  callable via tools/call, with proper error catalog formatting.
  """
  use ExUnit.Case, async: true

  # ── Test tool module ──────────────────────────────────────────────

  defmodule TaskTools do
    use Tidal.Tool.Operation

    defop :finish_task do
      desc("Signal task completion")
      mutation(true)

      param(:task_id, :string, required: true, desc: "Task UUID")

      param :result, :map, required: true, desc: "Completion data" do
        field(:summary, :string, required: true, desc: "What was accomplished")
      end

      success do
        field(:completed, :boolean)
        field(:task_id, :string)
      end

      error(:not_found, 404,
        retryable: false,
        desc: "Task does not exist",
        recovery: "Check the task_id and try again."
      )

      error(:already_completed, 409,
        retryable: false,
        desc: "Task was already completed"
      )

      guidance("Call when work is done and committed.")
    end

    @impl true
    def execute(:finish_task, %{task_id: task_id} = _params, _session) do
      case task_id do
        "missing" -> {:error, :not_found}
        "done" -> {:error, :already_completed}
        _ -> {:ok, %{completed: true, task_id: task_id}}
      end
    end
  end

  # ── Setup ─────────────────────────────────────────────────────────

  setup do
    # Start a Tidal session directly (no HTTP, just the protocol layer)
    {:ok, session_id} =
      Tidal.Session.start(
        tool_modules: [TaskTools],
        server_info: %{name: "test", version: "0.1"}
      )

    # Initialize the session
    init_request = %Tidal.JSONRPC.Request{
      id: "init-1",
      method: "initialize",
      params: %{
        "protocolVersion" => "2025-11-25",
        "capabilities" => %{},
        "clientInfo" => %{"name" => "test-client", "version" => "1.0"}
      }
    }

    {:ok, _response} = Tidal.Session.handle_message(session_id, init_request)

    # Send initialized notification
    init_notification = %Tidal.JSONRPC.Notification{
      method: "notifications/initialized"
    }

    {:ok, _} = Tidal.Session.handle_message(session_id, init_notification)

    %{session_id: session_id}
  end

  # ── Tests ─────────────────────────────────────────────────────────

  test "tools/list returns defop-defined tools", %{session_id: sid} do
    request = %Tidal.JSONRPC.Request{
      id: "list-1",
      method: "tools/list",
      params: %{}
    }

    {:ok, response} = Tidal.Session.handle_message(sid, request)

    assert %Tidal.JSONRPC.Response{result: %{"tools" => tools}} = response
    assert [tool] = tools
    assert tool["name"] == "finish_task"
    assert tool["description"] == "Signal task completion"

    # Verify JSON Schema was generated
    schema = tool["inputSchema"]
    assert schema["type"] == "object"
    assert schema["required"] == ["task_id", "result"]
    assert schema["properties"]["task_id"]["type"] == "string"

    # Nested map schema
    result_schema = schema["properties"]["result"]
    assert result_schema["type"] == "object"
    assert result_schema["properties"]["summary"]["type"] == "string"
    assert result_schema["required"] == ["summary"]
  end

  test "tools/call dispatches to execute and returns success", %{session_id: sid} do
    request = %Tidal.JSONRPC.Request{
      id: "call-1",
      method: "tools/call",
      params: %{
        "name" => "finish_task",
        "arguments" => %{
          "task_id" => "abc-123",
          "result" => %{"summary" => "Implemented the feature"}
        }
      }
    }

    {:ok, response} = Tidal.Session.handle_message(sid, request)

    assert %Tidal.JSONRPC.Response{result: result} = response
    [content] = result["content"]
    assert content["type"] == "text"

    parsed = Jason.decode!(content["text"])
    assert parsed["completed"] == true
    assert parsed["task_id"] == "abc-123"
  end

  test "tools/call returns structured error from catalog", %{session_id: sid} do
    request = %Tidal.JSONRPC.Request{
      id: "call-2",
      method: "tools/call",
      params: %{
        "name" => "finish_task",
        "arguments" => %{
          "task_id" => "missing",
          "result" => %{"summary" => "N/A"}
        }
      }
    }

    {:ok, response} = Tidal.Session.handle_message(sid, request)

    assert %Tidal.JSONRPC.Response{result: result} = response
    assert result["isError"] == true

    [content] = result["content"]
    error = Jason.decode!(content["text"])
    assert error["status"] == "error"
    assert error["error"] == "not_found"
    assert error["retryable"] == false
    assert error["recovery"] == "Check the task_id and try again."
  end

  test "tools/call returns error without recovery hint", %{session_id: sid} do
    request = %Tidal.JSONRPC.Request{
      id: "call-3",
      method: "tools/call",
      params: %{
        "name" => "finish_task",
        "arguments" => %{
          "task_id" => "done",
          "result" => %{"summary" => "Already done"}
        }
      }
    }

    {:ok, response} = Tidal.Session.handle_message(sid, request)

    result = response.result
    assert result["isError"] == true

    error = Jason.decode!(hd(result["content"])["text"])
    assert error["error"] == "already_completed"
    refute Map.has_key?(error, "recovery")
  end

  test "introspection: __tidal_operations__ returns full metadata" do
    [op] = TaskTools.__tidal_operations__()

    assert op.name == :finish_task
    assert op.mutation == true
    assert op.guidance == "Call when work is done and committed."
    assert length(op.params) == 2
    assert length(op.errors) == 2
    assert length(op.success_fields) == 2
  end
end
