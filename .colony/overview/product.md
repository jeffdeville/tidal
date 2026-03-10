---
type: product-overview
project: tidal
status: active
last_updated: 2026-03-09
---

# Tidal — Elixir MCP Server Library

## Vision

Tidal is an Elixir Hex package for building MCP (Model Context Protocol) servers.
It implements the full MCP 2025-11-25 specification with a focus on the Streamable HTTP
transport, giving each connecting client its own supervised server session — inspired by
Phoenix LiveView's per-connection process model.

## Problem

Existing Elixir MCP libraries (e.g., Hermes MCP) funnel all client connections through
a single GenServer process. This creates a bottleneck, prevents per-client state isolation,
and doesn't leverage the BEAM's natural concurrency model. The MCP spec explicitly
supports stateful per-client sessions via `Mcp-Session-Id`, but current libraries don't
take advantage of this.

## Solution

Tidal provides a per-session GenServer architecture where:

- Each connecting MCP client gets its own supervised process
- Session state is isolated, just like a LiveView socket
- The BEAM's supervision tree ensures fault tolerance per session
- The Streamable HTTP transport is first-class, built on Plug/Bandit

## Target Users

- **Primary (initial)**: The Colony project — an existing Phoenix application that needs
  MCP server capabilities
- **Secondary (future)**: Any Elixir developer wanting to expose MCP tools, resources,
  or prompts from their application

## Spec Coverage

Full implementation of the MCP 2025-11-25 specification:

### Core Protocol
- JSON-RPC 2.0 message encoding (UTF-8)
- Request/response, notifications, batching
- Lifecycle: initialize, initialized, ping, shutdown

### Transport
- Streamable HTTP (POST for client→server, GET for server→client SSE)
- Session management via `Mcp-Session-Id`
- Resumability and redelivery (SSE event IDs, `Last-Event-ID`)
- Multiple simultaneous SSE connections per session
- Backwards compatibility with legacy HTTP+SSE transport (2024-11-05)
- Origin header validation, localhost binding, authentication

### Server Features
- Tools (definition, listing, invocation, annotations)
- Resources (definition, listing, reading, subscriptions, templates)
- Prompts (definition, listing, retrieval, argument completion)
- Logging (level control, log message notifications)
- Sampling (server-initiated LLM requests to the client)
- Roots (client workspace roots)
- Elicitation (requesting user input via the client)
- Completion (argument auto-complete for resources and prompts)
- Tasks (async request tracking, polling, deferred results)
- Pagination (cursor-based, for list operations)
- Cancellation (`CancelledNotification`)
- Progress tracking (`ProgressNotification`)
- Extension framework (optional capability discovery)

## Non-Goals (for now)

- stdio transport (Streamable HTTP only for initial release)
- MCP client implementation (server-only library)
- Backward compatibility with Elixir versions < 1.19

## License

MIT
