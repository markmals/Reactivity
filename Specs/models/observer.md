---
id: domain.observer
kind: domain
depends-on: [domain.signal, domain.owner]
---

# Observer

An **observer** (an _effect_) is a side-effecting computation that runs once immediately and re-runs whenever a signal it read changes. It is how reactive state reaches the outside world: the library controls _when_ and _how often_ the closure runs; what the closure does is the caller's business. Created with `observe`, which returns an `ObservationHandle` for disposal.

```swift
let handle = observe {
    print("count is \(count)")   // runs now, and again whenever `count` changes
}
handle.dispose()                 // stops further runs
```

## Shape

| Member                       | Type                                          | Notes                                                                                                   |
| ---------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `observe(_:)`                | `(@escaping () -> Void) -> ObservationHandle` | Register an effect. Sync, `async`, `throws`, and `async throws` forms exist.                            |
| `observe(_:)` (accumulating) | `((Previous?) -> Next) -> ObservationHandle`  | An effect that threads a value from each run into the next; an optional `initialValue` seeds the first. |
| `ObservationHandle`          | value type                                    | `dispose()` tears the effect down.                                                                      |
| `ObservationOptions`         | value type                                    | `name` — a debugging label.                                                                             |

The `isolation:` parameter pins the actor the effect runs on; the accumulating overloads model an effect that derives its next state from its previous (Solid's `createEffect`-with-value shape).

## Identity

An observer _is_ its backing reactive node: the closure, its current dependency set, and its place in the `domain.owner` tree.

## Invariants

- **Runs immediately.** Registering an observer runs its body once, synchronously, establishing its initial dependencies.
- **Re-runs on change.** When a tracked dependency changes, the observer re-runs. See `behavior.reactive.effects`.
- **At-most-once per change.** A single change re-runs an observer at most once, regardless of dependency-graph shape (glitch-freedom). A dependency that ends up unchanged after a maybe-dirty check does not trigger a run. See `behavior.reactive.effects` and `behavior.reactive.glitch-free`.
- **Deterministic order.** Sibling observers run in registration order, on the first run and on every re-run. Duplicate subscriptions to the same signal do not change that order. See `behavior.reactive.effect-ordering`.
- **Dynamic dependencies.** An observer subscribes only to signals it read on its latest run; reads suppressed by `withoutTracking`/`peek()` create no subscription. See `behavior.reactive.dynamic-dependencies` and `behavior.reactive.untracking`.
- **Disposal stops runs.** After `dispose()`, the observer never runs again, even if its former dependencies change. See `behavior.reactive.effects`.
- **Ownership of nested observers.** An observer created inside another is a child in the owner tree; the parent re-running (or being disposed) disposes the child first. See `behavior.reactive.nested-effects`.

## Relationships

- Reads `domain.signal` values (`domain.state`, `domain.derived-state`) to form dependencies.
- Is a node in the `domain.owner` tree; `onCleanup` and disposal are governed there.

## Lifecycle

- **Active** — registered and subscribed to its current dependencies; re-runs on change.
- **Disposed** — torn down via `dispose()` or by an ancestor owner; runs no more. Its cleanups (see `domain.owner`) run on disposal and before each re-run.

## Notes

- The `async`/`throws` overloads exist for effects whose bodies suspend or throw; an error escaping an effect body is governed by `error.reactive.unhandled`.
- `ObservationHandle` and `ObservationOptions` are `Sendable`.
