---
name: deep-eval
description: Conduct independent deep evaluations of the entire project from each agent's perspective
effort: high
# NOTE: Agent names below (architect-elixir, elixir-senior-developer, ui-elixir, ui-ux-designer)
# are illustrative placeholders from the original HearthConnect project. Replace with available
# project agents before use. For Colony, use: colony-elixir-architect,
# colony-phoenix-app-architect, colony-ux-designer, product-owner.
synced_from_colony: true
sync_pack: universal
sync_source: packs/universal/deep-eval/SKILL.md
sync_version: d3fefcef
---

# Deep Evaluation Command: Multi-Agent Project Analysis

Orchestrate independent, thorough evaluations of the entire codebase from each specialist agent's perspective. Each agent conducts deep analysis in their area of expertise, writing findings to individual analysis files to enable "ultra thinking mode" with comprehensive reasoning trails.

## Command Overview

This command launches **5 parallel agents** that each conduct independent deep analysis:

| Agent | Focus Area | Output File |
|-------|------------|-------------|
| architect-elixir | Architecture, OTP patterns, cognitive load | `evaluations/architect_eval.md` |
| elixir-senior-developer | Code quality, patterns, best practices | `evaluations/developer_eval.md` |
| ui-elixir | LiveView best practices, component design | `evaluations/ui_liveview_eval.md` |
| ui-ux-designer | UX best practices, user flows, accessibility | `evaluations/ux_design_eval.md` |
| product-owner | Business alignment, feature completeness | `evaluations/product_owner_eval.md` |

After all agents complete, synthesize findings into a prioritized report.

## Workflow

```
Step 1: Create evaluations directory
    ↓
Step 2: Launch 5 Agents in Parallel (single message, 5 Task calls)
    ├─→ architect-elixir: Architecture deep dive
    ├─→ elixir-senior-developer: Code quality analysis
    ├─→ ui-elixir: LiveView/component review
    ├─→ ui-ux-designer: UX evaluation
    └─→ product-owner: Business alignment review
    ↓
Step 3: Wait for all agents to complete
    ↓
Step 4: Synthesize into prioritized recommendations
    ↓
Step 5: Generate final report
```

## Step 1: Setup

Create the evaluations directory:
```bash
mkdir -p evaluations
```

## Step 2: Launch 5 Parallel Deep Evaluations

Launch **ALL FIVE agents in parallel** using Task tool in a **single message** with 5 Task calls. Each agent writes their analysis to their own file for comprehensive reasoning.

### Agent 1: Architecture Evaluation (architect-elixir)

```
Task(
  subagent_type: "architect-elixir",
  description: "Deep architecture evaluation",
  prompt: "You are conducting a comprehensive architecture evaluation of the HearthConnect project.

## Your Mission
Perform an exhaustive architecture review. Write your COMPLETE analysis to `evaluations/architect_eval.md` as you work. This file is your thinking space - be thorough.

## Analysis Structure

Write to `evaluations/architect_eval.md` with this structure:

```markdown
# Architecture Deep Evaluation

**Evaluation Date**: [current date]
**Evaluator**: architect-elixir

## Executive Summary
[2-3 sentences on overall architecture health]

## 1. Project Structure Analysis

### Module Organization
- Review lib/hearth_connect/* organization
- Evaluate context boundaries
- Check for circular dependencies
- Assess module naming conventions

### OTP Architecture
- Supervision tree analysis
- GenServer usage patterns
- Process lifecycle management
- Fault tolerance design

## 2. Cognitive Load Assessment

For each major module, evaluate:
- 🧠 Low (≤4 facts to track)
- 🤔 Medium (5-6 facts)
- 🤯 High (7+ facts - needs refactoring)

### Module-by-Module Analysis
[Analyze each context/module for cognitive load]

## 3. Pattern Compliance

### Phoenix Best Practices
- Context layer usage
- Schema design
- Changeset patterns
- Query composition

### Elixir Idioms
- Pattern matching effectiveness
- Pipe usage
- With statement complexity
- Error handling patterns

## 4. Data Flow & Contracts

### Ecto Schema Design
- Association patterns
- Validation completeness
- Migration history

### Cross-Context Communication
- Data contracts between contexts
- API boundaries
- Shared types/structs

## 5. Security Architecture

- Input validation patterns
- Authentication/authorization flow
- Data exposure risks
- Secrets management

## 6. Performance Considerations

- N+1 query risks
- Preloading patterns
- Index coverage
- Caching strategies

## 7. Findings Summary

### Critical Issues (Must Fix)
[List with severity justification]

### High Priority (Should Fix Soon)
[List with severity justification]

### Medium Priority (Plan to Address)
[List with severity justification]

### Low Priority (Nice to Have)
[List with severity justification]

### Strengths (What's Working Well)
[Positive patterns to maintain]

## 8. Recommendations

[Prioritized actionable recommendations with code examples where helpful]
```

## Instructions

1. Read through ALL Elixir source files in lib/hearth_connect/
2. Read the web layer in lib/hearth_connect_web/
3. Examine config files and mix.exs
4. Write your analysis progressively to the file as you discover findings
5. Be specific - reference exact file paths and line numbers
6. Include code snippets showing problems and suggested fixes
7. Rate EVERY finding as Critical/High/Medium/Low with justification

Take your time. Be thorough. This is a comprehensive audit."
)
```

### Agent 2: Developer Code Quality (elixir-senior-developer)

```
Task(
  subagent_type: "elixir-senior-developer",
  description: "Deep code quality evaluation",
  prompt: "You are conducting a comprehensive code quality evaluation of the HearthConnect project.

## Your Mission
Perform an exhaustive code quality review. Write your COMPLETE analysis to `evaluations/developer_eval.md` as you work. This file is your thinking space - be thorough.

## Analysis Structure

Write to `evaluations/developer_eval.md` with this structure:

```markdown
# Code Quality Deep Evaluation

**Evaluation Date**: [current date]
**Evaluator**: elixir-senior-developer

## Executive Summary
[2-3 sentences on overall code health]

## 1. Code Organization

### Module Structure
- Single responsibility adherence
- Module size and complexity
- Public vs private function balance
- Naming conventions

### File Organization
- Related code proximity
- Test file locations
- Configuration management

## 2. Function Quality

### Function Design
- Function length (target: <20 lines)
- Parameter count (target: ≤4)
- Return value consistency
- Documentation completeness

### Pattern Usage
- Pattern matching effectiveness
- Guard clause usage
- Default parameter handling
- Function clause ordering

## 3. Error Handling

### Error Patterns
- {:ok, value} / {:error, reason} consistency
- Exception vs error tuple usage
- Error message quality
- Error recovery patterns

### Edge Cases
- Nil handling
- Empty collection handling
- Invalid input handling
- Timeout handling

## 4. Testing Quality

### Test Coverage
- Module coverage gaps
- Critical path coverage
- Edge case coverage
- Integration test presence

### Test Design
- Test readability
- Fixture/factory usage
- Mock/stub patterns
- Test isolation

## 5. Documentation

### Code Documentation
- @moduledoc presence
- @doc presence on public functions
- @spec completeness
- Example code in docs

### Type Specifications
- Type coverage
- Custom type definitions
- Dialyzer compliance

## 6. Dependencies

### Hex Dependencies
- Version currency
- Security vulnerabilities
- Unused dependencies
- Dependency conflicts

### Internal Dependencies
- Circular dependency risks
- Coupling analysis
- Dependency injection patterns

## 7. Code Smells

### Identified Smells
[List each smell with location and severity]
- Dead code
- Duplicated code
- Long parameter lists
- Feature envy
- Shotgun surgery
- Data clumps

## 8. Findings Summary

### Critical Issues (Must Fix)
[List with file:line references]

### High Priority (Should Fix Soon)
[List with file:line references]

### Medium Priority (Plan to Address)
[List with file:line references]

### Low Priority (Nice to Have)
[List with file:line references]

### Strengths (What's Working Well)
[Positive patterns to maintain]

## 9. Recommendations

[Prioritized actionable recommendations with code examples]
```

## Instructions

1. Read ALL source files systematically
2. Run mental analysis on each function
3. Check test files for coverage and quality
4. Examine mix.exs and dependencies
5. Write findings as you discover them
6. Be specific with file paths and line numbers
7. Include before/after code examples for improvements
8. Rate EVERY finding as Critical/High/Medium/Low

Take your time. Be thorough. This is a comprehensive audit."
)
```

### Agent 3: LiveView UI Evaluation (ui-elixir)

```
Task(
  subagent_type: "ui-elixir",
  description: "Deep LiveView evaluation",
  prompt: "You are conducting a comprehensive LiveView and UI evaluation of the HearthConnect project.

## Your Mission
Perform an exhaustive LiveView/UI review. Write your COMPLETE analysis to `evaluations/ui_liveview_eval.md` as you work. This file is your thinking space - be thorough.

## Instructions

1. Read ALL LiveView files in lib/hearth_connect_web/live/
2. Examine components in lib/hearth_connect_web/components/
3. Review layouts and templates
4. Check assets/js/ for hooks and integrations
5. Review CSS in assets/css/
6. Check LiveView tests
7. Write findings as you discover them
8. Be specific with file paths and line numbers
9. Rate EVERY finding as Critical/High/Medium/Low

Take your time. Be thorough. This is a comprehensive audit."
)
```

### Agent 4: UX Design Evaluation (ui-ux-designer)

```
Task(
  subagent_type: "ui-ux-designer",
  description: "Deep UX evaluation",
  prompt: "You are conducting a comprehensive UX design evaluation of the HearthConnect project.

## Your Mission
Perform an exhaustive UX review. Write your COMPLETE analysis to `evaluations/ux_design_eval.md` as you work. This file is your thinking space - be thorough.

## Instructions

1. Examine ALL templates and components visually
2. Trace each user journey through the code
3. Evaluate accessibility in templates
4. Review CSS for design patterns
5. Check responsive breakpoints
6. Analyze form designs
7. Evaluate error and empty states
8. Write findings as you discover them
9. Be specific about what to change and why
10. Rate EVERY finding as Critical/High/Medium/Low

Take your time. Be thorough. This is a comprehensive audit."
)
```

### Agent 5: Product Owner Business Evaluation (product-owner)

```
Task(
  subagent_type: "product-owner",
  description: "Deep business alignment evaluation",
  prompt: "You are conducting a comprehensive business alignment evaluation of the HearthConnect project.

## Your Mission
Perform an exhaustive business alignment review. Write your COMPLETE analysis to `evaluations/product_owner_eval.md` as you work. This file is your thinking space - be thorough.

## Required Reading First
Read ALL documents in docs/business/.

Then evaluate the codebase against these business objectives.

## Instructions

1. Read ALL business documents in docs/business/ FIRST
2. Map business requirements to code implementation
3. Evaluate user value delivery
4. Check feature completeness against documentation
5. Assess market readiness
6. Identify business-critical gaps
7. Write findings as you discover them
8. Be specific about business impact
9. Rate EVERY finding by business impact level
10. Think like a product owner preparing for launch

Take your time. Be thorough. This is a business-critical audit."
)
```

## Step 3: Wait for Completion

After launching all 5 agents, wait for each to complete. Each agent will write extensive analysis to their respective files.

## Step 4: Synthesize Findings

Once all agents complete, read all 5 evaluation files and synthesize into a master report.

Create `evaluations/SYNTHESIS.md` with overall health scores, critical/high/medium/low priority issues, cross-cutting themes, strengths to preserve, and recommended action plan.

## Step 5: Present Final Report

After synthesizing:

1. Display the synthesis summary
2. Highlight the top 5 most critical findings
3. Show cross-cutting themes discovered by multiple agents
4. Present recommended action plan
5. Offer to create GitHub issues for critical/high items

## Execution

Begin now:

1. Create `evaluations/` directory
2. Launch ALL 5 agents in PARALLEL (single message with 5 Task calls)
3. Wait for completion
4. Synthesize findings
5. Present prioritized report
