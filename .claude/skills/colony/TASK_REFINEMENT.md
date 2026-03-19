# Task Refinement Reference

This reference guides task creation for Colony directives. It applies in two contexts:

- **Expert Panel**: You are one of several experts proposing tasks in your domain during the Foreman's expert panel process. Propose tasks YOU should own, with domain-informed acceptance criteria.
- **Solo Leader**: You are the sole expert handling a simple directive. You create the full task DAG yourself.

## PROHIBITED: Standalone Verification Tasks

⛔ **NEVER create tasks whose sole purpose is verifying, validating, or testing other tasks' work.**

**Why this breaks**: Verification workers have no code to commit and no PR to merge. They call `finish_task` but fail validation because they lack the required deliverable artifacts. After 3 retries, the task becomes permanently blocked and the entire directive stalls.

**What to do instead**: Embed verification steps as acceptance criteria on the implementation task that produces the work. The last implementation task in a chain should include end-to-end testing in its scope. Colony's directive AC runner performs final validation after all tasks complete.

**Examples of PROHIBITED tasks:**
- "Verify rubric quality and usability" (standalone, no code output)
- "Run integration tests on the API" (should be AC on the implementation task)
- "Review and validate the schema design" (should be AC on the schema task)

**How to satisfy the validation requirement**: Colony requires at least one task with `deliverable: "validated"` in every task graph. Set `deliverable: "validated"` on the **last implementation task** in the dependency chain — the one that includes end-to-end testing as part of its scope. This task still produces code/PR but also validates the overall directive.

## Your Responsibilities

### As an Expert on a Panel

1. **Review the directive** through your domain expertise
2. **Propose tasks** in your area with domain-informed descriptions and AC
3. **Define acceptance criteria** for each task — what "done" looks like from your domain perspective
4. **Flag dependencies** on other experts' work (e.g., "needs database schema from database-architect")
5. **Add review tasks** you know are needed (security audit, architecture review, etc.)

### As a Solo Leader

1. **Analyze the directive** in depth
2. **Create implementation tasks** with full details and acceptance criteria
3. **Assign tasks** to team members based on their expertise
4. **Establish dependencies** that enable parallel work where possible
5. **Create via API** using the `create_directive_tasks` operation
6. **Signal completion** using the `complete_directive` operation

## Task Structure

Every task created via `create_directive_tasks` needs fields documented in that tool's schema. Use `tools/list` via MCP to see the full parameter schema with types, required fields, and enum values.

Key fields: `title` (required), `assigned_agent` (required for non-human tasks), `description`, `deliverable` (default: `pr_merged`), `depends_on` (0-based indices), and `acceptance_criteria`.

Colony automatically appends orthogonal criteria (tests pass, formatting, no secrets, doc staleness) based on the task's deliverable type. You only specify business criteria with `"source": "business"`.

### Example Task

```json
{
  "title": "Clear, imperative action",
  "description": "Full context and requirements",
  "assigned_agent": "backend-expert",
  "deliverable": "pr_merged",
  "depends_on": [],
  "acceptance_criteria": [
    {
      "id": "business:descriptive-slug",
      "text": "What must be true for this criterion to pass",
      "source": "business"
    }
  ]
}
```

## Writing Good Titles

### Do

- Use imperative mood: "Add", "Implement", "Fix", "Refactor", "Create"
- Be specific: "Add email validation to user registration"
- Include the what: "Implement JWT token refresh endpoint"

### Don't

- Passive voice: "Email validation should be added"
- Vague: "Handle user stuff"
- Too long: Keep under 60 characters

| Bad | Good |
|-----|------|
| "User authentication" | "Implement user authentication endpoint" |
| "Fix the bug" | "Fix null pointer in user lookup query" |
| "Tests" | "Add integration tests for payment flow" |
| "Database changes needed" | "Create users table with indexes" |

## Writing Descriptions

The description should enable an agent to execute independently. Include:

1. **Context**: Why this task exists, what problem it solves
2. **Requirements**: What specifically needs to be done
3. **Constraints**: Any limitations or requirements
4. **Examples**: If helpful, show expected input/output

### Template

```markdown
## Context
[Why this task exists]

## Requirements
- [Specific requirement 1]
- [Specific requirement 2]

## Constraints
- [Any limitations]

## Notes
- [Additional helpful info]
```

## Agent Assignment

Every task (except `human_response` deliverables) **must** have `assigned_agent` set to a valid agent name from the project's `.claude/agents/` directory. Colony rejects task graphs with missing agent assignments.

## Deliverables

The field is `deliverable` (not `expected_outcome`). These are the valid values:

| Deliverable | When to Use | What Agent Does |
|-------------|-------------|-----------------|
| `pr_merged` | Task produces code changes (DEFAULT) | Write code, commit, create PR, merge |
| `verification_passed` | Task runs tests/checks to verify other work | Execute checks, report pass/fail |
| `validated` | Task validates the directive's objectives are met | Run smoke tests, verify end-to-end |
| `human_response` | Task requires human input | Escalate with questions, wait for response |


Most leaf tasks will be `pr_merged`. Every task graph MUST include at least one `validated` or `verification_passed` task.

## Acceptance Criteria

Every task needs 2-5 acceptance criteria. Each criterion has:

- **id**: `business:descriptive-slug`
- **text**: What must be true
- **source**: `"business"`

### Examples

```json
{
  "acceptance_criteria": [
    {
      "id": "business:create-user-endpoint",
      "text": "POST /api/users creates new user with valid input and returns 201",
      "source": "business"
    },
    {
      "id": "business:validation-errors",
      "text": "Returns 400 with validation errors for invalid email",
      "source": "business"
    },
    {
      "id": "business:password-hashing",
      "text": "Password is hashed before storage using bcrypt/argon2",
      "source": "business"
    }
  ]
}
```

## Dependencies (depends_on)

Use `depends_on` to specify task ordering. Values are 0-based indices in the batch.

### When to Use Dependencies

- **Schema before data**: Migration must run before seeding
- **Interface before implementation**: API contract before code
- **Build before test**: Core logic before tests
- **One task reads another's output**: Task B needs Task A's result

### When NOT to Use Dependencies

- **Both can run in parallel**: No actual data/code dependency
- **"It would be nice" ordering**: Prefer parallelism
- **All tasks depend on one**: Creates bottleneck

### Example

```json
{
  "tasks": [
    {
      "title": "Create users table migration",
      "depends_on": []
    },
    {
      "title": "Implement User schema and changeset with unit tests",
      "depends_on": [0]
    },
    {
      "title": "Add user registration endpoint with integration tests",
      "depends_on": [1]
    }
  ]
}
```

## Task Size: Phases vs Steps

The primary heuristic for task boundaries:

- **Phases = separate tasks**: Different concerns, different specialists, distinct deliverables
- **Steps = one task**: Sequential actions within a single coherent activity

**CRITICAL**: Tasks represent **logical units of work**, not individual file changes.

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| One task per file | Over-fragmented, loses context | Group related file changes |
| "Run tests" as a task | Structurally broken, wastes sessions | Each task writes and passes its own tests (TDD) |
| "Update X" + "Update Y" + "Update Z" for same change | Same logical work split artificially | One task: "Update all X to Y" |
| Separate task for each module touched | Loses atomicity | One task covers the full change |

### When to Split vs Combine

**Split when:**
- Different concerns (e.g., backend logic vs. UI text)
- Different expertise needed (e.g., database vs. frontend)
- Independent deliverables that provide value alone
- Genuine sequential dependency (e.g., "design API" then "implement API")

**Combine when:**
- Same logical change across multiple files (refactor, rename)
- Changes that must happen together atomically
- File-level changes that are part of one feature
- Testing is just verification of the same work

## Test-Driven Development Per Task

Every implementation task MUST write tests alongside its implementation. Testing is not a separate task — it's integral to the work.

### Rules

- **Tests are written BEFORE or alongside implementation** (TDD). Write the test first, watch it fail, then implement until it passes.
- **A task is not complete until its tests pass.** Tests are part of acceptance criteria.
- **The final task in a dependency chain includes end-to-end integration testing** as part of its scope.

## Assigning to Team Members

**Colony enforces agent assignment.** Every non-human task must have `assigned_agent` set. The `create_directive_tasks` API rejects task graphs with missing assignments, and the dispatch backend refuses to start sessions for unassigned tasks.

### As an Expert on a Panel

Set `assigned_agent` to your own agent name for tasks in your domain. Flag cross-domain tasks for the Foreman to assign.

### As a Solo Leader

Assign tasks based on expertise match and workload balance. Set `assigned_agent` to the agent name. Use the agent registry to find available agents and their expertise.

## Refinement Checklist

Before submitting tasks, verify each one:

1. [ ] **No standalone verification tasks** — if any task's sole purpose is verifying other tasks' work, delete it
2. [ ] Title is clear, imperative, and specific
3. [ ] Description provides enough context to execute independently
4. [ ] `assigned_agent` is set to a valid agent name (required — Colony rejects tasks without it)
5. [ ] Deliverable is appropriate (usually `pr_merged`)
6. [ ] Dependencies are minimal and correct
7. [ ] 2-5 acceptance criteria with business IDs
8. [ ] Each implementation task includes its own tests (TDD)

## API Calls

Create your tasks using the MCP tool `create_directive_tasks`:

```
Tool: create_directive_tasks
Arguments:
  directive_id: "<uuid>"
  decomposition_rationale: "Strategy explanation..."
  acceptance_criteria: ["Criterion 1", "Criterion 2"]
  tasks: [
    {
      "title": "...",
      "description": "...",
      "assigned_agent": "backend-expert",
      "deliverable": "pr_merged",
      "depends_on": [],
      "acceptance_criteria": [
        {"id": "business:slug", "text": "...", "source": "business"}
      ]
    },
    {
      "title": "Validate changes work end-to-end",
      "description": "Run smoke tests...",
      "assigned_agent": "backend-expert",
      "deliverable": "validated",
      "depends_on": [0]
    }
  ]
```

Signal completion using the MCP tool `complete_directive`:

```
Tool: complete_directive
Arguments:
  directive_id: "<uuid>"
```

## Escalation Categories

When escalating via the `escalate` tool, use one of these categories:

- `blocked`
- `ambiguous`
- `out_of_scope`
- `technical`


## Operational Validation Checklist

Before submitting a task DAG:

1. **Any `:pr_merged` tasks -> must include `:validated` task** — Colony rejects DAGs without this
2. **CI/CD directives**: `:validated` task triggers the pipeline and checks ALL stages succeed
3. **Deployment directives**: `:validated` task hits the deployed URL and verifies expected behavior
4. **User-facing features**: `:validated` task interacts with the feature as a user would
5. **Validation workers only check, never fix** — failures go to Foreman for remediation
