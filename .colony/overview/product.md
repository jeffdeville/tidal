---
type: product-overview
project: tidal
status: active
last_updated: 2026-08-25
---

# Tidal — Elixir MCP Server Library

## Vision

Tidal is an Elixir library for building Model Context Protocol servers over
Streamable HTTP. Its primary target is MCP `2026-07-28`: independently routable
requests with explicit application state, rather than implicit per-client
protocol sessions.

## Problem

The handshake-era design mapped each client to one GenServer. That was a good
fit for older `Mcp-Session-Id` semantics, but it serializes unrelated work,
depends on affinity or local reconnect behavior, and can confuse a process
failure with an expired session. In the old HTTP path that confusion could
replay a side-effecting tool call.

MCP `2026-07-28` removes initialization and protocol sessions. Every request
carries the version and capabilities needed to process it, enabling normal
round-robin load balancing. Stateful application workflows still need explicit
identity, authorization, concurrency control, and sometimes durability.

## Product approach

Tidal separates those concerns:

- stateless protocol requests execute concurrently in independent BEAM
  processes;
- typed request context is rebuilt and authorized on every call;
- an explicit opaque handle can resolve to a supervised state actor;
- MRTR state travels in a protected, expiring continuation;
- one `subscriptions/listen` response owns one long-lived notification stream;
- replaceable resolver and event-bus boundaries let a deployment add
  cross-node routing or durable storage without changing MCP-visible handles.

This makes Elixir valuable at the correct granularity: a process per active
request, stream, task worker, or explicitly addressed state object—not a hidden
process per client conversation.

## Current modern coverage

- `server/discover` and per-request version/capability metadata
- tools listing and invocation
- resources listing, templates, reads, and update subscriptions
- deterministic catalogs and cache metadata
- HTTP header/body validation, custom parameter headers, and Origin validation
- complete and input-required result types
- protected MRTR request state
- local Arena-aware application state actors behind a replaceable resolver
- request-scoped SSE subscriptions behind a replaceable event bus
- isolated legacy `2025-11-25` compatibility path

Prompts, completions, and the optional Tasks extension are outside the current
modern implementation. Tasks specifically require a durable store and
cross-node recovery semantics before Tidal should advertise support.

## Target users

- Colony and other Phoenix applications exposing MCP capabilities.
- Elixir teams that need high concurrency, supervised work, and explicit
  stateful workflows behind ordinary load balancers.

## Non-goals

- Hiding node-local state behind an unreliable implicit routing key.
- Claiming durability for an in-memory process.
- A client implementation or stdio transport in the current release.
- Backward compatibility with Elixir versions before 1.19.

## License

MIT
