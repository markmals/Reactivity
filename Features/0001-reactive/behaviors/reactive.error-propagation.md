---
id: behavior.reactive.error-propagation
kind: behavior
depends-on: [domain.derived-state, error.reactive.unhandled]
---

# Error propagation

An error thrown inside a derived computation surfaces to whoever reads it and never corrupts the graph: unrelated values keep working, the failed value recovers once its inputs stop throwing, and an error with no handler propagates out of the reactive scope.

## Scenarios

### Background

- Given a source value
- And a derived value computed from it

### Scenario 1: A derived value that throws on first read surfaces the error and leaves others working

<!-- id: behavior.reactive.error-propagation.graph-consistent-on-activation -->

- Given a derived value whose computation always throws
- And a separate derived value computed from a source
- When the developer reads the throwing derived value for the first time
- Then the read surfaces the thrown error to the reader
- And after changing the source, the separate derived value still yields a result consistent with the source's new value

### Scenario 2: A derived value that throws on a later recompute surfaces the error and recovers afterward

<!-- id: behavior.reactive.error-propagation.graph-consistent-on-recompute -->

- Given a derived value that throws only when its source holds a particular value
- And a downstream value computed from it
- When the source changes to the value that makes the computation throw
- Then reading the throwing derived value surfaces the thrown error to the reader
- And after the source changes again to a value that no longer throws, the downstream value recovers and yields a result consistent with the source's new value

### Scenario 3: An error in a scope with no handler propagates out to the caller

<!-- id: behavior.reactive.error-propagation.no-handler-propagates -->

- Given a reactive scope with no error handler
- When work inside that scope throws an error
- Then the error propagates out of the scope to the caller
