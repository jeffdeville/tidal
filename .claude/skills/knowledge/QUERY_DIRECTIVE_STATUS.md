---
name: query_directive_status
description: Get full context for a directive - task graph, execution state, blocked subtrees, and rationale
---

# Query Directive Status

Use this skill when you need to understand the current state of a directive. This is the primary query for reassessment decisions.

## When to Use

- **Reassessment**: When re-analyzing a directive after task failures or stalls
- **AC verification**: When checking whether acceptance criteria are met
- **Progress review**: When summarizing what's been done and what remains
- **Failure triage**: When understanding which failures are structurally damaging

## MCP Resource

```
colony://knowledge/directive_status/<directive-id>
```

## Response Structure

```json
{
  "directive": {
      "id": "uuid",
      "title": "Auth System",
      "raw_input": "Build the auth system with...",
      "status": "in_progress",
      "remediation_iteration": 0
    },
    "tasks": [
      {
        "id": "uuid",
        "title": "Setup DB schema",
        "description": "Create users and sessions tables...",
        "status": "ready",
        "completed": false,
        "depends_on": [],
        "dependents": ["task-2-id", "task-3-id"],
        "execution": {
          "phase": "succeeded",
          "retry_count": 0,
          "last_failure_reason": null,
          "pr_url": "https://github.com/org/repo/pull/42"
        }
      }
    ],
    "blocked_subtrees": [
      {
        "blocking_task_id": "failed-task-id",
        "blocked_task_ids": ["dependent-1", "dependent-2"]
      }
    ],
    "acceptance_criteria": { ... },
    "decomposition_rationale": {
      "summary": "Three tasks for auth",
      "assumptions": ["Users table exists"],
      "planning_notes": {
        "initial_assessment": "Straightforward auth flow",
        "revised_understanding": "LiveView sockets need separate auth",
        "key_risks_to_watch": ["Socket auth", "Migration speed"],
        "complexity_drivers": "Dual HTTP + WebSocket auth paths"
      }
    }
}
```

## Key Fields

### `blocked_subtrees`
Shows which task failures are structurally damaging. Each entry lists a failed task and all tasks that cannot proceed because of it (directly or transitively through the dependency chain). Use this to decide whether to retry, restructure, or escalate.

### `decomposition_rationale.planning_notes`
The original Foreman's evolving understanding during planning. Read this before making reassessment decisions to inherit the original analysis context.

### `tasks[].dependents`
Reverse edges - which tasks depend on this one. Combined with `depends_on`, gives you the full DAG for understanding structural impact.

### `tasks[].execution`
Operational state from the Reconciler. `phase` shows current execution status; `retry_count` shows how many attempts have been made; `last_failure_reason` explains why it failed.

## Example Usage in Reassessment

1. Read this MCP resource to get the full directive state
2. Check `blocked_subtrees` - are failures blocking many downstream tasks?
3. Read `planning_notes` - what did the original analysis expect?
4. Review task execution data - are failures retryable or structural?
5. Decide: retry failed tasks, restructure the task graph, or escalate
