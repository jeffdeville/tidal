# Create Skill

When you identify missing conventions, domain knowledge, or repeatable workflows that should be codified for agents, create a skill.

## When to Use

- A pattern or convention keeps coming up that agents should always follow
- A workflow is needed that agents should be able to invoke
- Domain knowledge needs to be codified for consistent application across tasks
- You want to teach agents something they should "always know" in a particular context

## Skill vs Agent

Skills and agents serve different purposes:

- **Agent** = WHO (expertise, identity, knowledge) → `.claude/agents/{name}.md`
- **Skill** = WHAT TO DO (conventions, workflows, procedures) → `.claude/skills/{category}/SKILL.md` or `.claude/skills/{category}/{name}/SKILL.md`

Agents are loaded based on task assignment. Skills are loaded based on `skill_categories` in the agent's frontmatter.

## Skill File Format

### Directory Structure

Skills are organized by category (directory):

```
.claude/skills/
├── foreman/              # Category: foreman skills
│   ├── SKILL.md          # Main foreman workflow
│   ├── GRADING.md        # Complexity grading
│   ├── TEAM_ASSEMBLY.md  # Team assembly reference
│   └── CREATE_AGENT.md   # Agent creation
├── elixir/               # Category: elixir skills
│   └── SKILL.md          # Elixir conventions
└── phoenix/              # Category: phoenix skills
    └── SKILL.md          # Phoenix conventions
```

An agent with `skill_categories: ["foreman"]` loads ALL `.md` files from `.claude/skills/foreman/`.

### Single-File Skills

For simple skills, create a single file directly in the category directory:

```
.claude/skills/{category}/{name}.md
```

### Multi-File Skills

For skills with bundled resources (scripts, templates, reference docs), use a subdirectory:

```
.claude/skills/{category}/{name}/
├── SKILL.md              # Main skill file (required)
└── scripts/              # Optional bundled resources
    └── helper.sh
```

### YAML Frontmatter

Not required for skill files loaded via `skill_categories` (they're loaded by directory, not by frontmatter matching). If present, frontmatter can include:

```yaml
---
name: {skill-name}
description: {what it does AND when to use it}
---
```

The `description` field is important if the skill needs to be discoverable — it should explain both WHAT the skill does and WHEN it should apply.

## Skill Body Structure

The body should follow progressive disclosure:

1. **Title and purpose** (always visible, ~1-2 lines)
2. **When to Use** (triggers — when should this skill activate?)
3. **Quick Start** (optional — brief getting-started example)
4. **Guidelines** (the core conventions or rules)
5. **Examples** (good/bad code comparisons with explanations)
6. **References** (links to additional docs, loaded on-demand)

### Token Budget

- Keep the body **under 5k tokens**. Skills are injected into every prompt for agents with matching categories.
- Focus on the most impactful patterns. Don't try to cover everything.
- Use references to point to additional detail that agents can read when needed.

## Procedure

1. **Identify the category**: Which agents should receive this skill? Match to an existing category or create a new one. Check existing categories under `.claude/skills/`.
2. **Name the skill**: Lowercase with hyphens. Descriptive of what it teaches.
3. **Choose file structure**: Single file for simple skills, subdirectory for skills with resources.
4. **Write the skill file**: Follow the body structure above. Start with the most important guidelines.
5. **Verify loading**: The skill is immediately available to any agent session whose `skill_categories` includes the matching category. No registry refresh needed — skills are loaded from disk at session start.

## Key Principles

- **Description must explain WHAT and WHEN**: This is critical for discoverability and auto-loading. "Elixir conventions" is bad. "Idiomatic Elixir conventions for pattern matching, error handling, and function design. Use when writing or reviewing Elixir code." is good.
- **Progressive disclosure**: Metadata ~100 tokens, core instructions under 5k tokens, additional resources loaded on-demand via file reads.
- **Focus on impact**: A skill with 3 high-impact guidelines beats one with 30 minor suggestions.
- **Show, don't just tell**: Include good/bad examples for every non-obvious guideline.
- **Category alignment**: Put the skill where the agents who need it will find it. A Phoenix LiveView skill goes in `phoenix/`, not `frontend/`.
