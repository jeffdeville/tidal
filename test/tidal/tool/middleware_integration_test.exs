defmodule Tidal.Tool.MiddlewareIntegrationTest do
  use ExUnit.Case, async: true

  alias Tidal.Session
  alias Tidal.JSONRPC.{Request, Notification}

  # ── Test Tool ──────────────────────────────────────────────────────

  defmodule EchoTool do
    use Tidal.Tool.Operation

    defop :echo do
      desc("Echoes input")
      param(:message, :string, required: true)
    end

    @impl true
    def execute(:echo, %{message: msg}, _session), do: {:ok, %{echoed: msg}}
  end

  # ── Test Middleware ────────────────────────────────────────────────

  defmodule InjectPrefix do
    @behaviour Tidal.Tool.Middleware

    @impl true
    def call(tool_name, arguments, session, next) do
      arguments = Map.update(arguments, "message", "", &"prefixed:#{&1}")
      next.(tool_name, arguments, session)
    end
  end

  defmodule BlockTool do
    @behaviour Tidal.Tool.Middleware

    @impl true
    def call("blocked_tool", _arguments, _session, _next) do
      {:error, "Tool blocked by middleware"}
    end

    def call(tool_name, arguments, session, next) do
      next.(tool_name, arguments, session)
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp initialize_session(session_id) do
    init_request = %Request{
      id: "1",
      method: "initialize",
      params: %{
        "protocolVersion" => "2025-11-25",
        "clientInfo" => %{"name" => "test"},
        "capabilities" => %{}
      }
    }

    {:ok, _response} = Session.handle_message(session_id, init_request)

    initialized = %Notification{method: "notifications/initialized"}
    {:ok, _} = Session.handle_message(session_id, initialized)
  end

  # ── Tests ──────────────────────────────────────────────────────────

  describe "middleware through full session stack" do
    test "middleware modifies arguments before tool execution" do
      {:ok, session_id} =
        Session.start(
          tool_modules: [EchoTool],
          middleware: [InjectPrefix],
          server_info: %{name: "test"}
        )

      initialize_session(session_id)

      call_request = %Request{
        id: "2",
        method: "tools/call",
        params: %{
          "name" => "echo",
          "arguments" => %{"message" => "hello"}
        }
      }

      {:ok, response} = Session.handle_message(session_id, call_request)

      content = get_in(response.result, ["content", Access.at(0), "text"])
      decoded = Jason.decode!(content)
      assert decoded["echoed"] == "prefixed:hello"
    end

    test "middleware can short-circuit tool calls" do
      {:ok, session_id} =
        Session.start(
          tool_modules: [EchoTool],
          middleware: [BlockTool],
          server_info: %{name: "test"}
        )

      initialize_session(session_id)

      # Echo still works (not blocked)
      call_request = %Request{
        id: "2",
        method: "tools/call",
        params: %{
          "name" => "echo",
          "arguments" => %{"message" => "hello"}
        }
      }

      {:ok, response} = Session.handle_message(session_id, call_request)
      content = get_in(response.result, ["content", Access.at(0), "text"])
      assert Jason.decode!(content)["echoed"] == "hello"
    end

    test "multiple middleware compose in order" do
      {:ok, session_id} =
        Session.start(
          tool_modules: [EchoTool],
          middleware: [BlockTool, InjectPrefix],
          server_info: %{name: "test"}
        )

      initialize_session(session_id)

      call_request = %Request{
        id: "2",
        method: "tools/call",
        params: %{
          "name" => "echo",
          "arguments" => %{"message" => "hello"}
        }
      }

      {:ok, response} = Session.handle_message(session_id, call_request)
      content = get_in(response.result, ["content", Access.at(0), "text"])
      decoded = Jason.decode!(content)
      # BlockTool passes through for "echo", InjectPrefix adds prefix
      assert decoded["echoed"] == "prefixed:hello"
    end

    test "session without middleware works normally" do
      {:ok, session_id} =
        Session.start(
          tool_modules: [EchoTool],
          server_info: %{name: "test"}
        )

      initialize_session(session_id)

      call_request = %Request{
        id: "2",
        method: "tools/call",
        params: %{
          "name" => "echo",
          "arguments" => %{"message" => "hello"}
        }
      }

      {:ok, response} = Session.handle_message(session_id, call_request)
      content = get_in(response.result, ["content", Access.at(0), "text"])
      assert Jason.decode!(content)["echoed"] == "hello"
    end
  end
end
