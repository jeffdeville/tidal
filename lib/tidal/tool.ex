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
        def handle_tool_call("echo", %{"message" => message}, _context) do
          {:ok, %ToolResult{content: [%TextContent{text: message}]}}
        end
      end

  """

  alias Tidal.Protocol.{InputRequiredResult, Tool, ToolResult}

  @type result :: ToolResult.t() | InputRequiredResult.t()

  @doc """
  Returns a list of tool definitions provided by this module.

  Each tool definition is a `Tidal.Protocol.Tool` struct.
  """
  @callback define_tools() :: [Tool.t()]

  @doc """
  Handles a tool invocation.

  Receives the tool name, validated arguments, and either a modern request
  context or legacy session state. Returns a complete or input-required result.
  """
  @callback handle_tool_call(name :: String.t(), arguments :: map(), context :: map()) ::
              {:ok, result()} | {:error, String.t()}

  @doc """
  Executes a tool operation (used by `defop`-based modules).

  Receives the operation name as an atom, validated params with atom keys,
  and the session state. Returns `{:ok, result_map}`, `{:error, error_name}`,
  or `{:error, error_name, details}`.

  This callback is optional — only needed when using `Tidal.Tool.Operation`.
  """
  @callback execute(op_name :: atom(), params :: map(), session :: map()) ::
              {:ok, map()} | {:error, atom()} | {:error, atom(), map()}

  @optional_callbacks [execute: 3]
end
