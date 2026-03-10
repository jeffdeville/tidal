---
name: query_task_provenance
description: Get full provenance context for a task - directive rationale, sibling tasks, and dependencies
---

# Query Task Provenance

Use this skill when you need to understand the full context for a task you're working on. This is the "why does this task exist?" package.

## When to Use

- **Starting work on a task**: Understand the directive's intent and your task's role in the plan
- **Understanding dependencies**: See what other tasks depend on yours and what you depend on
- **Checking the original plan**: Read the decomposition rationale and planning notes
- **Coordinating with siblings**: See what parallel tasks exist and their status

## MCP Resource

```
colony://knowledge/task_provenance/<task-id>
```

## Response Structure

```json
{
    "task": {
      "id": "uuid",
      "title": "Build API endpoints",
      "description": "Create REST endpoints for...",
      "discipline": "backend",
      "deliverable": "pr_merged",
      "status": "ready",
      "depends_on": ["task-1-id"]
    },
    "directive": {
      "id": "uuid",
      "title": "Auth System",
      "raw_input": "Build user authentication with OAuth",
      "status": "in_progress"
    },
    "decomposition_rationale": {
      "summary": "Three tasks for auth implementation",
      "planning_notes": {
        "initial_assessment": "Straightforward OAuth flow",
        "key_risks_to_watch": ["Socket auth"]
      },
      "assumptions": [...]
    },
    "sibling_tasks": [
      {
        "id": "task-1-id",
        "title": "Setup DB schema",
        "status": "completed",
        "depends_on": []
      },
      {
        "id": "task-3-id",
        "title": "Build UI",
        "status": "ready",
        "depends_on": ["task-1-id"]
      }
    ]
}
```

## Key Fields

### `task`
Your task's details including dependencies. Check `depends_on` to understand what must complete before you.

### `directive`
The parent directive — the founder's original intent. Read `raw_input` to understand what outcome is expected.

### `decomposition_rationale`
The Foreman's reasoning when creating this task plan. `planning_notes` capture evolving understanding — read `initial_assessment` and `key_risks_to_watch` for context the Foreman wants you to keep in mind.

### `sibling_tasks`
Other tasks in the same directive. Check their status to understand what's done, what's in progress, and what's waiting. Tasks you depend on should be completed.

## Example Usage

1. Read this MCP resource at the start of your task
2. Read `directive.raw_input` to understand the big picture
3. Read `decomposition_rationale.planning_notes` for the Foreman's context
4. Check `sibling_tasks` to understand what's already done and what's parallel
5. Review `task.depends_on` — completed dependencies may have useful results
