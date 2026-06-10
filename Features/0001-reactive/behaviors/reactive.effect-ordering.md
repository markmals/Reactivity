---
id: behavior.reactive.effect-ordering
kind: behavior
depends-on: [domain.observer]
---

# Effect ordering

Effects run in a deterministic order — the order in which they were registered — on their first run and on every re-run, regardless of how their dependencies are wired or how many times a source is read.

## Scenarios

### Background

- Given two or more effects that each read a source
- And a record of the order in which the effects run

### Scenario 1: Sibling effects run in registration order

<!-- id: behavior.reactive.effect-ordering.registration-order -->

- Given two effects registered one after another within a scope, each reading a shared source
- When that source changes
- Then both effects re-run
- And they run in the order they were registered

### Scenario 2: Effects registered inside another effect run in registration order

<!-- id: behavior.reactive.effect-ordering.nested-registration-order -->

- Given two effects registered one after another inside an outer effect, each reading a shared source
- When that source changes
- Then both inner effects re-run
- And they run in the order they were registered

### Scenario 3: Effects affected by several changed sources re-run in registration order

<!-- id: behavior.reactive.effect-ordering.rerun-order -->

- Given two effects registered one after another, each reading a different source
- When both sources change
- Then both effects re-run
- And the affected effects re-run in registration order

### Scenario 4: Duplicate subscriptions do not change the run order

<!-- id: behavior.reactive.effect-ordering.duplicate-subscribers -->

- Given two effects registered one after another, where the first effect reads a source more than once
- When that source changes
- Then both effects re-run
- And subscribing to the same source more than once leaves the run order unchanged — the effects still run in registration order
