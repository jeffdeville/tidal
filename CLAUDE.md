# Tidal — Elixir MCP Server Library

## Quick Reference

- **Package**: `:tidal` (Hex)
- **Elixir**: 1.19+
- **Spec**: MCP 2025-11-25
- **License**: MIT
- **Deps**: Plug, Bandit, Jason, NimbleOptions

## Architecture

Per-session GenServer model inspired by Phoenix LiveView:
- Each MCP client gets its own supervised GenServer process
- DynamicSupervisor manages session lifecycle
- Sessions identified by cryptographically secure `Mcp-Session-Id` header
- Crash isolation: one session failure never affects others

## Style Guide

**When in doubt, follow what Phoenix does.**

- Phoenix-style supervision trees
- Phoenix-style callback patterns (behaviours)
- Phoenix-style documentation

## Constraints

1. **Structs, not maps** — All protocol messages and public API types must be structs. No bare maps at API boundaries.
2. **NimbleOptions everywhere** — All public option lists must have NimbleOptions schemas.
3. **Integration-first testing** — Every protocol feature needs integration tests through real HTTP (Plug/Bandit). Unit-only coverage is insufficient.
4. **Spec fidelity** — Respect MUST/SHOULD/MAY semantics from MCP 2025-11-25.

## Testing

- Integration tests exercise real HTTP through Plug/Bandit
- Spec conformance tests verify against MCP 2025-11-25 documented behavior
- Test coverage ratchet targets 90%
- Use `async: true` wherever possible

## v1 Scope

**In scope**: JSON-RPC 2.0, Streamable HTTP transport, per-session GenServer, tools, resources, progress, cancellation, developer behaviours/callbacks.

**Out of scope**: Prompts, sampling, elicitation, tasks (async polling), resumability, pagination, completion, extension framework, multi-node, legacy HTTP+SSE, stdio, MCP client.

## Spec References

- MCP spec: https://modelcontextprotocol.io/specification/2025-11-25/
- Transport spec: https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
- TypeScript schema: https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts
