---
name: query_expert_profile
description: Look up expert discipline profiles for agent creation or decision review
---

# Query Expert Profile

Look up the intellectual foundations and patterns for a discipline. Useful when creating agents or reviewing decisions against established domain expertise.

## When to Use

- Before creating a new agent -- check if a profile exists for the discipline
- Reviewing an agent's decisions against established expert principles

## How to Search

Use `memory_search` to find expert profiles:

```
memory_search(query: "elixir OTP expert profile", source_types: ["domain"])
```

Or browse agent definitions in `.claude/agents/` to see existing expertise declarations.
