---
id: behavior.<feature>.<capability>
kind: behavior
depends-on: []
---

# <Contract title>

<!--
  A behavior states ONE contract the reactive graph upholds — a guarantee a
  caller can depend on — then pins it with Gherkin scenarios that each trace to
  exactly one test. This is a library, so there is NO user persona: describe the
  system's observable behavior (values, run counts, ordering, errors), never a
  user's intent. Authored with the `writing-behaviors` skill.
-->

<One paragraph stating the contract this behavior guarantees, and briefly why it matters.>

## Scenarios

<!-- Optional: Background runs before each scenario; keep it ≤ 4 lines. -->

### Background

- Given <stable state shared by the scenarios below>

### Scenario 1: <specific observable behavior>

<!-- id: behavior.<feature>.<capability>.<short-name> -->

- Given <state>
- And <state>
- When <single stimulus>
- Then <observable outcome>
- And <observable outcome>

### Scenario 2: <another behavior>

<!-- id: behavior.<feature>.<capability>.<short-name> -->

- Given <state>
- When <single stimulus>
- Then <observable outcome>

<!--
  Each scenario sub-ID is the behavior's ID plus a short name — no `scenario.`
  prefix (the trait already says it). Tests bind via Swift Testing traits
  (see Specs/CONVENTIONS.md):
  @Suite(.spec("behavior.<feature>.<capability>"))
  @Test(.scenario("behavior.<feature>.<capability>.<short-name>"))
  func `a sentence describing the behavior`() { ... }
-->
