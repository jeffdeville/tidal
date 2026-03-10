---
name: grade-complexity
description: Assess task complexity and determine if decomposition is needed
---

# /grade-complexity

**Task ID**: $ARGUMENTS

## Workflow

1. Review task details (provided in prompt context, or fetch predecessors via MCP tool `get_predecessors`)
2. Score dimensions (1-3 each): scope, uncertainty, risk, dependencies
3. Map total to Fibonacci points (4-5→2, 6-7→4, 8-9→8, 10+→16)
4. If ≤4 points: record via MCP tool `submit_estimate`
5. If >4 points: invoke `/decompose`
6. Signal completion via MCP tool `finish_task`

## API Reference

For canonical operation definitions, see `lib/colony/session_operations/ops/`.

## Scoring Dimensions

### Scope (files/systems affected)
- 1: Single file or function
- 2: 2-5 files in same module
- 3: Cross-module or multiple systems

### Uncertainty (requirement clarity)
- 1: Crystal clear, well-defined
- 2: Mostly clear, minor ambiguity
- 3: Significant unknowns

### Risk (what could go wrong)
- 1: Isolated change, easy rollback
- 2: Affects existing behavior
- 3: Breaking changes, complex interactions

### Dependencies (external factors)
- 1: Self-contained
- 2: Depends on 1-2 external things
- 3: Multiple external dependencies

## Point Mapping

| Total Score | Story Points | Action |
|-------------|--------------|--------|
| 4-5 | 1-2 | Ready for implementation |
| 6-7 | 2-4 | Ready, or consider decomposition |
| 8-9 | 4-8 | Should decompose |
| 10+ | 8+ | Must decompose |

## Red Flags (decompose immediately)
- Task title contains "and" or multiple verbs
- Description spans multiple paragraphs
- Multiple distinct systems mentioned
- "Also need to..." appears in description
- No clear single acceptance criterion

## Green Flags (ready for implementation)
- Single clear action verb in title
- One well-defined acceptance criterion
- Follows existing patterns in codebase
- Single module/file affected
- Clear before/after state
