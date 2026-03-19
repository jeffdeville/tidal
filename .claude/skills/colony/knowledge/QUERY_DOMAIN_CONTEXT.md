---
name: query_domain_context
description: Understand domain context by reading the CLAUDE.md hierarchy for a code area
---

# Query Domain Context

Get oriented in a code area by reading the CLAUDE.md hierarchy and relevant docs.

## When to Use

- Starting work on a task -- understand conventions before making changes
- Exploring unfamiliar code
- Checking constraints that apply to your domain

## How to Get Context

1. Read the CLAUDE.md chain from most-specific to most-general:
   - `lib/colony/<domain>/CLAUDE.md` (domain-level context)
   - `lib/colony/CLAUDE.md` (system architecture)
   - `CLAUDE.md` (project conventions)

2. Check `.colony/architecture/` for design docs relevant to your domain

3. Check `.colony/constraints/` for rules you must follow

4. Use `memory_search` to find related docs:
   ```
   memory_search(query: "foreman session lifecycle", source_types: ["architecture", "constraint"])
   ```

## Tips

- Read domain CLAUDE.md first -- it has the specific patterns and rules
- Architecture docs describe patterns; constraint docs are rules you must follow
- The project overview at `colony://project/overview` concatenates all `.colony/overview/` files
