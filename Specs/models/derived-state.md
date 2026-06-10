---
id: domain.derived-state
kind: domain
depends-on: [domain.signal, domain.state]
---

# Derived State

`@DerivedState` is a **cached derived value** (a _memo_): a read-only signal whose value is produced by a closure over other signals. It recomputes only when one of the signals it actually read changes, recomputes at most once per change, and — when its recomputed value is unchanged — does not propagate to its own dependents. Realized as a `@propertyWrapper` conforming to `ReadableSignal`.

```swift
@State var count = 0
@DerivedState var doubled = count * 2   // recomputes only when `count` changes
```

## Shape

| Member           | Type                                          | Notes                                                      |
| ---------------- | --------------------------------------------- | ---------------------------------------------------------- |
| init             | `@autoclosure @escaping () throws -> Wrapped` | The computation. Captured, not run, until first read.      |
| `wrappedValue`   | `Wrapped`                                     | A tracked read of the cached value; computes it on demand. |
| `projectedValue` | `Self`                                        | `$derived` — the signal handle.                            |

The computation is a **throwing autoclosure**: it may read signals and may throw. A read of a derived value is therefore potentially throwing (`try`), and the body runs inside a reactive context so its reads register dependencies.

## Identity

A `DerivedState` instance _is_ its backing reactive node — the cache plus the computation plus the current dependency set.

## Invariants

- **Lazy.** The computation does not run until the value is first read.
- **Cached.** Repeated reads without an intervening dependency change return the cached value without recomputing.
- **Recompute-on-change.** When a tracked dependency changes, the next read recomputes the value. See `behavior.reactive.derivation`.
- **At-most-once.** A single change recomputes the value at most once, regardless of how many dependency paths reach it (glitch-freedom). See `behavior.reactive.glitch-free`.
- **Equality-gated propagation.** If a recompute yields a value _equal_ to the previous one, the derived value's own dependents are not recomputed. A change that nets to no change (e.g. a source written and then reverted) recomputes nothing observable. See `behavior.reactive.equality-gating`.
- **Dynamic dependencies.** Only the signals read on the latest run are dependencies; a branch not taken contributes none. See `behavior.reactive.dynamic-dependencies`.
- **Error transparency.** If the computation throws, the error rethrows to the reader and the surrounding graph stays consistent — other nodes keep working and the value can recompute successfully once its inputs change. See `behavior.reactive.error-propagation`.

## Relationships

- Conforms to `domain.signal` (`ReadableSignal`).
- Reads `domain.state` and other `domain.derived-state` values to form its dependency set.
- Owned by the enclosing `domain.owner`.

## Lifecycle

- Created from a computation; first read activates it (computes and registers dependencies).
- Re-activates its dependency set on each recompute (dependencies are recomputed dynamically, not fixed at creation).

## Notes

- **Equality-gating requires comparing successive computed values**, yet `DerivedState<Wrapped>` carries no `Wrapped: Equatable` bound in the current API surface. How the library compares — a constrained overload, a default that treats every recompute as a change for non-`Equatable` values, or reference identity — is unresolved. _[NEEDS CLARIFICATION: does equality-gating require `Wrapped: Equatable`, and what is the propagation behavior when `Wrapped` is not `Equatable`?]_ The `behavior.reactive.equality-gating` scenarios all use `Equatable` value types, so they do not disambiguate this.
- `Sendable`.
