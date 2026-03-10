---
name: create-issue
description: Create detailed GitHub issues from epic descriptions with parallel agent collaboration
---

# Create Issue Command: Epic to Implementation-Ready GitHub Issues

Transform high-level epic descriptions into detailed, implementation-ready GitHub issues with full business context, technical approach, UI considerations, and dependency analysis.

**Epic Description**: $ARGUMENTS

This command orchestrates architect-elixir, elixir-senior-developer, ui-elixir, and product-owner agents in parallel to create comprehensive GitHub issues that guide implementation work.

## Command Objectives

1. **Business Context**: Clear user value and success metrics (from product-owner)
2. **Technical Approach**: Architecture decisions and implementation patterns (from architect-elixir, elixir-senior-developer)
3. **UI Considerations**: User experience and accessibility requirements (from ui-elixir)
4. **Testability**: Integration test scenarios and acceptance criteria (from product-owner)
5. **Dependencies**: Identify blockers and sequencing requirements
6. **Issue Breakdown**: Multiple issues if epic is too large, numbered sequentially

## Workflow

```
Step 1: Parse Epic Description
    ↓
Step 2: Launch 4 Agents in Parallel (single message, 4 Task calls)
    ├─→ architect-elixir: Architecture analysis
    ├─→ elixir-senior-developer: Technical breakdown
    ├─→ ui-elixir: UI/UX considerations
    └─→ product-owner: Business value & user perspective
    ↓
Step 3: Synthesize Findings
    ↓
Step 4: Identify Dependencies & Blockers
    ↓
Step 5: Generate GitHub Issues with gh cli (numbered ##0-1, ##0-2, etc. where ##0- is a template for the Epic number. (000, 001, etc))
    ↓
Step 6: Display for User Review
```

## Step 1: Parse Epic Description

**Input**: $ARGUMENTS (can be plain text or reference to document)

If $ARGUMENTS contains a file reference (e.g., @docs/epics/feature.md), read the file first.

**Extract**:
- Feature name/title
- High-level user goal
- Key requirements
- Any constraints mentioned

## Step 2: Parallel Agent Collaboration (Think Hard)

Launch **FOUR agents in parallel** using Task tool in a **single message** with 4 Task calls:

##0- Agent 1: Architect Review (architect-elixir)

```
Task(
  subagent_type: "general-purpose",
  description: "Architecture analysis for epic",
  prompt: "You are architect-elixir from .claude/agents/architect-elixir.md.

Epic: $ARGUMENTS

Analyze this epic from architecture perspective:

1. **Affected Components**:
   - Which modules/contexts will be created or modified?
   - What are the integration points?
   - Which databases/external services are involved?

2. **OTP Patterns**:
   - What OTP patterns should be used (GenServer, Supervisor, Task)?
   - Are there concurrency concerns?
   - What supervision strategy is needed?

3. **Cognitive Load Risks**:
   - Where might complexity exceed 4 facts (🤯)?
   - What are the tricky conditional branches?
   - Where should we extract functions early?

4. **Existing Patterns**:
   - What similar implementations exist in the codebase?
   - Which patterns should be followed? (provide file references)
   - What anti-patterns should be avoided?

5. **Data Contracts**:
   - What Ecto schemas or embedded schemas are needed?
   - What validation rules are required?
   - How should data cross context boundaries?

Return structured analysis:
{
  \"affected_modules\": [\"Module1\", \"Module2\"],
  \"otp_patterns\": {\"pattern\": \"reason\"},
  \"cognitive_load_risks\": [\"risk1: explanation\"],
  \"existing_patterns\": [{\"pattern\": \"description\", \"file\": \"path\"}],
  \"data_contracts\": [\"Schema1\", \"Schema2\"],
  \"recommendations\": [\"recommendation1\", \"recommendation2\"]
}"
)
```

##0- Agent 2: Technical Breakdown (elixir-senior-developer)

```
Task(
  subagent_type: "general-purpose",
  description: "Technical implementation breakdown",
  prompt: "You are elixir-senior-developer from .claude/agents/elixir-senior-developer.md.

Epic: $ARGUMENTS

Break down this epic into implementation tasks:

1. **Module Structure**:
   - What new modules need to be created?
   - What existing modules need modification?
   - What is the dependency order?

2. **Database Changes**:
   - New tables/schemas required?
   - Migrations needed?
   - Indexes for performance?

3. **External Dependencies**:
   - New Hex packages needed?
   - API integrations required?
   - Configuration changes?

4. **Testing Strategy**:
   - What are the critical test scenarios?
   - Where do we need integration tests?
   - What edge cases must be covered?

5. **Complexity Estimate**:
   - Small (1-2 days), Medium (3-5 days), Large (5+ days)?
   - Can this be broken into smaller tasks?
   - What's the riskiest part?

6. **Implementation Order**:
   - What should be built first?
   - What are the dependencies between tasks?
   - What can be done in parallel?

Return structured breakdown:
{
  \"modules\": {\"new\": [], \"modified\": []},
  \"database_changes\": [\"migration1\", \"migration2\"],
  \"dependencies\": [\"package1\", \"package2\"],
  \"test_scenarios\": [\"scenario1\", \"scenario2\"],
  \"complexity\": \"small|medium|large\",
  \"suggested_tasks\": [{\"title\": \"Task 1\", \"description\": \"...\", \"depends_on\": []}]
}"
)
```

##0- Agent 3: UI Considerations (ui-elixir)

```
Task(
  subagent_type: "general-purpose",
  description: "UI/UX analysis for epic",
  prompt: "You are ui-elixir from .claude/agents/ui-elixir.md.

Epic: $ARGUMENTS

Analyze UI/UX requirements:

1. **UI Components Needed**:
   - What LiveView components are required?
   - Are there existing DaisyUI components to use?
   - What custom components need to be built?

2. **User Flows**:
   - What are the key user journeys?
   - What screens/pages are involved?
   - What real-time updates are needed?

3. **Forms & Validation**:
   - What forms need to be created?
   - What client-side validation is needed?
   - What server-side validation is required?

4. **Accessibility Requirements**:
   - What ARIA labels are needed?
   - What keyboard navigation must work?
   - What contrast ratios must be met?

5. **Responsive Behavior**:
   - What changes between mobile and desktop?
   - What are the critical breakpoints?
   - What touch interactions are needed?

6. **Browser Testing Scenarios**:
   - What user flows must be browser-tested?
   - What screenshots should be captured?
   - What elements must be verified?

Return structured analysis:
{
  \"components\": {\"existing\": [], \"new\": []},
  \"user_flows\": [{\"name\": \"Flow1\", \"steps\": []}],
  \"forms\": [{\"name\": \"FormName\", \"fields\": [], \"validation\": []}],
  \"accessibility\": [\"requirement1\", \"requirement2\"],
  \"responsive_notes\": \"key changes\",
  \"browser_tests\": [{\"flow\": \"name\", \"steps\": [], \"verify\": []}]
}"
)
```

##0- Agent 4: Business Value & User Perspective (product-owner)

```
Task(
  subagent_type: "general-purpose",
  description: "Business context and user value analysis",
  prompt: "You are product-owner from .claude/agents/product-owner.md.

Epic: $ARGUMENTS

Provide business context and user perspective:

1. **User Pain Point**:
   - What specific problem does this solve for homeowners?
   - What specific problem does this solve for contractors?
   - How does this reduce their work (not increase it)?

2. **Success Metrics**:
   - How will we measure success?
   - What baseline metrics exist today?
   - What is the target improvement?

3. **User Stories**:
   - Write 2-3 user stories in format: \"As a [user], I want [capability] so that [benefit]\"
   - What are the acceptance criteria for each story?

4. **User Flows to Test**:
   - What end-to-end user flows must work?
   - What does \"done\" look like from user perspective?
   - How will users verify it works?

5. **Edge Cases**:
   - What can go wrong from user perspective?
   - How should errors be communicated to users?
   - What happens when systems are unavailable?

6. **Non-Technical Description**:
   - Describe what users will see in plain language
   - What's different about their experience after this?
   - What do they gain (time saved, anxiety reduced, etc.)?

Return structured analysis:
{
  \"pain_points\": {\"homeowners\": \"...\", \"contractors\": \"...\"},
  \"success_metrics\": [{\"metric\": \"name\", \"baseline\": \"value\", \"target\": \"value\"}],
  \"user_stories\": [{\"story\": \"...\", \"acceptance_criteria\": []}],
  \"user_flows\": [{\"flow\": \"name\", \"steps\": [], \"success\": \"what users see\"}],
  \"edge_cases\": [{\"case\": \"...\", \"handling\": \"...\"}],
  \"user_facing_summary\": \"plain language description\"
}"
)
```

## Step 3: Synthesize Findings

After all 4 agents return, synthesize their findings into coherent understanding:

**Combine**:
- Technical approach (from architect + developer)
- UI requirements (from ui-elixir)
- Business value (from product-owner)

**Look for conflicts**:
- Does technical approach support user flows?
- Are there missing components identified by one agent but not others?
- Are complexity estimates realistic given UI requirements?

## Step 4: Identify Dependencies & Blockers

Analyze task dependencies:

1. **Sequential Dependencies**:
   - Task B cannot start until Task A completes
   - Example: Database schema must exist before business logic

2. **Parallel Work**:
   - Tasks that can be done simultaneously
   - Example: Frontend and backend can progress together once contracts defined

3. **External Blockers**:
   - Waiting for third-party API access
   - Waiting for design mockups
   - Waiting for product decisions

4. **Technical Blockers**:
   - Missing packages or infrastructure
   - Performance concerns that need resolution first
   - Architectural decisions needed before implementation

**Format blockers clearly**:
- ⛔ BLOCKER: [description]
- 🔗 DEPENDS ON: [task reference]
- ⚠️ RISK: [potential issue]

## Step 5: Generate GitHub Issues

Create detailed GitHub issues using synthesized information. Number issues sequentially as `##0-1`, `##0-2`, `##0-3`, etc. where ##0- is for the epic number. 000, 001, etc

**Issue Template**:

```markdown
##0-[N] [Issue Title from Task]

## Why This Matters (Business Context)

**User Pain Point**: [From product-owner - homeowners/contractors problem]

**Success Metrics**: [Measurable outcomes]
- Metric 1: Baseline → Target
- Metric 2: Baseline → Target

**Without This**: [What pain persists]

## User Stories

**As a [homeowner/contractor]**, I want to [capability] so that [specific benefit that reduces their work].

**Acceptance Criteria** (User Perspective):
- [ ] User can accomplish [goal] in [time/clicks]
- [ ] System provides [feedback] without user asking
- [ ] Edge case [scenario] handled gracefully
- [ ] User receives [value] without additional effort

## What Users See (Non-Technical)

**Current Experience**: [What users deal with today]

**New Experience**: [What they'll experience after this feature]

**Key Difference**: [The specific improvement in their day]

## Technical Approach

**Affected Modules**:
- New: [List from developer]
- Modified: [List from developer]

**Architecture Decisions**:
- [Key decision from architect with rationale]
- [OTP pattern to use and why]

**Database Changes**:
- [ ] Migration: [description]
- [ ] Schema: [description]
- [ ] Indexes: [description]

**External Dependencies**:
- Package: [name] - [purpose]
- API: [name] - [purpose]

**Existing Patterns to Follow**:
- Pattern: [description] (see: [file reference])

**Cognitive Load Considerations**:
- 🧠 Watch for: [potential complexity hotspot]
- Extract early: [suggestion from architect]

## UI Requirements (If Applicable)

**Components Needed**:
- Existing: [DaisyUI components to use]
- New: [Custom components to build]

**User Flow**:
1. User [action]
2. System [response]
3. User sees [result]

**Forms & Validation**:
- Form: [name]
  - Fields: [list]
  - Validation: [client-side and server-side rules]

**Accessibility**:
- [ ] ARIA labels: [specific requirements]
- [ ] Keyboard navigation: [tab order, focus management]
- [ ] Contrast ratios: [specific color pairs to verify]

**Responsive Behavior**:
- Mobile (< 768px): [key changes]
- Desktop (> 1024px): [key changes]

## Testing Requirements

**Integration Tests** (User Flows):
```elixir
# apps/hearth_app/test/hearth_app_web/integration/[feature]_test.exs
describe "[user goal]" do
  test "[specific user outcome]" do
    # Arrange: [setup user scenario]
    # Act: [perform user action]
    # Assert: [verify user-facing result]
  end
end
```

**Browser Test Scenarios**:
1. Navigate to [URL]
2. User [interaction]
3. Verify [expected element/state]
4. Capture screenshot of [state]

**Edge Cases to Test**:
- Empty state: [expected behavior]
- Error state: [expected message to user]
- Loading state: [expected feedback]

## Implementation Checklist

**Phase 1: Foundation**
- [ ] Create database migration
- [ ] Define Ecto schemas with validations
- [ ] Write unit tests (TDD red phase)

**Phase 2: Business Logic**
- [ ] Implement context functions
- [ ] Handle error cases explicitly
- [ ] Add integration tests for workflows

**Phase 3: UI (If Applicable)**
- [ ] Create LiveView modules
- [ ] Implement forms with validation
- [ ] Add real-time updates (if needed)
- [ ] Ensure accessibility compliance

**Phase 4: Quality**
- [ ] All tests passing (unit + integration)
- [ ] Code coverage ≥ 80%
- [ ] Credo clean (0 violations)
- [ ] Dialyzer clean (0 warnings)
- [ ] Browser tested with real data

**Phase 5: Documentation**
- [ ] @moduledoc on all public modules
- [ ] @doc and @spec on all public functions
- [ ] Update CLAUDE.md (if patterns changed)

## Dependencies & Blockers

**Depends On**:
- 🔗 ##0-[X]: [Issue title] - [why this is needed first]

**Blocks**:
- 🚫 ##0-[Y]: [Issue title] - [what can't proceed until this completes]

**External Blockers**:
- ⛔ [Description of external dependency]

**Risks**:
- ⚠️ [Potential technical risk and mitigation plan]

## Complexity Estimate

**Size**: [Small (1-2 days) | Medium (3-5 days) | Large (5+ days)]

**Risk Level**: [Low | Medium | High]

**Confidence**: [High | Medium | Low] - [explanation of uncertainty]

## Success Criteria (Definition of Done)

**Primary Criterion**: Working Software Delivers User Value
- [ ] User can actually accomplish the intended task
- [ ] Feature works end-to-end with real data/APIs
- [ ] Would pass product owner demo

**Code Quality**:
- [ ] Tests: 100% passing, ≥80% coverage
- [ ] Quality: 0 Credo violations, 0 Dialyzer warnings
- [ ] Complexity: Average CC <5, max CC <10
- [ ] Documentation: @moduledoc, @doc, @spec complete

**User Value**:
- [ ] Solves stated user pain point
- [ ] Reduces user work (not increases it)
- [ ] User-facing errors are clear and helpful
- [ ] Integration tests cover key user flows

**Integration** (If Applicable):
- [ ] External services actually connected (not mocked)
- [ ] UI validated in browser with real data
- [ ] Complete user workflow tested
- [ ] Screenshots captured demonstrating working feature

---
**Related Issues**: [Links to related issues if applicable]

**Created by**: /create-issue command
```

## Step 6: Display for User Review

After generating all issues:

1. **Summary**:
   - Total issues created: N
   - Dependencies identified: N
   - Blockers identified: N

2. **Dependency Graph**:
   ```
   ##0-1 → ##0-2 → ##0-4
        ↘ ##0-3 ↗
   ```

3. **Recommended Implementation Order**:
   - Phase 1: [Issues that can start immediately]
   - Phase 2: [Issues that depend on Phase 1]
   - Phase 3: [Issues that depend on Phase 2]

4. **Critical Path**:
   - Longest sequence: ##0-1 → ##0-2 → ##0-4 (X days)
   - Parallelization opportunities: ##0-2 and ##0-3 can run simultaneously

5. **Ask User**:
   - "Do these issues capture the epic correctly?"
   - "Should any issue be split further?"
   - "Are there dependencies I missed?"
   - "Ready to create these as GitHub issues?"

## Best Practices

**Issue Sizing**:
- Aim for issues that can be completed in 1-5 days
- If task is >5 days, break it down into sub-issues
- Each issue should have clear acceptance criteria

**Numbering**:
- Use ##0-1, ##0-2, ##0-3 format for sequential reference
- Preserve numbers even if issues are reordered
- Use numbers in dependency references (🔗 ##0-2)

**Dependencies**:
- Make dependencies explicit with 🔗 notation
- Explain WHY the dependency exists
- Identify both technical and business dependencies

**Blockers**:
- Distinguish between internal blockers (team can resolve) and external (requires others)
- For external blockers, identify who can unblock
- Estimate blocker resolution time

**User Perspective**:
- Every issue must have "Why This Matters" section
- Every issue must have user-facing acceptance criteria
- Technical details should connect to user value

## Examples

##0- Input: Simple Feature
```
Epic: Add ability for contractors to mark projects as archived
```

**Output**: Single issue (##0-1) with full template, no dependencies

##0- Input: Complex Feature
```
Epic: Implement AI-powered lead qualification conversation with homeowners, including photo upload, rendering generation, and contractor brief delivery
```

**Output**: Multiple issues with dependencies
- ##0-1: Database schema for conversations and messages
- ##0-2: Real-time conversation interface (depends on ##0-1)
- ##0-3: Photo upload and storage integration (parallel with ##0-2)
- ##0-4: Rendering generation service integration (depends on ##0-3)
- ##0-5: Contractor brief compilation (depends on ##0-1, ##0-2, ##0-4)

## Autonomy Guidelines

**You have autonomy to**:
- Use "think hard" if epic is complex and requires careful breakdown
- Decide how many issues to create (1 large vs. multiple small)
- Determine which agents' input is most relevant for each section
- Skip UI section if feature has no user interface

**You must follow**:
- All 4 agents must be consulted (in parallel)
- Every issue must have business context (from product-owner)
- Every issue must have technical approach (from architect + developer)
- Dependencies and blockers must be explicitly identified
- Issues must be numbered sequentially (##0-1, ##0-2, etc.)

## Begin Issue Creation

Start with Step 1 (Parse Epic Description) now.
