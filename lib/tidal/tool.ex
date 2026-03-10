defmodule Tidal.Tool do
  @moduledoc """
  Behaviour for defining MCP tools with a LiveView-inspired API.

  Implement this behaviour to define tools that can be listed and invoked
  by MCP clients. The API mirrors LiveView's declarative style — define
  tools with `define_tools/0` and handle invocations with `handle_tool_call/3`.

  ## Example

      defmodule MyApp.Tools.Echo do
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

  """

  alias Tidal.Protocol.{Tool, ToolResult}

  @doc """
  Returns a list of tool definitions provided by this module.

  Each tool definition is a `Tidal.Protocol.Tool` struct.
  """
  @callback define_tools() :: [Tool.t()]

  @doc """
  Handles a tool invocation.

  Receives the tool name, a map of validated arguments, and the session state.
  Returns `{:ok, %ToolResult{}}` or `{:error, reason}`.
  """
  @callback handle_tool_call(name :: String.t(), arguments :: map(), session :: map()) ::
              {:ok, ToolResult.t()} | {:error, String.t()}
end
