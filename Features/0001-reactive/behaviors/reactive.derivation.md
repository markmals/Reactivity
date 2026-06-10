---
id: behavior.reactive.derivation
kind: behavior
depends-on: [domain.state, domain.derived-state]
---

# Derived values

A value computed from other reactive values recomputes when any value it read changes, so a read always reflects the latest inputs — through chains of derivations and across multiple paths to the same source.

## Scenarios

### Background

- Given a source value
- And derived values computed from that source

### Scenario 1: A chained derived value reflects the latest source

<!-- id: behavior.reactive.derivation.chained-propagation -->

- Given a derived value computed from a source through a chain of intermediate derived values
- When the source changes and the developer reads the end of the chain
- Then the read yields a result computed from the source's latest value

### Scenario 2: A value derived by two paths reflects the new source

<!-- id: behavior.reactive.derivation.multi-path-source -->

- Given a value derived from a single source along two different paths
- When the source changes
- Then reading that value yields a result computed from the source's new value along both paths
