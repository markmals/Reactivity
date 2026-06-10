---
id: behavior.reactive.glitch-free
kind: behavior
depends-on: [domain.derived-state]
---

# Glitch-free updates

A value reachable from a source by more than one path recomputes **at most once** per change to that source, and never exposes a transient state that mixes old and new inputs.

## Scenarios

### Background

- Given a source value feeding derived values that converge on a downstream value
- And a count of how many times the downstream value recomputes

### Scenario 1: A diamond updates the downstream value once

<!-- id: behavior.reactive.glitch-free.diamond -->

- Given a source feeding two derived values that both feed a single downstream value
- When the source changes
- Then the downstream value recomputes exactly once
- And it yields a result consistent with the source's new value, never a transient mix of old and new

### Scenario 2: A diamond with a tail updates the tail once

<!-- id: behavior.reactive.glitch-free.diamond-tail -->

- Given a diamond whose downstream value feeds a further value (a tail)
- When the source changes
- Then the tail value recomputes exactly once

### Scenario 3: A jagged diamond updates each node once and preserves downstream order

<!-- id: behavior.reactive.glitch-free.jagged-diamond -->

- Given a source feeding derived values of differing path lengths that converge on shared downstream values
- When the source changes
- Then each downstream value recomputes exactly once
- And a downstream value recomputes only after the values it depends on have, so dependency order is preserved

### Scenario 4: A redundant re-entrant path causes no extra recomputation

<!-- id: behavior.reactive.glitch-free.drop-redundant -->

- Given a value that reads a source both directly and through an intermediate derived from the same source
- And a downstream value derived from it
- When the source changes
- Then the downstream value recomputes exactly once for that change
