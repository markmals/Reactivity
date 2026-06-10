---
description: Regenerate a spec's Swift implementation and tests in conformance with the spec.
argument-hint: <spec-id>
---

# /sdd-apply $ARGUMENTS

You are applying a single spec to the library. Spec ID is: `$ARGUMENTS`.

## Intent

Bring the implementation and tests **into conformance** with a single spec. The spec is authoritative; you are not editing the spec, you are aligning code to it. If the spec is wrong, stop and tell the user — they should edit the spec first, then re-invoke this command.

## Steps

1. **Locate the spec.** Search for the file whose frontmatter `id:` matches the spec ID. Read it in full, plus everything in its `depends-on` list.
2. **Identify existing reverse pointers.** `rg "SPEC: <spec-id>"` in `Sources/`. List the files that already point to this spec.
3. **Read the Swift idioms.** Consult the `swift-development` skill for frameworks, concurrency, and test conventions.
4. **Plan the changes.** What files need to be created or modified? What tests need to exist? Surface this plan to the user before making changes.
5. **Make changes.** Write tests first (tagged with the spec ID and the relevant scenario sub-IDs — `.spec("<spec-id>")` on the `@Suite`, `.scenario("<scenario-id>")` on each `@Test`). Implement to pass. Verify with `mise run test`.
6. **Verify reverse pointers.** Every changed implementation file must carry `// SPEC: <spec-id>` (or `// SPEC: <spec-id> (deviates: <reason>)` if a deliberate divergence is justified).
7. **Commit at natural boundaries.** Once tests are green and reverse pointers are in place, commit. See `.claude/rules/commit-discipline.md` for message style and staging discipline.

## Commit boundaries

Per spec, the natural boundaries are:

- **Test commit:** the failing tests that pin the spec's scenarios. Subject: `<spec-id>: add failing scenarios` (the scope is the spec ID — Scoped Commits, see `.claude/rules/commit-discipline.md`).
- **Implementation commit:** the minimum code to make them pass, with the `// SPEC: <id>` reverse pointer. Subject: `<spec-id>: implement <behavior>`.

If the test and impl are tightly bound and the diff is small, one combined commit is fine. If multiple specs were applied in one session, commit each independently — never bundle "implemented X and Y" into one commit.

## Notes for the implementer agent

- Do **not** invent or rename spec IDs; they are stable.
- Do **not** edit the spec from this command. If the spec needs changes, that's `/sdd-reconcile`.
- Divergences must be explicit: comment them with `(deviates: <reason>)`.
- If a `depends-on` spec is not yet implemented, surface this and offer to apply it first.

## Implementation status

This command's plumbing (drift checks, automated diff proposal) is **not yet implemented**. Until then, follow the steps above manually.
