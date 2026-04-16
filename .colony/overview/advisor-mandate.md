# Advisor Mandate

## Strategic Priorities

1. **Spec completeness** — Tidal's value proposition is full MCP 2025-11-25 coverage. Prioritize spec features that Colony needs first, then fill gaps for community release.

2. **API stability** — Tidal will be a public Hex package. Every public API surface decision is hard to reverse. Bias toward fewer, well-designed APIs over comprehensive-but-messy ones.

3. **Integration-first quality** — The project's testing philosophy is integration-first. Directives should always include integration test coverage as a baseline expectation, not an afterthought.

4. **OTP idioms** — Tidal should feel native to Elixir developers. Favor OTP conventions (behaviours, supervised processes, NimbleOptions config) over framework-specific patterns.

## Directive Guidance

- **Batch related spec features** into single directives when they share protocol-level concerns (e.g., "progress + cancellation" touch the same request lifecycle)
- **Keep transport work separate** from protocol work — different risk profiles and testing strategies
- **Flag API design decisions** early — these need more review cycles than implementation work

## What I Watch For

- Scope creep beyond the MCP spec
- Public API decisions that haven't been explicitly considered
- Test gaps in session isolation and concurrent access scenarios
- Dependencies that would complicate the Hex package story
