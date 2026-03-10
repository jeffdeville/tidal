---
name: findings-format
description: Structured output format for monitor review findings
---

# Findings Format

All monitor findings are written as structured markdown to `.colony/monitor/findings/`.

## File Naming

`<type>-YYYY-MM-DD.md`

Examples:
- `arch-2025-06-15.md`
- `docs-2025-06-15.md`
- `quality-2025-06-15.md`

If multiple runs happen on the same day, append a sequence number: `arch-2025-06-15-2.md`

## File Structure

```markdown
# <Review Type> Review - YYYY-MM-DD

**SHA range**: <from_sha>..<to_sha> | **Files reviewed**: N | **Verdict**: approved|needs_changes|rejected|escalate

## Summary

<1-3 sentence summary of findings>

## Findings

### <CONSTRAINT-ID>: <Title>

- **Severity**: blocker|error|warning|info
- **Location**: `<file>:<line>`
- **Issue**: <description of the violation>
- **Recommendation**: <specific fix suggestion>

### <CONSTRAINT-ID>: <Title>

...

## Architectural Notes (optional)

Observations from Dimension 3 (Fitness) and Dimension 4 (Adversarial) that aren't
constraint violations but are worth recording for architectural awareness. These
capture emerging patterns, boundary drift, complexity trends, and surfaced assumptions.

- <observation>
- <observation>

## Files Reviewed

- `path/to/file1.ex` (modified)
- `path/to/file2.ex` (added)
- `path/to/file3.ex` (deleted)
```

## Severity Levels

| Level | Meaning | Action Required |
|-------|---------|-----------------|
| `blocker` | Breaks invariants, data loss risk | Must fix before merge |
| `error` | Violates architecture constraints | Should fix before merge |
| `warning` | Deviates from patterns, technical debt | Fix when convenient |
| `info` | Observation, suggestion | No action required |

## Verdict Rules

- **approved**: Zero blockers and zero errors
- **needs_changes**: One or more errors (zero blockers)
- **rejected**: One or more blockers
- **escalate**: Reviewer confidence < 0.7 on any blocker-severity finding

## Dedup Rules

When previous findings exist for the same review type:
1. Load the most recent findings file for that type
2. For each previous finding, check if the code at that location has changed in the current diff
3. If the code is unchanged, skip re-reporting that finding
4. If the code changed, re-evaluate and report if still applicable
