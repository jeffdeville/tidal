---
name: documentation-standards
description: Standards for evaluating and updating domain documentation during task execution
---

# Documentation Standards

When your task includes the `orthogonal:doc_staleness` acceptance criterion, use this guide to evaluate and update documentation for the domains you're working in.

## Quick Assessment (Do This First)

1. **Identify your domains**: Which `lib/<domain>/` directories are you modifying files in?
2. **Check for CLAUDE.md**: Does each domain have a `CLAUDE.md` file?
3. **Assess staleness**: If a CLAUDE.md exists, does it accurately describe the current state of the code you're working with?

### Decision Matrix

| Situation | Action |
|-----------|--------|
| No CLAUDE.md, you modified 3+ files in the domain | Create one |
| CLAUDE.md exists but describes something you found to be wrong | Update it |
| CLAUDE.md exists and is accurate | Attest "no changes needed" in your completion notes |
| You discovered a non-obvious behavior or gotcha | Add it to the "Common Mistakes" section |
| You're only touching 1-2 files in a well-documented domain | Attest "no changes needed" |

## What Good Domain CLAUDE.md Looks Like

Follow the existing pattern in this project. A domain CLAUDE.md covers:

```markdown
# <Domain> Domain

<One paragraph: what this domain is responsible for and why it exists>

## Key Concepts

<State machines, lifecycle diagrams, or core patterns>

## Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| `service.ex` | Public API for domain mutations |
| `aggregate.ex` | CQRS aggregate with state validation |

## Common Mistakes

- **Don't do X** — because Y happens
- **Don't confuse A with B** — A is for <this>, B is for <that>
```

**Reference examples** (read these if unsure about format):
- `lib/colony/execution/CLAUDE.md` — good execution domain docs
- `lib/colony/tasks/CLAUDE.md` — good task domain docs
- `lib/colony/directives/CLAUDE.md` — good directive domain docs

## What to Capture

**High value** (always capture):
- Something you discovered that would have saved you time if you'd known it at the start
- A constraint or invariant that isn't obvious from reading the code
- A "don't do this" that you learned the hard way or almost fell into

**Medium value** (capture if straightforward):
- Updated module responsibility tables when you added new modules
- Updated state machines when you changed transitions

**Low value** (skip unless significant):
- Restating what functions do (the code says that)
- Documenting implementation details that will change next sprint

## Attesting "No Changes Needed"

If documentation is current and accurate, include in your completion notes:

```
Documentation review: Reviewed CLAUDE.md for <domain>. Content is accurate for current code state. No updates needed.
```

This satisfies the `orthogonal:doc_staleness` criterion without busywork.

## The `.colony/` Directory

Beyond domain CLAUDE.md files, the project maintains knowledge in `.colony/`:

| Directory | Purpose | When to update |
|-----------|---------|----------------|
| `.colony/architecture/` | Cross-domain architectural patterns | When you change how components interact |
| `.colony/adr/` | Architecture Decision Records | When you make a significant structural choice |
| `.colony/constraints/` | System invariants and rules | When you discover a new constraint |
| `.colony/domains/` | Domain-specific context beyond CLAUDE.md | When domain has extensive context |

**You are NOT expected to update `.colony/` docs on every task.** These are maintained primarily by the Foreman during directive reassessment, when the full picture is available. Focus your documentation effort on domain CLAUDE.md files.
