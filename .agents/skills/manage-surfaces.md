---
name: manage-surfaces
description: Register, list, and monitor runtime surfaces (deployed services). Use when managing service registry entries (e.g., "register my app as a surface", "list surfaces", "check surface health status").
argument-hint: <register|list|unregister|health> [surface details]
synced_from_colony: true
sync_pack: deploy-local
sync_source: packs/deploy-local/manage-surfaces.md
sync_version: d3fefcef
---

# Manage Surfaces

Register and monitor runtime surfaces — deployed services exposed via Cloudflare Tunnel with automatic health monitoring.

## What Are Surfaces?

A surface is a running service (web app, API, Livebook instance) tracked for health monitoring. Each surface has:
- A **subdomain** (unique identifier and URL prefix)
- A **local port** where the service listens
- A **health endpoint** that gets polled periodically
- A **status** (`up`, `down`, or `unknown`) tracked in-memory

## Registering a Surface

Use the surface registration tool (e.g., `mcp__colony__register_surface` if available):

```
register_surface({
  name: "My App Dashboard",
  subdomain: "myapp",
  local_port: 4001,
  service_type: "phoenix",
  health_path: "/health",
  public_hostname: "myapp.example.com"
})
```

**Required parameters**:
- `name` — Display name for the surface
- `subdomain` — Unique identifier and URL prefix (e.g., `myapp`)
- `local_port` — Local port the service runs on (1-65535)
- `service_type` — One of: `livebook`, `phoenix`, `static`, `api`, `custom`

**Optional parameters**:
- `health_path` — Health check endpoint path (default: `/health`)
- `public_hostname` — Full Cloudflare Tunnel hostname (e.g., `myapp.example.com`)

**Upsert behavior**: If a surface with the same subdomain already exists in the same project, it is updated with the new values. Safe to call repeatedly.

**Cross-project uniqueness**: Subdomains are unique across all active projects. If another project already has a surface with the same subdomain, registration will fail with a conflict error.

**Validation checks**: After registration, the system checks:
- Whether a Cloudflare Tunnel ingress rule exists for the hostname (warns if missing or port mismatch)
- Whether the surface is reachable at `localhost:{port}{health_path}` (warns if connection refused)

### Service Types

| Type | When to use |
|------|-------------|
| `phoenix` | Phoenix/LiveView applications |
| `api` | REST or GraphQL API services |
| `livebook` | Livebook instances |
| `static` | Static file servers, documentation sites |
| `custom` | Anything that doesn't fit the above categories |

## Listing Surfaces

Use the surface listing tool (e.g., `mcp__colony__list_surfaces` if available):

```
list_surfaces()
```

Filter by health status:

```
list_surfaces({ status: "down" })
```

Returns each surface with its config fields plus current `status` and `last_checked_at` from the health monitor.

## Unregistering a Surface

Use the surface unregistration tool (e.g., `mcp__colony__unregister_surface` if available):

```
unregister_surface({ subdomain: "myapp" })
```

This will:
1. Remove the surface entry from the registry
2. Clear the in-memory health state from the health monitor
3. Make the subdomain available for other projects to register

After unregistering, remember to also clean up the Cloudflare Tunnel ingress rule if no longer needed.

## Health Monitoring

The system automatically polls each surface's health endpoint periodically. The health state includes:
- `status` — `up` (health check returned 2xx), `down` (health check failed), `unknown` (not yet checked)
- `last_checked_at` — When the last health check ran

Health state is **in-memory only** — not persisted to disk. On restart, all surfaces start as `unknown` until the first health check completes.

After consecutive failures, an investigative task may be created to diagnose the issue.

Health state is namespaced by project — each project's surfaces are tracked independently, preventing cross-project interference.

## Relationship to register-service Skill

- **manage-surfaces** (this skill): Manages the registry-side registration and monitoring. Handles surface config and health monitoring setup.
- **register-service**: Handles the full infrastructure setup — Cloudflare Tunnel ingress rules, DNS records, cloudflared restart, *and then* calls surface registration as the final step.

Use `register-service` when deploying a new service end-to-end. Use `manage-surfaces` when you need to inspect, update, or manage surfaces that are already deployed.

## Updating and Removing Surfaces

- **Update**: Call the registration tool again with the same subdomain — it upserts, so the existing entry is updated with new values.
- **Remove**: Use the unregistration tool to remove a surface. Do NOT edit the surfaces config file directly — always use the provided tools. This ensures schema validation and health monitor updates.
