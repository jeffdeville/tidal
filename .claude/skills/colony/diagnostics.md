---
name: diagnostics
description: Investigate task failures using Colony's diagnostic resources and observability tools
---

# Diagnostics

When investigating task failures, use diagnostic resources and observability tools.

## MCP Resources

### Task diagnostic snapshot
```
colony://diagnostics/tasks/{task_id}
```
Returns: execution phase, retry count, failure reason, event timeline, log path.

### Directive health report
```
colony://diagnostics/directives/{directive_id}/health
```
Returns: health rating, task status summary, identified problems, recent errors.

## MCP Tools

- `get_directive_health` -- quick health check (healthy/degraded/critical)
- `get_task_timeline` -- chronological event timeline for a task
- `get_trace` -- full span tree for an OTel trace ID
- `query_events` -- filter execution events by task/directive/type/severity
- `query_logs` -- search JSONL log files
- `search_transcript` -- search session transcript by pattern

## Investigation Workflow

1. Start with `get_directive_health` for an overview
2. For specific failed tasks, read `colony://diagnostics/tasks/{id}`
3. Use `get_task_timeline` for the full event sequence
4. Use `query_logs` or `search_transcript` for detailed error messages
