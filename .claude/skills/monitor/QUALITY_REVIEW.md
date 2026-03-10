---
name: quality-review
description: Tier 1 quality review — per-module health card assessment
---

# Quality Review (Tier 1)

Assess individual Elixir modules for code quality, documentation, and pattern compliance. Produces a health card per module stored in `.colony/monitor/health-cards/`.

## Review Context Assembly

Before assessing a module, gather:

1. **Source file**: Read the module source (`lib/**/*.ex`)
2. **Existing card**: Check `.colony/monitor/health-cards/<mirrored-path>.md`
3. **Test file**: Check for corresponding test at `test/<mirrored-path>_test.exs`
4. **Current SHA**: `git log -1 --format=%H -- <source_path>`

## Moduledoc Quality Assessment

| Rating | Criteria |
|--------|----------|
| **rich** | ≥3 sentences. Explains purpose AND at least two of: interaction pattern, state shape, lifecycle, examples. For GenServers: must describe how other modules interact with it and what state it manages. |
| **adequate** | ≥2 sentences. Explains purpose clearly. May lack examples or detailed interaction description. |
| **weak** | 1 sentence or generic boilerplate (e.g., "Handles tasks"). Doesn't help a new developer understand the module. |
| **missing** | No `@moduledoc`, or `@moduledoc false`. |

### Ideal Moduledoc Templates

**GenServer**:
```elixir
@moduledoc """
<Purpose: what this process does and why it exists>

## Interaction Pattern

<How other modules communicate with this process — calls, casts, PubSub>

## State

<What the GenServer state contains and its shape>

## Supervision

<Where in the supervision tree, restart strategy>
"""
```

**Service** (e.g., TaskService, DirectiveService):
```elixir
@moduledoc """
<Purpose: what domain operations this service exposes>

## Usage

    {:ok, id} = MyService.create(attrs)
    :ok = MyService.complete(id, result)

## Domain vs Execution

<What this service owns vs what other layers handle>
"""
```

**Aggregate**:
```elixir
@moduledoc """
<Purpose: what consistency boundary this aggregate enforces>

## Status Lifecycle

<State machine diagram or table>

## State Transitions by Command

<Table of command → from → to>

## Design Philosophy

<What this aggregate owns and what it delegates>
"""
```

**Schema**:
```elixir
@moduledoc """
<Purpose: what data this schema represents and its role>

## Key Design

<Non-obvious field semantics, relationships, constraints>
"""
```

**Pure functions**:
```elixir
@moduledoc """
<Purpose: what transformations or utilities this module provides>

## Usage

    result = MyModule.transform(input)
"""
```

## Tier 1 Checklist

Apply each check to the module under review:

### Documentation Checks
1. **Moduledoc present and meaningful** — Rate as rich/adequate/weak/missing
2. **Public functions have @doc** — Every `def` (not `defp`) should have `@doc`
3. **Public functions have @spec** — Every `def` should have a `@spec`

### Complexity Checks
4. **Mixed abstraction levels in functions** — Length >20 lines is a *smell*, not a finding. When a function exceeds ~20 lines, investigate whether different lines operate at different abstraction levels. If so, the real finding is "mixed abstraction levels" — report what the levels are and which code belongs where. If the function is long but all code operates at the same level (e.g., a multi-step error pipeline, building a complex data structure, a sequence of independent recovery steps at the same granularity), it is **not a problem** — note this in the card and do not deduct.
5. **Mixed concerns in modules** — Length >300 lines is a *smell*, not a finding. When a module exceeds ~300 lines, investigate whether it handles multiple distinct responsibilities at different abstraction levels. If so, the real finding is "mixed concerns" — identify which concerns could be separated. If the module is long because its single responsibility is genuinely complex (e.g., a reconciler that must observe/diff/converge across many entity types), it is **not a problem** — note this in the card and do not deduct. Additionally, >12 `alias` declarations is a dependency smell — investigate whether the module is coupled to too many other modules. Report which alias groups represent distinct responsibilities.
6. **Arity ≤5** — Flag functions with more than 5 parameters
7. **Conceptual duplication** — Multiple functions (3+) that share a verb or concept (e.g., `resume_*`, `reconcile_*`) without clear, documented differentiation. The concern is not DRY — it's cognitive load. A reader encountering `reconcile`, `reconcile_now`, `reconcile_now_sync`, and `debounced_reconcile` can't predict which to call without reading all implementations. Flag when the distinctions aren't obvious from names and docs alone.

### Pattern Compliance Checks
8. **No nested case statements** — Use `with` blocks instead (per CLAUDE.md)
9. **GenServers use Arena.Process** — GenServers must `use Arena.Process` for test isolation
10. **Error handling patterns** — Check for bare `rescue` without logging, swallowed errors
11. **No Process.sleep** — Must use PubSub subscribe + assert_receive in tests
12. **Test file exists** — Public modules should have corresponding test files
13. **Inline observability noise** — Logging, telemetry spans, metrics, and tracing are orthogonal to business logic. When they're inline, they inflate function length and mix abstraction levels (business logic + operational concerns). The fix is declarative observability via decorators (e.g., `OpenTelemetryDecorator`, or a project-specific `@decorate trace(...)` macro). Decorators can only see function inputs and outputs, not intermediate values — but needing to trace an intermediate value usually means the function should be split so that value becomes an input or output.

    **What to flag**: ANY Logger/telemetry/ExecutionEvent calls interleaved with business logic in non-error paths. The issue is not percentage — it's the *presence* of observability concerns mixed with business logic. Even a single `Logger.info` in the middle of a business logic function is a code smell because it mixes abstraction levels (what the system does vs. what we want to observe about it).

    **What NOT to flag**: Error-path logging (rescue/catch blocks), dedicated observability modules, event handlers whose job is logging, or functions that are purely about emitting events.

### Architectural Checks
14. **CQRS discipline** — In service modules (`*Service`) and any module that operates on CQRS domain entities (Tasks, Directives): any direct `Repo.insert/update/delete` call on a domain entity bypasses the event store and breaks event replay. This is explicitly prohibited by CLAUDE.md. Flag each occurrence with the specific function and entity.

    **What to flag**: `Repo.update(task, ...)`, `Repo.insert(%Task{...})`, `Ecto.Changeset.change(task, ...) |> Repo.update!()` in service modules. The fix is a proper CQRS command.

    **What NOT to flag**: Execution-layer modules (Reconciler) writing to execution tables (`task_executions`, `execution_events`). These are intentionally not CQRS.

15. **GenServer state volatility** — For GenServers: examine whether process state can be reconstructed after a crash. If the GenServer holds state fields that are NOT backed by persistent storage (Postgres, EventStore) and NOT reconstructible from other running processes, it's a durability risk. When the process crashes and restarts, it loses this state, potentially leaving the system in an inconsistent state.

    **What to flag**: GenServer state maps/structs with >2 fields that would be lost on crash with no recovery path. Describe what happens to each field on restart. Note: a `startup_recovery` function that rebuilds state from persistent storage is a valid mitigation — document it if present.

    **What NOT to flag**: Caches (rebuild on miss), derived state (computable from persistent data), configuration (read from Application config on init).

16. **Naming-behavior consistency** — Function names must accurately describe their preconditions and behavior. When a function is named `resume_pending_directive` but actually requires `:analyzing` status (not `:pending`), the name misleads readers and callers. Flag when function names imply a precondition or behavior that doesn't match the implementation.

17. **Architectural complexity flag** — This is a meta-check, not a line-item deduction. When a module has ALL of:
    - >800 lines
    - >12 aliases
    - >4 conceptually distinct sections (separated by comment headers or clear responsibility boundaries)
    - Multiple interaction patterns (timers + PubSub + GenServer calls + DB queries)

    Add an "⚠️ Architectural Review Recommended" note to the health card's Recommendations section. This doesn't deduct from the score directly — the individual findings (mixed concerns, mixed abstractions, etc.) already do that. But it signals that piecemeal fixes won't resolve the root issue; the module needs holistic redesign.

## Scoring Rubric

Start at **10**. Deduct per issue found. Floor: **1**.

### Documentation (cap: -4)

| Issue | Deduction | Cap |
|-------|-----------|-----|
| Missing moduledoc | -2 | — |
| Weak moduledoc | -1 | — |
| Public fn without `@doc` | -0.5 each | -2 |
| Public fn without `@spec` | -0.5 each | -2 |

### Complexity (cap: -4)

| Issue | Deduction | Cap |
|-------|-----------|-----|
| Function with mixed abstraction levels | -0.5 each | -2 |
| Module with mixed concerns (distinct responsibilities) | -1 | — |
| Conceptual duplication (overlapping function groups) | -0.5 per group | -1 |
| Arity >5 | -0.5 each | -1 |

### Pattern Compliance (cap: -4)

| Issue | Deduction | Cap |
|-------|-----------|-----|
| Nested case statement | -0.5 each | -1 |
| Inline observability noise in business logic | -0.5 each | -2 |
| GenServer missing `Arena.Process` | -1 | — |
| No test file for public module | -0.5 | — |

### Architectural (cap: -5)

| Issue | Deduction | Cap |
|-------|-----------|-----|
| CQRS bypass (`Repo.update` on domain entity in service) | -2 each | -4 |
| GenServer volatile state (>2 non-reconstructible fields) | -1 | — |
| Naming-behavior mismatch | -0.5 each | -1 |

**Notes**:
- "adequate" moduledoc: no deduction
- "rich" moduledoc: no deduction
- Length alone is never a finding — it's a smell that triggers deeper analysis
- A long function where all code operates at the same abstraction level: **no deduction**
- A long module that owns a single complex responsibility: **no deduction**
- Architectural checks carry the heaviest per-finding weight because they affect system correctness, not just readability
- Round final score to nearest 0.5

### Score Interpretation

| Score | Meaning |
|-------|---------|
| 9-10 | Clean — no significant issues |
| 7-8.5 | Needs attention — documentation or minor pattern issues |
| 5-6.5 | Significant issues — architectural violations or multiple concerns |
| 3-4.5 | Major rework needed — CQRS bypass + volatility + complexity |
| 1-2.5 | Fundamentally broken — redesign required |

## Output Format

Write the health card following the template in `SCHEMA.md`. Store at the mirrored path under `.colony/monitor/health-cards/`.

Example: reviewing `lib/colony/tasks/task_service.ex` produces `.colony/monitor/health-cards/colony/tasks/task_service.md`.
