---
name: refine-testing
description: Refine test quality - coverage, integration tests, remove redundant unit tests
---

You will refine the test quality for recently changed code.

## Phase 0: Determine Target Files

First, determine what files to analyze based on the current git context.

```bash
# Check current branch
CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" = "main" ]; then
  # On main: use arguments or recent changes
  if [ -n "$ARGUMENTS" ]; then
    echo "Using provided arguments: $ARGUMENTS"
  else
    echo "On main without arguments - using HEAD~1"
  fi
else
  # On a feature branch: get all changes vs main
  echo "On branch '$CURRENT_BRANCH' - comparing to main"
fi
```

**Establish the target file lists once** (use these throughout all phases):

```bash
# TEST FILES changed in this branch (or recent commit if on main)
if [ "$CURRENT_BRANCH" = "main" ]; then
  TEST_FILES=$(git diff --name-only HEAD~1 | grep "_test.exs$" | sort)
else
  TEST_FILES=$(git diff --name-only main...HEAD | grep "_test.exs$" | sort)
fi

# PRODUCTION FILES changed (corresponding to test files)
if [ "$CURRENT_BRANCH" = "main" ]; then
  PROD_FILES=$(git diff --name-only HEAD~1 | grep -E "\.ex$" | grep -v "_test.exs$" | sort)
else
  PROD_FILES=$(git diff --name-only main...HEAD | grep -E "\.ex$" | grep -v "_test.exs$" | sort)
fi

echo "=== Target Test Files ==="
echo "$TEST_FILES"
echo ""
echo "=== Target Production Files ==="
echo "$PROD_FILES"
```

Store these lists - they define the scope for all subsequent phases.

## Philosophy

Unit tests verify HOW something works (implementation details).
Integration tests verify WHAT something does (behavior).

**Implementation changes; behavior shouldn't.**

Unit tests are valuable scaffolding during TDD. But once the code works, integration tests are the foundation. A unit test that duplicates what an integration test already covers is noise—it slows the suite and creates maintenance burden.

## Phase 1: Identify Changed Modules

Using the `PROD_FILES` list from Phase 0, identify the production modules that were touched.

## Phase 2: Analyze Coverage

For each changed module, check coverage:

```bash
mix test --cover --export-coverage default
mix test.coverage
```

**Focus on**:
- Functions with 0% coverage (must add tests)
- Non-trivial logic without coverage (conditionals, pattern matching, error handling)

**Ignore**:
- Simple getters/setters
- Struct definitions
- Delegation functions

## Phase 3: Audit Existing Tests

For each test file related to the changed modules:

### 3.1 Identify Unit vs Integration Tests

**Unit Test Characteristics**:
- Tests a single function in isolation
- Mocks dependencies
- Tests implementation details (internal state, private function behavior)
- Fast but brittle

**Integration Test Characteristics**:
- Tests behavior through public API
- Uses real (Arena-isolated) infrastructure
- Verifies what the system does, not how
- Slower but stable

### 3.2 Find Redundant Unit Tests

A unit test is redundant if:
1. An integration test already covers the same behavior
2. The test is testing implementation details that could change
3. The test mocks so much that it's not testing real behavior

### 3.3 Check for Anti-Patterns

**Process.sleep / Polling** (BAD):
```elixir
# Anti-pattern - slow and flaky
TaskService.start_task(task_id)
Process.sleep(100)
assert Task.get(task_id).status == :running
```

**Event-Driven** (GOOD):
```elixir
# Correct - fast and deterministic
Colony.PubSub.subscribe("tasks:all")
TaskService.start_task(task_id)
assert_receive {:task_event, %TaskStarted{task_id: ^task_id}}, 2000
```

**async: false** (BAD unless absolutely necessary)

**Missing Arena isolation** (BAD)

## Phase 4: Refine Tests

### 4.1 Add Missing Integration Tests

For uncovered non-trivial code, write integration tests that:
- Use the public API
- Verify observable behavior
- Use event assertions (`assert_receive`)
- Are `async: true` with Arena isolation

### 4.2 Remove Redundant Unit Tests

For each unit test, ask:
1. Is there an integration test that covers this behavior?
2. Would this test break if I refactored implementation without changing behavior?
3. Is this test mocking so much it's not testing anything real?

If yes to any, **delete the unit test**.

### 4.3 Convert Sleep/Poll to Event-Driven

Find all `Process.sleep` in tests and convert to `assert_receive`.

### 4.4 Ensure Arena Isolation

**Full documentation**: `.claude/docs/arena-guide.md`

Every test that touches Database, GenServers, PubSub, or Registry must use Arena.

**Common Arena issues** (use `/flaky-test-debug` for diagnosis):

1. **Missing `Arena.wrap`** when starting processes
2. **Using `__MODULE__` instead of `via_tuple()`**
3. **Missing `use Arena.Process`** in GenServer modules

## Phase 5: Verify Changes

```bash
# All tests still pass
mix test

# Coverage improved or maintained
mix test --cover

# No Process.sleep in test files (should be zero or justified)
grep -rn "Process.sleep" test/ | grep -v "# justified:"
```

## Phase 6: Architecture Consistency Check

After refining tests, verify they align with architecture documentation.

Launch the `colony-elixir-architect` agent to compare tests against:
- `.colony/architecture/state-machines-and-flows.md`
- `.colony/architecture/cqrs-boundaries.md`

## Phase 7: Report

Provide a summary of coverage changes, tests removed, tests added, anti-patterns fixed, and remaining issues.

## Success Criteria

- ✓ Non-trivial code has integration test coverage
- ✓ No redundant unit tests (integration tests cover behavior)
- ✓ No Process.sleep/polling patterns (event-driven)
- ✓ All tests async: true with Arena isolation
- ✓ Tests verify WHAT (behavior) not HOW (implementation)
- ✓ All GenServers use `via_tuple()` and `use Arena.Process`
- ✓ All process spawning uses `Arena.wrap(arena, opts)`
- ✓ Tests align with architecture documentation (no undocumented behavior)
- ✓ Architecture docs updated to reflect tested behavior

## Related Resources

- **Arena Guide**: `.claude/docs/arena-guide.md` - Complete Arena documentation
- **Arena Debugging**: `/flaky-test-debug` - Diagnose Arena configuration issues
- **Debugging Tools**: `lib/colony/test_support/arena_debugger.ex`, `test/support/arena_inspector.ex`
