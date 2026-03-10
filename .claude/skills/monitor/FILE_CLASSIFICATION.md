---
name: file-classification
description: Maps file paths to review domains for the monitor skill
---

# File Classification

Maps changed file paths to review domains. A file can trigger multiple review types.

## Architecture Review Triggers

| Pattern | Rationale |
|---------|-----------|
| `lib/colony/**/*.ex` | Core domain logic, CQRS aggregates, services |
| `lib/colony_web/**` | Phoenix controllers, LiveView, channels |
| `priv/repo/migrations/**` | Schema changes affect architecture |
| `lib/mix/tasks/**` | Custom mix tasks may affect build/deploy |
| `config/*.exs` | Configuration changes affect system behavior |
| `mix.exs` | Dependency changes affect architecture |

## Documentation Review Triggers (Phase 2)

| Pattern | Rationale |
|---------|-----------|
| `docs/**/*.md` | Documentation prose |
| `CLAUDE.md` | Project instructions |
| `.claude/**` | Agent/skill/command definitions |
| `.colony/**/*.md` | Constraints, governance, domain docs |

## Quality Review Triggers

| Pattern | Rationale |
|---------|-----------|
| `lib/**/*.ex` | All Elixir source code — moduledoc, @doc, @spec, complexity checks |
| `test/**/*.exs` | Test files — pattern compliance (no Process.sleep, Arena usage) |

## Complexity Audit Triggers (Phase 2)

The complexity audit is not file-triggered. It runs on accumulated change volume across the entire codebase.

## Classification Rules

1. A file matching multiple patterns triggers all corresponding review types
2. Files not matching any pattern are skipped
3. Deleted files are included (to check for orphaned references)
4. Renamed files trigger review for both old and new paths
