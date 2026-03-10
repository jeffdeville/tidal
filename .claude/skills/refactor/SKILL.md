---
name: refactor
description: Refactor code to improve quality while maintaining behavior
---

You will refactor the following code while maintaining existing behavior:

**Refactor Target**: $ARGUMENTS

Follow this process:

## Phase 1: Establish Safety Net
1. Verify existing tests exist and pass for target
2. IF insufficient tests:
   - Launch .claude/agents/testing.md to generate characterization tests
   - These tests document current behavior (even if flawed)
3. Run tests to establish baseline

## Phase 1.5: Detect Deprecated Code
**IMPORTANT**: Strongly prefer DELETING deprecated code over keeping it.

1. Search for deprecated functions and modules:
   - `grep -rn "@doc deprecated\|@deprecated\|# DEPRECATED\|# deprecated" lib/`
   - Check for functions marked with `@doc deprecated:` attribute
   - Look for comments indicating deprecation

2. For each deprecated item found:
   - Identify all usages: `grep -rn "FunctionName\|ModuleName" lib/ test/`
   - If usages exist, migrate them to the recommended replacement
   - If no usages exist, DELETE the deprecated code immediately
   - If usages are only in tests, update tests to use the canonical approach

3. **DEFAULT ACTION**: Delete deprecated code. Only keep if:
   - External API compatibility is explicitly required
   - Migration would break published interfaces
   - Document the reason in a comment if keeping

## Phase 2: Analyze Current State
Launch .claude/agents/optimization.md agent with:
- Target file/module
- Request: Complexity analysis and refactoring recommendations

The optimization agent will:
- Run `mix credo --strict --format=json`
- Identify functions with CC > 9 (must fix) and CC > 5 (should fix)
- Suggest specific refactoring patterns
- Prioritize recommendations by impact

## Phase 2.5: Verify Data Contracts
Launch .claude/agents/contracts-reviewer.md with:
- All changed files
- Request: Identify contract violations

The contracts reviewer will verify:
- Cross-context data uses Ecto embedded schemas
- Option lists use NimbleOptions validation
- Public APIs validate at boundaries
- Tests use ExMachina with pipe composition

If violations found, include fixes in refactoring plan.

## Phase 3: Incremental Refactoring (Think Hard)
As .claude/agents/elixir-senior-developer.md:
1. Apply highest priority refactoring
2. Run tests after EACH change
3. Commit after EACH successful refactoring
4. Repeat until quality targets met

Refactoring patterns to consider:
- Extract complex logic into smaller functions
- Replace nested case/if with `with`
- Use pattern matching over conditionals
- Apply pipe operator for transformations

## Phase 4: Verification
Launch .claude/agents/verification.md agent with:
- All refactored code
- Request: Full quality check

Verify:
- All tests still pass (behavior unchanged)
- Complexity reduced to acceptable levels
- No new Credo violations
- Coverage maintained or improved
- **No deprecated code remains** (unless explicitly justified)

## Phase 5: Documentation Update
IF public API or complexity significantly changed:
- Launch .claude/agents/documentation.md
- Update module docs to reflect clearer structure

## Phase 6: Final Commit
Create commit with:
- "refactor: [what was improved]"
- Note complexity reduction (e.g., "CC: 12 → 4")
- Note deprecated code removed (if any)
- Co-authored attribution

## Success Criteria
- ✓ All original tests still pass
- ✓ Average CC < 5, max CC < 10
- ✓ No new violations introduced
- ✓ Behavior provably unchanged
- ✓ Code more maintainable
- ✓ **No deprecated code remains** (or documented reason why)

## Safety Rules
- NEVER change behavior during refactoring
- Commit after each successful micro-refactoring
- If tests fail, revert immediately
- Keep refactorings small and focused
- **DELETE deprecated code by default** - keeping it requires justification

Begin with Phase 1 now.
