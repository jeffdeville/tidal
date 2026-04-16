---
name: arch-review
description: Review code for cognitive load and Elixir/Phoenix best practices
argument-hint: <file or module to review>
synced_from_colony: true
sync_pack: elixir
sync_source: packs/elixir/arch-review/SKILL.md
sync_version: d3fefcef
---

# Architecture Review Command

Review the specified code for cognitive load and Elixir/Phoenix best practices.

**Task**: Use the `elixir-architect` agent to conduct a thorough architecture review following these steps:

1. **Identify Target**: Review the code file(s) or module(s) specified by the user
2. **Systematic Analysis**:
   - Check for cognitive load issues (>7 facts to track)
   - Evaluate pattern matching, pipes, `with` statements
   - Review GenServer/supervision complexity
   - Assess Phoenix LiveView/Context design
3. **Generate Report**: Produce findings with:
   - Severity levels (Critical/High/Medium/Low)
   - Code examples showing current vs suggested
   - Cognitive load notation
   - Specific refactoring recommendations
4. **Prioritize**: Order findings by severity and impact

**Output Format**: Structured review report with actionable recommendations

**Subagent**: Use the `elixir-architect` agent with the Task tool to perform the review.
