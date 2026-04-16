---
name: register-service
description: Register a service with Cloudflare Tunnel routing and optional surface monitoring. Use when deploying a project service that needs a subdomain (e.g., "register my Phoenix app on port 4000 as myapp").
argument-hint: '<subdomain> <port> [service-type] [health-path]'
disable-model-invocation: true
allowed-tools: [Bash, Read, Edit, Write]
synced_from_colony: true
sync_pack: deploy-local
sync_source: packs/deploy-local/register-service.md
sync_version: d3fefcef
---

# Register Service with Cloudflare Tunnel

Register a project service with Cloudflare Tunnel routing and optional runtime surface monitoring.

**Input**: $ARGUMENTS

Parse the following from the input (ask if missing):
- **subdomain** (required): The subdomain prefix (e.g., `myapp`)
- **local_port** (required): The local port the service listens on (e.g., `4000`)
- **service_type** (optional, default: `custom`): One of `livebook`, `phoenix`, `static`, `api`, `custom`
- **health_path** (optional, default: `/`): Health check endpoint path

## Prerequisites

Before running this skill, ensure:
1. **cloudflared is installed and running** with a configured tunnel
2. **The cloudflared config file exists** at `~/.cloudflared/config.yml`
3. **The domain is configured in Cloudflare DNS**

## Step 1: Determine the Domain

Check the existing cloudflared config to find the domain in use:

```bash
grep 'hostname:' ~/.cloudflared/config.yml | head -1 | sed 's/.*hostname: [^.]*\.//' | tr -d ' '
```

This extracts the domain from existing ingress rules. If no rules exist, ask the user for their domain.

## Step 2: Add Ingress Rule to cloudflared Config

Read the current config, add a new ingress rule before the catch-all:

```bash
# Check if the subdomain already has a rule
grep -q "{subdomain}" ~/.cloudflared/config.yml
```

If no existing rule, add one. The ingress rule should be inserted **before** the final `- service: http_status:404` catch-all line:

```yaml
  - hostname: {subdomain}.{domain}
    service: http://localhost:{local_port}
```

**Important**: The catch-all `- service: http_status:404` MUST remain the last entry.

### Error Handling — Config

- **Config file not found**: cloudflared is not configured. Tell the user:
  > cloudflared config not found at `~/.cloudflared/config.yml`. Run `cloudflared tunnel login` and `cloudflared tunnel create <tunnel-name>` first.

- **Tunnel not running**: If the tunnel process is not active:
  > cloudflared tunnel is not running. Start it with `cloudflared tunnel run` or `sudo systemctl start cloudflared`.

- **Subdomain already exists**: The rule may need updating. Show the existing rule and ask if the user wants to update the port.

## Step 3: Create DNS Record

```bash
TUNNEL_NAME=$(grep '^tunnel:' ~/.cloudflared/config.yml | awk '{print $2}')
cloudflared tunnel route dns "$TUNNEL_NAME" {subdomain}.{domain}
```

If the DNS record already exists, cloudflared will report it — this is safe to ignore.

## Step 4: Restart cloudflared

Apply the new config by restarting the daemon:

```bash
# macOS (monit)
monit restart cloudflared

# Linux (systemd)
sudo systemctl restart cloudflared
```

### Error Handling — Restart

- **Monit not running (macOS)**: Check if monit is loaded. If monit doesn't know about cloudflared, verify a config exists at `~/.config/monit/conf.d/cloudflared.conf` and run `monit reload`.
- **systemd service not found (Linux)**: Run `sudo cloudflared service install` first.

## Step 5: Register Surface (if orchestrator is available)

If a surface registration tool is available (e.g., `mcp__colony__register_surface`), register the service for health monitoring:

- **name**: `{subdomain}`
- **subdomain**: `{subdomain}`
- **local_port**: `{local_port}`
- **health_path**: `{health_path}`
- **service_type**: `{service_type}`
- **public_hostname**: `{subdomain}.{domain}`

If no registration tool is available, inform the user that the tunnel route was created but automated health monitoring is not active.

## Step 6: Add to Cloudflare Access (Remind User)

Remind the user to add the new subdomain to their Cloudflare Access application:

> Don't forget to add `{subdomain}.{domain}` to your Cloudflare Access application so it's protected by authentication. Go to **Zero Trust > Access > Applications** and add the subdomain.

## Step 7: Verify the Service

Check that the service is reachable through the tunnel:

```bash
curl -s -o /dev/null -w "%{http_code}" https://{subdomain}.{domain}{health_path}
```

### Error Handling — Verification

- **Health check fails (non-2xx)**: Warn but do NOT fail the registration. The service may still be starting up. Tell the user:
  > The service registered successfully but the health check at `https://{subdomain}.{domain}{health_path}` returned a non-success status. It will be monitored and reported when it comes up.
- **DNS not resolving**: Cloudflare DNS propagation may take a moment. Suggest the user waits 30 seconds and retries.
- **Connection refused through tunnel**: Check cloudflared logs at `/tmp/cloudflared.err.log` (macOS) or `journalctl -u cloudflared` (Linux).

## Step 8: Report Success

On success, report:

```
Service registered successfully!

  URL:            https://{subdomain}.{domain}
  Local port:     {local_port}
  Service type:   {service_type}
  Health check:   {health_path}
  Tunnel route:   {subdomain}.{domain} → localhost:{local_port}
  Auth:           Protected by Cloudflare Access

  Note: Add {subdomain}.{domain} to your Cloudflare Access application
        if not already included.
```
