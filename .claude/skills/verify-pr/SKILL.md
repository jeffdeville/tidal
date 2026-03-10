---
name: verify-pr
description: Run comprehensive verification gauntlet on entire branch for PR readiness
---

You are conducting a comprehensive pre-PR verification for the current branch.

## Context

The user wants to ensure all code on the current branch is fully ready for PR review and merge. This is the final quality check before requesting code review.

## Your Task

Execute a complete verification gauntlet covering:

1. **Compilation Check**
   - Run `mix compile --warnings-as-errors --force`
   - Report any compilation warnings or errors
   - All apps must compile cleanly

2. **Test Coverage**
   - Run `mix test apps/hearth_interview` for the interview app
   - Run `mix test apps/hearth` for the main app
   - Run `mix test apps/hearth_app` for the UI app
   - Report test results: passed/failed/total
   - Identify any failing tests and categorize:
     - New failures from this branch's changes
     - Pre-existing failures (unrelated to this PR)

3. **Static Analysis**
   - Run `mix credo apps/hearth_interview --strict`
   - Run `mix credo apps/hearth --strict`
   - Run `mix credo apps/hearth_app --strict`
   - Report violations by severity (F/C/D/R/W)
   - Distinguish new violations from pre-existing

4. **Code Formatting**
   - Run `mix format --check-formatted`
   - Report any files needing formatting

5. **Git Status**
   - Check for uncommitted changes
   - Check current branch name
   - Check if branch is up to date with remote

6. **Documentation**
   - Check that modified files have updated moduledocs
   - Check that public functions have @doc annotations

7. **Quality Summary**
   - Create a comprehensive report with:
     - ✅ All checks that passed
     - ⚠️  Warnings that need attention
     - ❌ Blockers that must be fixed
     - 📋 Recommendations for improvements
   - Provide a clear "Ready for PR?" verdict

## Output Format

Present results in a structured, easy-to-scan format:

```
# PR Verification Report

## Branch: [branch-name]
Commit: [latest commit hash and message]

## Quality Gates

### ✅ Compilation
- All apps compile without warnings

### ⚠️  Tests (X/Y passing)
- hearth_interview: X/Y passed
  - Y failures are pre-existing database migration issues
- hearth: X/Y passed
- hearth_app: X/Y passed

### Static Analysis
- hearth_interview: Clean ✅
- hearth: 3 pre-existing violations (unrelated to PR)
- hearth_app: Clean ✅

### Formatting
- All files formatted ✅

### Git Status
- No uncommitted changes ✅
- Branch: task-X-feature-name
- Up to date with remote ✅

## Verdict

[Ready for PR | Needs Attention | Blocked]

[Summary of what needs to be addressed, if anything]
```

## Important Notes

- Focus on code changes introduced in THIS branch/PR
- Clearly distinguish between new issues and pre-existing ones
- Be thorough but concise
- Provide actionable feedback
- Remember: the goal is to ensure PR reviewers see clean, high-quality code
