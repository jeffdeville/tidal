defmodule Tidal.Tool.MiddlewareTest do
  use ExUnit.Case, async: true

  alias Tidal.Tool.Pipeline
  alias Tidal.Protocol.{ToolResult, TextContent}

  # ── Test Middleware Modules ────────────────────────────────────────

  defmodule LoggingMiddleware do
    @behaviour Tidal.Tool.Middleware

    @impl true
    def call(tool_name, arguments, session, next) do
      session = Map.update(session, :log, ["before:#{tool_name}"], &["before:#{tool_name}" | &1])
      {:ok, result, session} = next.(tool_name, arguments, session)
      session = Map.update(session, :log, ["after:#{tool_name}"], &["after:#{tool_name}" | &1])
      {:ok, result, session}
    end
  end

  defmodule ParamInjector do
    @behaviour Tidal.Tool.Middleware

    @impl true
    def call(tool_name, arguments, session, next) do
      arguments = Map.put(arguments, "injected", "yes")
      next.(tool_name, arguments, session)
    end
  end

  defmodule ShortCircuit do
    @behaviour Tidal.Tool.Middleware

    @impl true
    def call(_tool_name, _arguments, session, _next) do
      result = %ToolResult{content: [%TextContent{text: "blocked"}], is_error: true}
      {:ok, result, session}
    end
  end

  defmodule ErrorMiddleware do
    @behaviour Tidal.Tool.Middleware

    @impl true
    def call(_tool_name, _arguments, _session, _next) do
      {:error, "middleware rejected"}
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp echo_handler(tool_name, arguments, session) do
    text = "echo:#{tool_name}:#{inspect(arguments)}"
    result = %ToolResult{content: [%TextContent{text: text}]}
    {:ok, result, session}
  end

  # ── Tests ──────────────────────────────────────────────────────────

  describe "Pipeline.call/5 with no middleware" do
    test "passes through to handler directly" do
      {:ok, result, _session} =
        Pipeline.call([], "echo", %{"msg" => "hi"}, %{}, &echo_handler/3)

      assert [%TextContent{text: text}] = result.content
      assert text =~ "echo:echo"
      assert text =~ "hi"
    end
  end

  describe "Pipeline.call/5 with single middleware" do
    test "middleware can modify arguments before handler" do
      {:ok, result, _session} =
        Pipeline.call([ParamInjector], "echo", %{"msg" => "hi"}, %{}, &echo_handler/3)

      assert [%TextContent{text: text}] = result.content
      assert text =~ ~s("injected" => "yes")
    end

    test "middleware can modify session" do
      {:ok, _result, session} =
        Pipeline.call([LoggingMiddleware], "echo", %{}, %{}, &echo_handler/3)

      assert "before:echo" in session.log
      assert "after:echo" in session.log
    end
  end

  describe "Pipeline.call/5 with multiple middleware" do
    test "executes middleware in order (first registered = outermost)" do
      {:ok, result, session} =
        Pipeline.call(
          [LoggingMiddleware, ParamInjector],
          "echo",
          %{"msg" => "hi"},
          %{},
          &echo_handler/3
        )

      # ParamInjector ran (inner), so arguments were modified
      assert [%TextContent{text: text}] = result.content
      assert text =~ ~s("injected" => "yes")

      # LoggingMiddleware ran (outer), so log entries exist
      assert "before:echo" in session.log
      assert "after:echo" in session.log
    end
  end

  describe "Pipeline.call/5 short-circuit" do
    test "middleware can skip the handler entirely" do
      {:ok, result, _session} =
        Pipeline.call([ShortCircuit], "echo", %{}, %{}, &echo_handler/3)

      assert [%TextContent{text: "blocked"}] = result.content
      assert result.is_error == true
    end

    test "middleware can return an error tuple" do
      {:error, reason} =
        Pipeline.call([ErrorMiddleware], "echo", %{}, %{}, &echo_handler/3)

      assert reason == "middleware rejected"
    end
  end

  describe "Pipeline.call/5 with empty middleware list" do
    test "behaves identically to no middleware" do
      {:ok, result, _session} =
        Pipeline.call([], "echo", %{"msg" => "test"}, %{}, &echo_handler/3)

      assert [%TextContent{text: text}] = result.content
      assert text =~ "echo:echo"
    end
  end
end
