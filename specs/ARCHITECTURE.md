---
id: architecture
kind: architecture
---

# Architecture

> Orientation, not exhaustive reference. The behavioral contracts live in the `domain.*` and `story.*` specs; this document explains how the library is layered and how specs map onto Swift.

## Product overview

`ReactiveGraph` is a fine-grained reactive system for Swift, in the lineage of [Solid.js](https://www.solidjs.com) and Leptos' [`reactive_graph`](https://github.com/leptos-rs/leptos/tree/main/reactive_graph) crate. It provides reactive **primitives** — signals (mutable reactive values), memos (cached derived values), and effects (side effects that re-run when their dependencies change) — wired into a dependency **graph** that propagates changes precisely: only the computations that actually read a changed value re-run, and they re-run the minimum number of times (glitch-free, equality-gated).

The audience is Swift developers building reactive state without a UI framework dictating the model. The library is dependency-light, platform-neutral within the Apple ecosystem (macOS 15+, iOS 18+), and has **no UI, no networking, and no persistence** of its own.

## The central boundary: pure graph vs. effectful edges

The most consequential structural decision in this library is the line between the **pure reactive graph** and the **effectful work it schedules**.

```
┌─────────────────────────────────────────────┐
│  User closures (effects, memo bodies)        │  arbitrary side effects — the effectful edge
├─────────────────────────────────────────────┤
│  Scheduler / propagation                     │  spec: story.reactive.* (ordering, batching, glitch-freedom)
├─────────────────────────────────────────────┤
│  Reactive graph (nodes, edges, dirtiness)    │  spec: domain.* — pure data structure + invariants
├─────────────────────────────────────────────┤
│  Ownership / cleanup (owner tree)            │  spec: domain.owner, story.reactive.cleanup
└─────────────────────────────────────────────┘
```

- **Pure core** — the graph (nodes, the source/observer edges, dirty-marking, topological reachability) and the ownership tree are plain data structures with invariants. No clock, no global mutable singletons beyond the well-defined reactive context, no I/O. Given the same sequence of reads/writes they behave identically every time. **This is where the behavioral tests live** — a story test drives the public API and asserts on observable outcomes (values, run counts, ordering) without standing up anything external.
- **Effectful edge** — the user-supplied closures inside effects and memo bodies. The library invokes them; what they do is the caller's business. The library's contract is _when_ and _how often_ it invokes them, not _what_ they do.

Dependencies point inward: the scheduler depends on the graph; the graph depends on nothing. Invariants ("a memo recomputes at most once per batch", "an owner disposes its children before itself") are stated in `domain.*`/`story.*` specs and are exactly the kind of "for all" property a property-based test can hammer — see the `test-driven-development` skill.

## Concurrency model

The package compiles under Swift 6 with `StrictConcurrency` enabled (see `Package.swift`). The reactive context (the "currently-tracking observer") is ambient state that must be established correctly across the graph; how that ambient context is represented and isolated — task-local, actor-isolated, or main-actor-pinned — is a **load-bearing behavioral contract**, not an implementation detail. Capture it in `domain.*`/`story.*` specs (e.g. _what happens when a signal is read outside any reactive context_, _whether tracking crosses an `await`_), mark genuinely internal isolation bookkeeping `// SPEC: manual`, and flag any divergence with `(deviates: …)`. The "Why Thread Local?" discussion the README links is the historical context for this decision.

## Module layout

```
Sources/
└── ReactiveGraph/        ← the library (one product today; structured for a set)
    ├── API.swift         ← the public surface (Signal, Memo, Effect, …)
    └── …                 ← graph, scheduler, ownership — split by responsibility, // SPEC: tagged
Tests/
└── ReactiveGraphTests/   ← Swift Testing suites, one per story/domain spec, tagged with spec + scenario IDs
```

**One library, possibly a set.** Additional related Swift libraries (e.g. integrations or higher-level primitives built on the core) would be new SPM targets/products under `Sources/`, sharing these specs. They are ordinary Swift modules that depend on `ReactiveGraph`; there are no platform projections to keep in sync.

## How specs map to Swift

| Spec kind  | Realized as                                                                 | Reverse pointer location                                              |
| ---------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `domain.*` | A primitive or value type and its invariants (Signal, Memo, Effect, Owner). | The type declaration in `Sources/`.                                   |
| `story.*`  | Observable behavior of the graph under a sequence of reads/writes.          | The function(s) that produce that behavior; the `@Suite` in `Tests/`. |
| `error.*`  | A surfaced failure mode (e.g. a dependency cycle, a read with no context).  | The throwing/trapping site that raises or reports it.                 |

## Out of scope (this library)

- **UI.** No views, no view models, no rendering, no design system. A view layer (SwiftUI/UIKit) would be a _separate_ package that depends on this one.
- **Persistence and networking.** The graph holds in-memory reactive state only.
- **A scheduler abstraction for arbitrary executors** beyond what the concurrency model requires — _[NEEDS CLARIFICATION: is custom-executor support a goal, or is the context model fixed?]_

## Open architectural questions

<!-- Things deliberately deferred. Tag with the date so they can be revisited. -->

- _(2026-06-09)_ The isolation model for the reactive context (see "Concurrency model") is the load-bearing open question; pin it with a `domain.*` spec before broadening the public API.
