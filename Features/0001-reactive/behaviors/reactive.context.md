---
id: behavior.reactive.context
kind: behavior
depends-on: [domain.context]
---

# Scoped contextual values

A value provided to a scope is readable anywhere within that scope without threading it through calls, and a nested scope shadows the outer value for the duration of its body.

## Scenarios

### Background

- Given a context declared with a default value

### Scenario 1: A read yields the value provided for its scope

<!-- id: behavior.reactive.context.read-in-scope -->

- Given a provider scope for the context
- When the developer reads the context inside that scope
- Then the read yields the value the scope provides — the default when the scope supplies none, or the supplied value when it supplies one

### Scenario 2: A nested provider shadows the outer value

<!-- id: behavior.reactive.context.nested-shadowing -->

- Given the context being read inside a provider scope
- When the developer opens a nested provider scope supplying a different value
- Then reads inside the nested scope yield the nested value
- And reads revert to the outer value once the nested scope ends
