---
name: deliver
description: Complete feature delivery with full quality gauntlet and product owner review
disable-model-invocation: true
---

# Deliver Command: Complete Quality Workflow with Product Owner Review

Implement a feature with comprehensive quality checks from all specialized agents, including business value validation.

**Feature Request**: $ARGUMENTS

This command orchestrates all agents to ensure production-ready code that delivers real user value. Use this when you want the full quality treatment with business context validation.

## Workflow Overview

```
Phase 1: Planning (architect-elixir, functional-programming:elixir-pro, product-owner in parallel)
    ↓
Phase 2: Tests (testing agent) → TDD Red Phase
    ↓
Phase 3: Implementation (functional-programming:elixir-pro) → TDD Green Phase
    ↓
Phase 4: Quality Gates (verification agent) → MUST ALL PASS
    ↓ (if ANY fail)
Phase 5: Optimization Loop (optimization agent) ← ┐
    ↓                                              │
    └─ Re-run Phase 4 ─────────────────────────────┘
    ↓ (all green - NO EXCEPTIONS)
Phase 6: Comprehensive Review (architect-elixir + product-owner in parallel)
    ↓ (critical/high issues MUST be fixed)
Phase 7: Observability (observability agent)
    ↓
Phase 8: Documentation (documentation agent)
    ↓
Phase 9: UI Validation (if Phoenix/LiveView) → REAL data/APIs REQUIRED
    ↓
Phase 10: Pre-Commit Verification → Hooks MUST PASS (no --no-verify)
    ↓ (pre-commit failed?)
    └─ Fix issues, re-commit ─────────────────────┐
    ↓ (pre-commit passed)                          │
Phase 11: CI Verification → Pipeline MUST BE GREEN │
    ↓ (CI failed?)                                 │
    └─ Fix issues, push, wait for CI ──────────────┘
    ↓ (CI green - NO EXCEPTIONS)
Phase 12: Create PR → ONLY after ALL gates pass

⚠️  BLOCKERS (Cannot proceed past):
    - Phase 4: Until ALL quality checks pass
    - Phase 6: Until critical/high findings addressed
    - Phase 10: Until pre-commit hooks pass
    - Phase 11: Until CI pipeline is green
    - Phase 12: Until ALL criteria met
```

## Troubleshooting Protocol

If blocked >5 minutes on ANY phase, follow this protocol BEFORE declaring a blocker:

### Step 1: Quick Wins (2 min)
```bash
mix deps.clean --all && mix deps.get && mix compile
mix clean && mix compile
# Kill and restart mix phx.server
```

### Step 2: Web Search - Specific (3 min)
Search: `"[exact error message]" + [framework name] + [version]`

**Example**: "Protocol.UndefinedError LazyHTML Phoenix LiveView 1.1"

Check:
- First 3 Google results
- ElixirForum (add `site:elixirforum.com`)
- Recent GitHub issues (add `site:github.com/phoenixframework`)

### Step 3: Web Search - Community (3 min)
Search: `[general problem] + "elixir forum" OR "stackoverflow"`

Focus on:
- Recent posts (last 12 months)
- Accepted/upvoted answers
- Similar project setups

### Step 4: Runtime Intelligence (2 min)
Use Tidewave MCP to inspect running application:
- **Check logs**: `get_logs` to see recent errors
- **Query database**: `execute_sql_query` to verify data state
- **Inspect schemas**: `get_schemas` to understand data structure
- **Test code**: `project_eval` to run Elixir in app context

### Step 5: Check Patterns (2 min)
Is this related to:
- **Auth + LiveView**? → Check ui-elixir.md for on_mount patterns
- **Umbrella project**? → Check asset paths (need extra `../`)
- **Testing**? → Check for lazy_html dependency
- **Generators**? → Check for config duplicates or missing routes

### Step 6: Document & Escalate (2 min)
Only after 12 minutes total, declare blocker with:
- What searches you ran
- What results you found
- What you tried
- Why it didn't work

**Do not** assume framework bugs before completing all 6 steps.

## Phase 1: Planning & Research (Think Hard)

**Parallel Collaboration**: Launch architect-elixir, functional-programming:elixir-pro, and product-owner in parallel using Task tool.

Use THREE Task tool calls in a single message to run agents in parallel:

```
Task 1 - Architect (subagent_type: "general-purpose"):
"You are architect-elixir from .claude/agents/architect-elixir.md.

Feature: $ARGUMENTS

Analyze this feature from an architecture perspective:
1. What modules/contexts are affected?
2. What OTP patterns should be used?
3. What are the cognitive load risks (>4 facts)?
4. What existing patterns should be followed?
5. What are the key integration points?

Return:
- Affected modules/contexts
- OTP patterns recommended
- Cognitive load hotspots to watch for
- Existing patterns to follow (with file references)
- Integration points and dependencies"
```

```
Task 2 - Senior Developer (subagent_type: "general-purpose"):
"You are functional-programming:elixir-pro from .claude/agents/functional-programming:elixir-pro.md.

Feature: $ARGUMENTS

Plan the technical implementation:
1. Read CLAUDE.md and app-specific CLAUDE.md files
2. Search codebase for similar implementations
3. Identify required dependencies
4. Create step-by-step implementation plan
5. Define success criteria (functional + technical)

Return:
- Implementation approach
- Required dependencies
- Step-by-step plan
- Success criteria
- Complexity estimate"
```

```
Task 3 - Product Owner (subagent_type: "general-purpose"):
"You are product-owner from .claude/agents/product-owner.md.

Feature: $ARGUMENTS

Provide business context and user perspective:
1. What user pain point does this solve (homeowners/contractors)?
2. How does this reduce user work (not increase it)?
3. What are the success metrics?
4. What user flows need to be tested?
5. What are the acceptance criteria from user perspective?

Return:
- Business value statement
- User impact (homeowners + contractors)
- Success metrics
- Key user flows to test
- Non-technical acceptance criteria"
```

**Synthesize** results from all three agents into comprehensive plan with:
- Technical approach (from architect + developer)
- Business context (from product owner)
- Success criteria (functional, technical, user-facing)

## Phase 2: Test Strategy (TDD Red Phase)

**Delegate to**: testing agent via Task tool

Generate comprehensive test suite following TDD principles:
1. Write failing tests first (TDD red phase)
2. Unit tests for each public function
3. Property tests for data transformations (StreamData)
4. Integration tests for full user workflows (from product-owner)
5. Browser-testable scenarios (if UI feature)
6. Avoid mocks unless absolutely necessary
7. Cover happy paths, edge cases, error conditions

## Phase 3: Implementation (TDD Green Phase)

**Primary Agent**: functional-programming:elixir-pro (you)

Follow patterns from .claude/agents/functional-programming:elixir-pro.md:
1. Implement minimal code to make tests pass
2. Use idiomatic Elixir (pattern matching, pipes, `with`)
3. Keep functions small (<20 lines ideal)
4. Return tagged tuples: `{:ok, result} | {:error, reason}`
5. Handle all error cases explicitly

**For Phoenix/LiveView features**: Reference ui-elixir agent knowledge:
- `on_mount` hooks for LiveView auth
- Handle generator quirks (config duplication, missing deps)
- Umbrella project specifics (asset paths)
- Common testing issues (lazy_html, cache corruption)

**Output**: Working code that makes all tests pass (green phase)

## Phase 4: Quality Gates (Parallel Checks)

**⚠️ CRITICAL: Code CANNOT proceed to merge until ALL quality gates pass, including pre-commit hooks and CI.**

Run comprehensive quality checks:
1. mix test (100% must pass)
2. mix coveralls.json (≥80% coverage)
3. mix credo --strict --format=json (0 violations)
4. mix format --check-formatted (all formatted)

**Success Criteria (MUST ALL PASS)**:
- ✓ All tests passing
- ✓ Coverage ≥ 80%
- ✓ 0 Credo violations
- ✓ 0 Dialyzer warnings
- ✓ Code formatted

**⚠️ IF ANY GATE FAILS**: STOP and loop back to Phase 5 (Optimization) to fix issues. DO NOT proceed to Phase 6 until status is "pass".

## Phase 5: Optimization Loop (Conditional)

IF Phase 4 shows high complexity (CC > 9):

Run complexity analysis:
1. Identify functions with CC > 9 (must fix)
2. Identify functions with CC > 5 (should consider)
3. Suggest specific refactoring patterns

**Refactor** based on recommendations, then **loop back to Phase 4** until all quality gates pass.

## Phase 6: Comprehensive Review (Parallel)

**Launch TWO agents in parallel**: architect-elixir and product-owner.

**Review both outputs** and address:
- **Critical findings**: Must fix before proceeding
- **High findings**: Should fix before proceeding
- **Medium/Low findings**: Document for future improvement

## Phase 7: Observability Review (High-Value Only)

Evaluate HIGH-VALUE observability opportunities ONLY:
- Apply STRICT threshold: no noise!
- Only suggest measurements that answer specific questions
- Use AOP approach (decorators) for orthogonal concerns

## Phase 8: Documentation (Minimal - Clear Code First)

**Philosophy**: The best documentation is clear code.

**Required**:
- `@spec` on all public functions (always - this is non-negotiable)

**Only When Necessary**:
- `@doc` - Only for non-obvious behavior, edge cases, or algorithms
- `@moduledoc` - Only if the module's purpose isn't clear from its name and public API

## Phase 9: UI Validation (For Phoenix/LiveView Features)

**⚠️ REQUIRED for all UI features** - do not skip!

**⚠️ CRITICAL: Test with REAL data, REAL APIs, REAL integrations**

## Phase 10: Pre-Commit Verification (MANDATORY)

**⚠️ CRITICAL: Code CANNOT be committed until pre-commit hooks pass. This is NON-NEGOTIABLE.**

**⚠️ NEVER use `--no-verify` to bypass pre-commit hooks**.

## Phase 11: CI Verification (MANDATORY BEFORE MERGE)

**⚠️ CRITICAL: Code CANNOT be merged until CI passes. Passing tests locally is NOT sufficient.**

## Phase 12: Create Pull Request (ONLY AFTER CI PASSES)

**Prerequisites (MUST ALL BE TRUE)**:
- ✅ Pre-commit hooks passed
- ✅ CI pipeline passing (all checks green)
- ✅ All quality gates passed
- ✅ No outstanding issues from Phase 6 reviews

## Success Criteria (All Must Pass) - NON-NEGOTIABLE

**⚠️ PRIMARY CRITERION**: **Working Software Delivers User Value**

**Code Quality Criteria** (MUST PASS):
- ✓ **Tests**: 100% passing, ≥80% coverage
- ✓ **Quality**: 0 Credo violations, 0 Dialyzer warnings
- ✓ **Formatted**: mix format passes
- ✓ **Complexity**: Average CC <5, max CC <10

**⚠️ ABSOLUTE BLOCKERS (No Exceptions)**:
1. Pre-Commit Hooks MUST Pass
2. CI Pipeline MUST Be Green
3. All Tests MUST Pass in CI
4. Code Coverage MUST Meet Threshold (80%)
5. Credo MUST Be Clean (0 violations)
6. Dialyzer MUST Be Clean (0 warnings)
7. Architecture Review MUST Pass
8. Product Owner Review MUST Pass

Begin with Phase 1 now.
