---
name: cross-context-integration
description: Tier 3 analysis — cross-context integration review across all Tier 2 coherence reports
---

# Cross-Context Integration Review (Tier 3)

Analyze cross-context integration quality by synthesizing all Tier 2 context coherence reports into a unified dependency graph and evaluating boundary placement, coupling, event flow, and shared abstraction opportunities.

**Execution model**: Single Sonnet-class agent, single sequential run. Runs AFTER all Tier 2 context coherence reports have completed.

## Prerequisites

- All Tier 2 context coherence reports must exist in `.colony/monitor/reports/coherence-*.md`
- Health cards index at `.colony/monitor/health-cards/_index.md` must be current

## Workflow

### Step 1: Collect Tier 2 Reports

Read all context coherence reports from `.colony/monitor/reports/`:

```bash
ls .colony/monitor/reports/coherence-*.md
```

For each report, extract:
- **Context name** (from the report header)
- **Internal modules** (from the modules list)
- **Dependencies** (from the dependency section — both inbound and outbound)
- **Boundary violations** (any findings about leaky abstractions or improper cross-context calls)
- **Health score** (the context-level coherence score)

If fewer than 3 coherence reports exist, abort with: "Insufficient Tier 2 data — need at least 3 context coherence reports to perform integration analysis."

### Step 2: Build Dependency Graph

Construct a directed dependency graph where:
- **Nodes** = contexts (e.g., `colony/execution`, `colony/directives`, `colony/sessions`)
- **Edges** = dependencies between contexts, weighted by the number of cross-context module references

For each context pair (A, B), count:
- How many modules in A reference modules in B (outbound from A)
- How many modules in B reference modules in A (inbound to A)

Use the health cards' dependency information and `mix xref graph` output (if available in Tier 2 reports) to populate edges.

Classify each edge:
- **Strong coupling** (bidirectional, >5 cross-references each direction)
- **Normal dependency** (unidirectional, ≤5 references)
- **Weak coupling** (1-2 references, likely incidental)

### Step 3: Evaluate Integration Dimensions

Assess each dimension below. For each, produce findings with severity levels matching `FINDINGS_FORMAT.md` (blocker/error/warning/info).

#### Dimension 1: Boundary Placement

Evaluate whether context boundaries align with actual dependency patterns.

**Check for**:
- **Misplaced modules**: Modules that have more dependencies outside their context than inside (they may belong elsewhere)
- **Split concepts**: A single domain concept (e.g., "task lifecycle") spread across 3+ contexts without a clear integration point
- **Phantom boundaries**: Contexts that are so tightly coupled they are effectively one context pretending to be two
- **Missing boundaries**: A single context that handles 3+ distinct responsibilities with no internal partitioning

**Evidence**: Cross-reference the dependency graph edges with the Tier 2 coherence scores. Low coherence + high outbound dependencies = likely boundary misplacement.

#### Dimension 2: Coupling Analysis

Identify problematic coupling patterns across the full graph.

**Check for**:
- **High coupling pairs**: Context pairs with >10 bidirectional cross-references. List the top 5 by reference count.
- **Hub contexts**: Contexts with inbound edges from >60% of other contexts (potential god-context)
- **Unexpected couplings**: Dependencies between contexts with no logical domain relationship (e.g., `colony/mailer` depending on `colony/execution`)
- **Circular dependencies**: Cycles in the directed dependency graph (A→B→C→A). Even bidirectional pairs (A↔B) count.
- **Transitive coupling**: Context A depends on B only through C — could A depend on C directly instead?

**Severity guide**:
- Circular dependency involving 3+ contexts: **error**
- Bidirectional strong coupling: **warning**
- Hub context (>60% inbound): **warning**
- Unexpected coupling: **warning** (may be **error** if it crosses CQRS boundaries)

#### Dimension 3: Event Flow Traceability

Evaluate whether the CQRS event flows are traceable across context boundaries.

**Check for**:
- **Event fan-out opacity**: An event emitted in context A that triggers handlers in 3+ other contexts — can a developer trace the full impact?
- **Missing event documentation**: Cross-context event subscriptions not documented in either the source or handler context's health cards
- **Implicit coupling via PubSub**: Contexts coupled through PubSub topic subscriptions rather than explicit module dependencies. These don't show up in `mix xref` but create runtime coupling.
- **Event chain depth**: Sequences where event A triggers handler that emits event B, which triggers handler that emits event C. Chains >3 deep are hard to reason about.

**Evidence sources**: Look for `PubSub.subscribe` patterns in Tier 2 reports, event handler modules, and the CQRS command/event documentation in `CLAUDE.md`.

#### Dimension 4: Shared Abstraction Opportunities

Identify patterns that could benefit from shared abstractions WITHOUT over-engineering.

**Check for**:
- **Duplicate patterns**: 3+ contexts implementing the same pattern (e.g., similar error handling, similar state machines, similar GenServer lifecycle patterns)
- **Common infrastructure needs**: Multiple contexts independently solving the same infrastructure problem (e.g., retry logic, batch processing, rate limiting)
- **Shared type definitions**: Types defined in one context but used by 3+ others — candidate for a shared types module

**Important constraint**: Only recommend shared abstractions when:
1. The pattern is implemented in 3+ contexts (not just 2)
2. The implementations are genuinely similar (not superficially alike)
3. The abstraction would reduce total code AND cognitive load
4. The abstraction has a clear, stable interface

Flag as **info** severity — these are suggestions, not violations.

### Step 4: Produce Integration Report

Write the report to `.colony/monitor/reports/integration-YYYY-MM-DD.md` using the schema below.

If a report for today already exists, append a sequence number: `integration-YYYY-MM-DD-2.md`.

## Integration Report Schema

```markdown
# Cross-Context Integration Report — YYYY-MM-DD

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Contexts analyzed** | N |
| **Tier 2 reports consumed** | N |
| **Total cross-context edges** | N |
| **High coupling pairs** | N |
| **Findings** | N blocker, N error, N warning, N info |

## Dependency Graph Summary

### Context Map

<Table listing each context with: inbound edge count, outbound edge count, coherence score from Tier 2>

| Context | Inbound | Outbound | Coherence | Classification |
|---------|---------|----------|-----------|----------------|
| colony/directives | N | N | N/10 | core / supporting / generic |
| colony/execution | N | N | N/10 | core / supporting / generic |
| ... | ... | ... | ... | ... |

### High Coupling Pairs

<Top 5 most-coupled context pairs, sorted by total bidirectional reference count>

| Rank | Context A | Context B | A→B refs | B→A refs | Total | Assessment |
|------|-----------|-----------|----------|----------|-------|------------|
| 1 | ... | ... | N | N | N | expected / concerning / investigate |
| ... | ... | ... | ... | ... | ... | ... |

### Unexpected Couplings

<Dependencies that don't follow expected domain relationships>

- **<context A> → <context B>**: <description of why this is unexpected and what modules are involved>

### Circular Dependencies

<List any cycles found in the directed graph, or "None detected">

## Findings

### <INTEG-NNN>: <Title>

- **Severity**: blocker|error|warning|info
- **Dimension**: boundary-placement|coupling|event-flow|shared-abstractions
- **Contexts involved**: <list of affected contexts>
- **Evidence**: <specific modules, reference counts, or patterns observed>
- **Issue**: <description of the integration problem>
- **Recommendation**: <specific remediation suggestion>

### <INTEG-NNN>: <Title>

...

## Recommendations

<Prioritized list of 3-5 actionable improvements, ordered by impact>

1. **<recommendation>** — <rationale and affected contexts>
2. ...

## Context Health Summary

<One-line assessment per context from an integration perspective>

| Context | Integration Health | Key Concern |
|---------|--------------------|-------------|
| colony/directives | healthy / needs-attention / at-risk | <brief note or "none"> |
| ... | ... | ... |
```

## Finding ID Convention

Use the prefix `INTEG-` followed by a three-digit number, starting at 001 for each report:
- `INTEG-001`, `INTEG-002`, etc.

Group findings by dimension in the report, but number them sequentially across all dimensions.

## Severity Assignment Guide

| Pattern | Severity |
|---------|----------|
| Circular dependency (3+ contexts) | error |
| CQRS boundary violation across contexts | error |
| Bidirectional strong coupling | warning |
| Hub context (>60% inbound) | warning |
| Unexpected coupling (no domain relationship) | warning |
| Event chain depth >3 | warning |
| Missing event flow documentation | warning |
| Misplaced module (more external than internal deps) | warning |
| Phantom boundary (two contexts = effectively one) | info |
| Shared abstraction opportunity | info |
| Duplicate pattern across contexts | info |

## Report Storage

Reports are stored at: `.colony/monitor/reports/integration-YYYY-MM-DD.md`

This directory also stores Tier 2 coherence reports (`coherence-*.md`). Keep naming conventions distinct to avoid confusion.

## Relationship to Other Tiers

- **Tier 1** (health cards): Per-module quality scores. Consumed indirectly via the health cards index.
- **Tier 2** (context coherence): Per-context internal coherence. Tier 3 consumes these reports directly as primary input.
- **Tier 3** (this): Cross-context integration. Synthesizes Tier 2 reports into a system-wide view.
- **Tier 4** (future): System-level fitness evaluation consuming Tier 3 integration reports.

## Error Handling

- **Missing Tier 2 reports**: If a context listed in the health cards index has no coherence report, note it as a gap in the report but continue analysis with available data.
- **Stale Tier 2 reports**: If a coherence report's date is >7 days old, flag it as potentially stale in the report header.
- **mix xref unavailable**: Fall back to inferring dependencies from module alias/import declarations in health cards' findings sections.
- **Ambiguous context boundaries**: If health cards don't clearly map to contexts, use the "Contexts by Average Score" groupings from the health cards index as the canonical context list.
