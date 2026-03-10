---
name: secrets
description: Manage application secrets using 1Password references and .envrc.template — local dev and production
---

# Secrets Management

All secrets flow through 1Password. Never hardcode credentials, never commit `.env` files, never invent a custom secret-passing mechanism. Every environment variable containing a secret must be declared in `.envrc.template` using `op://` references.

## The Pattern

```
.envrc.template          →  op inject  →  .envrc (gitignored)
(checked in, no values)     (1Password)    (real values, local only)
```

### .envrc.template format

```bash
# Project secrets — resolved via: op inject -i .envrc.template -o .envrc
# See: https://developer.1password.com/docs/cli/secret-references/

export DATABASE_URL=op://Colony/<project-name>/database-url
export SECRET_KEY_BASE=op://Colony/<project-name>/secret-key-base
export STRIPE_SECRET_KEY=op://Colony/<project-name>/stripe-secret-key
```

Rules:
- One `export` per line
- Value is always an `op://` reference
- Comments explain what each secret is for
- Group related secrets with blank lines
- Vault is always `Colony` (our shared vault)

### Local setup

```bash
# Generate .envrc from template (requires 1Password CLI + sign-in)
op inject -i .envrc.template -o .envrc

# Trust the directory for direnv
direnv allow .
```

### Gitignore

`.envrc` must be in `.gitignore`. `.envrc.template` must be checked in.

```gitignore
# Secrets
.envrc
!.envrc.template
```

## Adding a New Secret

When the application needs a new secret:

1. **Check if the 1Password item exists** using the `op-vault-list` skill
2. **If it doesn't exist**, tell the user:
   > "This feature requires a `<ITEM_NAME>` secret in the Colony 1Password vault.
   > Please create it: `op item create --vault=Colony --title='<item>' --category=Login`
   > Then add the field: `op item edit '<item>' --vault=Colony '<field>=<value>'`"
3. **Add the `op://` reference** to `.envrc.template`
4. **Add runtime config** in `config/runtime.exs`:
   ```elixir
   if value = System.get_env("SECRET_NAME") do
     config :my_app, MyApp.SomeModule,
       secret_name: value
   end
   ```
5. **Read from application config** in the module, never `System.get_env/1` at call time:
   ```elixir
   # Good — reads from compiled config
   defp api_key, do: Application.get_env(:my_app, __MODULE__)[:api_key]

   # Bad — runtime coupling to OS environment
   defp api_key, do: System.get_env("API_KEY")
   ```
6. **Re-inject** to pick up the new secret: `op inject -i .envrc.template -o .envrc`

## Production Deployment

Production secrets follow the same principle — 1Password is the source of truth — but the injection mechanism differs by platform.

### Fly.io

```bash
# Set secrets from 1Password references
fly secrets set DATABASE_URL="$(op read 'op://Colony/<project>/database-url')" \
              SECRET_KEY_BASE="$(op read 'op://Colony/<project>/secret-key-base')"
```

### Docker / Kubernetes

```bash
# Generate a .env file for docker-compose or k8s secret creation
op inject -i .envrc.template -o .env.production

# Create k8s secret from generated file
kubectl create secret generic app-secrets --from-env-file=.env.production
rm .env.production  # Don't leave it on disk
```

### CI/CD (GitHub Actions)

Use 1Password GitHub Actions integration or set secrets from `op read`:
```yaml
- uses: 1password/load-secrets-action@v2
  with:
    export-env: true
  env:
    OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    DATABASE_URL: op://Colony/project-name/database-url
```

### General Rule

Every deployment target reads from `config/runtime.exs`, which reads from `System.get_env/1`. The only thing that changes between environments is HOW the env vars get set — `op inject` locally, `fly secrets set` in prod, GitHub Actions in CI. The application code is identical.

## Worktree Setup

Colony's post-checkout hook (`.lefthook/post-checkout/worktree-setup.sh`) handles secrets in new worktrees automatically:

1. Detects `.envrc.template` exists
2. Runs `op inject -i .envrc.template -o .envrc`
3. Falls back to copying `.envrc` from the main repo if `op` isn't available
4. Runs `direnv allow` to trust the new worktree

No manual intervention needed. If a worktree needs secrets, they're there.

## Audit Procedure

Run this audit to verify the project follows the secrets pattern correctly. This catches drift — env vars used in code that aren't declared in `.envrc.template`, secrets leaked into source, or custom secret mechanisms that bypass the standard flow.

### Step 1: Inventory declared secrets

```bash
# Extract all env var names from .envrc.template
grep -E '^export ' .envrc.template | sed 's/export \([^=]*\)=.*/\1/' | sort > /tmp/declared_secrets.txt
cat /tmp/declared_secrets.txt
```

### Step 2: Find all env var reads in application code

```bash
# System.get_env calls in Elixir
grep -rn 'System\.get_env' lib/ config/ --include='*.ex' --include='*.exs' \
  | grep -v '_build' | grep -v 'deps/' \
  | sed 's/.*System\.get_env[("]*"\([^"]*\)".*/\1/' | sort -u > /tmp/used_envvars.txt

# Also check for ${VAR} patterns in shell scripts and Dockerfiles
grep -rn '\${\?\w\+}\?' Dockerfile* docker-compose* .github/ bin/ \
  --include='*.sh' --include='*.yml' --include='*.yaml' --include='Dockerfile*' 2>/dev/null \
  | grep -v '#' | grep -vE '(PATH|HOME|PWD|SHELL|USER|MIX_ENV|NODE_ENV|PORT|PHX_SERVER|PHX_HOST|DNS_CLUSTER_QUERY)' \
  >> /tmp/used_envvars.txt

sort -u /tmp/used_envvars.txt -o /tmp/used_envvars.txt
cat /tmp/used_envvars.txt
```

### Step 3: Find undeclared secrets

```bash
# Env vars used in code but NOT in .envrc.template
comm -23 /tmp/used_envvars.txt /tmp/declared_secrets.txt
```

For each undeclared env var, decide:
- **Is it a secret?** Add to `.envrc.template` with an `op://` reference
- **Is it a non-secret config?** (like `PORT`, `MIX_ENV`, `PHX_SERVER`) — leave it, these are operational vars, not secrets
- **Is it dead code?** Remove the `System.get_env` call

### Step 4: Check for anti-patterns

```bash
# Hardcoded secrets (API keys, tokens, passwords in source)
grep -rn -iE '(api[_-]?key|secret|token|password|credential)\s*[:=]\s*"[^"]{8,}"' \
  lib/ config/ test/ --include='*.ex' --include='*.exs' \
  | grep -v 'test/' | grep -v '_build' | grep -v 'deps/' | grep -v '\.get_env'

# .env files that shouldn't exist (only .envrc.template should be checked in)
find . -name '.env' -o -name '.env.local' -o -name '.env.production' \
  -o -name '.env.development' | grep -v node_modules | grep -v _build | grep -v deps

# System.get_env at module attribute or function call time (not in config/runtime.exs)
grep -rn 'System\.get_env' lib/ --include='*.ex' \
  | grep -v '_build' | grep -v 'deps/'

# Secrets in Dockerfiles
grep -n -iE '(ENV|ARG).*(KEY|SECRET|TOKEN|PASSWORD)' Dockerfile* 2>/dev/null
```

### Step 5: Report

Summarize findings:

| Finding | Severity | Action |
|---------|----------|--------|
| Undeclared secret `FOO_KEY` used in `lib/foo.ex:42` | High | Add to `.envrc.template` |
| `System.get_env("BAR")` called in `lib/bar.ex:10` (not runtime.exs) | Medium | Move to `config/runtime.exs` |
| Hardcoded token in `lib/client.ex:55` | Critical | Remove, add to 1Password |
| `.env` file exists at project root | High | Delete, ensure `.gitignore` covers it |

### What passes audit

- Every secret env var used in `config/runtime.exs` has a matching `export` in `.envrc.template`
- No `System.get_env` calls in `lib/` — all env var reads happen in `config/runtime.exs`
- No `.env` files in the repo (only `.envrc.template`)
- No hardcoded secrets in source
- `.envrc` is in `.gitignore`
