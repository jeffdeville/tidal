# Expert Panel Planning

After assembling a team, use this skill to moderate a planning panel where experts propose tasks and acceptance criteria in their domains.

## When to Use

- After team assembly, when 2+ experts are on the team
- For any directive with multiple disciplines involved

For simple directives with a single expert (the leader), skip the panel — have the leader propose tasks directly using TASK_REFINEMENT.md.

## The Foreman's Role

You are the **moderator**, not the planner. Your job:

1. Present the work to each expert with a rough success framing
2. Collect their task proposals and acceptance criteria
3. Ensure complete coverage — every aspect of the directive is addressed
4. Resolve conflicts, overlaps, and dependency issues
5. Synthesize and submit the final DAG

You do NOT write implementation tasks. The experts do. You ensure the pieces fit together.

## Step 1: Prepare the Expert Brief

Before consulting experts, assemble the context they'll all receive:

- **Full directive text**: The original request
- **Rough success framing**: Your initial sense of what "done" looks like (experts will refine this into formal AC)
- **Panel roster**: All experts and their domains, so each expert knows who else is involved
- **Codebase context**: Key findings from your triage (affected files, existing patterns, risk factors)

## Step 2: Consult Each Expert

**CRITICAL: Do NOT spawn Agent subprocesses or subagents for expert consultation — they hang in worktree contexts. Instead, role-play each expert yourself sequentially.** For each expert on the team, adopt their perspective and produce their task proposals inline. Use the following prompt structure as the expert's brief:

```
You are {expert-agent-name}, an expert in {their domain}.

## Directive
{Full directive text}

## Success Framing
{Your rough sense of what "done" looks like — experts will refine this into formal AC}

## Your Panel
You are one of several experts planning this work:
{List each expert and their domain}

## Codebase Context
{Key findings from triage — affected files, existing patterns, risk areas}

## Your Task

Review this directive through your domain expertise. Propose the tasks YOU should own.

For each task, provide:

1. **Title**: Clear, imperative (e.g., "Implement JWT refresh endpoint")
2. **Description**: Full context and requirements — enough for an agent to execute independently
3. **Acceptance Criteria**: Domain-informed, specific, testable business criteria for this task.
   Format: [{"id": "business:slug", "text": "What must be true", "source": "business"}]
4. **Dependencies**: What must happen before this task? Reference other experts' likely work by domain
5. **Risks/Concerns**: Anything the Foreman should know from your domain perspective
6. **Estimated size**: S, M, or L

Be specific. You are the domain expert. Write AC that reflects your actual expertise, not generic placeholders.

Respond with a JSON array of task proposals.
```

### Product Owner Variant

If an expert on the team holds a product/business perspective, their prompt should emphasize different responsibilities:

```
You are {product-owner-name}, representing the product and user perspective.

[Same directive, success framing, panel, and context sections as above]

## Your Task

You do NOT write implementation tasks. Your role is to:

1. **Validate the plan from the user's perspective**: Will this actually serve user needs?
2. **Enrich acceptance criteria**: Add criteria the technical experts may miss:
   - Performance requirements (response times, concurrent users)
   - UX requirements (accessibility, error messages, edge cases)
   - Business constraints (data retention, compliance, SLAs)
3. **Challenge assumptions**: What are the technical experts assuming about user behavior?
4. **Propose validation tasks**: Suggest specific things to test from the user's perspective

Respond with:
- Additional acceptance criteria to add to relevant tasks
- Concerns or questions about the technical approach
- Suggested validation/review tasks (with clear scope)
```

**IMPORTANT**: The Product Owner is NOT optional. Every panel must include a Product Owner.
If no "Product Owner" agent exists for this project, create one immediately using CREATE_AGENT.
The agent MUST always be named "Product Owner" for consistency across projects.
The Product Owner validates that acceptance criteria will truly prove the directive's desired
outcome — not just that code was written.

## Step 3: Collect and Synthesize

After all experts respond, you (the Foreman) synthesize their proposals:

### 3a. Map AC Coverage

For each aspect of the directive, identify which expert's tasks address it:

| Directive Aspect | Covered By | Tasks |
|-----------------|------------|-------|
| User can reset password | backend-architect | "Implement reset endpoint", "Add token generation" |
| Tests pass | (implicit) | Each task includes its own tests (TDD) |
| No security vulnerabilities | security-expert | "Security audit of auth changes" |

**If any aspect is uncovered**: Ask the relevant expert to add tasks, or add a task yourself if the gap is obvious.

### 3b. Resolve Overlaps

If two experts proposed tasks touching the same area:

1. Determine who owns it (domain closest to the work)
2. Merge or reassign the duplicate
3. If unclear, ask the experts to clarify scope boundaries

### 3c. Sequence Dependencies

Build the dependency graph across all experts' tasks:

1. Convert expert cross-references ("needs database schema from database-architect") into concrete `depends_on` indices
2. Maximize parallelism without creating conflicts
3. Verify the graph is a DAG (no cycles)

### 3d. Validate Constraints

Before submitting, check every task against:

- [ ] No standalone verification tasks (review tasks that produce findings are OK)
- [ ] Every task has acceptance criteria
- [ ] Dependencies form a DAG (no cycles)
- [ ] Every aspect of the directive is covered by at least one implementation task
- [ ] Product Owner reviewed and approved all business acceptance criteria
- [ ] If any task is `:pr_merged`, at least one task is `:validated` (Colony enforces this)
- [ ] `:validated` tasks verify live outcomes, not just code artifacts

### 3e. Incorporate Product Owner Feedback

If a product owner participated:

- Add their enriched acceptance criteria to the relevant tasks
- Address or document their concerns
- Include their suggested validation tasks in the DAG

## Step 4: Submit the DAG

Assemble all tasks into the final DAG and submit using the MCP tool `create_directive_tasks`:

```
Tool: create_directive_tasks
Arguments:
  directive_id: "<uuid>"
  decomposition_rationale: "Expert panel with N experts. [How tasks integrate and why they were split this way]"
  tasks:
    - title: "Implement feature X"
      description: "Full context..."
      assigned_agent: "agent-name"
      deliverable: "pr_merged"
      depends_on: []
      acceptance_criteria:
        - id: "business:feature-x"
          text: "Feature X works correctly"
          source: "business"
    - title: "Validate end-to-end"
      description: "Run smoke tests..."
      assigned_agent: "agent-name"
      deliverable: "validated"
      depends_on: [0]
```

## Single-Expert Shortcut

For simple directives with only one expert on the team (the leader), skip the panel process entirely. Have the leader propose tasks directly using TASK_REFINEMENT.md, validate coverage yourself, and submit. Don't add ceremony where it isn't needed.

## Handling Expert Disagreements

If experts propose conflicting approaches:

1. Note the disagreement
2. Evaluate which approach better serves the directive's goals
3. If unclear, consider escalating with both options for the human to decide
4. Document the decision in `decomposition_rationale.strategy`
