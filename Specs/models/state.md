---
id: domain.state
kind: domain
depends-on: [domain.signal]
---

# State

`@State` is the concrete **writable signal**: a piece of mutable reactive state a caller reads, assigns, and observes. It is the source from which `domain.derived-state` values and `domain.observer` effects derive. Realized as a `@propertyWrapper` conforming to `WritableSignal`.

```swift
@State var count = 0
count += 1          // a tracked write — notifies dependents
let now = count     // a tracked read inside a reactive context — registers a dependency
let peeked = $count.peek()  // an untracked read — registers nothing
```

## Shape

| Member           | Type            | Notes                                                                |
| ---------------- | --------------- | -------------------------------------------------------------------- |
| `wrappedValue`   | `Wrapped`       | `get` is a tracked read; `nonmutating set` is a write that notifies. |
| `projectedValue` | `Self`          | `$state` — the signal handle, used for `peek()`.                     |
| `peek()`         | `() -> Wrapped` | Reads the current value **without** registering a dependency.        |

The setter is `nonmutating`: assigning through `@State` mutates shared reactive storage, not the wrapper struct. Two reads of the same `@State` see the same storage.

## Identity

A `State` instance _is_ its backing reactive node. Copying the wrapper value shares the node; there is no separate identifier a caller addresses.

## Invariants

- **Tracked read.** Reading `wrappedValue` inside a reactive context registers the reader as a dependent (per `domain.signal`).
- **Notifying write.** Assigning `wrappedValue` updates the stored value and schedules dependents to be re-checked.
- **Untracked read.** `peek()` returns the current value and registers nothing — even inside a reactive context. See `behavior.reactive.untracking`.
- **Value identity of storage.** Reads observe the latest written value; there is no stale snapshot between a write and the next read.

## Relationships

- Conforms to `domain.signal` (`WritableSignal`, hence `ReadableSignal`).
- Read by `domain.derived-state` and `domain.observer` to form dependencies.

## Lifecycle

- Created with an initial value (`@State var x = …`).
- Owned by the enclosing reactive scope (`domain.owner`); its dependents are released when those dependents are disposed.

## Notes

- `Sendable`.
- Whether assigning a value _equal_ to the current one still notifies — versus being suppressed at the source — is not pinned by the current suite; the observable equality behavior the tests do pin lives downstream, at the derived value. See `domain.derived-state` and `behavior.reactive.equality-gating`. _[NEEDS CLARIFICATION: does writing an equal value to a `@State` notify dependents, or is it a no-op at the source?]_
