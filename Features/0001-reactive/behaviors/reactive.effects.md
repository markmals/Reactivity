---
id: behavior.reactive.effects
kind: behavior
depends-on: [domain.observer]
---

# Effects

An effect runs once when it is registered and re-runs whenever a value it read changes — exactly once per change — and stops running once it is disposed.

## Scenarios

### Background

- Given a count of how many times an effect runs

### Scenario 1: A disposed effect stops re-running

<!-- id: behavior.reactive.effects.dispose-stops -->

- Given an effect that reads a derived value over a source
- And the effect has run once on registration and re-run once for an earlier change to that source
- And the effect has since been disposed
- When the source changes again
- Then the effect does not run

### Scenario 2: An effect re-runs once for a source reached through a chain

<!-- id: behavior.reactive.effects.change-through-chain -->

- Given an effect that reads a derived value reachable from a source only through a chain of intermediate derived values
- When the source changes
- Then the effect re-runs exactly once

### Scenario 3: An effect does not re-run when its value settles unchanged

<!-- id: behavior.reactive.effects.settles-unchanged -->

- Given an effect that reads a derived value whose result is unaffected by a particular source change
- When that source changes in a way that leaves the derived value's result the same
- Then the effect does not re-run
