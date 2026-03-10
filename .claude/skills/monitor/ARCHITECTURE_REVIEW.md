---
name: architecture-review
description: Review prompt template for architecture monitoring
---

# Architecture Review Template

This document defines how to conduct an architecture review within the monitor skill. You are reviewing changes through the lens of the colony-elixir-architect (`.claude/agents/colony-elixir-architect.md`) and using the four-dimension review defined in `.colony/governance/architecture-reviewer.md`.

## Review Context Assembly

Before running the review, gather and read all of the following:

### 1. Architecture Docs (Foundation)

Read these three documents to ground the review in Colony's actual architecture:
- `.colony/architecture/README.md` — Invariants and three-layer overview
- `.colony/architecture/three-layer-model.md` — Directive / Task / Execution layer separation
- `.colony/architecture/cqrs-boundaries.md` — What uses CQRS vs Reconciler, and why

### 2. Constraints

Read `.colony/constraints/architecture.md` for ARCH-001 through ARCH-005.

### 3. The Diff

```bash
git diff <from_sha>..<to_sha> -- <architecture_files>
```

### 4. Current Content of Changed Files

Read the full current content of each changed file. The diff alone lacks surrounding context needed for structural analysis.

### 5. Blast Radius Files

For each changed `.ex` file, identify files that depend on it:
```bash
mix xref graph --sink <file> --only-nodes
```
If `mix xref` fails (compilation errors, etc.), fall back to:
- Grep for the module name across `lib/` and `test/`

You do NOT need to read blast radius files in full — just note them as context for how widely a change propagates.

### 6. Previous Findings (for dedup)

Read the most recent `arch-*.md` file from `.colony/monitor/findings/` (if any exists). Use it to avoid re-reporting unchanged issues.

### 7. Additional Architecture Docs (as needed)

If the change touches sessions, state machines, or founder interaction, also read:
- `.colony/architecture/state-machines-and-flows.md`
- `.colony/architecture/session-management.md`
- `.colony/architecture/founder-interaction.md`

If the change introduces new patterns or revisits old decisions, also read:
- `.colony/adr/001-task-execution-architecture.md`
- `.colony/adr/002-dispatch-as-transition.md`

## Four-Dimension Review

Evaluate the diff and changed files across all four dimensions defined in `.colony/governance/architecture-reviewer.md`:

### Dimension 1: Constraint Compliance

Check against ARCH-001 through ARCH-005. Key Colony-specific checks:
- **ARCH-004**: Domain mutations via `TaskService`/`DirectiveService` only. No direct `Repo.insert/update/delete` for tasks or directives. domain states are `:ready`, `:blocked`, `:completed`, `:cancelled`. Execution phases (`:pending`, `:scheduled`, `:running`, `:succeeded`, `:failed`) belong to the Reconciler, not CQRS.
- Arena pattern: `use Arena.Process`, `to_process_key/1`, `via_tuple()`, `Arena.wrap(arena, [])`.
- Code style: No nested `case` (use `with`), no `Process.sleep` in tests, no `Application.put_env` in async tests.

### Dimension 2: Architectural Coherence

Does the change *fit*?
- Three-layer placement (Directive / Task / Execution — data flows downward)
- CQRS vs Reconciler boundary (audit-trail test vs derivability test)
- Aggregate ownership (Directive vs Task responsibilities)
- Session artifact pattern (`session_id` + `cwd` + `transcript_path`)

### Dimension 3: Architectural Fitness

Is the architecture still serving the system?
- Layer stress, boundary drift, emerging patterns, complexity accumulation
- Legacy namespace usage (`Colony.Legacy.*` should be fully replaced)
- Design tension re-emergence from ADR-001 (agents-as-expertise) and ADR-002 (dispatch-as-transition)

### Dimension 4: Adversarial Challenge

Argue against the change:
- Necessity (what breaks without it?), simplicity (simplest alternative?), fragility (blast radius?)
- Assumption surfacing (session behavior, concurrency, single-instance)
- V1 regression check: `ClaimTask`, `CrashTask`, `SubmitPr`, `:in_progress`/`:pending` as domain task status

## Output

Produce a JSON verdict matching the format in `.colony/governance/architecture-reviewer.md`:

```json
{
  "status": "approved|needs_changes|rejected|escalate",
  "confidence": 0.0-1.0,
  "findings": [
    {
      "dimension": "compliance|coherence|fitness|adversarial",
      "constraint_id": "ARCH-XXX|COHERENCE|FITNESS|ADVERSARIAL",
      "severity": "blocker|error|warning|info",
      "location": "file:line",
      "issue": "Description",
      "recommendation": "Fix suggestion"
    }
  ],
  "architectural_notes": [
    "Dimension 3/4 observations worth recording"
  ],
  "summary": "One-line summary"
}
```

Then convert to the markdown format defined in `FINDINGS_FORMAT.md` and write to `.colony/monitor/findings/arch-YYYY-MM-DD.md`.
