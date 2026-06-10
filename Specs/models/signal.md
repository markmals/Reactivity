---
id: domain.signal
kind: domain
depends-on: []
---

# Signal

A **signal** is the abstract reactive value: a container whose reads are _tracked_ and whose writes _notify_. It is the contract two protocols express — `ReadableSignal` (a value you can read) and `WritableSignal` (a value you can also assign) — and the basis every other primitive builds on. `domain.state` and `domain.derived-state` are the concrete realizations.

This model defines _what a reactive read and a reactive write mean_. It does not prescribe how the dependency graph is stored.

## Shape

| Member         | Protocol         | Notes                                                                                 |
| -------------- | ---------------- | ------------------------------------------------------------------------------------- |
| `Wrapped`      | both             | The carried value type.                                                               |
| `wrappedValue` | `ReadableSignal` | Reading it. A read inside a reactive context registers a dependency (see Invariants). |
| `wrappedValue` | `WritableSignal` | `nonmutating set` — assigning it updates the value and notifies dependents.           |

`ReadableSignal` is the read-only contract; `WritableSignal` refines it with a settable `wrappedValue`. A primitive that can only be read (a derived value) conforms to the former; a primitive a caller can assign (a piece of state) conforms to the latter.

## The reactive context

A **reactive context** is the dynamic scope of the computation currently running — a `domain.derived-state` body or a `domain.observer` effect. Reads are interpreted relative to it:

- A read performed **inside** a reactive context registers a dependency edge from the running computation to the signal: the computation becomes a _dependent_ of the signal.
- A read performed **outside** any reactive context (or inside `withoutTracking`, or via `peek()`) returns the current value and registers nothing.

The reactive context is ambient, established by the library as it runs each computation. How that ambient state is isolated for Swift concurrency is a load-bearing contract tracked in `Specs/ARCHITECTURE.md` → "Concurrency model" and is _[NEEDS CLARIFICATION: whether a tracked read may cross an `await` — i.e. does the reactive context propagate across suspension points?]_.

## Invariants

- **Read-tracks.** Inside a reactive context, reading a signal makes the reader a dependent of that signal.
- **Write-notifies.** Assigning a `WritableSignal`'s value schedules every current dependent to be re-checked.
- **Dynamic dependencies.** The dependents of a signal are exactly the computations whose _most recent_ run read it. A computation that stops reading a signal on a later run stops being its dependent. See `behavior.reactive.dynamic-dependencies`.
- **At-most-once per change.** A dependent is re-evaluated at most once in response to a single change, however many paths connect them. The minimum-recompute guarantee is stated in `behavior.reactive.glitch-free`.
- **Untracked reads register nothing.** A read through `peek()` or `withoutTracking` never creates a dependency, even inside a reactive context. See `behavior.reactive.untracking`.

## Relationships

- `domain.state` — the concrete `WritableSignal` a caller mutates.
- `domain.derived-state` — the concrete `ReadableSignal` computed from other signals.
- `domain.observer` — effects are readers; their tracked reads create dependencies the same way.

## Notes

- `Sendable` is part of the contract: signals are values that may be shared across isolation domains.
- Equality-gating of _change propagation_ (a write or recompute that yields an unchanged value not forcing downstream work) is specified where it is observable: `domain.derived-state` and `behavior.reactive.equality-gating`.
