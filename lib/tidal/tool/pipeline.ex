defmodule Tidal.Tool.Pipeline do
  @moduledoc """
  Executes a middleware chain around a tool handler.

  Middleware modules are applied in order — first in the list is outermost
  (runs first on the way in, last on the way out). The handler is the
  innermost function that actually executes the tool.

  ## Example

      Pipeline.call(
        [RoleFilter, ParamInjector, Logger],
        "my_tool",
        %{"arg" => "value"},
        request_context,
        &actual_tool_handler/3
      )

  The execution order is:
  1. RoleFilter.call → 2. ParamInjector.call → 3. Logger.call → 4. handler
  """

  alias Tidal.Tool

  @type handler :: (String.t(), map(), map() ->
                      {:ok, Tool.result(), map()} | {:error, String.t()})

  @doc """
  Runs the middleware chain and handler for a tool invocation.

  ## Parameters

  - `middleware` — list of modules implementing `Tidal.Tool.Middleware`
  - `tool_name` — the MCP tool name being called
  - `arguments` — the tool arguments map
  - `context` — a modern request context or legacy session state
  - `handler` — the innermost function: `fn tool_name, arguments, context -> result end`
  """
  @spec call([module()], String.t(), map(), map(), handler()) ::
          {:ok, Tool.result(), map()} | {:error, String.t()}
  def call([], tool_name, arguments, session, handler) do
    handler.(tool_name, arguments, session)
  end

  def call([middleware | rest], tool_name, arguments, session, handler) do
    next = fn next_name, next_args, next_session ->
      call(rest, next_name, next_args, next_session, handler)
    end

    middleware.call(tool_name, arguments, session, next)
  end
end
