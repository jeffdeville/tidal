---
name: deploy-service
description: Deploy a project service with Monit process supervision, HTTP health checks, and Cloudflare Tunnel routing. Use when setting up a new service for external access (e.g., "deploy my Phoenix app on port 4000").
argument-hint: '<service-name> <subdomain> <port> <start-command>'
disable-model-invocation: true
allowed-tools: [Bash, Read, Edit, Write]
synced_from_colony: true
sync_pack: deploy-local
sync_source: packs/deploy-local/deploy-service.md
sync_version: d3fefcef
---

# Deploy Service with Monit + Cloudflare Tunnel

Full deployment workflow for a project service: Monit supervision with health checks and Cloudflare Tunnel ingress.

**Input**: $ARGUMENTS

Parse the following from the input (ask if missing):
- **service_name** (required): Name for the service (e.g., `myapp-phoenix`)
- **subdomain** (required): The subdomain prefix (e.g., `myapp`)
- **local_port** (required): The local port the service listens on (e.g., `4000`)
- **start_command** (required): Command to start the service (e.g., `/path/to/start.sh`)
- **stop_command** (optional): Command to stop the service (default: kill via PID or signal)
- **service_type** (optional, default: `custom`): One of `livebook`, `phoenix`, `static`, `api`, `custom`
- **health_path** (optional, default: `/`): Health check endpoint path
- **process_match** (optional): Process matching pattern (used instead of pidfile if provided)
- **depends_on** (optional): Monit service name this service depends on (e.g., `cloudflared`)

## Prerequisites

Before running this skill, ensure:
1. **Monit is installed**: `brew install monit` (macOS) or `apt install monit` (Linux)
2. **Monit is running**: Supervised by launchd (macOS) or systemd (Linux)
3. **cloudflared is installed and configured** with a tunnel
4. **The include directory exists**: `~/.config/monit/conf.d/` for user service configs

## Step 1: Verify Monit is Running

```bash
monit summary
```

If monit is not running:
- **macOS**: `launchctl start com.tildeslash.monit` or `brew services start monit`
- **Linux**: `sudo systemctl start monit`

If monit is not installed, tell the user to run `brew install monit` (macOS) or `apt install monit` (Linux).

## Step 2: Write Monit Configuration

Create a monit config file at `~/.config/monit/conf.d/{service_name}.conf`:

### Option A: With PID file

```
check process {service_name} with pidfile /tmp/{service_name}.pid
  start program = "{start_command}"
  stop program = "{stop_command}"
  if failed
    host 127.0.0.1
    port {local_port}
    protocol http
    request "{health_path}"
    with timeout 10 seconds
  then restart
  if 3 restarts within 5 cycles then alert
```

### Option B: With process matching (no PID file)

```
check process {service_name} matching "{process_match}"
  start program = "{start_command}"
  stop program = "{stop_command}"
  if failed
    host 127.0.0.1
    port {local_port}
    protocol http
    request "{health_path}"
    with timeout 10 seconds
  then restart
  if 3 restarts within 5 cycles then alert
```

### Adding Dependencies

If `depends_on` is specified, add to the config:

```
  depends on {depends_on}
```

### Error Handling — Config

- **Include directory doesn't exist**: Create it with `mkdir -p ~/.config/monit/conf.d/`
- **monitrc doesn't include the directory**: Add `include ~/.config/monit/conf.d/*` to the end of `/opt/homebrew/etc/monitrc` (macOS) or `/etc/monitrc` (Linux)
- **Service name conflict**: Check `monit summary` for an existing service with the same name. Ask the user if they want to replace it.

## Step 3: Reload Monit

```bash
monit reload
```

Then verify the service is picked up:

```bash
monit summary
```

The service should appear in the summary. If it shows as "not monitored", start it:

```bash
monit start {service_name}
```

## Step 4: Verify Health Check

Wait a few seconds for the service to start, then verify the health check:

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:{local_port}{health_path}
```

Expected: HTTP 200 (or another 2xx status).

### Error Handling — Health Check

- **Connection refused**: The service hasn't started yet or crashed on startup. Check logs and `monit status {service_name}`.
- **Non-2xx response**: The service is running but the health endpoint isn't ready. Check if the path is correct.
- **Timeout**: The service may be binding to a different interface. Verify it listens on 127.0.0.1 or 0.0.0.0.

## Step 5: Configure Cloudflare Tunnel Route

Determine the domain from the existing cloudflared config:

```bash
DOMAIN=$(grep 'hostname:' ~/.cloudflared/config.yml | head -1 | sed 's/.*hostname: [^.]*\.//' | tr -d ' ')
TUNNEL_NAME=$(grep '^tunnel:' ~/.cloudflared/config.yml | awk '{print $2}')
```

Add a DNS route:

```bash
cloudflared tunnel route dns "$TUNNEL_NAME" {subdomain}.$DOMAIN
```

## Step 6: Update cloudflared Config

Read `~/.cloudflared/config.yml` and add an ingress rule **before** the catch-all `- service: http_status:404`:

```yaml
  - hostname: {subdomain}.{domain}
    service: http://localhost:{local_port}
```

**Important**: The catch-all `- service: http_status:404` MUST remain the last entry.

### Error Handling — Config

- **Config not found**: cloudflared is not configured. Tell the user to run `cloudflared tunnel login` and `cloudflared tunnel create <tunnel-name>` first.
- **Subdomain already exists**: Show the existing rule and ask if the user wants to update the port.

## Step 7: Restart cloudflared via Monit

```bash
# macOS
monit restart cloudflared

# Linux
sudo systemctl restart cloudflared
```

If cloudflared is not managed by monit yet (macOS), fall back to:

```bash
launchctl kickstart -k gui/$(id -u)/com.cloudflare.cloudflared
```

## Step 8: Register Surface (if orchestrator is available)

If a surface registration tool is available (e.g., `mcp__colony__register_surface`), register the service for health monitoring:

- **name**: `{service_name}`
- **subdomain**: `{subdomain}`
- **local_port**: `{local_port}`
- **health_path**: `{health_path}`
- **service_type**: `{service_type}`
- **public_hostname**: `{subdomain}.{domain}`

If no registration tool is available, inform the user that the service is deployed but not registered for automated health monitoring.

## Step 9: Verify End-to-End

Check the service is accessible through the tunnel:

```bash
curl -s -o /dev/null -w "%{http_code}" https://{subdomain}.{domain}{health_path}
```

### Error Handling — Verification

- **Health check fails**: The tunnel route may need DNS propagation time. Wait 30 seconds and retry.
- **403 Forbidden**: Cloudflare Access is blocking the request. Remind the user to add the subdomain to their Access application.
- **502 Bad Gateway**: cloudflared can't reach the local service. Check `monit status {service_name}` and verify the port.

## Step 10: Report Success

```
Service deployed successfully!

  Service:        {service_name}
  URL:            https://{subdomain}.{domain}
  Local port:     {local_port}
  Health check:   {health_path}
  Supervision:    Monit (HTTP health-checked, auto-restart)
  Tunnel route:   {subdomain}.{domain} → localhost:{local_port}

  Monit config:   ~/.config/monit/conf.d/{service_name}.conf
  Monit status:   `monit status {service_name}`

  Note: Add {subdomain}.{domain} to your Cloudflare Access application
        if not already included.
```
