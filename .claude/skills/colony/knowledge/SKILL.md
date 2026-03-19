---
name: knowledge_skills_index
description: Overview of Colony knowledge query skills and when to use each
---

# Knowledge Skills Index

Colony provides knowledge queries across three layers:
- **Document layer** (filesystem): CLAUDE.md hierarchy, .colony/ docs
- **Versioned layer** (git): Commits, PRs, decision history
- **Live layer** (database): Tasks, directives, executions

## Which Skill to Use?

| Question | Skill / Tool |
|----------|-------------|
| "What's the current state of this directive?" | `colony://directives/{id}/status` resource |
| "Why does my task exist?" | `colony://tasks/{id}/provenance` resource |
| "What do I need to know about this code area?" | Read the CLAUDE.md chain (see `query_domain_context`) |
| "Why was this built this way?" | `memory_search` with `source_types: ["adr", "architecture"]` |
| "Find docs related to X" (broad/semantic) | `memory_search` tool |
| "What did my predecessor tasks produce?" | `get_predecessors` tool |

## MCP Resources

- `colony://directives` -- list all directives
- `colony://directives/{id}` -- directive detail
- `colony://directives/{id}/status` -- task graph, execution state, blocked subtrees
- `colony://tasks/{id}/provenance` -- task with parent directive and siblings
- `colony://project/conventions` -- task conventions from `.colony/overview/task-conventions.md`
- `colony://project/overview` -- all `.colony/overview/*.md` files

## MCP Tools

- `memory_search` -- semantic search across all indexed knowledge docs
- `memory_write` -- record observations for future search
- `get_predecessors` -- fetch results from completed dependency tasks
