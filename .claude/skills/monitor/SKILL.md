---
name: monitor
description: SHA-scoped continuous code monitoring with focused reviews against Colony constraints
---

# Monitor Skill

Continuous code monitoring that tracks the last-reviewed git SHA per review type, computes diffs, classifies changed files, and runs focused reviews against Colony's architectural constraints.

## Workflow

### Step 1: Parse Arguments

Determine the run configuration from the command arguments:

| Argument | Effect |
|----------|--------|
| (none) | Run all enabled review types |
| `--type arch` | Architecture review only |
| `--type quality` | Quality review (Tier 1 health cards) |
| `--tier 1` | Tier 1 only (default for quality; tiers 2-4 are future phases) |
| `--since <sha>` | Override the stored SHA for this run |
| `--full` | Ignore stored SHA; review all matching files |
| `--output files` | Write markdown to `.colony/monitor/findings/` (default) |
| `--output directives` | Create Colony directives for blocker/error findings |
| `--output stdout` | Print findings to console only |
| `--triggered-by <source>` | Tag the run source (default: "manual") |

Currently enabled review types: `architecture`, `quality`.

### Step 2: Read State

Load monitor state from the MCP resource:

```
Resource: colony://monitor/state/architecture
```

Response: `{"review_type": "architecture", "last_reviewed_sha": "abc123", "accumulated_points": 15, "base_threshold": 40, "enabled": true}`

- If `last_reviewed_sha` is `null` **and** `--since` was not provided **and** `--full` was not specified:
  - Record a baseline run (sets last_reviewed_sha to HEAD)
  - Report: "Baseline set to <sha>. No delta to review on first run."
  - **Skip the review for this type**

- If `--since <sha>` was provided: Use that SHA as the "from" point
- If `--full` was specified: Use `git ls-files` instead of `git diff`
- Otherwise: Use `last_reviewed_sha` from the response

### Step 3: Compute Changed Files

**For delta mode** (normal or `--since`):
```bash
git diff --name-only --diff-filter=ACDMR <from_sha>..HEAD
```

**For full-scan mode** (`--full`):
```bash
git ls-files
```

If no files changed, report "No changes since last review (<sha>)" and stop.

### Step 4: Classify Files

Apply the patterns from `FILE_CLASSIFICATION.md` to determine which review types are triggered.

For each review type being run:
- Filter the changed files list to only those matching that type's trigger patterns
- If no files match, skip that review type
- Report: "Architecture: N files to review" (etc.)

### Step 5: Gather Context

For each triggered review type, assemble the review context. For architecture reviews, follow `ARCHITECTURE_REVIEW.md`:

1. **Read the diff** for triggered files only:
   ```bash
   git diff <from_sha>..HEAD -- <file1> <file2> ...
   ```
   For `--full` mode, read the full current content instead of a diff.

2. **Read current content** of each changed file (use the Read tool).

3. **Determine blast radius** using `mix xref graph --sink <file> --only-nodes` for each changed `.ex` file. If `mix xref` fails, fall back to grepping for the module name. Just note the dependent files — do not read them all.

4. **Load constraints**: Read `.colony/constraints/architecture.md`.

5. **Load previous findings** for dedup: Read the most recent `arch-*.md` from `.colony/monitor/findings/` (if any). This prevents re-reporting unchanged issues.

### Step 6: Run Review

Conduct the review directly (no subagent needed). Adopt the colony-elixir-architect perspective from `.claude/agents/colony-elixir-architect.md` and use the architecture-reviewer checklist from `.colony/governance/architecture-reviewer.md`.

Work through each check in `ARCHITECTURE_REVIEW.md` against the gathered context:
- ARCH-001 through ARCH-005
- CQRS boundary compliance
- Arena pattern adherence
- LiveView patterns
- Test patterns
- Code style rules from CLAUDE.md

For each finding, assess severity (blocker/error/warning/info) and provide a specific recommendation.

**Dedup**: If a finding matches a previous finding (same constraint ID + same file location) and the code at that location has NOT changed in the current diff, skip it.

Produce a JSON verdict:
```json
{
  "status": "approved|needs_changes|rejected|escalate",
  "confidence": 0.0-1.0,
  "findings": [...],
  "summary": "..."
}
```

### Step 7: Store/Dispatch Findings

Convert the JSON verdict to the structured markdown format defined in `FINDINGS_FORMAT.md`.

Write to `.colony/monitor/findings/arch-YYYY-MM-DD.md`.

If a file with that name already exists (multiple runs same day), append a sequence number: `arch-YYYY-MM-DD-2.md`.

Branch on `--output` mode:

**`files` (default)**: Write findings to `.colony/monitor/findings/` as before.

**`directives`**: For each finding with severity `blocker` or `error`:
1. Create a remediation directive via MCP tool `create_directive`:
   ```
   Tool: create_directive
   Arguments:
     raw_input: "[Monitor: ARCH-003] Fix CQRS bypass...\n\nLocation: lib/foo.ex:45\nIssue: ...\nRecommendation: ..."
     title: "[ARCH-003] Fix CQRS bypass in DirectiveController"
     metadata:
       source: "monitor"
       constraint_id: "ARCH-003"
       severity: "error"
   ```
2. Collect the returned `directive_id` values
3. Skip warnings/info findings — they don't warrant remediation directives
4. Also write findings to files for the local audit trail

**`stdout`**: Print findings inline only, no file writes or directive creation.

### Step 8: Update State

Record the completed run via the MCP tool `record_monitor_run`:

```
Tool: record_monitor_run
Arguments:
  review_type: "architecture"
  from_sha: "<from_sha>"
  to_sha: "<current HEAD>"
  verdict: "needs_changes"
  finding_counts:
    blocker: 0
    error: 2
    warning: 3
    info: 1
  files_reviewed: 42
  directives_created: 2
  directive_ids: ["uuid1", "uuid2"]
  output_mode: "directives"
  triggered_by: "manual"
```

This records the run in `monitor_runs` AND updates `last_reviewed_sha` in `monitor_trigger_states`.

### Step 9: Report Summary

Output a summary to the user:

```
## Monitor Review Complete

**SHA range**: <from>..<to>
**Review type**: architecture
**Files reviewed**: N
**Blast radius**: M dependent files noted
**Verdict**: <status>

### Findings by Severity
- Blocker: N
- Error: N
- Warning: N
- Info: N

**Findings written to**: `.colony/monitor/findings/arch-YYYY-MM-DD.md`
```

If the verdict is `needs_changes` or `rejected`, list the blocker/error findings inline in the summary so the user sees them immediately.

---

## Quality Review: Tier 1 Health Cards

When `--type quality` (or no `--type` with quality enabled):

### Q-Step 1: Discover Modules

Run module discovery:
- With `--full`: `mix colony.health_cards.discover --batches --json`
- Without `--full`: `mix colony.health_cards.discover --stale --batches --json`

If zero modules to review, report "All N health cards are current" and skip.

### Q-Step 2: Review Batches

For each batch from Q-Step 1, spawn a Task agent (use haiku model for cost efficiency).

**Agent prompt template:**
> You are reviewing Elixir modules for code quality. For each module listed below,
> read the source file and its test file (if it exists), then write a health card
> following the schema and rubric.
>
> **Schema**: [include content from `.colony/monitor/health-cards/SCHEMA.md`]
> **Rubric**: [include content from `.colony/monitor/QUALITY_REVIEW.md`]
>
> **Modules to review:**
> - lib/colony/tasks/task.ex
> - lib/colony/tasks/task_service.ex
> - [...]
>
> Write each health card to `.colony/monitor/health-cards/<mirrored-path>.md`.
> The mirrored path strips `lib/` and replaces `.ex` with `.md`.
> After writing all cards, report a summary: module name, score, moduledoc quality.

Use `subagent_type: "general-purpose"` and `model: "haiku"`.
Launch up to 5 batches concurrently.

### Q-Step 3: Regenerate Index

Run: `mix colony.health_cards.reindex`

### Q-Step 4: Report Summary

Output:
- Modules reviewed: N
- Average score: N.N/10
- Moduledoc coverage: N rich, N adequate, N weak, N missing
- Modules needing attention (score ≤ 5): list

---

## Error Handling

- **Git errors**: If `git diff` fails (e.g., invalid SHA), report the error and suggest `--full` mode or checking the SHA
- **mix xref errors**: Fall back to grep-based dependency detection; note the fallback in the summary
- **No matching files**: Report "No architecture-relevant files changed" and skip the review
- **API unavailable**: Fall back to `--full` mode and warn the user that state could not be read/written
- **API errors**: Report the error and continue with the review if possible
