# Naming Directives

This is a lightweight skill for generating concise, descriptive titles for directives.

## Constraints

- **Maximum 50 characters** - Titles must fit in compact displays
- **Imperative mood** - Start with an action verb
- **Specific** - Include what's being changed, not just the area

## Title Formula

```
[Action Verb] + [Specific Target] + [Optional Context]
```

Examples:
- "Add OAuth2 authentication"
- "Fix null pointer in user lookup"
- "Refactor payment processing"
- "Update API rate limiting"
- "Remove deprecated endpoints"

## Action Verbs by Problem Type

| Problem Type | Typical Verbs |
|--------------|---------------|
| feature | Add, Implement, Create, Build, Enable |
| bug_fix | Fix, Resolve, Handle, Correct, Repair |
| refactor | Refactor, Simplify, Extract, Reorganize, Clean up |
| security | Secure, Harden, Patch, Validate, Encrypt |
| infrastructure | Configure, Deploy, Scale, Migrate, Upgrade |
| documentation | Document, Update docs for, Add README for |
| performance | Optimize, Speed up, Cache, Reduce |

## Examples by Complexity

### Simple (1-4 points)
- "Fix typo in error message"
- "Add index to users.email"
- "Update config timeout"

### Medium (8-16 points)
- "Add user authentication"
- "Refactor task scheduler"
- "Implement caching layer"

### Complex (32-64 points)
- "Build multi-tenant support"
- "Migrate to event sourcing"
- "Add real-time notifications"

## Anti-Patterns

| Bad | Why | Good |
|-----|-----|------|
| "User stuff" | Too vague | "Add user profile editing" |
| "Fix bug" | No specificity | "Fix login redirect loop" |
| "Update code" | Meaningless | "Update payment validation" |
| "Implement the feature for handling..." | Too long | "Add order processing" |
| "Changes to auth" | Passive, vague | "Refactor auth middleware" |

## Process

1. Read the directive text
2. Identify the primary action (what's being done)
3. Identify the target (what's being changed)
4. Compose: verb + target + optional context
5. Truncate if over 50 characters
6. Update the directive using the `rename_directive` operation

## API Call

Use the MCP tool `rename_directive`:

```
Tool: rename_directive
Arguments:
  title: "Your concise title"
```
