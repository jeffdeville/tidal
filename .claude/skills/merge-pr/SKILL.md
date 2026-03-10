---
name: merge-pr
description: Push, create PR, monitor CI, fix failures, merge, and complete implementation tasks
categories: [merge, implementation]
---

# Merge PR: Agent-Side PR Lifecycle

Handle the complete PR lifecycle: push, create PR, monitor CI, fix problems, merge, and signal completion.

## Phase 1: Pre-flight

Verify your working tree is ready:

```bash
# Clean working tree (all changes committed)
git status --porcelain

# Tests pass locally
mix test
mix format --check-formatted
mix compile --warnings-as-errors

# GitHub CLI available
gh auth status
```

If pre-flight fails, fix issues before proceeding.

## Phase 2: Push & Create PR

```bash
# Push branch
git push --set-upstream origin HEAD

# Create PR with structured body
gh pr create --title "<concise task title>" --body "$(cat <<'EOF'
## Task
Task ID: <task_id>

## Summary
<what_was_done>

## What Was Tricky
<challenges encountered, if any>

## What Future Agents Should Know
<learnings for subsequent tasks>

## Acceptance Criteria
<attestation for each criterion from the task>
EOF
)"
```

## Phase 3: Monitor & Fix

This is the key value — you can fix problems instead of being stuck polling.

### Monitor CI

```bash
# Watch CI checks (timeout after 10 minutes)
gh pr checks --watch --fail-fast

# Or poll manually
gh pr view --json statusCheckRollup --jq '.statusCheckRollup[] | [.name, .status, .conclusion] | @tsv'
```

### Fix CI Failures

```bash
# Get failed run logs
gh run list --branch "$(git branch --show-current)" --json databaseId,status,conclusion --jq '.[] | select(.conclusion == "failure") | .databaseId'
gh run view <run-id> --log-failed

# Fix the issue, commit, push
# ... make fixes ...
git add -A && git commit -m "fix: address CI failure"
git push
```

Then re-monitor CI.

### Fix Merge Conflicts

```bash
git fetch origin main
git rebase origin/main
# Resolve conflicts if any
git push --force-with-lease
```

### Address Review Feedback

```bash
gh pr view --comments
# ... address feedback ...
git add -A && git commit -m "fix: address review feedback"
git push
```

## Phase 4: Merge

### Standard Tasks (non-self-modification)

```bash
# Enable auto-merge with squash
gh pr merge --squash --auto

# Wait for merge to complete
gh pr view --json state --jq '.state'
# Should be "MERGED"
```

### Self-Modification Tasks

For tasks that modify Colony's own codebase:

- Do NOT use `--auto`
- Do NOT merge without founder approval
- Escalate and wait for the founder to approve and merge the PR
- After founder merges, continue to Phase 5

## Phase 5: Complete

After the PR is merged:

```bash
# Get the merge commit SHA
MERGE_SHA=$(gh pr view --json mergeCommit --jq '.mergeCommit.oid')
echo "Merge SHA: $MERGE_SHA"
```

Then call `finish_task` with the merge SHA:

```
finish_task(
  task_id: "<task_id>",
  result: {
    "merge_sha": "<sha from above>",
    "summary": "<brief description of what was implemented>"
  }
)
```

The `merge_sha` field is **required** for implementation tasks. Without it, `finish_task` will reject the completion.

## Error Recovery

If you lose context (e.g., after a crash/restart):

```bash
# Find existing PRs for your branch
gh pr list --head "$(git branch --show-current)" --json number,url,state

# Check if already merged
gh pr view <number> --json state,mergeCommit
```

### finish_task Errors

If `finish_task` returns an error, **read the response and fix it**. Common cases:

| Error | Cause | Fix |
|-------|-------|-----|
| `verification_failed` | Uncommitted files in worktree | Run `git status`, commit or .gitignore the files, retry |
| `missing_merge_sha` | No `merge_sha` in result | Get SHA via `gh pr view --json mergeCommit --jq '.mergeCommit.oid'`, retry |
| `criteria_incomplete` | Missing acceptance criteria responses | Add `criteria_responses` map to your result, retry |
| `missing_evidence` | Validated task missing evidence | Add `evidence` field describing what you tested, retry |

All these errors return `retryable: true`. **Never give up without investigating** — you have full CLI access to diagnose and fix the issue.

## Key Rules

1. **Always include `merge_sha`** in finish_task result for implementation tasks
2. **Fix CI failures yourself** — read logs, fix code, push
3. **Fix merge conflicts yourself** — rebase, resolve, push
4. **Self-mod tasks**: never auto-merge, wait for founder approval
5. **Escalate** if stuck after 2 fix attempts on the same issue
6. **Fix finish_task errors yourself** — read the hint, diagnose with CLI tools, retry
