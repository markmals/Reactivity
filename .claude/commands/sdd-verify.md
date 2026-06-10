---
description: Run the behavioral test suite and report which spec IDs pass.
argument-hint:
---

# /sdd-verify

You are verifying conformance by running the library's test suite.

## Intent

Run all behavioral tests and produce a report keyed by spec ID. The report distinguishes:

- **Pass:** every test tagged with the spec ID passed.
- **Fail:** at least one test tagged with the spec ID failed.
- **Missing:** the spec is implemented (a `// SPEC:` pointer exists in `Sources/`) but no tests reference it.
- **Unimplemented:** the spec exists but no `// SPEC:` pointer references it.

## Steps

1. **Run the test suite** via `mise run test` (`swift test`).
2. **Parse the results** by spec ID. Tests use custom Swift Testing traits: `.spec("<spec-id>")` on the `@Suite` carries the spec ID, and `.scenario("<scenario-id>")` on each `@Test` carries the scenario sub-ID. Grep the test sources for the strings `.spec("` and `.scenario("` to map suites and tests to spec IDs and scenarios.
3. **Cross-reference reverse pointers.** `rg "SPEC: " Sources/` and parse out the spec IDs to identify implementations without tests.
4. **Cross-reference all known specs.** Walk `Specs/` and `Features/<n>/` for every spec ID that could be implemented.
5. **Output a table** of spec ID → status with a summary count.

## Implementation status

Manual until tooling lands. `mise run test` works today; the cross-referencing is the missing piece.
