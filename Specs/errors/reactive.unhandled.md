---
id: error.reactive.unhandled
kind: error
depends-on: [domain.derived-state, domain.observer, domain.owner]
---

# Unhandled error in a reactive computation

The "user" here is a developer using the reactive API. This error spec describes what happens when a reactive computation — a `@DerivedState` body or an `observe` effect — throws, and how the library lets the developer intercept it.

## When this happens

A derived value's computation throws, or an effect body throws, while the reactive graph is running it. This can happen on first activation, on a later recompute/re-run, or inside a nested effect or memo.

## What the developer sees

- **At a derived read.** Reading a `@DerivedState` whose computation threw rethrows the same error to the reader: `try derived` throws.
- **At a scope boundary with no handler.** An error with no enclosing `onError` propagates out of the `withReactiveScope` call that was running — `try withReactiveScope { … }` rethrows it.
- **At an `onError` boundary.** If an `onError(_:handle:)` encloses the failing work, the thrown error is delivered to the handler instead of propagating; the handler decides whether to recover or rethrow to an outer boundary.

> The error surfaces as the _same_ Swift `Error` the computation threw — it is not wrapped or replaced.

## What the developer can do

- **`onError(body, handle:)`** — run `body`; if it throws, invoke `handle` with the error. Boundaries nest: a handler may rethrow to the next `onError` out. Covers errors thrown during an effect's initial run and its re-runs, and across nested effects and memos.
- **`try` at the read or scope** — let the error rethrow from `try derived` or `try withReactiveScope { … }` and handle it with ordinary Swift `do/catch`.

## Graph consistency (contract)

A thrown error must not corrupt the graph. After a computation throws:

- Other nodes that did not depend on the failed computation keep working (a sibling derived value still reads correctly).
- The failed derived value can recompute successfully on a later change once its inputs no longer cause a throw.

See `behavior.reactive.error-propagation` for the consistency scenarios and `behavior.reactive.error-boundaries` / `behavior.reactive.nested-error-boundaries` for the `onError` scenarios.

## Underlying cause (informational)

- Any `Error` thrown from the `@autoclosure` computation of a `@DerivedState` or from an `observe` body.

## Related

- `domain.derived-state` — the throwing computation and its error-transparency invariant.
- `domain.observer` — effect bodies that may throw.
- `behavior.reactive.error-propagation`, `behavior.reactive.error-boundaries`, `behavior.reactive.nested-error-boundaries`.
