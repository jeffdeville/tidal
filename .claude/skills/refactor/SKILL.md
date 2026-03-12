---
name: refactor
description: Refactor code and tests to improve quality while maintaining behavior
---

You will refactor the following code while maintaining existing behavior:

**Refactor Target**: $ARGUMENTS (or auto-detect from git diff)

## Phase 1: Determine Scope

```bash
CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" = "main" ]; then
  CHANGED=$(git diff --name-only HEAD~1 | grep -E "\.exs?$" | sort)
else
  CHANGED=$(git diff --name-only main...HEAD | grep -E "\.exs?$" | sort)
fi
```

Split into production files and test files. These define scope for all phases.

## Phase 2: Establish Safety Net

1. Run existing tests: `mix test --trace`
2. Check coverage: `mix test --cover`
3. If changed production code lacks adequate test coverage, write characterization tests first — they document current behavior

## Phase 3: Clean House

### 3a: Delete Dead & Deprecated Code

**Default action: DELETE.**

1. Search: `grep -rn "@doc deprecated\|@deprecated\|# DEPRECATED" lib/`
2. For each item: find usages → no usages = delete, test-only = update tests then delete, production = migrate then delete
3. Only keep if external API compatibility explicitly requires it (document why)

### 3b: Remove Redundant Tests

For each unit test, ask:
1. Does an integration test already cover this behavior?
2. Would this break if I refactored internals without changing behavior?
3. Is it mocking so much it's not testing anything real?

If yes to any → **delete the test**.

### 3c: Fix Test Anti-Patterns

- **Process.sleep / polling** → replace with `assert_receive {:event, _}, 2000`
- **async: false** → convert to async: true (document if truly impossible)
- **Testing implementation** → rewrite to test behavior through public API

## Phase 4: Refactor Production Code

Run complexity analysis:
```bash
mix credo --strict
```

Apply refactorings incrementally — **one change at a time, test after each**:

- Extract complex functions (CC > 9 must fix, CC > 5 should fix)
- Replace nested `case`/`if` with `with` chains
- Use pattern matching over conditionals
- Apply pipe operator for data transformations
- Flatten deeply nested code with guard clauses / early returns

**After EACH successful change**: run `mix test` and commit.

## Phase 5: Fill Coverage Gaps

For uncovered non-trivial code, write integration tests that:
- Use the public API (not internal functions)
- Verify observable behavior (WHAT not HOW)
- Are `async: true`
- Test both success and error paths

## Phase 6: Verification

Run the full quality gauntlet:
```bash
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix test
mix test --cover
grep -rn "Process.sleep" test/ | grep -v "# justified:"
```

All must pass. Coverage must be maintained or improved. No new Credo violations.

## Phase 7: Documentation

If public API or module structure changed:
- Update `@moduledoc` and `@doc` annotations
- Update `CLAUDE.md` if architecture descriptions are affected

## Phase 8: Final Commit

Commit with: `refactor: [what was improved]`
- Note complexity reduction if measurable
- Note deprecated code / redundant tests removed
- Note coverage changes

## Success Criteria

- All original tests still pass
- No new Credo violations
- Behavior provably unchanged
- No redundant unit tests (integration tests cover behavior)
- No unjustified Process.sleep or async: false
- 90% minimum coverage maintained
- No deprecated code remains (or documented reason)

## Safety Rules

- NEVER change behavior during refactoring
- Commit after each successful micro-refactoring
- If tests fail, revert immediately (`git checkout -- .`)
- Keep refactorings small and focused
- DELETE deprecated code and redundant tests by default
