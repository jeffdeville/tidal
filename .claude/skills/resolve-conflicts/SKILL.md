---
name: resolve-conflicts
description: Intelligently resolve git merge conflicts with Elixir-specific knowledge
---

# /resolve-conflicts - Intelligent Merge Conflict Resolution

Resolve git merge conflicts with understanding of Elixir/Phoenix patterns and semantic intent.

**Arguments**: $ARGUMENTS

## Usage

```
/resolve-conflicts              # Interactive resolution
/resolve-conflicts --analyze    # Just analyze, don't resolve
/resolve-conflicts --auto       # Auto-resolve simple conflicts
/resolve-conflicts --strategy combine  # Combine both changes
```

## Workflow

### Step 1: Gather Context

First, understand what's being merged:

```bash
# What we're trying to merge
git log --oneline main..HEAD

# What changed on main since we branched
git log --oneline HEAD..main

# Our changes
git diff main...HEAD --stat

# Files with conflicts
git diff --name-only --diff-filter=U
```

### Step 2: Analyze Each Conflict

For each conflicting file, determine the conflict type:

#### Type A: Independent Changes (Easy)
Both sides changed different parts of the file.
**Resolution**: Combine both changes.

#### Type B: Same Line, Different Intent (Medium)
Both sides modified the same code for different reasons.
**Resolution**: Analyze intent and merge semantically.

#### Type C: Refactoring Conflicts (Hard)
One side refactored while the other added features.
**Resolution**: Apply our logic to their structure.

#### Type D: Config/Schema Conflicts (Common)
Mix.exs, router.ex, or schema files with additions from both sides.
**Resolution**: Usually combine, but check for version conflicts.

### Step 3: Elixir-Specific Patterns

#### Pattern: Router Conflicts
When both sides add routes to the same scope:
- Keep both routes
- Check for path conflicts
- Maintain alphabetical ordering

#### Pattern: Schema Conflicts
When both sides add fields:
- Keep both fields
- Check for migration ordering
- Ensure no duplicate field names

#### Pattern: Context Module Conflicts
When both sides add functions:
- Keep both functions
- Check for naming conflicts
- Maintain module organization

#### Pattern: Test Conflicts
When both sides add test cases:
- Keep both tests
- Check for duplicate test names
- Ensure proper setup/teardown

### Step 4: Resolve and Verify

After resolving each conflict:

```bash
# Mark file as resolved
git add <file>

# Verify it compiles
mix compile --warnings-as-errors

# Run related tests
mix test test/path/to/related_test.exs
```

### Step 5: Complete the Merge

```bash
# Ensure all conflicts resolved
git diff --check

# Complete merge
git commit

# Run full test suite
mix test
```

## Auto-Resolution Rules

When using `--auto`, these patterns are resolved automatically:

1. **Both add different deps to mix.exs**: Combine
2. **Both add different routes to router**: Combine
3. **Both add different schema fields**: Combine (if no name collision)
4. **Both add different test cases**: Combine
5. **Formatting-only conflicts**: Use main's formatting
6. **Import/alias additions**: Combine

## Manual Review Required

These patterns always need human review:

1. **Logic changes to same function**: Semantic understanding needed
2. **Version bumps on same dep**: Choose appropriate version
3. **Breaking API changes**: Understand impact
4. **Migration conflicts**: Ordering matters
5. **Auth/security code**: Critical review needed

## Conflict Prevention

To reduce future conflicts:

1. **Rebase frequently**: `git fetch origin && git rebase origin/main`
2. **Small PRs**: Easier to merge
3. **Coordinate on shared files**: router.ex, schema.ex
4. **Use feature flags**: Avoid long-running branches
