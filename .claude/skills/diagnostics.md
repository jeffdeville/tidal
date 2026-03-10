---
name: diagnostics
description: Query Colony's diagnostic API to get error context for failed tasks
---

# Diagnostics Skill

When fixing Colony bugs or investigating failures, use the diagnostics API to get full error context.

## MCP Resources

### Get task diagnostic snapshot
```
colony://diagnostics/<task-id>
```

Returns: execution phase, retry count, failure reason, event timeline, task log content, Claude log path.

### Get directive diagnostic snapshot (all failed tasks)
```
colony://diagnostics/directive/<directive-id>
```

Returns: snapshots for all failed tasks in the directive.

## Usage

1. When a task fails, first read its diagnostic MCP resource
2. Check the event timeline for the sequence of events leading to failure
3. Check the failure reason and retry count
4. If needed, read the Claude log file at the provided path for full session context
5. Use this information to understand the root cause before proposing fixes
