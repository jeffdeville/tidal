# Team Assembly Reference

## Team Structure

Every directive gets a team:
- **Leader**: The primary agent responsible for the work (always 1)
- **Contributors**: Additional agents with complementary expertise (0-3)
- **Escalation Path**: Leader → Contributors → Human (built automatically)

## Selecting a Leader

The leader should be the agent best suited to own the work. Consider:

### Expertise Match
Match the agent's expertise tags to the problem type and affected areas:
- `bug_fix` in `lib/colony/tasks/` → agent with `elixir`, `testing`
- `feature` for `frontend` → agent with `frontend`, `javascript`, `react`
- `security` → agent with `security`, `auth`, `cryptography`

### Scope Appropriateness
- Simple tasks (1-4 points): Any matching agent works
- Complex tasks (8+ points): Prefer senior/architect-level agents
- Cross-cutting work: Prefer generalists or architects

### Specialization
If the work is clearly in one domain, prefer a specialist:
- Database migrations → backend specialist
- UI component → frontend specialist
- CI/CD changes → devops specialist

## Selecting Contributors

Contributors provide complementary expertise. Add them when:

1. **Multiple disciplines involved**: Frontend + backend work
2. **Specialized knowledge needed**: Security review, performance tuning
3. **High complexity**: More eyes on decomposition helps
4. **Knowledge transfer**: Pairing less experienced with experts

### Don't Over-Staff

- 1-4 point tasks: Usually leader alone is sufficient
- 8 point tasks: 1-2 contributors if multi-disciplinary
- 16+ point tasks: May warrant 2-3 contributors

Avoid adding contributors just for the sake of it.

## Agent Selection Criteria

When choosing from available agents, evaluate:

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Expertise match | High | Does their expertise align with the problem? |
| Experience level | Medium | Is their seniority appropriate for complexity? |
| Current load | Low | Are they already overloaded? (You may not know this) |
| Collaboration | Low | Do they work well with the leader? |

## Example Selections

### Simple Bug Fix (2 points)
Request: "Fix null pointer in user lookup"
- **Leader**: `elixir-dev` (Elixir expertise, testing)
- **Contributors**: None needed

### Medium Feature (8 points)
Request: "Add password reset flow"
- **Leader**: `backend-architect` (Auth expertise, Elixir)
- **Contributors**: `frontend-dev` (UI for reset form)

### Complex Feature (16 points)
Request: "Implement OAuth2 authentication with multiple providers"
- **Leader**: `security-specialist` (Auth, OAuth, security)
- **Contributors**: `backend-architect` (Integration), `frontend-dev` (Login UI)

### Cross-Cutting Refactor (16 points)
Request: "Migrate from callbacks to event sourcing"
- **Leader**: `backend-architect` (Architecture, patterns)
- **Contributors**: `elixir-dev` (Implementation), `testing-lead` (Test updates)

## Handling Missing Capabilities

If no available agent matches the needed expertise, **create one immediately**.
Do NOT escalate for missing expertise. Do NOT continue planning without the expert.

1. Follow the CREATE_AGENT skill to write a new agent file
2. The agent is automatically available after writing the file
3. Include the new agent in your team assignment
4. Continue planning with the full team

The new agent will be available for task assignment in this directive and all future work.

If you are unsure what expertise the agent needs (you don't understand the domain
well enough to specify it), THEN escalate to the human for guidance.

## Building Escalation Paths

The escalation path is deterministic:
1. Leader (first contact for issues)
2. Contributors (in order added)
3. Human (final escalation)

Example: Leader `backend-architect`, Contributors `frontend-dev`, `testing-lead`
- Escalation path: `["backend-architect", "frontend-dev", "testing-lead", "human"]`

## Team Assembly Checklist

1. [ ] Did I select a leader with matching expertise?
2. [ ] Is the leader's seniority appropriate for complexity?
3. [ ] Did I add contributors only where needed?
4. [ ] Are all affected areas covered by the team?
5. [ ] Did I identify capability gaps if any exist?
