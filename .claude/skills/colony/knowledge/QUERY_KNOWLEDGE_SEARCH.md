---
name: query_knowledge_search
description: Semantic search across Colony's knowledge base using the memory_search MCP tool
---

# Knowledge Search

Search Colony's knowledge base by meaning. Finds documents by semantic similarity, not just keyword matching.

## When to Use

- Exploring unfamiliar territory without knowing exact doc names
- Cross-cutting queries spanning multiple concerns
- Natural language questions ("How does session crash recovery work?")

## MCP Tool

Use `memory_search`:

```
memory_search(
  query: "session crash recovery",
  source_types: ["adr", "architecture", "constraint", "domain"],
  limit: 5
)
```

## Source Types

- `adr` -- Architecture Decision Records
- `architecture` -- System design docs
- `constraint` -- Rules and limitations
- `domain` -- Business knowledge
- `interview` -- Stakeholder conversations
- `research` -- Findings
- `claude_md` -- CLAUDE.md files

## Tips

- Results are ranked by semantic similarity (0 to 1, higher is better)
- Results are document chunks -- read the full file if a chunk looks relevant
- For decision history specifically, filter to `source_types: ["adr"]`
