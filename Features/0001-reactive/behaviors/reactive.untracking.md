---
id: behavior.reactive.untracking
kind: behavior
depends-on: [domain.signal, domain.derived-state, domain.observer]
---

# Untracked reads

A value read through `withoutTracking` or `peek()` is observed without creating a dependency, so a computation can consult a value without re-running every time that value changes.

## Scenarios

### Background

- Given a source and a count of how many times the consuming derived value or effect runs

### Scenario 1: An untracked read in a derived value creates no dependency

<!-- id: behavior.reactive.untracking.derived-without-tracking -->

- Given a derived value that reads a source inside `withoutTracking`
- When the source changes one or more times
- Then the derived value does not recompute
- And its value stays at the result of its single original computation

### Scenario 2: An untracked read in an effect creates no dependency

<!-- id: behavior.reactive.untracking.effect-without-tracking -->

- Given an effect that reads a source inside `withoutTracking`
- When the source changes one or more times
- Then the effect does not re-run on account of that source

### Scenario 3: A peek read in a derived value creates no dependency

<!-- id: behavior.reactive.untracking.derived-peek -->

- Given a derived value that reads a source through `peek()`
- When the source changes one or more times
- Then the derived value does not recompute
- And its value stays at the result of its single original computation

### Scenario 4: A peek read in an effect creates no dependency

<!-- id: behavior.reactive.untracking.effect-peek -->

- Given an effect that reads a source through `peek()`
- When the source changes one or more times
- Then the effect does not re-run on account of that source
