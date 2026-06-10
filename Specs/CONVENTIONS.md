---
id: conventions
kind: conventions
---

# Spec Conventions

This document defines the structure of specs in this repo. Every spec, every reverse pointer, every drift check assumes these rules. If you change anything here, audit every existing spec and pointer for consistency.

> **TL;DR:** Markdown files with YAML frontmatter, stable dotted IDs, one logical thing per file, and `// SPEC: <id>` comments in the Swift code that implements them.

## Why specs at all

A reactive system has subtle behavioral contracts — propagation order, glitch-freedom, cleanup timing, equality-gating, ownership — that are easy to get plausibly-but-wrongly right. Specs pin those contracts down in prose and Gherkin so the Swift implementation has something authoritative to satisfy and the tests have something concrete to prove. The spec is the contract; the code in `Sources/` is a regeneration target.

Specs describe **what** must hold. Tests prove it. The implementation satisfies it. None of those three is the source of truth on its own.

## File and directory layout

```
Specs/                          ← cross-cutting (used by ≥ 2 features or library-wide)
├── ARCHITECTURE.md             ← singular per-product
├── CONVENTIONS.md              ← this file
├── STACK.md                    ← the toolchain catalog
├── models/<id>.md              ← cross-cutting domain models (the reactive primitives)
└── errors/<id>.md              ← cross-cutting error catalog entries

Features/<NNNN>-<slug>/         ← feature-scoped (only this feature uses it)
├── NARRATIVE.md                ← singular per feature
├── README.md                   ← singular per feature; describes the folder
├── behaviors/<id>.md           ← one behavioral contract per file (Gherkin scenarios)
├── models/<id>.md              ← one domain model per file
└── errors/<id>.md              ← one error catalog entry per file
```

### One logical thing per file

If a kind has multiple instances in a feature (multiple behaviors, multiple errors, multiple models), it gets a **directory** of `<id>.md` files. If a kind has exactly one instance per feature (the narrative), it stays a **file**.

The directory name is the kebab-case equivalent of the kind name (`behaviors/`, not `Behaviors/` or `behaviour/`).

### Cross-cutting vs feature-scoped

A spec lives in `Features/<n>/` until a _second_ feature depends on it. At that point it gets **promoted**: the file moves to `Specs/<kind>/<id>.md`, but its **ID does not change**. Reverse pointers in code stay valid through the move.

The only specs that start cross-cutting are `ARCHITECTURE.md`, `STACK.md`, and this file.

## Frontmatter schema

Every spec file (in `Specs/<kind>/` or `Features/<n>/<kind>/`, plus the singular files like `NARRATIVE.md`) starts with YAML frontmatter:

```yaml
---
id: <stable-dotted-id> # required, must match filename stem
kind: <one of the kinds below> # required
depends-on: [<id>, <id>, ...] # optional; specs this one references
status: draft | accepted # optional; default = accepted
---
```

The top-level singular files (`ARCHITECTURE.md`, `NARRATIVE.md` per feature, `CONVENTIONS.md`) use a special form:

```yaml
---
id: architecture # or conventions, narrative.<feature-slug>
kind: architecture # the kind matches the file's role
---
```

`depends-on` is a flat list of IDs. It is not transitive, not enforced by tooling yet, and exists primarily so a human or agent can grep for "what depends on `domain.signal`".

## Kind taxonomy

Kinds are the closed set of allowed `kind:` values, paired with their directory and ID prefix.

| Kind           | Directory       | ID prefix                         | One per file? | Notes                                                                                                          |
| -------------- | --------------- | --------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------- |
| `narrative`    | (singular file) | `narrative.<feature-slug>`        | yes           | One per feature.                                                                                               |
| `behavior`     | `behaviors/`    | `behavior.<feature>.<capability>` | yes           | A behavioral contract over the reactive graph, pinned by Gherkin scenarios. Authored with `writing-behaviors`. |
| `domain`       | `models/`       | `domain.<entity>`                 | yes           | A reactive primitive or value type: its shape, semantics, and invariants.                                      |
| `error`        | `errors/`       | `error.<domain>.<kind>`           | yes           | An observable failure mode (e.g. a dependency cycle) + how the library surfaces it.                            |
| `architecture` | (singular file) | `architecture`                    | yes           | Cross-cutting; one per product.                                                                                |
| `conventions`  | (this file)     | `conventions`                     | yes           | Cross-cutting; one per product.                                                                                |

A kind can grow over time (e.g. a `benchmark` kind for performance contracts), but adding a kind is a deliberate change to this document, not an ad-hoc choice. See "Adding a new spec kind".

> This is a non-UI library, so there are no `view-model`, `flow`, `story`, or `use-case` kinds — those frame software around a user persona, which a reactive graph has no use for. The behavioral target is `domain` (the primitives and their invariants) plus `behavior` (the contracts the graph upholds, pinned by Gherkin scenarios).

## Stable IDs

IDs are dotted, lowercase, hierarchical, and stable. The first segment is the kind prefix; the rest narrow to a specific instance.

**Good:** `domain.signal`, `domain.memo`, `behavior.reactive.glitch-free`, `error.reactive.cycle`

**Bad:** `Signal`, `reactive/derivation`, `domain-signal`, `model.signal` (use `domain.`)

### Stability rules

- IDs are immutable once an implementation references them. Renaming requires a deliberate migration: update the spec ID, every `// SPEC:` reference, and every test tag in one commit.
- IDs do not change when a spec is promoted from `Features/` to `Specs/`.
- IDs describe abstract behavior, not a specific Swift type name. If you rename `Signal` to `Source` in code, the spec ID `domain.signal` can stay (or migrate deliberately) — the ID tracks the concept.

### Filename = ID stem

Filename matches the trailing segment of the ID, with dots → hyphens at the kind boundary and preserved within the stem:

- `domain.signal` → `models/signal.md`
- `behavior.reactive.glitch-free` → `behaviors/reactive.glitch-free.md`
- `error.reactive.cycle` → `errors/reactive.cycle.md`

Dots are legal in macOS/Linux filenames and survive grep, git, and most editors. Keep them.

## Reverse pointers

Every type, function, or extension that realizes a spec carries the spec ID in a comment.

```swift
// SPEC: domain.state
@propertyWrapper
public struct State<Wrapped>: WritableSignal, Sendable { /* ... */ }
```

```swift
// SPEC: domain.derived-state
@propertyWrapper
public struct DerivedState<Wrapped>: ReadableSignal, Sendable { /* ... */ }
```

### Granularity

- One reverse pointer per spec realization, attached to the smallest unit that fully realizes the spec (usually a type or top-level function, sometimes a whole file/module).
- Multiple files may reference the same ID if the implementation is split across them.
- Do not annotate every helper — only the unit that fulfills the contract.

### Tests carry the same IDs

Every behavioral test declares the spec ID it verifies and the scenario sub-ID it pins with **custom test traits**, and reads like a sentence via a **raw-identifier** name. The dotted IDs are carried verbatim — not stuffed into a display string — so drift/coverage tooling greps `.spec("…")` and `.scenario("…")` directly. The trait definitions live in `Tests/ReactiveGraphTests/SpecTraits.swift`.

```swift
import Testing

@testable import ReactiveGraph

@Suite(.spec("behavior.reactive.derivation"))
struct Derivation {

    @Test(.scenario("behavior.reactive.derivation.recompute-once"))
    func `a derived value recomputes once when its source changes`() {
        withReactiveScope {
            var runs = 0
            @State var source = 0
            @DerivedState var doubled = { runs += 1; return source * 2 }()

            _ = doubled            // initial computation
            #expect(runs == 1)
            source = 5
            #expect(doubled == 10)
            #expect(runs == 2)     // recomputed once, not twice
        }
    }
}
```

- `.spec("<id>")` on the `@Suite` binds the whole suite to one spec; `.scenario("<id>")` on each `@Test` pins the scenario. Both carry the dotted ID verbatim and greppable.
- The test name is a **raw identifier** ([SE-0451](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0451-escaped-identifiers.md), Swift 6.2+) — the sentence _is_ the symbol, so it shows verbatim in failure output. No `[scenario.id]` display-string prefix needed.
- **Why traits, not tags:** a `@Tag` must be a pre-declared static member and can't contain dots, which forces a lossy alias plus a registry that drifts from the canonical ID. A trait takes the exact dotted ID as an argument. Tags stay available for orthogonal categories (`.slow`, `.regression`).
- Assert on **run counts and ordering**, not just values — a behavior that yields the right value but recomputes twice is a bug a value-only test misses.
- Use `#expect` / `#require`, not XCTest's `XCTAssert*`.

Each test must trace to a specific scenario, not just a behavior — that's what the `.scenario(...)` trait pins (Gherkin scenarios in behavior files have their own sub-IDs; see "Behaviors and scenarios").

## Behaviors and scenarios

Behaviors follow the `writing-behaviors` skill. A behavior file states one **contract** the reactive graph upholds, then pins it with Gherkin scenarios. There is no user persona — this is a library, so the "actor" is the reactive system, not a person. Each behavior file contains:

1. Frontmatter with `id: behavior.<feature>.<capability>`
2. A one-paragraph statement of the contract the behavior guarantees
3. A `## Scenarios` section with Gherkin scenarios

Each scenario has a stable sub-ID that **extends the behavior's ID** with a short name. The `scenario.` word is intentionally omitted — the `.scenario("…")` trait already says it, so repeating it in the ID is redundant:

```md
## Scenario 1: A diamond updates the downstream value once

<!-- id: behavior.reactive.glitch-free.diamond -->

- Given a source feeding two derived values that both feed one downstream value
- When the source changes
- Then the downstream value recomputes exactly once
```

Sub-IDs follow the pattern `behavior.<feature>.<capability>.<short-name>` — the parent behavior ID plus a short scenario name. Tests reference them via the `.scenario("…")` trait described above.

## Marking unspecified or ambiguous content

When authoring a spec, do **not** silently guess at unspecified details. Mark them inline with a `[NEEDS CLARIFICATION: <question>]` token:

```md
- Given a signal observed by two effects
- When the signal changes within a batch
- Then the effects run [NEEDS CLARIFICATION: in registration order, or is order unspecified?]
```

Why: an LLM that fills in plausible-but-unverified details produces specs that _look_ complete but contain hidden assumptions. A spec sprinkled with `[NEEDS CLARIFICATION]` markers is more honest, easier to review, and forces a deliberate resolution step before implementation.

**Resolution:** the `/sdd-clarify <feature-or-spec-id>` slash command scans for these markers, surfaces the highest-priority questions to the user, and edits the answers back into the spec. A spec cannot be considered ready for `/sdd-apply` while `[NEEDS CLARIFICATION]` markers remain.

**When to use:**

- The user prompt didn't specify a behavior, ordering guarantee, or value.
- Two interpretations are equally plausible and you can't pick without input.
- A non-functional contract (re-entrancy, thread-safety, complexity bound) is implied but not stated.

**When NOT to use:**

- For known-unknowns about implementation details (those belong in `// SPEC: <id> (deviates: <reason>)` comments, not in the spec).
- For "we'll figure this out later" placeholders for features outside the current scope (just don't write the spec yet).

## Deviation marker

When the implementation must differ from the spec — a performance-driven shortcut, a Swift-idiom constraint, a deliberate semantic choice the spec didn't anticipate — annotate it on the reverse pointer:

```swift
// SPEC: domain.memo (deviates: caches the last value across owners for O(1) reads; spec implies recompute)
public struct Memo<Value> { /* ... */ }
```

```swift
// SPEC: manual
// Internal graph bookkeeping — no behavioral contract of its own.
final class ReactiveNode { /* ... */ }
```

`(deviates: <reason>)` keeps the pointer live so drift detection still flags spec changes; you then decide whether the deviation still makes sense (and whether the spec should absorb it via `/sdd-reconcile`). `// SPEC: manual` opts out entirely, for genuinely internal plumbing with no contract to converge on.

## Drift detection

A spec and its implementation are **in sync** when:

1. The spec has at least one reverse pointer in `Sources/` (or is intentionally not yet implemented).
2. The spec's mtime ≤ the most recent mtime of files containing reverse pointers to its ID.
3. Tests tagged with the spec's ID exist in `Tests/` and pass.

Drift is detected by `/sdd-drift` (scaffolded; implementation deferred). The command outputs the IDs that fail any of the above.

All three invariants are mechanically checkable — reverse-pointer presence, an mtime comparison, a tagged-test lookup — yet they are still enforced by an agent running `rg` by hand. They are the canonical target for promotion to a real `/sdd-drift` implementation: cheap and deterministic, exactly the kind of rule that should live in a mechanism rather than in prose an agent must remember. See `.claude/rules/enforcement-hierarchy.md`.

## Reconciliation

When the implementation diverges from the spec — usually because the code was edited directly to fix a bug or change behavior — the spec must be updated to match. This is what `/sdd-reconcile` does:

1. Read the current implementation and tests.
2. Diff the observed behavior against the spec.
3. Propose updates to the spec (and to any tests that encode the old behavior).
4. The human reviews each diff before it lands.

Reconciliation is **not automatic**. The agent proposes; a human approves. Decide first whether the divergence is a bug to fix (the spec was right) or a behavior change to absorb (the spec was wrong) — only the second calls for reconciliation.

## Adding a new feature

1. Pick the next number: `Features/<NNNN>-<slug>/`. Slug is kebab-case.
2. Copy `.claude/templates/feature/` into the new feature directory.
3. Author `NARRATIVE.md` first (use the `brainstorming-feature` skill).
4. Author behaviors from the narrative — each one a contract the graph upholds, pinned by Gherkin scenarios (use the `writing-behaviors` skill).
5. Derive models and errors as needed. Not every feature uses every kind.
6. Implement against the spec with `/sdd-apply <spec-id>` — write the failing Swift Testing scenarios first, then the minimum code to pass.

## Adding a new spec kind

1. Add a row to the kind taxonomy table above.
2. Decide ID prefix and directory name.
3. Add a template file at `.claude/templates/feature/<dir>/<KIND>.md`.
4. Update `.claude/templates/feature/README.md`.
5. Update the file/directory layout diagram at the top of this document.
6. Commit the convention change before authoring any specs of the new kind.

## What is NOT a spec

These are reference material an agent may read, but not the spec layer. Do not put them under `Specs/` or in a feature folder's spec subdirectories.

- Prototype code, benchmarks-as-scratch, or sandbox explorations.
- Meeting notes, RFCs, decision logs (use a `docs/` directory if you need one).
- Internal implementation details with no observable contract (graph bookkeeping, allocation strategy) — these are code, marked `// SPEC: manual` where useful.
- Known rough edges the spec deliberately doesn't cover (a not-yet-fixed quirk, a Swift-version-specific wrinkle) — these go in `DEFECTS.md`, not in specs. See the `triaging-defects` skill for the classifier that decides which side of the line an observation falls on.

If you find yourself writing implementation details into a spec, stop and ask: **is this an observable behavioral contract a caller can depend on, or an internal choice the library is free to change?** If the latter, it is implementation, not spec.
