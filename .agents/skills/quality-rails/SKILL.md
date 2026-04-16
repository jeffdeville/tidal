---
name: quality-rails
description: Install or update the standard Elixir quality rails bundle: formatter, Credo, lefthook, coverage ratchet, CI parity, and portable custom checks
synced_from_colony: true
sync_pack: elixir
sync_source: packs/elixir/quality-rails/SKILL.md
sync_version: d3fefcef
---

# Elixir Quality Rails

Use this skill when a managed Elixir project needs the standard quality bundle.

The default approach is copy-first, not reinvention. Start from the canonical pack files:

- `packs/elixir/files/root/.formatter.exs`
- `packs/elixir/files/root/.credo.exs`
- `packs/elixir/files/root/lefthook.yml`
- `packs/elixir/files/root/.lefthook/pre-push/coverage-ratchet.sh`
- `packs/elixir/files/root/checks/*.ex`
- `packs/elixir/workflows/ci.yml`

## Phase 1: Audit Existing Setup

Read:
- `mix.exs`
- `.formatter.exs` if present
- `.credo.exs` if present
- `lefthook.yml` if present
- `.github/workflows/ci.yml` if present
- any existing `checks/` or custom Credo check paths

Determine:
- Phoenix vs plain Elixir vs LiveView
- whether Credo is already configured
- whether git hooks already exist
- whether coverage is already tracked
- whether the project already has custom checks

## Phase 2: Copy the Canonical Rails

Copy the canonical pack files into the project’s default target paths.

Prefer these standard destinations:
- `.formatter.exs`
- `.credo.exs`
- `lefthook.yml`
- `.lefthook/pre-push/coverage-ratchet.sh`
- `checks/*.ex`
- `test/checks/*_test.exs`
- `.github/workflows/ci.yml`

Do not hand-author these from scratch unless the pack file is missing.

## Phase 3: Adapt Minimally

Only change what the target repo genuinely needs:
- formatter `import_deps` or plugins for framework-specific formatters
- CI database service or env
- coverage baseline storage if `README.md` is not appropriate
- Credo thresholds if the repo is not yet clean enough
- add or remove portable checks based on project needs

Keep the path hierarchy stable so future sync can stay copy-based.

## Phase 4: Verify Parity

The local rails and CI should check the same things:
- compile with warnings as errors
- format check
- Credo
- tests
- coverage ratchet if enabled

Do not let hooks and CI drift into separate policy systems.

## Phase 5: Verify

Run:
- `mix compile --warnings-as-errors`
- `mix format --check-formatted`
- `mix credo --min-priority=high`
- `mix test`

If hooks were installed, verify `lefthook install` succeeds.

## Notes

- Portable custom checks belong in `checks/`, not `lib/<app>/checks/`
- Project-specific checks can extend the bundle, but should preserve the default paths
- If the project already has another hook manager, document the conflict explicitly
