---
name: epic
description: Focus on a single epic's subtasks using DAG-guided execution
disable-model-invocation: true
---

# /epic - DAG-Guided Epic Development

Work through an epic's subtasks in dependency order, using GitHub labels as the single source of truth.

**Epic**: $ARGUMENTS

## Usage Examples

```
/epic WS-01          # Start working on WS-01, show status, begin next task
/epic WS-01 --status # Just show status, don't start work
/epic WS-01 --next   # Show what task would be next
```

## Epic Reference

| Epic | Name | Issue |
|------|------|-------|
| WS-01 | Foundation - Auth, Orgs, Billing | #19 |
| WS-02 | AI Lead Qualification Engine | #20 |
| WS-03 | Bad Lead Calculator (Lead Magnet) | #21 |
| WS-04 | Self-Service Onboarding | #22 |
| WS-05 | Proof of Value Engine (Push-Based) | #25 |
| WS-06 | Automated Weekly Summaries | #28 |
| WS-07 | Email Nurture Integration (Loops.so) | #27 |
| WS-08 | CRM Integrations (Jobber, HousecallPro) | #23 |
| WS-12 | Facebook Group Monitoring | #24 |
| WS-13 | Voice Agent (Gemini Live + Twilio) | #26 |

## Workflow

### Step 1: Load Epic State

Read the DAG state and sync with GitHub labels:

```bash
# Get all issues for this epic from GitHub
gh issue list -l "epic:$EPIC" --json number,title,labels,state -q '.[]'
```

Parse GitHub labels as source of truth:
- `dag:ready` - Dependencies complete, can be started
- `dag:claimed` - Someone is working on this
- `dag:in-progress` - Work actively happening
- `dag:complete` - Task finished successfully
- `dag:blocked` - Waiting on dependencies

### Step 2: Display Epic Status

Show status in this format:

```
Epic WS-01: Foundation (Issue #19)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ #35 Company Profile Fields     (complete)
✅ #34 Cloak Credential Vault     (complete)
🔄 #33 Stripe Billing             (in-progress, this window)
⏳ #37 Grace Period Logic         (blocked by #33)
⏳ #38 Oban Billing Queue         (blocked by #33)
⏳ #36 Demo Seed Script           (blocked by #34) → READY
⏳ #128 Consolidate hearth_mktg   (ready)

Progress: 2/7 complete (29%)
Next ready: #36 Demo Seed Script
```

### Step 3: Identify Next Task (if not --status)

Find the next task to work on:

1. **Check DAG dependencies** from `docs/gtm_dag_state.yaml`
2. **Find issues where**:
   - Has `dag:ready` label, OR
   - All `depends_on` issues have `dag:complete` label
3. **Exclude**:
   - Issues with `dag:in-progress` or `dag:claimed` labels
   - Issues already `dag:complete`
4. **Prioritize by**:
   - Critical path tasks first
   - Lower issue number (created earlier)

### Step 4: Claim the Task

Before starting work:

```bash
# Claim the task
.claude/scripts/dag-claim.sh <issue_number>
```

This will:
- Remove `dag:ready` label
- Add `dag:claimed` + `dag:in-progress` labels

### Step 5: Execute Work via /deliver

Run the full delivery workflow:

```
/deliver Issue #<number>: <issue_title>
```

The `/deliver` command handles:
- Planning with all specialized agents
- TDD test-first development
- Implementation
- Quality gates
- Code review
- PR creation

### Step 6: Mark Complete and Update Dependents

After successful PR creation:

```bash
# Mark task complete and unblock dependents
.claude/scripts/dag-complete.sh <issue_number>
```

This will:
- Remove `dag:claimed`, `dag:in-progress` labels
- Add `dag:complete` label
- Check dependent issues and add `dag:ready` to any now unblocked

### Step 7: Continue or Complete

After task completion:
- Check for more `dag:ready` tasks in this epic
- If found: Prompt "Continue with #XX <title>? (y/n)"
- If epic complete: Celebrate and suggest next epic based on DAG

## Failure Handling

### Consumption Limit Hit

If the session hits the consumption limit:

1. Note the time limit reset occurs
2. Save current state (which issue, which phase of /deliver)
3. Alert: "Consumption limit reached. Resume after <time> with `/epic WS-XX --resume`"

### Other Failures

If /deliver fails after Phase 4 quality gates:

1. **Retry once**: Sometimes transient failures
2. **If still failing**:
   - Add `dag:blocked` label to the issue
   - Add comment to issue with failure details
   - Alert via Slack: `.claude/scripts/send-alert.sh <issue> "Delivery failed: <reason>"`
   - Prompt for human intervention

### Manual Override

You can manually:
- Mark tasks complete: `gh issue edit <num> --add-label dag:complete`
- Unblock tasks: `gh issue edit <num> --add-label dag:ready`
- Reset task: `gh issue edit <num> --remove-label dag:in-progress,dag:claimed`

## DAG State File Reference

The `docs/gtm_dag_state.yaml` file contains:

```yaml
epics:
  WS-01:
    issue: 19
    status: in_progress

issues:
  33:
    title: "Stripe Billing Integration"
    epic: WS-01
    depends_on: []

  37:
    title: "Grace Period Logic"
    epic: WS-01
    depends_on: [33]
```

Use this for:
- Understanding dependency relationships
- Calculating which tasks become unblocked
- Identifying critical path

## Commands Summary

| Command | Description |
|---------|-------------|
| `/epic WS-XX` | Start working on epic, show status, begin next task |
| `/epic WS-XX --status` | Show current status only |
| `/epic WS-XX --next` | Show what the next task would be |
| `/epic WS-XX --resume` | Resume after interruption |

## Success Criteria

An epic is complete when:
- All sub-issues have `dag:complete` label
- All PRs have been merged
- No `dag:blocked` issues remain

## Begin

Parse the arguments and:
1. If `--status`: Just show status and exit
2. If `--next`: Show next task and exit
3. Otherwise: Show status, claim next task, run `/deliver`
