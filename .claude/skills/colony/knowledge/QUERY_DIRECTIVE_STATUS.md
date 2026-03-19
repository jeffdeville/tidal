---
name: query_directive_status
description: Get full context for a directive -- task graph, execution state, blocked subtrees
---

# Query Directive Status

Get the current state of a directive including its task graph, execution state, and blocked subtrees.

## When to Use

- Reassessment after task failures or stalls
- Checking acceptance criteria progress
- Summarizing what's done and what remains
- Triaging which failures are structurally damaging

## MCP Resource

```
colony://directives/{directive_id}/status
```

## Key Fields in Response

- **blocked_subtrees**: Which task failures block downstream tasks. Use to decide retry vs restructure vs escalate.
- **decomposition_rationale**: The Foreman's original planning context. Read before reassessment.
- **tasks[].dependents**: Reverse dependency edges -- which tasks depend on this one.
- **tasks[].execution**: Operational state (phase, retry_count, last_failure_reason).

## Usage in Reassessment

1. Read the resource to get full directive state
2. Check `blocked_subtrees` -- are failures blocking many downstream tasks?
3. Read planning notes -- what did the original analysis expect?
4. Review execution data -- are failures retryable or structural?
5. Decide: retry, restructure, or escalate
