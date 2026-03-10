---
name: decompose
description: Decompose a complex task into smaller subtasks with dependencies
---

# /decompose

**Task ID**: $ARGUMENTS

## Workflow

1. Review task details (provided in prompt context, or fetch predecessors via MCP tool `get_predecessors`)
2. Analyze complexity dimensions (scope, uncertainty, risk, dependencies)
3. Identify natural boundaries (layers, phases, streams)
4. Design DAG with 2-6 subtasks, each ≤4 points
5. Submit via MCP tool `create_subtasks`
6. If any subtask > 4 points, note for recursive decomposition
7. Signal completion via MCP tool `finish_task`

## API Reference

For canonical operation definitions, see `lib/colony/session_operations/ops/`.

## Design Guidelines

### Subtask Structure
- **title**: Clear, imperative action (e.g., "Create user schema")
- **description**: What needs to be done with acceptance criteria
- **estimated_points**: 1, 2, or 4 (keep small - max 4 points each)
- **depends_on**: Array of subtask indices (0-based)
- **expected_outcome**: implementation | planning | estimation
- **discipline**: backend | frontend | testing | devops | documentation

### Common DAG Patterns
- **Sequential**: `[0] -> [1] -> [2]` (setup, build, polish)
- **Parallel**: `[0], [1], [2]` all independent
- **Diamond**: `[0] -> [1,2] -> [3]` (foundation, parallel work, integration)
- **Fan-out**: `[0] -> [1,2,3]` (setup, then multiple independent streams)

### Validation Checklist
- [ ] No cycles in dependencies
- [ ] All paths eventually complete
- [ ] Critical path is reasonable
- [ ] Each subtask is independently testable
- [ ] No subtask exceeds 4 story points

## Success Criteria

- All subtasks have clear titles and descriptions
- No subtask exceeds 4 story points
- Dependencies form a valid DAG (no cycles)
- Each subtask has appropriate expected_outcome
- API call succeeds and returns subtask IDs
