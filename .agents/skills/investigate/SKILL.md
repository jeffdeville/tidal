---
name: investigate
description: Systematically diagnose failures using observability tools and structured investigation methodology
argument-hint: <directive ID, task ID, or alert description>
synced_from_colony: true
sync_pack: universal
sync_source: packs/universal/investigate/SKILL.md
sync_version: d3fefcef
---

# Investigation Skill

<!-- ADAPTATION NOTE: This skill's methodology (four-phase investigation) is universal.
     The specific MCP tool calls (mcp__colony__*) and Colony module references
     (Colony.Observability.Investigator) need project-specific adaptation.
     Replace with your project's observability tools and error reporting systems. -->

Systematic failure diagnosis for directives and tasks. Triggered by an alert notification or a manual request to investigate a failure.

**Input**: An alert, a directive ID, or a task ID to investigate.

## Four-Phase Methodology

```
Phase 1: Orient     → Understand scope and severity
Phase 2: Investigate → Gather evidence from all sources
Phase 3: Correlate   → Classify root cause
Phase 4: Report      → Create actionable GitHub issue
```

---

## Phase 1: Orient

**Goal**: Quickly understand what failed and how bad it is.

### Step 1.1: Parse the trigger

Determine what initiated the investigation:

| Trigger | Action |
|---------|--------|
| Alert struct (from PubSub `observability:alerts`) | Extract `directive_id`, `task_id`, `type`, `severity` |
| Manual directive ID | Use the provided directive ID |
| Manual task ID | Use the provided task ID |

### Step 1.2: Get directive health

Call the `get_directive_health` MCP tool:

```
Tool: mcp__colony__get_directive_health
Arguments:
  directive_id: "<directive_id>"
```

From the response, note:
- **Health rating**: healthy / degraded / critical
- **Problems list**: escalations, repeated failures, stalls, blocked tasks, error storms
- **Task status summary**: how many ready, blocked, completed, cancelled
- **Recent errors**: last 10 errors from the past hour

### Step 1.3: Get task timeline

If a specific task is implicated (from alert or from the problems list), call:

```
Tool: mcp__colony__get_task_timeline
Arguments:
  task_id: "<task_id>"
  include_log_errors: true
```

From the response, note:
- **Execution phase**: pending, scheduled, running, succeeded, failed
- **Retry count**: how many attempts
- **Timeline entries**: chronological sequence of events, session records, log errors

### Step 1.4: Assess scope

Based on Orient findings, decide investigation depth:

| Health | Scope |
|--------|-------|
| Critical (multiple failures, error storm) | Full investigation — all Phase 2 steps |
| Degraded (stalls, escalations, blocked) | Targeted investigation — focus on implicated tasks |
| Healthy (manual investigation request) | Light investigation — verify health, check recent logs |

---

## Phase 2: Investigate

**Goal**: Gather detailed evidence from all observability sources.

### Step 2.1: Query logs for errors

```
Tool: mcp__colony__query_logs
Arguments:
  task_id: "<task_id>"          # if investigating a specific task
  level: "error"                # or "warning" for broader search
  limit: 50
```

Look for:
- Error messages and stack traces
- Repeated error patterns (same message appearing multiple times)
- Timing of errors relative to task execution

### Step 2.2: Query execution events

```
Tool: mcp__colony__query_events
Arguments:
  directive_id: "<directive_id>"
  limit: 100
```

Or for a specific task:

```
Tool: mcp__colony__query_events
Arguments:
  task_id: "<task_id>"
  limit: 50
```

Look for:
- Event sequence (claimed → started → failed patterns)
- Duration anomalies (events taking much longer than expected)
- Missing events (expected events that never occurred)

### Step 2.3: Search session transcript

```
Tool: mcp__colony__search_transcript
Arguments:
  pattern: "error|fail|crash|timeout"
  has_error: true
  limit: 30
```

Look for:
- Claude session errors (tool failures, context issues)
- MCP tool call failures
- Unexpected session termination patterns

### Step 2.4: Get trace spans (if trace_id available)

If the alert or execution events include a `trace_id`:

```
Tool: mcp__colony__get_trace
Arguments:
  trace_id: "<trace_id>"
```

Look for:
- Span tree showing operation hierarchy
- Slow spans (high duration relative to siblings)
- Error spans (spans with error status)
- Gaps in the span tree (missing expected operations)

### Step 2.5: Query metrics (for pattern detection)

```
Tool: mcp__colony__query_metrics
Arguments:
  directive_id: "<directive_id>"
  from: "<1 hour ago ISO8601>"
  to: "<now ISO8601>"
```

Look for:
- Failure rate trends (increasing failure counts)
- Throughput drops (fewer events than expected)
- Duration spikes (operations taking longer over time)

---

## Phase 3: Correlate

**Goal**: Classify the root cause into an actionable category.

### Root Cause Categories

Analyze the evidence gathered in Phase 2 and classify into one of these six categories:

#### 1. Colony Bug
**Indicators**: Internal errors in Colony modules, unexpected state transitions, CQRS event processing failures, Reconciler errors.
**Evidence pattern**: Stack traces in Colony code, events in wrong order, aggregate validation failures.
**Action**: Fix in Colony codebase.

#### 2. Configuration Issue
**Indicators**: Missing or incorrect config values, Arena setup failures, database connection issues, MCP tool registration problems.
**Evidence pattern**: Config-related errors at startup or first use, schema prefix errors, process naming conflicts.
**Action**: Fix configuration or environment setup.

#### 3. Session Management
**Indicators**: Claude session crashes, session timeouts, worktree conflicts, CLI process failures.
**Evidence pattern**: Session records showing unexpected termination, transcript errors about tool failures, retry count > 0 with same failure.
**Action**: Fix session lifecycle handling or worktree management.

#### 4. Target Project Issue
**Indicators**: Errors originating from the project being worked on (not Colony itself), test failures in target code, compilation errors in target project.
**Evidence pattern**: Transcript shows tool errors in target project files, build/test failures in worktree, dependency resolution failures.
**Action**: Fix in target project or adjust task instructions.

#### 5. External Dependency
**Indicators**: Network errors, API rate limits, GitHub API failures, third-party service unavailability.
**Evidence pattern**: HTTP errors, timeout errors to external services, authentication failures.
**Action**: Wait and retry, or escalate to human for credential/access fixes.

#### 6. Resource Exhaustion
**Indicators**: Out of memory, disk space, process limits, database connection pool exhaustion.
**Evidence pattern**: System-level errors, Ecto pool timeout, file system errors, OS-level resource warnings.
**Action**: Scale resources or optimize resource usage.

### Classification Process

1. Review all evidence collected in Phase 2
2. Match error patterns against the six categories above
3. If multiple categories match, identify the **primary** cause (the one that, if fixed, would prevent the failure)
4. Note any **contributing factors** from other categories
5. Assign a **confidence level**: high (clear evidence), medium (likely but not certain), low (best guess from limited data)

---

## Phase 4: Report

**Goal**: Create a GitHub issue with structured evidence for resolution.

### Step 4.1: Check for duplicate issues

Before creating a new issue, search for existing open issues:

```bash
gh issue list --state open --search "<key terms from root cause>"
```

Use `Colony.Observability.Investigator.check_duplicate/2` to compare the proposed title against existing issue titles. If a duplicate is found:
- Add a comment to the existing issue with new evidence
- Do NOT create a new issue
- Report: "Added evidence to existing issue #N"

### Step 4.2: Build issue body

Use `Colony.Observability.Investigator.render_issue_body/2` to generate the issue markdown.

The function takes an alert (or constructed alert map) and an evidence map:

```elixir
alert = %{
  title: "Task failures in directive abc123",
  severity: :critical,
  type: "repeated_failures",
  description: "3 task failures detected",
  directive_id: "abc-123",
  task_id: "task-456"
}

evidence = %{
  health: %{...},           # from get_directive_health
  timeline: %{...},         # from get_task_timeline
  logs: [...],              # from query_logs
  events: [...],            # from query_events
  transcript: [...],        # from search_transcript
  trace: %{...},            # from get_trace (may be nil)
  metrics: %{...},          # from query_metrics (may be nil)
  root_cause: %{
    category: "session_management",
    confidence: "high",
    summary: "Session crashed due to worktree conflict",
    contributing_factors: ["high retry count suggests intermittent issue"]
  }
}
```

### Step 4.3: Create the GitHub issue

```bash
gh issue create \
  --title "[Colony Investigation] <concise description>" \
  --body "<rendered issue body>" \
  --label "investigation,<root_cause_category>"
```

### Step 4.4: Report findings

Output a summary to the user:

```
## Investigation Complete

**Directive**: <id> — <title>
**Health**: <rating>
**Root Cause**: <category> (confidence: <level>)

### Summary
<1-2 sentence description of what went wrong and why>

### Action
- GitHub Issue: #<number> — <title>
- Suggested Fix: <brief recommendation>

### Evidence Collected
- Directive health: <rating>
- Timeline entries: <count>
- Error logs: <count>
- Execution events: <count>
- Transcript matches: <count>
```

---

## Error Handling

- **MCP tool failures**: If any observability tool returns an error, log it and continue with remaining tools. Report which tools failed in the issue.
- **Missing data**: If a directive or task ID is not found, report the failure immediately and suggest checking the ID.
- **No root cause identified**: If evidence is insufficient to classify a root cause, report as "Indeterminate" with all gathered evidence and escalate to human.
- **Duplicate detection fails**: If `gh issue list` fails, skip dedup and create the issue with a note about unchecked duplicates.
