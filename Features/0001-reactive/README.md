# Feature 0001 — Reactive core

The fine-grained reactive system itself: the primitives (`@State`, `@DerivedState`, `observe`, `withReactiveScope`, `@Context`) and the behavioral contracts that make them glitch-free, equality-gated, dynamically-tracked, and correctly torn down. This is the one feature the library exists to deliver; its `<feature>` ID segment is `reactive`.

These behaviors were **reverse-engineered from the test suite** ported from [Alien Signals](https://github.com/stackblitz/alien-signals) and [Solid.js](https://www.solidjs.com): each Gherkin scenario carries a stable sub-ID that exactly one Swift Testing test pins via `.scenario(...)`. See `Specs/CONVENTIONS.md` → "Tests carry the same IDs".

## Layout

```
Features/0001-reactive/
├── README.md          ← this file
├── NARRATIVE.md       ← narrative.reactive
└── behaviors/         ← behavior.reactive.<capability> — one contract per file
```

The reactive **primitives** are cross-cutting domain models — they live in `Specs/models/` (`domain.signal`, `domain.state`, `domain.derived-state`, `domain.observer`, `domain.owner`, `domain.context`), because the whole library is built on them. The error catalog entry is `Specs/errors/reactive.unhandled.md`.

## Behaviors

| Behavior                                    | Contract                                                                           |
| ------------------------------------------- | ---------------------------------------------------------------------------------- |
| `behavior.reactive.derivation`              | A derived value tracks its sources and propagates through chains.                  |
| `behavior.reactive.glitch-free`             | A node updates at most once per change, whatever the graph shape.                  |
| `behavior.reactive.equality-gating`         | Propagation stops when a recomputed value is unchanged.                            |
| `behavior.reactive.dynamic-dependencies`    | A computation subscribes only to the sources it read on its latest run.            |
| `behavior.reactive.effects`                 | An effect runs now, re-runs on change, and stops when disposed.                    |
| `behavior.reactive.effect-ordering`         | Effects run in a deterministic, registration order.                                |
| `behavior.reactive.nested-effects`          | An effect owns inner effects; ownership governs their lifetime and order.          |
| `behavior.reactive.cleanup`                 | Cleanups run before a re-run and on disposal.                                      |
| `behavior.reactive.context`                 | A contextual value is provided to and read within a scope, with nesting.           |
| `behavior.reactive.untracking`              | Reading a source without subscribing to it (`withoutTracking` / `peek`).           |
| `behavior.reactive.error-propagation`       | Errors from derived computations surface to readers and keep the graph consistent. |
| `behavior.reactive.error-boundaries`        | `onError` catches errors from its body and across effect runs.                     |
| `behavior.reactive.nested-error-boundaries` | `onError` catches errors across nested effects and memos.                          |
