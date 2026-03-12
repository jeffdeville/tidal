defmodule Tidal.Tool.Middleware do
  @moduledoc """
  Behaviour for pluggable tool dispatch middleware.

  Middleware wraps tool invocations with before/after logic. Each middleware
  receives the tool name, arguments, session state, and a `next` function
  that continues the chain.

  ## Example

      defmodule MyApp.Middleware.Logger do
        @behaviour Tidal.Tool.Middleware

        @impl true
        def call(tool_name, arguments, session, next) do
          Logger.info("Calling tool: \#{tool_name}")
          {:ok, result, session} = next.(tool_name, arguments, session)
          Logger.info("Tool completed: \#{tool_name}")
          {:ok, result, session}
        end
      end

  ## Short-Circuiting

  Middleware can skip downstream processing by not calling `next`:

      def call(_tool_name, _arguments, session, _next) do
        {:error, "access denied"}
      end

  ## Return Types

  Middleware must return one of:
  - `{:ok, %ToolResult{}, session}` — success (possibly modified result/session)
  - `{:error, reason}` — halt the chain with an error
  """

  alias Tidal.Protocol.ToolResult

  @type next :: (String.t(), map(), map() -> {:ok, ToolResult.t(), map()} | {:error, String.t()})

  @doc """
  Called for each tool invocation in the middleware chain.

  Invoke `next.(tool_name, arguments, session)` to continue the chain.
  Modify arguments or session before calling next. Modify results after.
  Return `{:error, reason}` to short-circuit.
  """
  @callback call(
              tool_name :: String.t(),
              arguments :: map(),
              session :: map(),
              next :: next()
            ) :: {:ok, ToolResult.t(), map()} | {:error, String.t()}
end
