---
id: narrative.reactive
kind: narrative
---

# Reactive core

## Who this is for

Swift developers building stateful logic — view models, document models, derived caches, coordinators — who want values that update each other automatically, without a UI framework dictating the model and without hand-wiring change notifications.

## The situation today

To keep a computed value in sync with its inputs in plain Swift, a developer wires it by hand: observe each input, recompute on every notification, remember to unsubscribe, and hope they did not miss a dependency or recompute one too many times. Combine and `@Observable` help, but they push toward whole-object observation and coarse invalidation; expressing "this one value depends on those two, and nothing else" — and trusting it updates exactly once when either changes — is still fiddly and easy to get plausibly-but-subtly wrong.

## What we're building

A fine-grained reactive graph. A developer declares a piece of state (`@State`), derives values from it (`@DerivedState`), and registers side effects (`observe`) — and the library tracks, at the granularity of individual reads, exactly which computations depend on which values. When state changes, only the computations that actually read it re-run, each at most once, in a predictable order, and only when their result truly changed. Work is scoped to an owner so it tears down cleanly; errors thrown inside computations surface to the developer instead of corrupting the graph; and a value can be read without subscribing to it when that is what the developer wants.

## Why this matters

The developer writes _what depends on what_ and stops writing _when to recompute_. Updates are precise (no over-firing), glitch-free (no transient wrong values from a multi-path update), and cheap (unchanged values short-circuit). That removes a whole class of stale-data and double-update bugs that manual change propagation invites.

## What this is NOT

- **Not a UI framework.** No views, no rendering, no diffing. A view layer would be a separate package built on this one.
- **Not persistence or networking.** The graph holds in-memory reactive state only.
- **Not whole-object observation.** Dependencies are per-read, not per-object.
