---
name: document
description: Generate or update documentation for code
---

Generate comprehensive documentation for: $ARGUMENTS

## Phase 1: Analyze Target
1. Read target module/feature code
2. Identify public API surface
3. Understand purpose and usage
4. Note any complex behaviors

## Phase 2: Generate Module Documentation
For each public module:
1. Add @moduledoc with:
   - Clear description of purpose
   - Overview of main functionality
   - Basic usage examples
   - Links to related modules

2. Add @doc for each public function:
   - What the function does
   - Parameter descriptions
   - Return value specification
   - Practical examples

3. Add @spec for type safety:
   - Complete type specifications
   - Use proper Elixir types
   - Document all return variants

## Phase 3: Create Livebook (if complex)
IF feature is complex or requires interactive examples:
1. Create Livebook in `/notebooks/[feature_name].livemd`
2. Include:
   - Setup instructions
   - Interactive examples
   - Common use cases
   - Debugging scenarios
   - Operational runbooks (if applicable)

## Phase 4: Update CLAUDE.md Files
Evaluate if CLAUDE.md updates needed:

### Update Root CLAUDE.md When:
- Project-wide patterns changed
- New quality standards added
- New monitoring tools integrated
- Agentic workflow evolved

### Update App CLAUDE.md When:
- App purpose/objectives changed
- New features added
- New endpoints exposed
- Known issues identified
- Structure reorganized

Remember: CLAUDE.md = **specific usage guidance**, NOT general theory

## Phase 5: Summary
Provide summary of:
- Modules documented (count of @moduledoc, @doc, @spec added)
- Livebook created (location and purpose)
- CLAUDE.md updates (which file, why, what changed)

## Documentation Standards
- Use clear, concise language
- Provide executable examples
- Focus on practical usage
- Document edge cases
- Include error scenarios

Begin Phase 1 now.
