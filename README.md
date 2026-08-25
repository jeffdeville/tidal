# Tidal

Tidal is an Elixir library for building Model Context Protocol (MCP) servers
over Streamable HTTP. It supports the stateless MCP `2026-07-28` request model
and keeps a version-isolated `2025-11-25` compatibility path for clients that
still use initialization and `Mcp-Session-Id`.

The modern path creates a fresh, typed `Tidal.RequestContext` for every request.
It does not require load-balancer affinity, but it still lets applications use
the BEAM for explicit, long-lived state: a client carries an opaque state
handle, and a replaceable resolver routes each request to the appropriate actor
or durable record.

## Installation

Add `tidal` to your dependencies:

```elixir
def deps do
  [
    {:tidal, "~> 0.1"}
  ]
end
```

Until the stateless transport release is published to Hex, test this branch
directly from GitHub:

```elixir
{:tidal, github: "jeffdeville/tidal", branch: "feat/mcp-2026-07-28"}
```

Tidal requires Elixir 1.19 or later.

## Getting started

Define a module implementing `Tidal.Tool`. Tool definitions are built once
when the Plug is initialized; calls run concurrently in their HTTP request
processes.

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

Mount Tidal in a Phoenix router:

```elixir
forward "/mcp", Tidal.Plug,
  tool_modules: [MyApp.Tools],
  server_info: %{name: "my-app", version: "1.0.0"},
  allowed_origins: ["https://app.example.com"]
```

Or run it without Phoenix:

```elixir
{:ok, _server} =
  Bandit.start_link(
    plug:
      {Tidal.Plug,
       [
         tool_modules: [MyApp.Tools],
         server_info: %{name: "my-app", version: "1.0.0"}
       ]},
    ip: :loopback,
    port: 4000
  )
```

Discover the endpoint without a handshake or session:

```sh
curl http://localhost:4000/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2026-07-28' \
  -H 'Mcp-Method: server/discover' \
  --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"server/discover",
    "params":{"_meta":{
      "io.modelcontextprotocol/protocolVersion":"2026-07-28",
      "io.modelcontextprotocol/clientCapabilities":{},
      "io.modelcontextprotocol/clientInfo":{"name":"curl","version":"1.0.0"}
    }}
  }'
```

The request above targets the Phoenix `/mcp` mount. Use
`http://localhost:4000/` for the direct Bandit example.

Modern requests repeat the protocol version and client capabilities in
`params._meta`. They also send `Mcp-Method`, matching the JSON-RPC method, and
send `Mcp-Name` for `tools/call`, `resources/read`, and `prompts/get`. If a
tool schema uses `x-mcp-header`, the corresponding argument is mirrored in an
`Mcp-Param-*` header and Tidal validates that the two values agree.

## Resources

Implement `Tidal.Resource` to expose fixed resources and URI templates:

```elixir
defmodule MyApp.Resources do
  @behaviour Tidal.Resource

  alias Tidal.Protocol.{Resource, ResourceTemplate, TextResourceContents}

  @impl true
  def define_resources do
    [
      Resource.new!(uri: "status://current", name: "Current status"),
      ResourceTemplate.new!(uri_template: "users://{id}", name: "User")
    ]
  end

  @impl true
  def handle_read_resource("status://current" = uri, _context) do
    {:ok, [%TextResourceContents{uri: uri, text: "healthy", mime_type: "text/plain"}]}
  end

  def handle_read_resource("users://" <> id = uri, context) do
    case MyApp.Accounts.fetch_visible_user(context.auth_context, id) do
      {:ok, user} ->
        {:ok, [%TextResourceContents{uri: uri, text: Jason.encode!(user), mime_type: "application/json"}]}

      :error ->
        {:error, :not_found}
    end
  end
end
```

Add `resource_handlers: [MyApp.Resources]` to the Plug options.

## Authentication and request context

Authenticate before forwarding to Tidal and store the current principal in
`conn.assigns.tidal_auth_context`. Tidal copies it into every
`Tidal.RequestContext`; state handles and request-state tokens bind themselves
to that value.

Use `:context_builder` for request-scoped dependencies such as account IDs,
feature flags, or trace metadata:

```elixir
context_builder = fn conn, metadata ->
  {:ok,
   %{
     account_id: conn.assigns.current_account.id,
     client_info: metadata.client_info
   }}
end

Tidal.Plug.init(
  tool_modules: [MyApp.Tools],
  context_builder: context_builder
)
```

The builder receives the current `Plug.Conn` and validated request metadata. It
must return a map, `{:ok, map}`, or `{:error, reason}`. Its result is available
as `context.assigns` and is never retained as an implicit client session.

## Server options

`Tidal.Plug.init/1` accepts the following modern options:

| Option | Default | Purpose |
| --- | --- | --- |
| `:tool_modules` | `[]` | Modules implementing `Tidal.Tool` |
| `:resource_handlers` | `[]` | Modules implementing `Tidal.Resource` |
| `:server_info` | Tidal name/version | MCP server `name` and `version` |
| `:instructions` | `nil` | Agent-facing server instructions |
| `:capabilities` | derived | Additional or overriding server capabilities |
| `:middleware` | `[]` | `Tidal.Tool.Middleware` modules, in call order |
| `:cache` | `[ttl_ms: 0, scope: :private]` | Discovery and result cache metadata |
| `:context_builder` | `nil` | Rebuilds application assigns for every request |
| `:allowed_origins` | `[]` | Exact HTTP(S) browser origins allowed to connect |
| `:request_state_secret` | `nil` | At least 32 bytes; signs multi-round-trip state |
| `:state_resolver` | `Tidal.StateHandle.Local` | Resolver for explicit application-state handles |
| `:subscription_bus` | `Tidal.Subscriptions.Local` | Bus for modern subscription notifications |

An absent `Origin` is accepted for non-browser clients. The default empty
allowlist rejects every request that carries `Origin`; list the exact browser
origins that may reach the endpoint. Tidal does not infer a trusted origin from
`Host`, because doing so would weaken DNS-rebinding protection.

## Explicit state, not implicit sessions

Stateless MCP means that a modern request cannot depend on an earlier protocol
negotiation or an implicit `Mcp-Session-Id`. It does not mean your application
must be stateless.

A tool can create and return an opaque handle:

```elixir
def handle_tool_call("start_cart", _arguments, context) do
  with {:ok, handle} <- Tidal.StateHandle.create(context, %{items: []}) do
    {:ok, text_result(handle)}
  end
end

def handle_tool_call("add_item", %{"handle" => handle, "sku" => sku}, context) do
  with {:ok, item_count} <-
         Tidal.StateHandle.transact(context, handle, fn cart ->
           cart = update_in(cart.items, &[sku | &1])
           {:ok, cart, length(cart.items)}
         end) do
    {:ok, text_result("items=#{item_count}")}
  end
end
```

The handle is explicit client-carried data. Every operation is authorized using
the current request's `auth_context`. The built-in resolver runs one
Arena-aware GenServer per live handle and expires it after 30 idle minutes; pass
`idle_timeout: milliseconds` to `Tidal.StateHandle.create/3` to change that for
a handle.

`Tidal.StateHandle.Local` is intentionally node-local and non-durable. It is a
good fit for development, a single BEAM node, and state whose loss is acceptable.

## Multi-round-trip requests

When a tool needs elicitation, sampling, or roots input, it should finish the
current request and ask the client to retry rather than leave a process waiting:

```elixir
{:ok, request_state} =
  Tidal.RequestState.sign(context, %{"step" => "confirm"}, expires_in_ms: 120_000)

{:ok,
 Tidal.Protocol.InputRequiredResult.new!(
   input_requests: %{
     "confirmation" => %{
       "method" => "elicitation/create",
       "params" => %{
         "message" => "Continue?",
         "requestedSchema" => %{"type" => "boolean"}
       }
     }
   },
   request_state: request_state
 )}
```

Configure the same `:request_state_secret` of at least 32 bytes on every node.
On retry, verify `context.request_state` with `Tidal.RequestState.verify/2` and
read `context.input_responses`. Tokens are signed, expire after five minutes by
default, and are bound to both the authorization context and original request.
No server process remains alive between trips.

## Deployment

### One node

For a small deployment, run Tidal inside your Phoenix release or as a Bandit
child behind the same TLS-terminating proxy as the rest of your application.
The defaults are sufficient when state handles and open subscription streams
may disappear during a deploy:

```elixir
children = [
  {Bandit,
   plug:
     {Tidal.Plug,
      [
        tool_modules: [MyApp.Tools],
        resource_handlers: [MyApp.Resources],
        allowed_origins: ["https://app.example.com"],
        request_state_secret: System.fetch_env!("TIDAL_REQUEST_STATE_SECRET")
      ]},
   port: 4000}
]
```

Keep authentication in a Plug before Tidal, terminate TLS at the endpoint or
proxy, restrict `:allowed_origins`, and source the request-state secret at
runtime. A restart invalidates local state handles and closes subscription
streams; clients can reconnect streams, but applications must decide how to
recover lost handle state.

### Multiple nodes or regions

Round-robin load balancing works for ordinary calls because every request is
self-describing. The stateful features have explicit distribution boundaries:

| Feature | What every node needs |
| --- | --- |
| Tools and resources | The same immutable catalog and application code |
| Multi-round-trip tokens | The same request-state signing secret |
| State handles | A shared/distributed `Tidal.StateHandle.Resolver` |
| Subscription streams | A shared/distributed `Tidal.SubscriptionBus` |

There is still substantial value in BEAM processes at scale. A resolver can
maintain one hot actor per handle, route any incoming request to the actor's
current owner, checkpoint durable state, and rehydrate the actor after node
loss. The protocol stays stateless at the HTTP boundary while the application
uses supervised state internally.

Configure adapters as a module or `{module, options}` tuple:

```elixir
Tidal.Plug.init(
  tool_modules: [MyApp.Tools],
  state_resolver: {MyApp.ClusteredStateResolver, repo: MyApp.Repo},
  subscription_bus: {MyApp.DistributedSubscriptionBus, pubsub: MyApp.PubSub},
  request_state_secret: System.fetch_env!("TIDAL_REQUEST_STATE_SECRET")
)
```

Implement `Tidal.StateHandle.Resolver` so every callback authenticates the
current principal and resolves a public handle through a durable record or
distributed directory. Implement `Tidal.SubscriptionBus` so a publisher on any
node can reach the process holding the matching open HTTP stream. With those
adapters, sticky sessions are unnecessary.

Deploy secret rotations with an overlap window or versioned verifier if active
multi-round-trip tokens must survive a rotation. Do not advertise durable
semantics unless the resolver actually checkpoints state and can recover it.

## Subscriptions

Modern clients open a dedicated `subscriptions/listen` POST stream with the
notification classes and resource URIs they want. Publish changes with:

```elixir
Tidal.Subscriptions.tools_changed()
Tidal.Subscriptions.resources_list_changed()
Tidal.Subscriptions.resource_updated("status://current")
```

Pass the configured bus tuple as the last argument when using a custom bus.
The local bus keeps no subscriber process beyond the life of its HTTP stream.

## Legacy compatibility

Requests using `2025-11-25` continue through the handshake-era compatibility
path with `initialize`, `Mcp-Session-Id`, GET event streams, and DELETE session
termination. New integrations should use `2026-07-28`; legacy sessions are
isolated from the modern state-handle and request-context model.

The optional Tasks extension is not advertised or implemented. Correct Tasks
semantics require a durable, cross-node store; an in-memory process would imply
durability the server cannot provide.

## Development and documentation

```sh
mix deps.get
mix precommit
mix docs
```

Generated documentation is written to `doc/index.html`. The test suite uses
Arena for ownership-aware process registration and async isolation; processes
spawned by application code should propagate the current `Arena.Config` in the
same way as Tidal's built-in state actors.

Before publishing to Hex, the project still needs an explicit open-source
license and Arena must be available as a Hex dependency (or the packaging
strategy must change). Neither release decision is hidden behind conditional
runtime behavior.
