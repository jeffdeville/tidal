# Tidal

Tidal is an Elixir library for building Model Context Protocol servers over
Streamable HTTP. It implements the stateless MCP `2026-07-28` request model and
keeps a version-isolated compatibility path for handshake-era `2025-11-25`
clients.

The modern path rebuilds a typed `Tidal.RequestContext` from every request. It
does not create an implicit client session, require load-balancer affinity, or
replay a tool call after a process failure.

## Modern server

Define tools using the `Tidal.Tool` behaviour:

```elixir
defmodule MyApp.Tools do
  @behaviour Tidal.Tool

  alias Tidal.Protocol.{TextContent, Tool, ToolResult}

  @impl true
  def define_tools do
    [
      Tool.new!(
        name: "echo",
        description: "Echo a message",
        input_schema: %{
          "type" => "object",
          "properties" => %{"message" => %{"type" => "string"}},
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
```

Mount the Plug in Phoenix or start it directly with Bandit:

```elixir
forward "/mcp",
  Tidal.Plug,
  tool_modules: [MyApp.Tools],
  server_info: %{name: "my-app", version: "1.0.0"},
  allowed_origins: ["https://app.example.com"],
  cache: [ttl_ms: 5_000, scope: :private]
```

Modern POSTs carry the protocol version and client capabilities in every
request's `params._meta`. The HTTP request must also include:

- `Content-Type: application/json`
- `Accept: application/json, text/event-stream`
- `MCP-Protocol-Version: 2026-07-28`
- `Mcp-Method`, matching the JSON-RPC method
- `Mcp-Name` for `tools/call`, `resources/read`, and `prompts/get`

An absent `Origin` is accepted for non-browser clients. The default empty
allowlist rejects every request that carries `Origin`; configure
`:allowed_origins` with the exact browser origins that should reach the MCP
endpoint. Tidal does not infer a trusted origin from the request `Host` header,
because doing that would defeat DNS-rebinding protection.

## State without protocol sessions

Stateless MCP means a request cannot depend on an earlier negotiation or an
implicit `Mcp-Session-Id`. It does not prohibit application state.

- Ordinary calls execute concurrently in their Plug/Bandit request processes.
- `Tidal.StateHandle` gives a tool an explicit opaque handle for related state.
- `Tidal.RequestState` signs short-lived MRTR continuation data and binds it to
  both the authorization context and original request.
- `subscriptions/listen` owns one long-lived response process and only the
  filters accepted for that stream.

`Tidal.StateHandle.Local` and `Tidal.Subscriptions.Local` are deliberately
node-local defaults. They use OTP processes efficiently and are useful for a
single BEAM node, but they do not claim durability. A round-robin multi-node
deployment must configure a `Tidal.StateHandle.Resolver` backed by a shared or
distributed directory, and a `Tidal.SubscriptionBus` that reaches every node.
The public handle remains stable while the resolver may route it to a hot actor
or rehydrate one from durable storage.

Tidal uses [Arena](https://github.com/jeffdeville/arena) for ownership-aware
process registration and async test isolation. Any process spawned from a
request must carry the current Arena configuration; the built-in handle actors
already do this.

## Multi-round-trip requests

A handler can end a request and ask the client for elicitation, sampling, or
roots input:

```elixir
{:ok, request_state} = Tidal.RequestState.sign(context, %{"step" => "confirm"})

{:ok,
 Tidal.Protocol.InputRequiredResult.new!(
   input_requests: %{
     "confirmation" => %{
       "method" => "elicitation/create",
       "params" => %{"message" => "Continue?", "requestedSchema" => %{"type" => "boolean"}}
     }
   },
   request_state: request_state
 )}
```

Configure a deployment secret of at least 32 bytes with
`:request_state_secret`. The client retries the original call with
`requestState` and `inputResponses`; no server process waits between trips.

## Current modern coverage

The `2026-07-28` path includes discovery, tools, resources and templates,
cache/result metadata, explicit state handles, protected MRTR continuation,
and request-scoped subscriptions. It rejects batches and client-sent JSON-RPC
responses as required by the modern HTTP transport.

The optional Tasks extension is not advertised or implemented. Its correctness
depends on a durable, cross-node store contract; an in-memory task process would
give misleading durability semantics. The legacy `2025-11-25` session path
remains available during migration.
