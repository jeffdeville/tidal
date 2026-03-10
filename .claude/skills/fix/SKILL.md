---
name: fix
description: Fix bug using lightweight TDD workflow
---

You will fix the following bug using a lightweight TDD workflow:

**Bug Report**: $ARGUMENTS

Follow this streamlined process:

## Phase 1: Investigation (Think)
1. Reproduce the bug (write test that demonstrates it)
2. Identify root cause through:
   - Code search (@apps/*/lib paths)
   - Runtime inspection (if needed via Tidewave)
   - Review related tests
3. Plan minimal fix

## Phase 2: Write Failing Test
1. Create test that captures bug behavior
2. Verify test fails for the right reason
3. Document expected behavior in test

## Phase 3: Implement Fix
As .claude/agents/elixir-senior-developer.md:
1. Write minimal code to fix bug
2. Ensure new test passes
3. Verify no regressions (run full suite)

## Phase 4: Quick Quality Check
Run in parallel:
- mix test (all must pass)
- mix credo --strict --format=oneline (check changed files only)

IF complexity increased or new violations:
- Launch .claude/agents/optimization.md for refactoring

## Phase 5: Commit
Create commit with:
- "fix: [concise description]"
- Reference issue number if applicable
- Co-authored attribution

## Success Criteria
- ✓ Bug test passes
- ✓ No test regressions
- ✓ No new code smells introduced
- ✓ Root cause addressed (not just symptom)

Begin with Phase 1 now.
