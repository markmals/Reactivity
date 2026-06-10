---
name: writing-behaviors
description: Use when writing or reviewing a behavior spec for this reactive library — a contract the graph upholds, pinned by Gherkin (Given/When/Then) scenarios. Trigger when the output is observable system behavior (values, run counts, ordering, errors). NOT for user-facing capabilities framed around a persona — a library has no user, so there is no "As a / I want / So that".
---

# Writing Behaviors

A **behavior** spec states **one contract** the reactive graph upholds — a guarantee a caller can depend on — and pins it with **Gherkin acceptance criteria** that are externally observable. The contract statement is the _what and why_; the scenarios are the _proof obligations_, each tracing to exactly one test.

**Core principle:** this is a library, not an app. There is no user, no persona, no journey. The "actor" is the reactive system itself. Describe what an observer of the graph can **see** — values, how many times something recomputed, the order effects ran, the error that surfaced — never a person's intent.

## When to Use

- Authoring or reviewing a `behavior.<feature>.<capability>` spec.
- Writing Gherkin scenarios that pin a contract to tests.
- Splitting a too-large behavior into focused ones.

**Do NOT use this skill for:** domain models (the primitive's shape/invariants — that's a `domain.*` spec), the error catalog (`error.*`), or anything framed around a human user.

## Behavior Format

```md
---
id: behavior.<feature>.<capability>
kind: behavior
depends-on: [<domain or error ids this contract exercises>]
---

# <Contract title>

<One paragraph stating the guarantee, and briefly why it matters.>

## Scenarios

### Scenario 1: <specific observable behavior>

<!-- id: behavior.<feature>.<capability>.<short-name> -->

- Given <state of the graph>
- When <single stimulus>
- Then <observable outcome>
```

**Rules:**

- The contract statement is a guarantee, in plain declarative prose: _"A value reachable from a source by more than one path recomputes at most once per change."_ No persona, no "I want".
- One contract per file. If the scenarios branch into unrelated guarantees, split the behavior.
- The scenario sub-ID **extends the behavior's ID** with a short name — no `scenario.` prefix (the `.scenario("…")` trait already says it).

## One Behavior = One Contract

A behavior delivers **one guarantee**. Symptoms it is too large:

- More than ~6 scenarios, especially spanning different guarantees (ordering _and_ cleanup _and_ error handling).
- Scenarios that would each make sense under a different one-line contract.

Split along the seam. A cross-cutting guarantee (glitch-freedom spans derived values _and_ effects) gets its own behavior; it is not an invariant of a single `domain.*` model.

## Acceptance Criteria (Gherkin)

### Given = State, Not Actions

`Given` is the scene before the stimulus — the shape of the graph and any prior history. Setup only, no action.

**Don't:** `Given the source is changed` **Do:** `Given a derived value over a source` / `Given an effect that has already re-run once`

### When = Exactly One Stimulus

One change or event per scenario — a single write, a single disposal, a single read. If you need two, you have two scenarios (or fold the earlier ones into `Given` as established history).

**Don't:** `When the effect is registered, then the source changes, then the effect is disposed` **Do:** `When the source changes` (registration and the prior change live in `Given`)

### Then = Observable Outcomes

Only what an observer of the graph can see: a value, a recompute/run **count**, the **order** of effects, a thrown error. Never internal mechanism.

**Don't:** `Then the node is marked dirty` / `Then the dependency edge is removed` **Do:** `Then the derived value recomputes exactly once` / `Then the effect does not run again`

Assert on **counts and ordering**, not just final values — a behavior that yields the right value but recomputes twice is a bug a value-only scenario misses.

### Background

Repeated `Given` steps across every scenario move to a `Background` (≤ 4 lines) that runs before each.

## Forbidden Vocabulary (implementation leak)

Scenario prose describes observable behavior, never the mechanism. Banned in scenarios: `node`, `dirty`, `mark`/`sweep`, `checkDirty`, `subscriber list`, `topological`, `edge`. If you reach for one, restate it as something the caller can observe.

## Worked Example

```md
---
id: behavior.reactive.glitch-free
kind: behavior
depends-on: [domain.derived-state]
---

# Glitch-free updates

A value reachable from a source by more than one path recomputes at most once per change, and never exposes a transient state that mixes old and new inputs.

## Scenarios

### Background

- Given a source feeding derived values that converge on a downstream value
- And a count of how many times the downstream value recomputes

### Scenario 1: A diamond updates the downstream value once

<!-- id: behavior.reactive.glitch-free.diamond -->

- Given a source feeding two derived values that both feed one downstream value
- When the source changes
- Then the downstream value recomputes exactly once
- And it reflects the source's new value consistently
```

One contract. Scenarios an observer can verify by counting recomputations and reading values. No persona, no mechanism.

## Red Flags — Stop and Rewrite

| Red flag in a scenario                             | Why it's wrong                | Fix                                          |
| -------------------------------------------------- | ----------------------------- | -------------------------------------------- |
| `As a / I want / So that`                          | Persona framing; no user here | State the contract as a guarantee            |
| `node`, `dirty`, `mark`, `edge`, `subscriber list` | Implementation mechanism      | Describe what the caller observes            |
| Multiple `When`s in one scenario                   | Compound stimulus             | Split, or move earlier steps into `Given`    |
| `Given the source changes`                         | Action in `Given`             | Move to `When`, or restate as state          |
| `Then` asserts only a value, never a count/order   | Misses over-firing bugs       | Assert recompute/run counts and ordering too |
| One behavior covering ordering + cleanup + errors  | Too-large behavior            | Split, one contract each                     |
