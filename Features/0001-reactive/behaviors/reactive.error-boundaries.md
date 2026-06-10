---
id: behavior.reactive.error-boundaries
kind: behavior
depends-on: [error.reactive.unhandled, domain.observer]
---

# Error boundaries

An `onError` boundary catches errors thrown by the work it wraps — including during an effect's first run and its re-runs — and its handler may recover or rethrow to the next enclosing boundary.

## Scenarios

### Background

- Given a reactive scope

### Scenario 1: A handler catches an error its body throws

<!-- id: behavior.reactive.error-boundaries.catches-body -->

- Given a body wrapped in a handler
- When the body throws an error
- Then the handler runs with that error
- And the error does not escape the surrounding scope

### Scenario 2: A rethrowing handler passes the error to the enclosing handler

<!-- id: behavior.reactive.error-boundaries.rethrow-to-outer -->

- Given a handler-wrapped body nested inside another handler-wrapped body
- When the inner handler rethrows the error it catches
- Then the outer handler runs with that error
- And the error does not escape the surrounding scope

### Scenario 3: A handler catches an error thrown on an effect's first run

<!-- id: behavior.reactive.error-boundaries.initial-effect -->

- Given an effect whose work is wrapped in a handler
- When the effect runs for the first time and its body throws
- Then the handler runs with that error
- And the error does not escape the surrounding scope

### Scenario 4: A handler catches an error thrown when an effect re-runs

<!-- id: behavior.reactive.error-boundaries.update-effect -->

- Given an effect that reads a source and whose work is wrapped in a handler
- And the effect's body throws only once the source is non-zero
- When the source changes so the effect re-runs
- Then the handler runs with the error thrown on that re-run
