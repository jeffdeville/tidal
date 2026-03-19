---
name: query_decision_rationale
description: Search architecture decision records and design docs to understand why things were built a certain way
---

# Query Decision Rationale

Understand *why* something was built a certain way by searching ADRs and architecture docs.

## When to Use

- Before changing architecture -- understand past decisions first
- Checking if a similar approach was considered and rejected
- Onboarding to a domain -- get the "why" behind the "what"

## How to Search

Use the `memory_search` MCP tool with `source_types: ["adr", "architecture"]`:

```
memory_search(query: "CQRS task execution", source_types: ["adr", "architecture"])
```

Or read files directly from `.colony/adr/` and `.colony/architecture/`.

## Tips

- Search broadly first (e.g., "session"), then narrow
- ADRs document what was considered and chosen; architecture docs describe current state
- If you find a relevant ADR, read the full file for alternatives considered
