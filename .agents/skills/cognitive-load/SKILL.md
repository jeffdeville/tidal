---
name: cognitive-load
description: The foundational design principle — every decision should minimize the mental effort required for the next person to understand and modify the system.
synced_from_colony: true
sync_pack: universal
sync_source: packs/universal/cognitive-load/SKILL.md
sync_version: d3fefcef
---

# Cognitive Load: The Meta-Principle

Every design decision either spends or saves someone's mental budget. Cognitive load is the currency underlying all other mental models — first principles, Occam's razor, minimum effective dose all work because they reduce it. This skill makes the principle explicit and actionable.

## Two Types (Only One Is Your Problem)

**Intrinsic** — inherent difficulty of the domain. You can't simplify distributed consensus or CQRS event sourcing without losing what makes them useful. Accept this cost.

**Extraneous** — difficulty created by how *you* chose to express the solution. Naming, structure, abstractions, indirection, conventions. This is entirely within your control. **Ruthlessly minimize it.**

## The Modeling Imperative

This principle extends beyond code. When solving *any* complex problem — architecture, task decomposition, system design, even planning — the quality of your mental model determines everything. A correct model makes hard problems tractable. A wrong model makes simple problems impossible. Invest disproportionate effort in getting the model right before building on top of it.

## Practical Heuristics

**Deep modules over shallow modules.** A module should do a lot behind a simple interface. Five functions hiding 10,000 lines of complexity (like Unix I/O) beats fifty thin wrappers that each do one thing and force callers to orchestrate them. If your interface is as complex as the implementation, the abstraction isn't earning its keep.

**Linear flow over nested branching.** Guard clauses and early returns let readers follow a single "happy path." Nested conditionals force them to hold multiple branches in working memory simultaneously. Flatten aggressively.

**Names as compression.** A good variable or function name eliminates the need to read the implementation. `user_has_billing_permission` is instantly understood; `check_auth(user, 3, true)` forces a reader to look up what `3` and `true` mean. Name things so the reader never has to jump to the definition.

**Earn your abstractions.** Every layer of indirection consumes working memory. A little copying is better than a little dependency. Don't extract a pattern until you've seen it three times and confirmed the instances are truly the same concept, not coincidental similarity.

**Self-describing over requires-lookup.** String status codes in API responses beat numeric codes. Enum names beat magic numbers. If someone has to consult a reference table to understand your code, that's extraneous load you created.

**Composition over inheritance.** Inheritance forces readers to mentally traverse a class hierarchy. Composition makes dependencies explicit and visible at the call site.

**Familiarity is not simplicity.** You internalized the project's mental model over months. A new team member hasn't. The litmus test: if a competent developer can't understand a module's purpose and behavior within 40 minutes of pair programming, the module has too much extraneous cognitive load.

## The Design Review Question

Before finalizing any design, ask: **"What extraneous cognitive load am I imposing on the next person who reads this?"** If the answer isn't "almost none," simplify.
