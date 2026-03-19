---
name: query_task_provenance
description: Understand why a task exists -- directive context, sibling tasks, and dependencies
---

# Query Task Provenance

Understand the full context for a task: why it exists, what it depends on, and what depends on it.

## When to Use

- Starting work on a task -- understand the directive's intent and your role
- Checking dependencies and sibling task status
- Reading the original planning context

## MCP Resource

```
colony://tasks/{task_id}/provenance
```

## What You Get

- **task**: Your task details including dependencies
- **directive**: The parent directive's original intent (`raw_input`)
- **decomposition_rationale**: The Foreman's reasoning when creating the task plan
- **sibling_tasks**: Other tasks in the same directive and their status

## Also Useful

Use `get_predecessors` MCP tool to fetch results from completed dependency tasks:

```
get_predecessors(task_id: "<your-task-id>", depth: 1)
```

## Workflow

1. Read provenance at the start of your task
2. Read `directive.raw_input` for the big picture
3. Check sibling task status -- what's done, what's parallel
4. Use `get_predecessors` to get outputs from completed dependencies
