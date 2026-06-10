---
id: behavior.reactive.nested-effects
kind: behavior
depends-on: [domain.observer, domain.owner]
---

# Nested effects

An effect created inside another is owned by it: when the outer effect re-runs or is disposed it tears down its inner effects first, so an inner effect never runs against stale state nor outlives its parent.

## Scenarios

### Background

- Given an outer effect that, on each run, registers a cleanup disposing its current inner effect and then creates a new inner effect it owns

### Scenario 1: A disposed inner effect never runs again

<!-- id: behavior.reactive.nested-effects.cleanup-before-rerun -->

- Given an outer effect that depends on a derived value over a source
- And the outer effect's inner effect would record a failure were it to run while the source is zero
- When the source changes to zero so the outer effect re-runs and its cleanup disposes the inner effect
- Then the inner effect is torn down before it could run against the new source value
- And the inner effect never runs again after that disposal

### Scenario 2: An outer effect tears down its inner before the inner sees stale state

<!-- id: behavior.reactive.nested-effects.outer-first -->

- Given an outer effect that depends on a source and owns an inner effect depending on a second source
- And the inner effect would record a failure were it to run while the first source is zero
- When the first source changes to zero
- Then the outer effect re-runs first and tears down its inner effect before the inner effect could run against the stale first source
