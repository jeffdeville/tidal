---
type: technical-overview
project: tidal
status: active
last_updated: 2026-08-25
---

# Technical Decisions & Constraints

## Runtime and dependencies

- Elixir 1.19+ and its corresponding OTP release.
- Plug and Bandit provide the Streamable HTTP boundary.
- Jason encodes JSON-RPC messages; NimbleOptions validates public protocol
  structures.
- Arena propagates process ownership and isolates async tests that create OTP
  processes.

## Version boundary

Tidal supports two protocol eras at the HTTP edge:

```text
Tidal.Plug
  └─ Transport.VersionRouter
      ├─ 2026-07-28 → Origin/Header validation → RequestContext → stateless dispatcher
      └─ 2025-11-25 → legacy Session GenServer and lifecycle dispatcher
```

Modern semantics do not leak into `Tidal.Session`, and legacy lifecycle state
does not leak into modern handlers. The compatibility path can therefore be
removed without redesigning the modern core.

## MCP 2026-07-28 architecture

`Tidal.Server` is immutable endpoint configuration: identity, capabilities,
catalogs, cache policy, middleware, and replaceable state/subscription
adapters. `Tidal.RequestContext` is reconstructed for every POST from required
request metadata, the current authenticated connection, trace fields, and an
optional context-builder callback.

Ordinary calls execute in independent Plug/Bandit request processes. There is
no initialize handshake, client process, session ID, reconnect cache, or
transparent replay on this path.

Longer-lived state is explicit and has the lifetime that owns it:

- `subscriptions/listen` keeps one response process alive with one accepted
  filter set;
- `Tidal.RequestState` carries signed, expiring, auth- and request-bound MRTR
  continuation data between independent requests;
- `Tidal.StateHandle` resolves an opaque application handle to a state actor or
  another configured store;
- a future Tasks extension must persist the task record before supervising a
  hot worker.

## OTP and load balancers

The modern protocol is stateless at its routing boundary, not prohibited from
using state internally. A load balancer may send consecutive requests to
different nodes because every request carries version and capability metadata.

For an explicitly stateful tool, the receiving node must resolve the handle.
The node-local defaults do not satisfy that promise across nodes. Production
systems that need it must configure a shared/durable `StateHandle.Resolver` and
a cross-node `SubscriptionBus`. A resolver may locate a hot process, route to
its owner, or rehydrate one from durable state. This retains BEAM concurrency
and per-object serialization without exposing node affinity to the client.

`Tidal.StateHandle.Local.Actor` uses `Arena.Process`; its Arena owner is
propagated into each spawned actor. This gives production a stable registry
owner and gives every async test an isolated owner and process namespace.

## Modern conformance and safety rails

- Each HTTP message is a new POST containing one request or notification.
- POST `Accept` includes both JSON and SSE response types.
- Protocol version, method, name, and annotated tool parameters are mirrored
  into validated HTTP headers.
- Present browser origins are rejected by default or checked against an
  explicit allowlist; the untrusted request host is not an allowlist.
- All modern result objects contain `resultType`; discover/list/read results
  contain cache scope and TTL.
- Tool/resource catalogs are deterministic and tool header annotations are
  validated at configuration time.
- Modern GET/DELETE return 405; session and replay headers are ignored.
- A tool crash is returned once and never interpreted as a reason to replay a
  side-effecting request.
- Locked HTTP dependencies must pass `mix hex.audit`.

## Testing

Changes use red-green TDD. Pure validation and state transitions have focused
tests; protocol features also receive Plug or real Bandit coverage. The real
listener subscription test verifies acknowledgment ordering, opt-in filtering,
SSE delivery, subscription IDs, and the absence of session headers.

The CI-compatible gates are warnings-as-errors compilation, formatter check,
high-priority Credo, and the complete ExUnit suite. Strict Credo currently has
pre-existing repository-wide design/readability debt and is not the CI gate.

## Current scope

Modern discovery, tools, resources/templates, MRTR, explicit state handles, and
subscriptions are implemented. Prompts, completions, and the optional durable
Tasks extension are not advertised by the modern server. The task extension
must not be added until a durable cross-node store contract and recovery tests
exist.

Primary decision record:
[`mcp-2026-07-28-stateless-otp.md`](../architecture/mcp-2026-07-28-stateless-otp.md).
