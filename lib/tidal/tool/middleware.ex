defmodule Tidal.Tool.Middleware do
  @moduledoc """
  Behaviour for pluggable tool dispatch middleware.

  Middleware wraps tool invocations with before/after logic. Each middleware
  receives the tool name, arguments, request context, and a `next` function
  that continues the chain.

  ## Example

      defmodule MyApp.Middleware.Logger do
        @behaviour Tidal.Tool.Middleware

        @impl true
        def call(tool_name, arguments, context, next) do
          Logger.info("Calling tool: \#{tool_name}")
          {:ok, result, context} = next.(tool_name, arguments, context)
          Logger.info("Tool completed: \#{tool_name}")
          {:ok, result, context}
        end
      end

  ## Short-Circuiting

  Middleware can skip downstream processing by not calling `next`:

      def call(_tool_name, _arguments, _context, _next) do
        {:error, "access denied"}
      end

  ## Return Types

  Middleware must return one of:
  - `{:ok, result, context}` — success (possibly modified result/context)
  - `{:error, reason}` — halt the chain with an error
  """

  alias Tidal.Tool

  @type next :: (String.t(), map(), map() -> {:ok, Tool.result(), map()} | {:error, String.t()})

  @doc """
  Called for each tool invocation in the middleware chain.

  Invoke `next.(tool_name, arguments, context)` to continue the chain.
  Modify arguments or context before calling next. Modify results after.
  Return `{:error, reason}` to short-circuit.
  """
  @callback call(
              tool_name :: String.t(),
              arguments :: map(),
              context :: map(),
              next :: next()
            ) :: {:ok, Tool.result(), map()} | {:error, String.t()}
end
