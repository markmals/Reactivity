---
id: behavior.reactive.cleanup
kind: behavior
depends-on: [domain.owner]
---

# Cleanup

A cleanup registered during reactive work runs before its effect re-runs and when its owning scope is disposed, so resources opened in reactive work are always released at the right moment.

## Scenarios

### Background

- Given a cleanup registered during reactive work
- And a record of whether the cleanup has run

### Scenario 1: A cleanup runs before its effect re-runs

<!-- id: behavior.reactive.cleanup.runs-before-rerun -->

- Given an effect that reads a source and registers a cleanup
- And the cleanup has not run while the source is unchanged
- When the source changes so the effect re-runs
- Then the cleanup runs before the effect runs again

### Scenario 2: A cleanup runs when its scope is disposed

<!-- id: behavior.reactive.cleanup.runs-on-dispose -->

- Given a cleanup registered inside a scope
- And the cleanup has not run while the scope is alive
- When the scope is disposed
- Then the cleanup runs
