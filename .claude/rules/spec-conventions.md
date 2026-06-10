# Shared Spec Rules

> **This file is `@included` from the root `CLAUDE.md`.** Keep it short — it loads on every session.

## The compact

- **Specs in `specs/` and `features/<n>/` are the source of truth.** The Swift implementation must satisfy them.
- **Reverse pointers are mandatory.** Every type, function, or extension that realizes a spec carries `// SPEC: <id>` in `Sources/`. Tests are tagged with the spec IDs they verify.
- **Use `// SPEC: <id> (deviates: <reason>)` when the implementation must differ** from the spec. Use `// SPEC: manual` for genuinely internal code with no behavioral contract.
- **The spec defines what; the test proves it; the implementation satisfies it.** None is the source of truth alone.

## Before writing implementation code

1. Read the spec file. Confirm the ID, depends-on chain, and behavior.
2. Read the existing patterns for similar specs (look for other `// SPEC:` annotations in the same area of `Sources/`).
3. Write the failing tests first, tagged with the spec ID and scenario sub-IDs (Swift Testing — see `specs/CONVENTIONS.md`).
4. Implement the minimum to pass the tests.
5. Verify with `/sdd-verify` (`swift test`).

## Before changing a spec

1. Search for the ID in the code: `rg 'SPEC: <id>'`.
2. List the affected files and tests.
3. Update the spec.
4. Use `/sdd-apply <id>` to re-align the implementation — propose changes, do not auto-merge.

## Before changing implementation that has a spec

1. Decide: is this a bug fix that the spec already requires, or a behavior change?
2. If behavior change: update the spec first (`/sdd-reconcile`), then `/sdd-apply`.
3. If bug fix: just fix it, run `/sdd-verify`, and confirm the spec still describes the intended behavior.

## Where to read more

- `specs/CONVENTIONS.md` — full conventions, kind taxonomy, frontmatter schema, drift rules.
- `specs/ARCHITECTURE.md` — layering, the pure-core / effectful-edge boundary, module layout.
