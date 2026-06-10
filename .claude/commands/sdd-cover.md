---
description: Show whether a spec is implemented and which of its tests pass.
argument-hint: <spec-id>
---

# /sdd-cover $ARGUMENTS

You are reporting coverage for a single spec: `$ARGUMENTS`.

## Intent

For a given spec ID, show:

- Whether a `// SPEC: <id>` reverse pointer exists in `Sources/` (and where).
- Which tests are tagged with this spec ID (and which scenarios are covered).
- Whether those tests currently pass.
- Whether the implementation carries a `(deviates: <reason>)` marker for this spec.

## Steps

1. **Read the spec.** Confirm the ID exists and read its content (so the report header includes the spec's intent in one line).
2. **Find the implementation.** `rg "SPEC: <spec-id>"` in `Sources/` — record matching files.
3. **Find the tests.** `rg '.spec("<spec-id>")' Tests/` to locate the `@Suite`; `rg '.scenario("' <suite-file>` to enumerate covered scenario sub-IDs.
4. **Optionally run the tests** filtered to this spec ID and record pass/fail.
5. **Emit a report** of {impl files, scenarios covered, status, deviation note}.

## Output format

```
COVERAGE — spec: <spec-id>
==========================
Intent: <one-line summary from the spec>

Impl:        Sources/ReactiveGraph/<file>.swift
Scenarios:   empty, populated
Status:      PASS
Notes:       —
```

## Implementation status

Manual until tooling lands. `rg` + `mise run test` cover this today, just without aggregation.
