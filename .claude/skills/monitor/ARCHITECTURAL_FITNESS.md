---
name: architectural-fitness
description: Tier 4 analysis — system-level architectural fitness evaluation with remediation pipeline
---

# Architectural Fitness Evaluation (Tier 4)

Evaluate system-level architectural fitness by synthesizing the Tier 3 integration report with structural configuration files. Produce a fitness report with quantified metrics, trend analysis, and a machine-parseable remediation plan.

**Execution model**: Single Opus-class agent, single sequential run. Runs AFTER the Tier 3 integration report has been produced.

## Prerequisites

- Tier 3 integration report must exist in `.colony/monitor/reports/integration-*.md` (most recent)
- Health cards index at `.colony/monitor/health-cards/_index.md` must be current

## Inputs

### Primary Inputs

| Source | Path | Purpose |
|--------|------|---------|
| Tier 3 integration report | `.colony/monitor/reports/integration-*.md` (latest) | Cross-context coupling, boundary, and event flow findings |
| Health cards index | `.colony/monitor/health-cards/_index.md` | Module-level scores, moduledoc coverage |

### Structural Inputs

| Source | Path | Purpose |
|--------|------|---------|
| Application supervisor tree | `lib/colony/application.ex` | Process architecture, supervision strategy |
| Runtime config | `config/runtime.exs` | Environment-dependent configuration |
| Architecture overview | `.colony/architecture/README.md` | Documented architectural intent |
| Three-layer model | `.colony/architecture/three-layer-model.md` | Directive → Task → Execution layer separation |
| CQRS boundaries | `.colony/architecture/cqrs-boundaries.md` | Domain vs operational state boundary |
| Previous fitness report | `.colony/monitor/reports/fitness-*.md` (latest, if exists) | Trend comparison baseline |

### Optional Inputs (read only if referenced in findings)

- `.colony/constraints/architecture.md` — Architectural constraint definitions
- `.colony/architecture/state-machines-and-flows.md` — State machine documentation
- `CLAUDE.md` — Project-level coding and architectural conventions

## Workflow

### Step 1: Collect Inputs

1. **Find the latest Tier 3 integration report**:
   ```bash
   ls -t .colony/monitor/reports/integration-*.md | head -1
   ```
   If no integration report exists, abort with: "No Tier 3 integration report found. Run Tier 3 cross-context integration review first."

2. **Read the integration report** and extract:
   - Dependency graph summary (context map, coupling pairs)
   - All findings (INTEG-NNN) with severity and dimension
   - Recommendations
   - Context health summary

3. **Read the health cards index** and extract:
   - Total module count, average score
   - Moduledoc coverage breakdown (rich/adequate/weak/missing)
   - Modules with scores ≤ 7 (attention needed)

4. **Read structural inputs** listed above. For each, note:
   - Whether the file exists and is current
   - Key architectural patterns and decisions documented

5. **Find the previous fitness report** (if any):
   ```bash
   ls -t .colony/monitor/reports/fitness-*.md | head -1
   ```
   If found, read it for trend comparison in Step 3.

### Step 2: Evaluate Fitness Dimensions

Assess the system across four dimensions. Each produces quantified metrics and qualitative findings.

#### Dimension 1: Evolvability Metrics

Compute five metrics that indicate how easy the system is to change. Each metric is scored 1-10.

##### 1a. Change Amplification

**Question**: When a developer changes one concept, how many files must they touch?

**Method**:
- From the Tier 3 integration report, identify the top 5 highest-coupling context pairs
- For each pair, estimate the typical change set size: if a developer modifies one module in context A, how many modules in context B would likely need updating?
- Score: 10 = changes are well-contained (1-2 files), 1 = changes ripple across 10+ files

**Evidence**: Use coupling pair reference counts from the Tier 3 report. High bidirectional coupling with shared data structures = high amplification.

##### 1b. Cognitive Load

**Question**: How much must a developer hold in their head to work in a given context?

**Method**:
- From the health cards index, compute the average moduledoc quality across all contexts
- From the Tier 3 report, count contexts with "at-risk" integration health
- From the Tier 2 reports (referenced in Tier 3), note any contexts with missing abstractions findings
- Score: 10 = excellent docs, clear boundaries, obvious patterns; 1 = poor docs, tangled dependencies, unclear patterns

**Evidence**: Moduledoc coverage (rich vs missing), context coherence scores, boundary placement findings.

##### 1c. Coupling Ratio

**Question**: What fraction of cross-context dependencies are "strong" (bidirectional, >5 references)?

**Method**:
- From the Tier 3 report, count total cross-context edges and strong coupling edges
- Ratio = strong_coupling_edges / total_edges
- Score: 10 = ratio < 0.05 (very few strong couplings); 1 = ratio > 0.50 (majority are strong)

**Scoring scale**:
| Ratio | Score |
|-------|-------|
| < 0.05 | 10 |
| 0.05 - 0.10 | 9 |
| 0.10 - 0.15 | 8 |
| 0.15 - 0.20 | 7 |
| 0.20 - 0.30 | 6 |
| 0.30 - 0.40 | 5 |
| 0.40 - 0.50 | 4 |
| > 0.50 | 3 or below |

##### 1d. Struct Coherence

**Question**: Are data structures well-encapsulated within their owning context?

**Method**:
- From the Tier 3 report, identify any "misplaced module" or "split concept" findings
- From health cards, count struct/schema modules and check if they are used primarily within their own context
- Score: 10 = all structs owned and consumed within their context; 1 = structs widely shared with no clear ownership

**Evidence**: Tier 3 boundary placement findings, shared type definition findings.

##### 1e. Moduledoc Coverage

**Question**: What percentage of modules have adequate or better documentation?

**Method**:
- From the health cards index, compute: (rich + adequate) / total_cards × 100
- Score: 10 = ≥ 95% coverage; 1 = < 50% coverage

**Scoring scale**:
| Coverage | Score |
|----------|-------|
| ≥ 95% | 10 |
| 90-94% | 9 |
| 85-89% | 8 |
| 80-84% | 7 |
| 70-79% | 6 |
| 60-69% | 5 |
| 50-59% | 4 |
| < 50% | 3 or below |

##### Evolvability Summary

Compute the **evolvability score** as the weighted average:
- Change Amplification: 25%
- Cognitive Load: 25%
- Coupling Ratio: 20%
- Struct Coherence: 15%
- Moduledoc Coverage: 15%

#### Dimension 2: Trend Analysis

Compare current metrics against the previous fitness report to identify trajectory.

**If no previous report exists**: Skip trend analysis. Note "Baseline report — no trend data available" and proceed.

**If a previous report exists**, for each evolvability metric:
1. Compare current score to previous score
2. Classify the trend: **improving** (≥ +0.5), **stable** (within ±0.5), **degrading** (≤ -0.5)
3. Note the delta

Also compare:
- Total module count (growth rate)
- Number of Tier 3 findings by severity (are we fixing or accumulating?)
- Number of "at-risk" contexts (improving or growing?)

Produce a trend summary table:

```markdown
| Metric | Previous | Current | Delta | Trend |
|--------|----------|---------|-------|-------|
| Evolvability score | N.N | N.N | ±N.N | improving/stable/degrading |
| Change amplification | N | N | ±N | ... |
| Cognitive load | N | N | ±N | ... |
| Coupling ratio | N | N | ±N | ... |
| Struct coherence | N | N | ±N | ... |
| Moduledoc coverage | N | N | ±N | ... |
| Module count | N | N | ±N | — |
| Tier 3 findings (error+) | N | N | ±N | ... |
| At-risk contexts | N | N | ±N | ... |
```

**Trend alerts**: If any evolvability metric has degraded for 2+ consecutive reports, flag it as a finding with severity "High" — this indicates sustained architectural erosion.

#### Dimension 3: Architectural Alignment

Evaluate whether the running system matches documented architectural intent.

**Check 1: Three-Layer Separation**
- Does the codebase respect Directive → Task → Execution layer boundaries?
- Are there modules that blur layer responsibilities?
- Evidence: Tier 3 coupling analysis, CQRS boundary doc alignment

**Check 2: CQRS Boundary Integrity**
- Are domain mutations routed through CQRS commands?
- Are operational mutations handled by the Reconciler?
- Evidence: Tier 3 integration findings, any CQRS violation findings from Tier 2

**Check 3: Process Isolation**
- Does the supervision tree match the multi-project architecture?
- Are Arena patterns consistently applied?
- Evidence: `application.ex` structure, Tier 2 pattern consistency findings

**Check 4: Configuration Hygiene**
- Are environment-specific values properly externalized?
- Are there hardcoded values that should be configurable?
- Evidence: `config/runtime.exs`, any hardcoded port/path findings from Tier 1/2

For each check, produce a pass/fail/partial assessment with evidence.

#### Dimension 4: Adversarial Challenge

Adopt a skeptical perspective. Challenge the architecture by asking:

1. **Single point of failure**: If the Reconciler process crashes, what is the blast radius? Is there a single GenServer whose failure cascades across all projects?

2. **Scaling bottleneck**: Which context would break first under 10x load? Where are the serialization points (single-process bottlenecks)?

3. **Knowledge concentration**: Are there modules or contexts that only one person (or no one) fully understands? Evidence: low moduledoc quality + high complexity (many dependencies).

4. **Assumption rot**: What implicit assumptions does the architecture make that may no longer hold? Examples: "all tasks complete in under 1 hour", "event store never needs compaction", "worktrees are always on local disk".

5. **Migration risk**: If Colony needed to change a core pattern (e.g., swap event store, change CQRS library), how many modules would be affected? Evidence: coupling to Commanded-specific APIs.

For each challenge, produce a brief assessment (2-3 sentences) with a risk rating: **low**, **medium**, **high**.

### Step 3: Compile Remediation Findings

Synthesize findings from all four dimensions into a prioritized remediation plan. This section is **machine-parseable** — the remediation pipeline reads this format to generate Colony directives.

#### Finding Classification Rules

**Critical**: Actively degrading system quality or blocking development. Requires immediate action.
- Sustained metric degradation (2+ reports)
- CQRS boundary violations
- Missing process isolation
- Circular dependencies involving core contexts

**High**: Significant architectural concern that will worsen if unaddressed. Fix within the current cycle.
- High coupling pairs with no documented justification
- Layer boundary violations
- Single points of failure with no mitigation
- Scaling bottlenecks in core paths

**Medium**: Pattern inconsistency or debt that slows comprehension. Fix when working in the affected area. Medium findings should be **aggregated by context and category** when 3+ related findings exist.
- Documentation gaps in important contexts
- Minor pattern inconsistencies
- Missing abstractions identified in Tier 2/3
- Configuration hygiene issues

**Low**: Aspirational improvements and observations. Address opportunistically.
- Shared abstraction opportunities
- Minor moduledoc quality improvements
- Cosmetic pattern alignment

#### Aggregation Rule for Medium Findings

When 3 or more Medium findings share the same context AND category, aggregate them into a single finding:

```markdown
### [MEDIUM] FIT-NNN: <context> — <category> improvements (N items)
- **Category**: documentation_improvement | tech_debt_cleanup | structural_refactoring
- **Modules**: <combined list>
- **Description**: N related <category> issues in the <context> context: (1) <brief>, (2) <brief>, (3) <brief>
- **Recommendation**: <unified recommendation addressing all items>
- **Estimated effort**: <S/M/L based on combined work>
```

### Step 4: Produce Fitness Report

Write the report to `.colony/monitor/reports/fitness-YYYY-MM-DD.md` using the schema below.

If a report for today already exists, append a sequence number: `fitness-YYYY-MM-DD-2.md`.

Target length: ~4K tokens (roughly 3000-5000 words).

## Fitness Report Schema

```markdown
# Architectural Fitness Report — YYYY-MM-DD

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Tier 3 report** | integration-YYYY-MM-DD.md |
| **Previous fitness report** | fitness-YYYY-MM-DD.md or "none (baseline)" |
| **Modules analyzed** | N |
| **Contexts analyzed** | N |
| **Evolvability score** | N.N/10 |
| **Findings** | N critical, N high, N medium, N low |

## Evolvability Metrics

| Metric | Score | Evidence |
|--------|-------|----------|
| Change amplification | N/10 | <1-line evidence summary> |
| Cognitive load | N/10 | <1-line evidence summary> |
| Coupling ratio | N/10 | <1-line evidence summary> |
| Struct coherence | N/10 | <1-line evidence summary> |
| Moduledoc coverage | N/10 | <1-line evidence summary> |
| **Evolvability (weighted)** | **N.N/10** | |

## Trend Analysis

<If no previous report: "Baseline report — no trend data available.">

<If previous report exists, include the trend summary table from Dimension 2>

### Trend Alerts

<List any metrics degrading for 2+ consecutive reports, or "None">

## Architectural Alignment

### Three-Layer Separation

**Assessment**: pass | partial | fail

<Evidence and details>

### CQRS Boundary Integrity

**Assessment**: pass | partial | fail

<Evidence and details>

### Process Isolation

**Assessment**: pass | partial | fail

<Evidence and details>

### Configuration Hygiene

**Assessment**: pass | partial | fail

<Evidence and details>

## Adversarial Challenges

| Challenge | Risk | Assessment |
|-----------|------|------------|
| Single point of failure | low/medium/high | <2-3 sentence assessment> |
| Scaling bottleneck | low/medium/high | <2-3 sentence assessment> |
| Knowledge concentration | low/medium/high | <2-3 sentence assessment> |
| Assumption rot | low/medium/high | <2-3 sentence assessment> |
| Migration risk | low/medium/high | <2-3 sentence assessment> |

## Remediation Findings

### [CRITICAL] FIT-NNN: <title>
- **Category**: structural_refactoring | documentation_improvement | tech_debt_cleanup
- **Modules**: <comma-separated list of affected module paths>
- **Description**: <what's wrong — specific and evidence-based>
- **Recommendation**: <what to do — actionable and scoped>
- **Estimated effort**: S | M | L

### [HIGH] FIT-NNN: <title>
- **Category**: structural_refactoring | documentation_improvement | tech_debt_cleanup
- **Modules**: <comma-separated list>
- **Description**: <what's wrong>
- **Recommendation**: <what to do>
- **Estimated effort**: S | M | L

### [MEDIUM] FIT-NNN: <title> (N items)
- **Category**: structural_refactoring | documentation_improvement | tech_debt_cleanup
- **Modules**: <combined list>
- **Description**: <aggregated description when 3+ related findings>
- **Recommendation**: <unified recommendation>
- **Estimated effort**: S | M | L

### [LOW] FIT-NNN: <title>
- **Category**: structural_refactoring | documentation_improvement | tech_debt_cleanup
- **Modules**: <list>
- **Description**: <what's wrong>
- **Recommendation**: <what to do>
- **Estimated effort**: S | M | L

## Recommendations

<Prioritized list of 3-5 actionable improvements, ordered by impact>

1. **<recommendation>** — <rationale and expected benefit>
2. ...

## Context Fitness Summary

| Context | Fitness | Evolvability Concern | Integration Concern | Key Action |
|---------|---------|---------------------|---------------------|------------|
| colony/directives | healthy / needs-attention / at-risk | <brief or "none"> | <brief or "none"> | <action or "none"> |
| ... | ... | ... | ... | ... |
```

## Finding ID Convention

Use the prefix `FIT-` followed by a three-digit number, starting at 001 for each report:
- `FIT-001`, `FIT-002`, etc.

Number findings sequentially across all severity levels. Group by severity in the report (Critical first, then High, Medium, Low).

## Remediation Finding Format — Machine-Parseable Specification

The Remediation Findings section is designed to be parsed by the remediation pipeline (a downstream task) that converts findings into Colony directives. The format is strict:

### Required Fields

Every finding MUST contain exactly these fields in this order:

| Field | Format | Values |
|-------|--------|--------|
| **Severity** | `### [LEVEL]` in the heading | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| **Finding ID** | `FIT-NNN` in the heading | Three-digit, zero-padded, sequential |
| **Title** | Free text after the finding ID | Concise description (< 80 chars) |
| **Category** | `- **Category**: <value>` | `structural_refactoring`, `documentation_improvement`, `tech_debt_cleanup` |
| **Modules** | `- **Modules**: <value>` | Comma-separated `lib/colony/...` paths |
| **Description** | `- **Description**: <value>` | What is wrong (1-3 sentences) |
| **Recommendation** | `- **Recommendation**: <value>` | What to do (1-3 sentences, actionable) |
| **Estimated effort** | `- **Estimated effort**: <value>` | `S` (≤2 story points), `M` (3-4 points), `L` (5-8 points, consider breakdown) |

### Parsing Contract

The remediation pipeline will:
1. Split the report on `## Remediation Findings` to find the section
2. Parse each `### [LEVEL] FIT-NNN: <title>` as a finding header
3. Extract fields by matching `- **<Field>**: <value>` lines
4. Use **Category** to route findings: `structural_refactoring` → backend implementation tasks, `documentation_improvement` → documentation tasks, `tech_debt_cleanup` → refactoring tasks
5. Use **Estimated effort** to decide whether to create a single task or request decomposition (L → request breakdown)
6. Use **Modules** to scope worktree isolation and set task descriptions

### Category Definitions

| Category | Description | Pipeline Routing |
|----------|-------------|-----------------|
| `structural_refactoring` | Module moves, boundary changes, API redesign, dependency restructuring | Backend agent, implementation task |
| `documentation_improvement` | Missing/stale moduledocs, CLAUDE.md gaps, architecture doc updates | Documentation task |
| `tech_debt_cleanup` | Pattern inconsistencies, dead code, test gaps, configuration issues | Backend agent, refactoring task |

## Effort Estimation Guide

| Size | Story Points | Typical Scope |
|------|-------------|---------------|
| **S** | 1-2 | Single file change, doc update, simple rename |
| **M** | 3-4 | Multi-file change within one context, new module, test additions |
| **L** | 5-8 | Cross-context refactoring, new abstraction, significant restructuring. Pipeline will request breakdown. |

## Severity Assignment Guide

| Pattern | Severity |
|---------|----------|
| CQRS boundary violation (domain mutation via Repo) | CRITICAL |
| Sustained metric degradation (2+ reports) | CRITICAL |
| Missing process isolation in production paths | CRITICAL |
| Circular dependency involving 3+ core contexts | CRITICAL |
| High coupling pair with no documented justification | HIGH |
| Three-layer boundary violation | HIGH |
| Single point of failure with no mitigation strategy | HIGH |
| Scaling bottleneck in core execution path | HIGH |
| Documentation gap in context with score ≤ 7 | MEDIUM |
| Pattern inconsistency within a context | MEDIUM |
| Missing shared abstraction (3+ contexts affected) | MEDIUM |
| Configuration value that should be externalized | MEDIUM |
| Minor moduledoc quality improvement | LOW |
| Aspirational shared abstraction opportunity | LOW |
| Cosmetic pattern alignment | LOW |

## Report Storage

Reports are stored at: `.colony/monitor/reports/fitness-YYYY-MM-DD.md`

This directory also stores Tier 2 coherence reports (`coherence-*.md`) and Tier 3 integration reports (`integration-*.md`). Keep naming conventions distinct.

## Relationship to Other Tiers

- **Tier 1** (health cards): Per-module quality scores. Consumed via the health cards index.
- **Tier 2** (context coherence): Per-context internal coherence. Referenced indirectly through Tier 3.
- **Tier 3** (cross-context integration): Cross-context dependency and coupling analysis. Primary input to Tier 4.
- **Tier 4** (this): System-level fitness evaluation. Produces the remediation plan consumed by the remediation pipeline.

## Integration with Monitor Skill

The architectural fitness evaluation is invoked as part of the monitor workflow:

```
--type fitness                           # Run Tier 4 fitness evaluation
--tier 4                                 # Alias for --type fitness
```

Results are stored in `.colony/monitor/reports/` following the naming convention above.

## Error Handling

- **Missing Tier 3 report**: Abort with clear message. Tier 4 cannot run without Tier 3 input.
- **Missing structural inputs**: Note the missing file in the report header as a caveat, proceed with available data. Score affected metrics conservatively (assume worst case for missing evidence).
- **Missing previous fitness report**: Skip trend analysis entirely. Mark as baseline report.
- **Stale Tier 3 report**: If the integration report's date is >7 days old, flag it as potentially stale in the report header. Proceed with available data but note reduced confidence.
- **Ambiguous scoring**: When evidence is insufficient to score a metric precisely, provide a range (e.g., "6-7/10") and explain what additional data would narrow it.
