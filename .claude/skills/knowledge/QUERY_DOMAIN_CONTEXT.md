---
name: query_domain_context
description: Get hierarchical CLAUDE.md context and relevant .colony/ docs for a file path
---

# Query Domain Context

Use this skill when you need to understand the domain context for a file or directory you're working in. This gives you the "orientation package" — what do I need to know about this area?

## When to Use

- **Starting work on a task**: Before making changes, understand the domain's patterns and rules
- **Exploring unfamiliar code**: When you don't know the conventions for this area
- **Checking constraints**: Find architecture and constraint docs that apply to your domain
- **Understanding the hierarchy**: See how this module fits into the broader system

## MCP Resource

```
colony://knowledge/domain_context?path=<file-path>
```

The `path` parameter is a project-relative file path (e.g., `lib/colony/foreman/server.ex`).

## Response Structure

```json
{
  "domain": "foreman",
    "claude_md_chain": [
      {
        "path": "lib/colony/foreman/CLAUDE.md",
        "content": "# Foreman Domain\n\nThe Foreman is Colony's strategic brain..."
      },
      {
        "path": "lib/colony/CLAUDE.md",
        "content": "# Colony Core\n\nColony is an AI-powered task orchestration..."
      },
      {
        "path": "CLAUDE.md",
        "content": "# CLAUDE.md\n\nThis file provides guidance..."
      }
    ],
    "relevant_architecture": [
      {
        "path": ".colony/architecture/session-management.md",
        "name": "Session Management"
      }
    ],
    "relevant_constraints": [
      {
        "path": ".colony/constraints/architecture.md",
        "name": "Architecture Constraints"
      }
    ]
}
```

## Key Fields

### `claude_md_chain`
Ordered most-specific-first. The first entry is the CLAUDE.md closest to your file (domain-level context). Read these in order for progressive understanding — domain specifics first, then broader system context.

### `domain`
The detected domain name (e.g., "directives", "execution", "foreman", "sessions", "tasks"). Null for files outside `lib/colony/<domain>/`.

### `relevant_architecture`
Architecture docs from `.colony/architecture/` that mention this domain or apply to all domains. Read these for structural patterns and design decisions.

### `relevant_constraints`
Constraint docs from `.colony/constraints/` that apply. These are rules you must follow — check before making architectural changes.

## Example Usage

1. Read this MCP resource with the path of the main file you're about to modify
2. Read the `claude_md_chain` top-to-bottom for domain orientation
3. Check `relevant_constraints` for rules that apply to your changes
4. Refer to `relevant_architecture` for broader context on design patterns

## Notes

- The CLAUDE.md chain includes the full content of each file — no need for separate reads
- Architecture and constraint docs return path + name only — read the full file if the name looks relevant
- If `domain` is null, you're working outside the main domain structure — constraints that `applies_to_all` will still appear
