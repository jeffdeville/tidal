---
name: documentation
description: Update Elixir code documentation and domain knowledge for the modules and subsystems you changed
argument-hint: <module, file, feature, or domain to document>
synced_from_colony: true
sync_pack: elixir
sync_source: packs/elixir/documentation/SKILL.md
sync_version: d3fefcef
---

Update documentation for: $ARGUMENTS

Use this skill when Elixir work changed public APIs, non-obvious behavior, domain boundaries,
or subsystem knowledge. This skill covers both code-level documentation and repository
knowledge maintenance.

## Phase 1: Analyze What Changed

1. Read the Elixir modules, tests, and supporting files you changed
2. Identify the public API surface and any changed invariants
3. Identify which domains or subsystems were touched
4. Decide whether the change is:
   - code API documentation
   - domain knowledge / subsystem docs
   - both

## Phase 2: Update Elixir Code Documentation

For public Elixir modules and functions that changed materially:

1. Add or update `@moduledoc` when the module's purpose, constraints, or usage changed
2. Add or update `@doc` for public functions whose behavior or contract changed
3. Add or update `@spec` for public functions when types are missing or stale
4. Prefer small, executable examples over vague prose

Focus on:
- purpose and boundaries
- input and return contracts
- important invariants
- error cases and side effects
- practical usage examples

Do not add noise:
- do not restate obvious implementation details
- do not document private helpers unless the module pattern requires it
- do not add examples that do not reflect actual usage

## Phase 3: Update Domain Knowledge

For each touched Elixir domain or subsystem:

1. Check the nearest `AGENTS.md` or other local guidance file
2. Assess whether it is stale relative to the code you just read
3. Create or update domain knowledge when:
   - you changed 3+ files in the same domain
   - you discovered a non-obvious invariant or failure mode
   - module responsibilities or boundaries changed
   - existing docs were wrong in a way that could mislead the next implementer

High-value knowledge to capture:
- constraints that are easy to violate
- state transitions or lifecycle rules
- module responsibility boundaries
- "do not do this" mistakes and why
- test setup or operational gotchas that would save future debugging time

Low-value knowledge to skip:
- speculative future plans
- restating what the code already says clearly
- details likely to churn immediately
- duplicating event data or implementation trivia

## Phase 4: Update Repository Knowledge

If the change affects cross-domain understanding, also review:
- `.colony/architecture/` for architectural interaction changes
- `.colony/constraints/` for newly discovered invariants
- `.colony/adr/` when a structural decision was made
- `.colony/domains/` when domain context exceeds what belongs in local guidance

Prefer documenting what is true now, not what might exist later.

## Phase 5: Optional Livebook

Create a Livebook in `notebooks/` only when interactive examples or an operational walkthrough
would materially help future developers. Good candidates:
- complex workflows
- debugging runbooks
- integration examples
- operational procedures

Do not create a Livebook for ordinary module docs.

## Decision Matrix

| Situation | Action |
|-----------|--------|
| Public Elixir API changed | Update `@moduledoc`, `@doc`, and `@spec` as needed |
| Local domain doc is stale | Update it |
| No local doc exists and the domain now has meaningful complexity | Create one |
| Cross-domain architecture changed | Update `.colony/architecture/` or ADRs |
| Docs are already accurate | Attest "no changes needed" in completion notes |

## Quality Bar

A good documentation update should save the next Elixir implementer time. It should
make boundaries, invariants, and usage clearer without creating maintenance burden.

If no documentation changes are needed, say so explicitly:

`Documentation review: Reviewed relevant Elixir/domain docs. Content is accurate for the current code state. No updates needed.`
