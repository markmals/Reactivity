---
id: domain.context
kind: domain
depends-on: [domain.owner]
---

# Context

`@Context` provides a **scoped contextual value**: a value made available to everything running inside a `withValue { … }` block, read back through the wrapper, with nested blocks shadowing outer ones. It is dynamic-scope value passing — _not_ a signal. Reading a context does not subscribe to anything; changing the provided value happens by entering a new scope, not by assignment.

```swift
@Context var theme = Theme.light
$theme.withValue {            // body runs with the default value
    render()                  // reads of `theme` here see .light
    $theme.withValue(.dark) { // nested provider shadows it
        render()              // reads of `theme` here see .dark
    }
}
```

## Shape

| Member            | Type                      | Notes                                                          |
| ----------------- | ------------------------- | -------------------------------------------------------------- |
| init              | `(wrappedValue: Wrapped)` | The default value used when no scope overrides it.             |
| `wrappedValue`    | `Wrapped`                 | Reads the nearest provided value in the current dynamic scope. |
| `projectedValue`  | `ContextHandle<Wrapped>`  | `$context` — the handle that opens scopes.                     |
| `withValue(_:)`   | `(() -> P) -> P`          | Run `body` with the context's current/default value.           |
| `withValue(_:_:)` | `(Wrapped, () -> P) -> P` | Run `body` with `value` provided for the context.              |

`withValue` returns the body's value; sync and `async` forms exist.

## Identity

A `Context` is identified by the wrapper instance; the value it yields depends on the dynamic scope in which it is read, not on stored mutable state.

## Invariants

- **Read sees the nearest provider.** Reading `wrappedValue` returns the value provided by the innermost enclosing `withValue` block, or the default if none. See `behavior.reactive.context`.
- **Nested shadowing.** A nested `withValue(v)` makes reads observe `v` for the duration of its body; on exit, the outer value is observed again. See `behavior.reactive.context`.
- **Scoped to the dynamic extent.** The provided value is in effect only while `body` runs; it does not persist after `withValue` returns.
- **Not reactive.** Reading a context registers no dependency and triggers no re-run; it is value provision, not subscription.

## Relationships

- Scopes nest with the dynamic extent established by `withValue`, conceptually parallel to how `domain.owner` scopes ownership; a context value is not owned reactive state, but its provision follows the same enclosing-scope discipline.

## Lifecycle

- A provided value lives exactly as long as the `withValue` body that provides it.

## Notes

- `Context` and `ContextHandle` are `Sendable`.
- Interaction between a context's dynamic extent and `async` suspension (whether a provided value survives an `await` inside `withValue`) follows the same isolation question raised in `Specs/ARCHITECTURE.md` → "Concurrency model".
