---
name: custom-credo-check
description: Create or update a project-specific Credo check and wire it into the standard Elixir quality rails layout
synced_from_colony: true
sync_pack: elixir
sync_source: packs/elixir/custom-credo-check/SKILL.md
sync_version: d3fefcef
---

# Custom Credo Check

Use this skill when a project needs a custom lint rule beyond the portable defaults.

## Standard Layout

Place new checks in:
- `checks/<check_name>.ex`

Place tests in:
- `test/checks/<check_name>_test.exs`

Register the file in:
- `.credo.exs` under `requires`
- the appropriate Credo config under `checks.enabled`

## Design Rules

Write checks that are:
- narrowly scoped
- explainable in one sentence
- grounded in a real failure mode or recurring review issue
- testable with small AST fixtures

Avoid checks that encode taste without payoff.

## Process

1. Name the rule after the behavior it prohibits or enforces
2. Write the failing tests first
3. Implement the AST traversal
4. Add a concise error message and explanation
5. Register the check in `.credo.exs`
6. Run the targeted check tests plus `mix credo`

## Portability

If the rule is generic enough for most Elixir repos, consider promoting it into
the portable Elixir pack bundle under `packs/elixir/files/root/checks/`.

If it depends on project-specific architecture or module names, keep it project-local.
