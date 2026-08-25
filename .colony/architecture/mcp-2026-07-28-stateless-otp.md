# MCP 2026-07-28: Stateless Protocol, Stateful OTP

**Status:** Recommended architecture
**Date:** 2026-08-24
**Scope:** Tidal's Streamable HTTP server architecture

## Decision

Make Tidal's protocol and transport core stateless for MCP `2026-07-28`.
Do not replace `Mcp-Session-Id` with another implicit client or conversation key.

Keep OTP processes, but attach them to lifetimes that still exist in the new
protocol:

- one process for each HTTP request already exists in Plug/Bandit;
- a supervised worker may own an active request that streams progress;
- a long-lived `subscriptions/listen` request may own a subscription process;
- an explicit application handle may address a stateful actor;
- a durable task ID may address a supervised task state machine.

The new differentiator is therefore **a supervised process per active unit of
work or explicitly addressed state object**, not a process per implicit MCP
client session.

This remains a strong fit for Elixir. It is also a more precise fit than the
current per-session design because unrelated calls no longer serialize through
one client process, while calls that mutate the same explicit state handle can
still be serialized by one actor.

## What "stateless" means

MCP `2026-07-28` removes protocol-level sessions, `Mcp-Session-Id`, and the
initialization handshake. A server cannot infer version, capabilities, client
identity, or application context from an earlier request. Required protocol
metadata arrives on every request.

It does **not** prohibit application state. Cross-request state must be named
explicitly:

- an application object is referenced by a server-minted handle in ordinary
  tool arguments;
- an asynchronous task is referenced by `taskId`;
- an MRTR retry carries the original server state in `requestState`, or an
  explicit reference to protected server-side state;
- a subscription is scoped to the still-open `subscriptions/listen` request.

The handle is present on every related request, but the complete state does not
have to be loaded and deserialized on every request. A handle lookup may resolve
to a hot BEAM process. The requirement is that any listener which receives the
request can resolve that handle; process locality cannot be visible to the MCP
client.

The announcement's claim that ordinary requests can reach any instance without
shared storage applies to the protocol core. A tool that deliberately creates
application state must choose one of three application-level strategies:

1. Put small state in a signed or encrypted self-contained handle.
2. Store durable state in a database or external service and look it up by
   handle.
3. Route the handle inside a BEAM cluster to a state-owning process, optionally
   checkpointing durable state so another process can be rehydrated after node
   loss.

The third option preserves a plain round-robin HTTP load balancer. The receiving
node performs an internal handle-to-owner resolution; the external load
balancer does not need affinity.

## Current architecture assessment

### Critical: `Tidal.Session` is the protocol core

`Tidal.Plug` requires `Mcp-Session-Id` for every non-initialize request and
routes all messages through `Tidal.Session`. `Tidal.Session` stores negotiated
metadata, configuration, application assigns, subscriptions, and SSE
subscribers in one process. `Tidal.Protocol` then gates every method on the
session lifecycle (`lib/tidal/plug.ex:108`, `lib/tidal/session.ex:28`, and
`lib/tidal/protocol.ex:46`).

That entire control path is incompatible with `2026-07-28`. It should remain
only inside an optional `2025-11-25` compatibility adapter, not underneath the
new protocol implementation.

### Critical: session failure handling can replay a side-effecting tool

A tool currently executes synchronously inside `Session.handle_call/3`.
`Session.handle_message/2` converts any `GenServer.call` exit—including the
default five-second call timeout or a handler crash—into `:not_found`. The Plug
interprets that as an expired session, creates a replacement, performs a
synthetic handshake, and dispatches the original message again
(`lib/tidal/session.ex:189`, `lib/tidal/plug.ex:147`, and
`lib/tidal/plug.ex:366`).

This both serializes unrelated client work through one mailbox and risks
executing a side effect twice. The modern path must preserve distinct timeout,
crash, cancellation, and unknown-handle errors and must never transparently
replay a tool call.

### High: stream and subscription lifetimes are session-shaped

The current GET stream and `resources/subscribe`/`resources/unsubscribe`
implementation attach notification filters to a session. The new transport has
no GET endpoint. A client POSTs `subscriptions/listen`, and the response stream
itself owns the requested filters and lifetime.

The existing SSE receive loop is still useful, but it must be driven by a
request-scoped subscription struct/process and tag every notification with the
listen request ID.

### High: request context is named and modeled as mutable session state

Tool middleware and resource handlers receive the complete session map. The
middleware contract even permits returning updated state, but
`Tidal.Protocol.Tools` discards it (`lib/tidal/protocol/tools.ex:97`). For the
new protocol they should receive a typed, immutable `Tidal.RequestContext`
containing only per-request and deployment context: protocol version, declared
client capabilities, optional client info, auth principal, trace context,
server configuration, and request-scoped assigns.

Application state handles remain ordinary validated tool arguments. They must
not be silently injected from request context.

### High: multi-node correctness is currently local-only

The Registry, DynamicSupervisor, and ETS reconnect cache are local to one VM.
They cannot support round-robin requests across multiple instances. The
reconnect cache restores options rather than application state, so it also
creates a new hidden session whose semantics the client cannot rely on.

Delete reconnect behavior for the new protocol. If optional handle-addressed
actors are added, make their resolution strategy explicit and replaceable.

### Medium: catalog results lack new result and cache metadata

All successful results need `resultType: "complete"`. Discover and list/read
results also need `ttlMs` and `cacheScope`. Tool and resource catalogs must have
deterministic ordering and must not vary as a side effect of operating on an
application handle.

### Medium: the HTTP validation model has changed

Modern POSTs require both response media types in `Accept`, required per-request
metadata, and matching `MCP-Protocol-Version`, `Mcp-Method`, and where relevant
`Mcp-Name` headers. Tool schemas may require validated `Mcp-Param-*` mirrors via
`x-mcp-header`. The modern HTTP body is one request or notification, not a JSON-
RPC batch.

GET and DELETE return 405 for the modern protocol. `Mcp-Session-Id` and
`Last-Event-ID` are ignored. A broken response stream cancels its request; it is
not resumed.

## Proposed boundaries

```text
Tidal.Plug
  -> Transport.VersionRouter
       -> V2026_07_28.RequestValidator
       -> optional V2025_11_25.SessionAdapter
  -> Server
  -> RequestContext
  -> Protocol.Dispatcher
       -> stateless tool/resource/discovery handler
       -> request worker / response SSE stream
       -> subscription stream
       -> application-owned handle resolver
       -> durable task store + supervised task worker
```

### `Tidal.Server` and `Tidal.RequestContext`

Construct one immutable `Tidal.Server` value for a configured endpoint. It owns
server identity, supported versions, capabilities, validated and deterministically
ordered catalogs, middleware, and cache policy. This replaces the current split
between per-session module lists and the separate `Tidal.Registry` catalog.

Build `Tidal.RequestContext` from the current request and server. It is passed
to middleware and handlers but is never retained as an implicit conversation.
Suggested fields:

- protocol version and declared client capabilities;
- optional client implementation metadata and requested log level;
- authenticated principal/authorization context;
- W3C trace context;
- a reference to the immutable server configuration;
- request-scoped assigns derived from an explicit callback.

Replace `init_assigns` with a request-context builder callback so authorization
and tenant data are recomputed and verified for every request.

### Stateless handlers

For normal calls, execute in the Plug request process. Bandit already gives each
request an isolated BEAM process. Start a child under `Task.Supervisor` only when
Tidal needs an independently supervised or cancellable worker, such as an SSE
response that emits progress before its final result.

Do not create a GenServer for every ordinary request merely to preserve the old
shape. That adds a hop without adding a distinct lifetime.

### Explicit handle actors

Application state is outside the MCP core, but Tidal can later offer an optional
handle-resolution behaviour. It should support:

- opaque, cryptographically strong handle creation;
- `(handle, auth_context)` authorization on every operation;
- atomic `call`, explicit destroy, idle expiry, and useful expired errors;
- a local development implementation;
- a clustered router/store implementation selected by the host application.

Never expose a PID, node name, or routing topology as the public handle. On a
cluster, the handle resolves to an actor through a distributed directory or a
stable shard function. If the actor is only in memory, node loss may expire the
handle. If the state promises durability, checkpoint it and rehydrate the actor
on demand.

This is where OTP adds unusual value: one actor can serialize concurrent
mutations for one handle, supervision isolates failures, timers implement idle
expiry, and thousands or millions of unrelated handles remain concurrent.

### MRTR

Do not leave a process blocked while the client gathers input. Return
`resultType: "input_required"` and end the request.

The default `requestState` implementation should be a short-lived,
integrity-protected, self-contained envelope containing at least the auth
principal binding, method/argument digest, expiry, and continuation data. A
store-backed opaque reference is also valid, but every node must resolve it.
One-time effects require server-side replay protection even when the rest of
the envelope is self-contained.

### Tasks

Treat a task as a durable state machine with a hot process, not merely as a
process. The Tasks extension requires creation to be durable before returning
the task ID. Persist task status/result first, then supervise execution. Any
node must serve `tasks/get`, `tasks/update`, and `tasks/cancel`; a worker process
may be located or reconstructed from the durable record.

This store-plus-process design uses each technology for what it is good at:
the store provides identity, durability, and cross-node recovery; the process
provides serialized transitions, cancellation, timers, and failure isolation.

### Subscriptions

A `subscriptions/listen` POST is one long-lived request. Its connection process
or a supervised companion owns only that request's filter set. Event producers
publish through an application event bus; the stream filters and emits matching
notifications. On disconnect the subscription dies. On server failure the
client opens a new listen request. No resumption log is required.

The stream sends the required acknowledgment first, tags every subsequent
notification with the listen request ID, disables proxy buffering, and sends a
final completion result if the server closes it gracefully.

Across nodes, the event bus must reach the node holding the stream. This can be
distributed PubSub or an external broker depending on the host application's
delivery requirements. This is not sticky HTTP session routing.

## Version strategy

Use a clean protocol-version boundary at the transport edge.

- Build `2026-07-28` as the primary core.
- Keep the existing `2025-11-25` implementation only if Colony has clients that
  still need it, behind an explicit legacy adapter.
- Do not put optional lifecycle fields on one shared context or teach every
  handler to branch on "session versus stateless." Normalize only truly common
  tool/resource business operations behind version-specific wire adapters.
- Because Tidal is still pre-1.0, prefer removing the legacy adapter once known
  consumers migrate rather than making it a permanent architectural burden.

## Migration sequence

1. Introduce version-specific transport validation and a typed
   `RequestContext`; keep existing handlers operational through a narrow adapter.
2. Implement modern `server/discover`, per-request metadata, modern errors,
   `resultType`, deterministic catalogs, and cache hints.
3. Route modern requests directly to stateless protocol handlers. Remove modern
   dependence on `Tidal.Session`, the session Registry, and reconnect ETS.
4. Implement request-scoped SSE, cancellation, and `subscriptions/listen`.
5. Implement MRTR with protected `requestState`.
6. Add the Tasks extension only with a durable store contract.
7. Add optional handle-actor helpers after at least two real stateful tool
   integrations establish the common API.
8. Retire the legacy adapter when active clients no longer require it.

Each step is independently testable. In particular, integration tests should
send related calls to alternating server nodes and prove that:

- ordinary calls need no affinity or shared protocol state;
- explicit handles resolve on either node;
- concurrent calls for one handle serialize correctly;
- separate handles execute concurrently;
- acknowledged tasks survive worker/node restart;
- a disconnected SSE request cancels its worker;
- a listen stream can be reopened on another node.

## Premortem

The migration has failed if any of these are true:

1. A replacement "context ID" silently recreates one hidden session for every
   client or conversation.
2. A handle works only when the load balancer happens to return to the process's
   original node.
3. Tidal acknowledges a task before its durable record can be read from another
   node.
4. `tools/list` changes after a connect/create call, defeating the new cache
   contract.
5. Legacy and modern semantics are spread through every handler instead of
   being isolated at the transport/version boundary.

## Primary sources

- [MCP 2026-07-28 announcement](https://blog.modelcontextprotocol.io/posts/2026-07-28/)
- [2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)
- [Base protocol and statelessness](https://modelcontextprotocol.io/specification/2026-07-28/basic)
- [Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http)
- [Stateful tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools#stateful-tools)
- [Multi Round-Trip Requests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr)
- [Caching](https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching)
- [SEP-2567: explicit state handles](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/seps/2567-sessionless-mcp.md)
- [SEP-2575: stateless MCP](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/seps/2575-stateless-mcp.md)
- [SEP-2663: Tasks extension](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/seps/2663-tasks-extension.md)
