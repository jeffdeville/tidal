---
name: mental-models
description: Domain-agnostic mental models for structured reasoning. Apply these frameworks before diving into implementation.
---

# Mental Models for Software Engineering

Apply these reasoning frameworks when analyzing problems, evaluating approaches, or reviewing decisions. Each model is a lens — use multiple lenses for important decisions.

## 1. First Principles Thinking
Strip away assumptions until you reach foundational truths. In software: "What problem are we actually solving?" before "What framework should we use?"

## 2. Inversion
Instead of asking "How do I make this succeed?", ask "What would guarantee failure?" Then avoid those things. In software: list the ways a design could fail before committing to it.

## 3. Second-Order Effects
Every change has consequences beyond the immediate. In software: adding a cache speeds up reads but introduces staleness, invalidation complexity, and memory pressure. Trace at least two levels deep.

## 4. Blast Radius Analysis
Before any change, assess: if this goes wrong, how much breaks? In software: a config change affecting all users has infinite blast radius. A feature flag limiting to 1% has bounded blast radius. Prefer bounded.

## 5. Minimum Effective Dose
The smallest intervention that achieves the goal. In software: don't build a framework when a function suffices. Don't add a service when a module boundary works. Complexity is a one-way door.

## 6. Reversibility Check
Classify decisions as one-way doors (irreversible) or two-way doors (reversible). In software: database migrations are one-way; feature flags are two-way. Apply proportional rigor — agonize over one-way doors, move fast on two-way doors.

## 7. Occam's Razor
The simplest explanation is usually correct. In software: before suspecting a race condition, check for typos. Before adding distributed coordination, try a single process. Complexity should be earned, not assumed.

## 8. Map vs Territory
The model is not the system. In software: the architecture diagram is not the architecture. The test suite is not correctness. Regularly verify your mental model against actual system behavior.

## 9. Premortems
Before starting, imagine the project failed. What went wrong? In software: "We shipped late because..." forces you to identify risks before they materialize. Write down the top 3 failure modes and mitigate them upfront.

## 10. Leverage Points
Small changes in the right place produce outsized effects. In software: fixing a slow database query beats optimizing application code. Choosing the right abstraction boundary beats refactoring internals. Find where effort multiplies.
