# Complexity Grading Reference

## Story Point Scale

| Points | Level | Description | Example |
|--------|-------|-------------|---------|
| 1 | Trivial | Single line change, obvious fix | Fix typo, update version number |
| 2 | Simple | Few files, clear scope | Add validation, update error message |
| 4 | Small | Multiple files, some decisions | Add new endpoint, refactor function |
| 8 | Medium | Significant work, cross-cutting | New feature touching multiple modules |
| 16 | Large | Multi-day effort, architectural impact | Major refactor, new subsystem |
| 32 | XL | Major feature, team coordination | Full feature with frontend/backend |
| 64 | Epic | Decomposition definitely required | Multi-week initiative |

## The 4-Point Threshold

**Tasks ≤4 points** can be executed directly by a single agent.
**Tasks >4 points** must be decomposed into smaller subtasks.

When grading, ask: "Can a single agent complete this in focused work without needing to context-switch significantly?" If yes, it's ≤4 points.

## Problem Types

You can use any problem type that fits, but common ones include:

| Type | Description |
|------|-------------|
| `feature` | New functionality |
| `bug_fix` | Fixing broken behavior |
| `refactor` | Restructuring without behavior change |
| `security` | Security improvements or fixes |
| `infrastructure` | Build, deploy, CI/CD changes |
| `documentation` | Docs, READMEs, comments |
| `performance` | Speed/memory optimization |
| `testing` | Test coverage improvements |
| `data_migration` | Database schema or data changes |
| `ux_improvement` | User experience enhancements |

Feel free to propose new types if these don't fit (e.g., `accessibility`, `localization`, `api_versioning`).

## Identifying Affected Areas

Look at the codebase structure. For a Phoenix/Elixir project:

- `lib/colony/` - Core business logic
- `lib/colony_web/` - Web layer (controllers, views, live views)
- `lib/colony/tasks/` - Task domain
- `lib/colony/sessions/` - Claude session management
- `priv/repo/migrations/` - Database migrations
- `test/` - Test files

Use Glob and Grep to identify which areas will be touched:

```bash
# Find related files
glob "lib/**/*user*.ex"
grep "User" lib/

# Understand existing patterns
read lib/colony/tasks/task.ex
```

## Risk Factors

Identify risks that could complicate execution:

| Risk | Description |
|------|-------------|
| **Unclear requirements** | The request is vague or ambiguous |
| **Large blast radius** | Many files/modules affected |
| **External dependencies** | Relies on third-party services |
| **Data migration** | Requires database changes with data |
| **Security sensitive** | Touches auth, secrets, or user data |
| **Performance critical** | High-traffic or latency-sensitive code |
| **Cross-team impact** | Affects other teams or projects |
| **Breaking changes** | May break existing API consumers |

## Confidence Assessment

Your confidence (0.0-1.0) reflects how certain you are about the grading:

| Confidence | Meaning |
|------------|---------|
| 0.9-1.0 | Very confident - clear scope, familiar pattern |
| 0.7-0.9 | Confident - reasonable understanding, minor unknowns |
| 0.5-0.7 | Moderate - some significant unknowns |
| 0.3-0.5 | Low - major unknowns, consider escalating |
| 0.0-0.3 | Very low - should probably escalate |

## Capability Gap Detection

If the work requires expertise not present among available agents, note it:

```json
{
  "capability_gaps": [
    {
      "type": "agent",
      "name": "ml-engineer",
      "description": "Machine learning expertise for recommendation system",
      "expertise": ["machine-learning", "python", "tensorflow"]
    }
  ]
}
```

This informs the system that new agents may need to be hired.

## Acceptance Criteria Scaling

After grading complexity, determine the appropriate number of acceptance criteria:

| Points | Criteria Count | Guidance |
|--------|---------------|----------|
| 1-4 | 1-2 | Focus on the core behavior. Automated preferred. |
| 5-16 | 3-5 | Cover key behaviors and edge cases. Mix of automated and manual. |
| 17+ | 5-8 | Comprehensive coverage. Must include automated measurements. Manual criteria need assigned reviewers. |

### Rules

- **Automated criteria** should use executable commands: `mix test path`, `mix compile --warnings-as-errors`, `curl` checks, etc.
- **Manual criteria** must specify a reviewer role (e.g., `product-owner`, `security-auditor`)
- At least 50% of criteria should be automated for directives ≥5 points
- Each criterion must be pass/fail — no subjective "looks good" criteria

## Grading Checklist

Before finalizing your grade:

1. [ ] Did I read relevant code to understand the scope?
2. [ ] Is my point estimate on the Fibonacci scale?
3. [ ] Did I identify all affected areas?
4. [ ] Did I note relevant risk factors?
5. [ ] Is my confidence realistic (not artificially high)?
6. [ ] If >4 points, am I prepared to decompose?
7. [ ] Did I determine the right number of acceptance criteria for this complexity level?
