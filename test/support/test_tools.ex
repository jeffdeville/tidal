defmodule Tidal.TestTools.Echo do
  @moduledoc false
  @behaviour Tidal.Tool

  alias Tidal.Protocol.{Tool, TextContent, ToolResult}

  @impl true
  def define_tools do
    [
      Tool.new!(
        name: "echo",
        description: "Echoes back the provided message",
        input_schema: %{
          "type" => "object",
          "properties" => %{
            "message" => %{"type" => "string", "description" => "The message to echo"}
          },
          "required" => ["message"]
        }
      )
    ]
  end

  @impl true
  def handle_tool_call("echo", %{"message" => message}, _session) do
    {:ok, %ToolResult{content: [%TextContent{text: message}]}}
  end
end

defmodule Tidal.TestTools.Math do
  @moduledoc false
  @behaviour Tidal.Tool

  alias Tidal.Protocol.{Tool, TextContent, ToolResult}

  @impl true
  def define_tools do
    [
      Tool.new!(
        name: "add",
        description: "Adds two numbers",
        input_schema: %{
          "type" => "object",
          "properties" => %{
            "a" => %{"type" => "number"},
            "b" => %{"type" => "number"}
          },
          "required" => ["a", "b"]
        }
      ),
      Tool.new!(
        name: "noop",
        description: "Does nothing, no arguments required"
      )
    ]
  end

  @impl true
  def handle_tool_call("add", %{"a" => a, "b" => b}, _session) do
    {:ok, %ToolResult{content: [%TextContent{text: "#{a + b}"}]}}
  end

  def handle_tool_call("noop", _args, _session) do
    {:ok, %ToolResult{content: [%TextContent{text: "done"}]}}
  end
end

defmodule Tidal.TestTools.Failing do
  @moduledoc false
  @behaviour Tidal.Tool

  alias Tidal.Protocol.{Tool, ToolResult}

  @impl true
  def define_tools do
    [
      Tool.new!(
        name: "fail",
        description: "Always fails"
      )
    ]
  end

  @impl true
  def handle_tool_call("fail", _args, _session) do
    {:error, "something went wrong"}
  end
end
