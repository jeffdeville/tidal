---
name: context-coherence
description: Tier 2 analysis — cross-module coherence within a bounded context
---

# Context Coherence Review (Tier 2)

Assess coherence across all modules within a single bounded context. Where Tier 1 (QUALITY_REVIEW.md) examines individual modules in isolation, Tier 2 examines how modules within a context work *together*: duplication, pattern consistency, API surface design, responsibility distribution, and missing abstractions.

## Prerequisites

- Tier 1 health cards must exist for the context's modules. If cards are missing or stale (reviewed before the most recent commit to any module in the context), run `--type quality` first.

## Inputs

- **Context name**: A directory under `lib/colony/` (e.g., `execution`, `directives`, `sessions`)
- **Health cards**: All `.md` files under `.colony/monitor/health-cards/colony/<context>/`
- **Source files**: Selectively read (max 5 per context) for modules flagged with concerns

## Bounded Contexts

The following bounded contexts are derived from `lib/colony/`:

| Context | Directory | Description | Module Count |
|---------|-----------|-------------|--------------|
| accounts | `lib/colony/accounts/` | Claude account management and API key lifecycle | 3 |
| checks | `lib/colony/checks/` | Compile-time code quality checks (e.g., no nested case) | 1 |
| directives | `lib/colony/directives/` | CQRS aggregate for directive lifecycle, commands, events, projections | 36 |
| event_store | `lib/colony/event_store/` | Commanded event store configuration and serialization | 1 |
| execution | `lib/colony/execution/` | Reconciler, task execution tracking, condition evaluation | 7 |
| foreman | `lib/colony/foreman/` | Task decomposition, complexity grading, agent/command registries | 13 |
| knowledge | `lib/colony/knowledge/` | Semantic search, embeddings, expert synthesis, knowledge indexing | 14 |
| mcp | `lib/colony/mcp/` | MCP server, tool registry, resource routing, idempotency | 4 |
| monitor | `lib/colony/monitor/` | Code monitoring run tracking and trigger state | 2 |
| notifications | `lib/colony/notifications/` | PubSub-driven notification event handling | 1 |
| observability | `lib/colony/observability/` | Telemetry, metrics, error detection, fix proposals | 16 |
| orchestration | `lib/colony/orchestration/` | Orchestration event definitions | 1 |
| projects | `lib/colony/projects/` | Multi-project infrastructure, supervisors, schema isolation | 7 |
| reviews | `lib/colony/reviews/` | Code review checks and task templates | 2 |
| session_operations | `lib/colony/session_operations/` | Operation DSL and MCP tool implementations (cancel, escalate, finish, etc.) | 27 |
| sessions | `lib/colony/sessions/` | Claude CLI session management, capacity, LLM process lifecycle | 21 |
| skills | `lib/colony/skills/` | Skill file discovery and loading | 2 |
| tasks | `lib/colony/tasks/` | CQRS aggregate for task lifecycle, commands, events, projections | 21 |
| test_support | `lib/colony/test_support/` | Shared test utilities | 1 |
| verification | `lib/colony/verification/` | Git verification for task completion | 1 |
| worktrees | `lib/colony/worktrees/` | Git worktree management, isolation, and lifecycle | 4 |

**Root-level modules** (files directly under `lib/colony/` like `completion.ex`, `prompt_builder.ex`, `pubsub.ex`) are not part of a bounded context directory. They should be assessed individually in Tier 1 only, not grouped into a Tier 2 context review.

**Web layer** (`lib/colony_web/`) is a separate concern assessed by its own context groups: `controllers`, `live`, `admin`, `plugs`, `components`.

## Workflow

### Step 1: Load Health Cards

Read all health cards under `.colony/monitor/health-cards/colony/<context>/`. For each card, extract:
- Module name
- Type (GenServer, Service, Aggregate, Schema, etc.)
- Score
- Moduledoc quality rating
- Findings (issues from Tier 1)
- Recommendations

If fewer than 2 cards exist for the context, skip it — a single-module context has no cross-module coherence to assess.

### Step 2: Build Context Mental Model

From the health cards alone (do NOT read source files yet), construct a mental model:
1. **What is this context's responsibility?** Infer from module names, types, and moduledocs.
2. **What are the key module roles?** Identify the aggregate, service, projections, schemas, helpers.
3. **What patterns are used?** CQRS commands/events, GenServer state machines, pure function pipelines, etc.
4. **What is the module count and type distribution?** How many of each type?

### Step 3: Evaluate Coherence Dimensions

Assess the context across five dimensions. For each dimension, note strengths and concerns.

#### Dimension 1: Duplication Detection

Look for signs of duplication across modules within the context:
- Multiple modules that define similar structs or data shapes
- Functions with overlapping names and signatures across modules
- Repeated validation logic or error handling patterns
- Similar transformation pipelines in different modules

**What to flag**: Concrete duplication that increases maintenance burden. Two modules doing the same transformation differently is a finding. Two modules that happen to use similar patterns for different purposes is NOT a finding.

#### Dimension 2: Pattern Consistency

Evaluate whether modules in the context follow consistent patterns:
- Do all commands follow the same struct/validation pattern?
- Do all events follow the same field naming convention?
- Are error tuples consistent (`{:ok, result}` / `{:error, reason}` vs mixed)?
- Do GenServers use consistent callback patterns?
- Is `Arena.Process` usage consistent across all GenServers?

**What to flag**: Inconsistencies that force a reader to re-learn patterns within the same context. A command that uses `validate/1` while all others use `valid?/1` is a finding.

#### Dimension 3: API Surface Analysis

Evaluate the context's public interface:
- Is there a clear entry point (service module) or are callers expected to know internal structure?
- How many modules expose public functions? (Fewer is better for a well-encapsulated context)
- Are there functions that should be private (`defp`) but are public?
- Does the context follow the facade pattern (single service module delegating to internals)?

**What to flag**: Contexts where callers must reach into internal modules (e.g., calling `Colony.Directives.TaskGraph.add_task/2` directly instead of going through `DirectiveService`). Also flag contexts with no clear public API boundary.

#### Dimension 4: Responsibility Coherence

Evaluate whether the context's modules all belong together:
- Do all modules serve the context's stated responsibility?
- Are there modules that would fit better in another context?
- Are there responsibilities split across multiple contexts that should be unified?
- Is the context trying to do too many things?

**What to flag**: Modules that feel misplaced (e.g., a notification concern inside the execution context). Also flag contexts where a single module handles a responsibility that could be its own context.

#### Dimension 5: Missing Abstractions

Evaluate whether the context is missing useful abstractions:
- Are there repeated patterns that suggest a missing shared module?
- Is there a missing behavior/protocol that would unify similar modules?
- Would a shared type module reduce coupling?
- Are there cross-cutting concerns (logging, validation) handled inconsistently?

**What to flag**: Concrete cases where introducing an abstraction would reduce code, improve consistency, or clarify intent. Do NOT flag hypothetical abstractions that might be useful someday.

### Step 4: Selective Source File Review

Based on concerns identified in Step 3, read up to **5 source files** from the context. Prioritize:
1. Modules flagged with Tier 1 scores <= 7
2. Modules at the API boundary (services, public interfaces)
3. Modules suspected of duplication or misplaced responsibility

Reading source confirms or refutes concerns found from health cards alone. Do NOT read source files speculatively.

### Step 5: Produce Report

Write the context coherence report to:
```
.colony/monitor/reports/contexts/<context-name>-<YYYY-MM-DD>.md
```

If a report for the same context and date already exists, append a sequence number: `<context-name>-<YYYY-MM-DD>-2.md`.

Target length: ~2K tokens (roughly 1500-2500 words).

## Report Schema

```markdown
# Context Coherence Report: <Context Name>

| Field | Value |
|-------|-------|
| **Context** | `colony/<context>` |
| **Directory** | `lib/colony/<context>/` |
| **Module count** | <N> |
| **Average score** | <N.N>/10 |
| **Date** | <YYYY-MM-DD> |
| **Reviewer** | Tier 2 Context Coherence |

## Context Summary

<2-3 sentences describing what this context does and its role in the system>

## Module Inventory

| Module | Type | Score | Role in Context |
|--------|------|-------|-----------------|
| `Module.Name` | Type | N/10 | <brief role description> |
| ... | ... | ... | ... |

## Coherence Assessment

### Strengths

- <Strength 1: what the context does well>
- <Strength 2: patterns that work>
- <Strength 3: good encapsulation, etc.>

### Findings

#### <FINDING-ID>: <Title>

- **Severity**: Critical | High | Medium | Low
- **Dimension**: Duplication | Pattern Consistency | API Surface | Responsibility | Missing Abstraction
- **Affected modules**: `Module.A`, `Module.B`
- **Issue**: <Description of the coherence issue>
- **Recommendation**: <Specific action to resolve>

#### <FINDING-ID>: <Title>

...

### Recommendations

1. <Highest priority recommendation with rationale>
2. <Next priority recommendation>
3. <Optional third recommendation>

## Source Files Reviewed

- `lib/colony/<context>/<file>.ex` — <reason for reading>
- ...

## Health Card References

- `.colony/monitor/health-cards/colony/<context>/<module>.md`
- ...
```

### Finding IDs

Use the pattern `COH-<NNN>` (e.g., `COH-001`, `COH-002`). Numbers are sequential within a single report. Finding IDs are local to each report — they do not need to be globally unique across reports.

### Severity Levels

| Severity | Meaning | Action |
|----------|---------|--------|
| **Critical** | Actively causing bugs, data inconsistency, or blocking development | Fix immediately |
| **High** | Significant maintenance burden, confusing API, or architectural drift | Fix in next sprint |
| **Medium** | Pattern inconsistency or missing abstraction that slows comprehension | Fix when working in context |
| **Low** | Minor style inconsistency or aspirational improvement | Address opportunistically |

### Health Card Field References

This review references health card fields defined in `SCHEMA.md`:
- **Score**: 1-10 scale per the rubric in `QUALITY_REVIEW.md`
- **Type**: Module type (GenServer, Service, Aggregate, etc.)
- **Moduledoc quality**: rich / adequate / weak / missing
- **Findings**: Issues found during Tier 1 individual module review

## Integration with Monitor Skill

The context coherence review is invoked as part of the monitor workflow:

```
--type coherence --context <name>     # Review a single context
--type coherence --all                # Review all contexts with >= 2 modules
--tier 2                              # Alias for --type coherence --all
```

Results are stored in `.colony/monitor/reports/contexts/` following the naming convention above.

## Error Handling

- **Missing health cards**: If Tier 1 cards don't exist for a context, report "Tier 1 health cards missing for colony/<context>. Run `--type quality` first." and skip.
- **Stale cards**: If any card's "Last reviewed" date is more than 14 days old, note it as a caveat in the report but proceed with the review.
- **Single-module context**: Skip with message "Context colony/<context> has only 1 module — no cross-module coherence to assess."
- **Empty context**: Skip with message "No health cards found for colony/<context>."
