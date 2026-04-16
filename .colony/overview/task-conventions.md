---
type: task-conventions
project: tidal
last_updated: 2026-03-09
---

# Task Conventions

## Archetypes

### spec_feature
Implementing a feature defined in the MCP specification (tools, resources, sampling, etc.)
- deliverable: pr_merged
- default_criteria:
  - Implementation matches MCP 2025-11-25 spec requirements (MUST/SHOULD/MAY semantics)
  - All protocol messages use validated structs, not bare maps
  - Integration test covering the full HTTP request/response cycle
  - Spec compliance test that verifies against documented protocol behavior
  - NimbleOptions validation for any public configuration surface
  - No regressions in existing spec feature tests

### transport_feature
Work on the Streamable HTTP transport layer (SSE, session management, resumability, etc.)
- deliverable: pr_merged
- default_criteria:
  - Conforms to Streamable HTTP transport specification
  - Integration test with real HTTP requests through Plug/Bandit
  - Session isolation verified (one session's state doesn't leak to another)
  - Error/edge cases covered (disconnection, invalid session ID, malformed requests)
  - Concurrent session test where applicable

### protocol_primitive
Implementing a JSON-RPC or MCP protocol-level primitive (batching, error codes, cancellation, progress)
- deliverable: pr_merged
- default_criteria:
  - JSON-RPC 2.0 compliance verified
  - Struct-based message representation with changeset validation
  - Round-trip serialization test (encode → decode → compare)
  - Integration test exercising the primitive through the transport layer

### api_design
Designing or refining the public API surface that Tidal consumers use
- deliverable: pr_merged
- default_criteria:
  - API follows Elixir/OTP conventions (behaviours, callbacks, supervision)
  - NimbleOptions schema for all option lists
  - Typespecs on all public functions
  - Documentation with usage examples
  - No breaking changes without explicit justification

### test_infrastructure
Building or improving test tooling, helpers, factories, or test architecture
- deliverable: pr_merged
- default_criteria:
  - Enables integration testing of MCP protocol features
  - Reusable test helpers are well-documented
  - Does not introduce flaky test patterns
  - Test isolation maintained (no shared mutable state between tests)

### config_migration
Applying a Colony config migration (schema changes to `.colony/` YAML/JSON files)
- deliverable: validated
- default_criteria:
  - Migration applied cleanly via the `apply-config-migration` skill
  - No data loss in existing config files
  - Committed with standard `chore: apply config migration` message
- notes: Mechanical, single-task directives. Solo leader delegation is sufficient — no expert panel needed.

### bug_fix
Fixing a defect in existing functionality
- deliverable: pr_merged
- default_criteria:
  - Root cause identified and documented in PR description
  - Regression test added that fails without the fix
  - No unrelated changes bundled in

### refactor
Improving code structure without changing behavior
- deliverable: pr_merged
- default_criteria:
  - All existing tests pass without modification (behavior unchanged)
  - Cognitive load reduced (clearer naming, simpler control flow, better abstractions)
  - No new public API surface unless justified

### documentation
Writing or updating project documentation
- deliverable: validated
- default_criteria:
  - Accurate and consistent with current implementation
  - Follows hexdocs conventions for Elixir projects
  - Includes code examples where appropriate

## Workflow Patterns

- Every `spec_feature` should be preceded by reading the relevant spec section and
  producing a brief design note (captured in the task description or PR) before coding
- `transport_feature` and `spec_feature` tasks should always include integration tests;
  unit-only coverage is insufficient
- `api_design` tasks should consider the LiveView-inspired session model as the guiding
  metaphor for developer experience
- `refactor` tasks must not be bundled with feature work — keep them separate for clean
  review
