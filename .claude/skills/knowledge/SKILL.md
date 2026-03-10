---
name: knowledge_skills_index
description: Overview of all Colony knowledge graph skills
---

# Knowledge Skills Index

Colony's knowledge graph provides named traversal queries across three layers:
- **Document layer** (filesystem): CLAUDE.md hierarchy, .colony/ docs
- **Versioned layer** (git): Commits, PRs, decision history
- **Live layer** (database): Tasks, directives, executions

## Available Skills

### `query_directive_status`
**When**: Reassessment, AC verification, progress review, failure triage
**Returns**: Task graph + execution state + blocked subtrees + rationale
**MCP Resource**: `colony://knowledge/directive_status/<directive-id>`
**Doc**: `QUERY_DIRECTIVE_STATUS.md`

### `query_domain_context`
**When**: Starting work in unfamiliar code, checking domain constraints
**Returns**: CLAUDE.md hierarchy + relevant architecture/constraint docs
**MCP Resource**: `colony://knowledge/domain_context?path=<file-path>`
**Doc**: `QUERY_DOMAIN_CONTEXT.md`

### `query_decision_rationale`
**When**: Understanding why something was built a certain way
**Returns**: Matching ADR + architecture docs with context snippets
**MCP Resource**: `colony://knowledge/decision_rationale?topic=<topic>`
**Doc**: `QUERY_DECISION_RATIONALE.md`

### `query_task_provenance`
**When**: Starting a task, understanding dependencies and context
**Returns**: Task details + directive rationale + sibling tasks
**MCP Resource**: `colony://knowledge/task_provenance/<task-id>`
**Doc**: `QUERY_TASK_PROVENANCE.md`

### `query_knowledge_search`
**When**: Free-form semantic search across all knowledge docs
**Returns**: Ranked document chunks by vector similarity
**MCP Resource**: `colony://knowledge/search?q=<query>&types=<types>`
**Doc**: `QUERY_KNOWLEDGE_SEARCH.md`

### `reindex`
**When**: After bulk doc changes or when semantic search returns stale results
**MCP Tool**: `reindex_knowledge`

## Which Skill to Use?

| Question | Skill |
|----------|-------|
| "What's the current state of this directive?" | `query_directive_status` |
| "What do I need to know about this code area?" | `query_domain_context` |
| "Why was this built this way?" | `query_decision_rationale` |
| "Why does my task exist and what's the plan?" | `query_task_provenance` |
| "Find docs related to X" (broad/semantic) | `query_knowledge_search` |

## Access

All knowledge queries are available as MCP resources under the `colony://knowledge/` URI scheme. The session context (project, session ID) is injected automatically by the MCP server.
