# Tidal

Tidal is an Elixir MCP (Model Context Protocol) server library. It implements the MCP 2025-11-25 spec with Streamable HTTP transport, per-session process isolation, and a declarative tool definition macro (`defop`).

## Build & Development Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/tidal/tool/operation_test.exs

# Run a specific test by line number
mix test test/tidal/tool/operation_test.exs:42

# Compile with warnings as errors
mix compile --warnings-as-errors

# Format code
mix format

# Quality checks (format + credo)
mix quality

# Pre-commit checks (compile, format, credo, test)
mix precommit

# CI test with coverage (90% threshold)
mix ci.test
```

## Architecture Overview

```
Tidal.Supervisor
├── Registry (SessionRegistry) — tracks session PIDs
└── DynamicSupervisor (SessionSupervisor)
    ├── Session GenServer (client 1, idle timeout 30m)
    ├── Session GenServer (client 2)
    └── ...
```

Each MCP client gets its own isolated GenServer session. No shared state between sessions.

### Key Modules

| Module | Purpose |
|--------|---------|
| `Tidal.Plug` | HTTP endpoint — POST (JSON-RPC), GET (SSE), DELETE (terminate) |
| `Tidal.Session` | Per-client GenServer with lifecycle state machine |
| `Tidal.Protocol` | Request/notification dispatch based on method + lifecycle state |
| `Tidal.Protocol.Lifecycle` | initialize, initialized, ping, shutdown handlers |
| `Tidal.Protocol.Tools` | tools/list, tools/call — discovery and invocation |
| `Tidal.Protocol.Resources` | resources/list, read, templates, subscribe |
| `Tidal.Tool` | Behaviour for tool modules (`define_tools/0`, `handle_tool_call/3`) |
| `Tidal.Tool.Operation` | `defop` macro for declarative tool definitions |
| `Tidal.Tool.SchemaBuilder` | Converts param declarations to JSON Schema |
| `Tidal.Tool.ErrorSpec` | Structured error catalog entries |
| `Tidal.Tool.Middleware` | Behaviour for pluggable tool dispatch hooks |
| `Tidal.Tool.Pipeline` | Executes middleware chain around tool handler |
| `Tidal.Registry` | Queryable catalog of all registered tool operations |
| `Tidal.Checks.NoNestedCase` | Custom Credo check: flags nested `case` statements |
| `Tidal.Resource` | Behaviour for resource modules |
| `Tidal.JSONRPC` | JSON-RPC 2.0 encode/decode |

### Session Lifecycle

```
:created → :initializing → :ready → :shutting_down
```

- `initialize` request transitions `:created` → `:initializing`
- `notifications/initialized` transitions `:initializing` → `:ready`
- `shutdown` request transitions to `:shutting_down`
- Sessions auto-terminate after 30min inactivity (configurable)

### Defining Tools

Two approaches — both implement `Tidal.Tool` behaviour:

**Manual (raw JSON Schema):**
```elixir
defmodule MyTools do
  @behaviour Tidal.Tool

  def define_tools do
    [Tool.new!(name: "echo", input_schema: %{...})]
  end

  def handle_tool_call("echo", args, session) do
    {:ok, %ToolResult{content: [%TextContent{text: args["message"]}]}}
  end
end
```

**Declarative (`defop` macro):**
```elixir
defmodule MyTools do
  use Tidal.Tool.Operation

  defop :echo do
    desc("Echoes back the message")
    param(:message, :string, required: true, desc: "The message")

    success do
      field(:echoed, :string)
    end

    error(:empty, 400, retryable: false, desc: "Message was empty")
    guidance("Call this to test connectivity.")
  end

  @impl true
  def execute(:echo, %{message: msg}, _session) do
    if msg == "", do: {:error, :empty}, else: {:ok, %{echoed: msg}}
  end
end
```

`defop` auto-generates JSON Schema, tool definitions, structured error formatting,
and introspection functions (`__tidal_operations__/0`, `__tidal_errors__/1`).

### Middleware

Pluggable before/after hooks on tool dispatch. Middleware wraps the tool handler:

```elixir
defmodule MyApp.Middleware.Logger do
  @behaviour Tidal.Tool.Middleware

  @impl true
  def call(tool_name, arguments, session, next) do
    Logger.info("Calling: #{tool_name}")
    {:ok, result, session} = next.(tool_name, arguments, session)
    Logger.info("Done: #{tool_name}")
    {:ok, result, session}
  end
end

# Configure per-session:
Session.start(tool_modules: [MyTools], middleware: [MyApp.Middleware.Logger])
```

Middleware can modify arguments, short-circuit calls, or transform results.
First in the list = outermost (runs first on the way in, last on the way out).

## Code Style

- Max line length: 120 characters
- Use `with` for sequential fallible operations (no nested `case`)
- Predicate functions end with `?`
- All tests `async: true` unless they share global state
- 90% minimum test coverage enforced

## Testing

```bash
mix test                    # Run all tests
mix test --trace            # Verbose output
mix coveralls.html          # Coverage report in cover/
```

Tests exercise the full stack: JSON-RPC encoding → Protocol dispatch → Session GenServer → HTTP transport.
