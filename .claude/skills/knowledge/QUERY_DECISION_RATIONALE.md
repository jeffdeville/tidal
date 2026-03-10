---
name: query_decision_rationale
description: Search Colony's decision and architecture documentation by topic
---

# Query Decision Rationale

Use this skill when you need to understand *why* something was built a certain way. Searches ADR documents and architecture docs by topic.

## When to Use

- **Before changing architecture**: Understand past decisions before overriding them
- **Understanding design choices**: Why was this pattern chosen over alternatives?
- **Avoiding past mistakes**: Check if a similar approach was considered and rejected
- **Onboarding to a domain**: Get the "why" behind the "what"

## MCP Resource

```
colony://knowledge/decision_rationale?topic=<topic>
```

## Response Structure

```json
{
  "topic": "CQRS",
    "decisions": [
      {
        "path": ".colony/adr/001-task-execution-architecture.md",
        "name": "ADR-001: Task Execution & Planning Architecture",
        "snippet": "...Colony uses CQRS with Event Sourcing for domain state..."
      }
    ],
    "architecture": [
      {
        "path": ".colony/architecture/cqrs-boundaries.md",
        "name": "CQRS Boundaries",
        "snippet": "...Domain entities are the source of truth for business state..."
      }
    ]
}
```

## Key Fields

### `decisions`
Architecture Decision Records from `.colony/adr/`. These document the *why* behind architectural choices — what was considered, what was chosen, and what tradeoffs were accepted.

### `architecture`
Architecture documentation from `.colony/architecture/`. These describe the current *how* — patterns, boundaries, and interaction models.

### `snippet`
A context snippet (~400 chars) around the first match of your topic in the document. Read the full file if the snippet looks relevant.

## Tips

- Search broadly first (e.g., "session"), then narrow down
- Searches are case-insensitive and match any word in the topic
- If you find a relevant ADR, read the full file for alternatives considered
- Architecture docs describe current state; ADRs describe the journey
