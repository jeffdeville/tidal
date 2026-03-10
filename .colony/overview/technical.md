---
type: technical-overview
project: tidal
status: active
last_updated: 2026-03-09
---

# Technical Decisions & Constraints

## Language & Runtime

- **Elixir 1.19+** (latest stable, no backward compat for older versions yet)
- **OTP**: Whatever ships with Elixir 1.19
- **Package format**: Hex package (`:tidal`)

## Core Dependencies

| Dependency | Purpose |
|---|---|
| Plug | HTTP endpoint abstraction |
| Bandit | HTTP server (Plug adapter) |
| Jason | JSON encoding/decoding |
| NimbleOptions | Option/configuration validation |

## Architecture — LiveView-Inspired Sessions

```
┌─────────────────────────────────────────────┐
│              Tidal.Supervisor               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │ Tidal.Plug  │  │ Tidal.SessionSupervisor│
│  │ (HTTP entry)│  │  (DynamicSupervisor) │   │
│  └──────┬──────┘  └──────────┬──────────┘   │
│         │                    │              │
│         │    ┌───────────────┼───────────┐  │
│         │    │               │           │  │
│         ▼    ▼               ▼           ▼  │
│      ┌──────────┐  ┌──────────┐  ┌──────────┐
│      │ Session  │  │ Session  │  │ Session  │
│      │ GenServer│  │ GenServer│  │ GenServer│
│      │ (client1)│  │ (client2)│  │ (client3)│
│      └──────────┘  └──────────┘  └──────────┘
│                                             │
└─────────────────────────────────────────────┘
```

Each MCP client session maps to a supervised GenServer process:
- Session created on `InitializeRequest`
- Identified by `Mcp-Session-Id` header
- Holds per-client state (capabilities, subscriptions, roots, progress)
- Terminated on explicit DELETE or timeout
- Crash-isolated: one session failure doesn't affect others

## Data Modeling Constraints

- **Structs over maps**: All protocol messages, capabilities, and internal state must be
  represented as structs, not bare maps
- **Changesets for validation**: Use Ecto-style changesets (likely via embedded schemas
  or a lightweight changeset library) for building and validating protocol structures
- **NimbleOptions**: All public-facing option lists must be validated with NimbleOptions
  schemas — no untyped keyword lists at API boundaries

## Testing Philosophy

- **Integration-first**: The primary test strategy is integration tests that exercise
  real HTTP requests through the full Plug/Bandit stack
- **Spec conformance**: Tests should verify behavior against the MCP specification,
  not just implementation details
- **No unit-test-only shortcuts**: Unit tests are acceptable for pure functions, but
  every protocol feature must have integration coverage
- **Property-based testing**: Consider for JSON-RPC message parsing and edge cases

## Spec Reference

- **Protocol version**: `2025-11-25`
- **Spec URL**: https://modelcontextprotocol.io/specification/2025-11-25/
- **Transport spec**: https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
  (Streamable HTTP defined here, carried forward into 2025-11-25)

## Key Spec Compliance Points

### Streamable HTTP Transport
- Single MCP endpoint supporting POST and GET
- POST: client sends JSON-RPC messages; server responds with `application/json` or
  `text/event-stream`
- GET: client opens SSE stream for server-initiated messages
- `Mcp-Session-Id` header for session tracking
- `Accept` header must include both `application/json` and `text/event-stream`
- Notifications/responses return 202 Accepted (no body)
- Origin header validation (DNS rebinding protection)
- Resumability via SSE event IDs and `Last-Event-ID`

### Session Lifecycle
- Session created at initialization, identified by `Mcp-Session-Id`
- Session ID must be globally unique and cryptographically secure
- 404 response when session is terminated/expired
- Client DELETE to explicitly end session
- Server may terminate sessions at any time

### JSON-RPC 2.0
- Full request/response/notification support
- Batch support (arrays of requests/notifications/responses)
- Error codes per spec
