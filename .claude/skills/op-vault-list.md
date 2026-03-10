---
description: Discover what secrets exist in the Colony 1Password vault (titles and field labels only, never actual values)
user_invocable: true
---

# op-vault-list — Discover Colony secrets

Use this skill to find what secrets are available in the Colony 1Password vault. This never exposes actual secret values.

## Steps

1. List all items in the Colony vault:
```bash
op item list --vault=Colony --format json
```

2. To see field labels for a specific item (never values):
```bash
op item get "<item-title>" --vault=Colony --format json | jq '[.fields[] | {label: .label, type: .type}]'
```

3. Reference secrets using the format: `op://Colony/<item>/<field>`

4. If a needed secret doesn't exist, tell the user to create it in 1Password under the "Colony" vault.

## Important

- NEVER read or display actual secret values
- NEVER run `op read` or access field values
- Only report item titles and field labels
