---
id: behavior.reactive.nested-error-boundaries
kind: behavior
depends-on: [error.reactive.unhandled, domain.observer]
---

# Error boundaries across nested work

An `onError` boundary catches errors thrown by effects and derived computations nested below it, so a failure deep in nested reactive work is still recoverable at an outer boundary.

## Scenarios

### Background

- Given a reactive scope and a handler that records whether it ran
- And the scope completing without letting the error escape

### Scenario 1: A handler catches an error from a nested effect's first run

<!-- id: behavior.reactive.nested-error-boundaries.nested-initial-effect -->

- Given an effect that registers a second effect nested inside it
- And a handler wrapping work that throws on that nested effect's first run
- When the scope runs and the nested effect runs for the first time
- Then the handler runs
- And the error does not escape the surrounding scope

### Scenario 2: A handler catches an error when a nested effect re-runs

<!-- id: behavior.reactive.nested-error-boundaries.nested-update-effect -->

- Given an effect that registers a second effect nested inside it
- And the nested effect reading a source and throwing only when that source is non-zero
- When the source changes and the nested effect re-runs
- Then the handler runs

### Scenario 3: A handler at an outer level catches an error from work nested below it

<!-- id: behavior.reactive.nested-error-boundaries.different-levels -->

- Given an effect whose handler wraps a second effect nested below it
- And the nested effect reading a source and throwing only when that source is non-zero
- When the source changes and the nested effect re-runs
- Then the outer handler runs

### Scenario 4: A handler catches an error from a derived computation that schedules an effect

<!-- id: behavior.reactive.nested-error-boundaries.nested-memo -->

- Given a derived value whose computation schedules an effect and then throws
- And a handler wrapping that computation
- When the scope runs and the derived value computes
- Then the handler runs
- And the error does not escape the surrounding scope
