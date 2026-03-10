---
name: query_knowledge_search
description: Semantic search across Colony's knowledge documentation using vector embeddings
---

# Query Knowledge Search

Use this skill for free-form semantic search across Colony's knowledge base. Unlike keyword-based queries, this finds documents by meaning — searching "why was the reconciler built this way?" can find relevant ADR docs even without exact keyword overlap.

## When to Use

- **Exploring unfamiliar territory**: When you don't know the exact doc names or keywords
- **Cross-cutting queries**: Finding docs that span multiple concerns
- **Natural language questions**: "How does session crash recovery work?"
- **Broader than decision_rationale**: Searches ALL doc types, not just ADR/architecture

## MCP Resource

```
colony://knowledge/search?q=<query>&types=<comma-separated-types>
```

## Parameters

- `q` (required) — The search query string
- `types` (optional) — Comma-separated source types to filter: `adr`, `architecture`, `constraint`, `claude_md`

## Response Structure

```json
{
  "query": "session crash recovery",
  "results": [
    {
      "source_path": ".colony/architecture/session-management.md",
      "source_type": "architecture",
      "chunk_content": "When a session crashes, the Reconciler detects...",
      "chunk_index": 2,
      "metadata": {"heading": "Crash Recovery"},
      "similarity": 0.87
    }
  ]
}
```

## Key Fields

### `results`
Ranked list of matching document chunks, ordered by semantic similarity (highest first).

### `similarity`
Cosine similarity score (0 to 1). Higher means more relevant. Scores above 0.8 are strong matches.

### `chunk_content`
The actual text chunk that matched. Documents are split by `##` headings, so each result is a focused section.

### `metadata.heading`
The markdown heading for this chunk, useful for understanding context without reading the full document.

## Prerequisites

Documents must be indexed before search works. Trigger indexing via MCP tool `reindex_knowledge`.

This reads all `.colony/` docs and CLAUDE.md files, chunks them, generates embeddings, and stores them for search.

## Tips

- If search returns no results, check if docs have been indexed (call reindex endpoint)
- Use `types` filter to narrow results (e.g., only search ADRs)
- For specific decision lookups, `query_decision_rationale` may be more appropriate
- Results are chunks, not full documents — read the full file if a chunk looks relevant
