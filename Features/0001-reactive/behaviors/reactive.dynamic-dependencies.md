---
id: behavior.reactive.dynamic-dependencies
kind: behavior
depends-on: [domain.derived-state, domain.observer]
---

# Dynamic dependencies

A computation depends only on the values it actually read on its latest run. An unread or unreachable value triggers no work, a branch not taken creates no dependency, and a disposed observer stops tracking entirely.

## Scenarios

### Background

- Given a source value
- And a count of how many times a derived value recomputes

### Scenario 1: An unread source never triggers work

<!-- id: behavior.reactive.dynamic-dependencies.unread-source-ignored -->

- Given a source feeding two derived values
- And one derived value that is read and one that is never read
- When the source changes
- Then the read derived value yields the source's new value
- And the never-read derived value never recomputes, so its recompute count stays at zero

### Scenario 2: Disposing the only observer makes its chain go quiet

<!-- id: behavior.reactive.dynamic-dependencies.disposed-stops -->

- Given a chain of derived values whose only observer reads the end of the chain
- And a separate derived value observed independently from that source
- When the chain's only observer is disposed and the source changes
- Then no derived value in the disposed chain recomputes
- And the independently-observed derived value still yields the source's new value

### Scenario 3: A conditional branch tracks only the source it took

<!-- id: behavior.reactive.dynamic-dependencies.conditional-branch -->

- Given a derived value whose computation reads different sources depending on which branch it takes
- When the source changes so the computation takes a different branch
- Then the derived value yields the value from the branch it took
- And it depends only on the source on that branch, re-subscribing when a later change flips the branch back
