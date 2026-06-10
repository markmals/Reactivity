---
name: triaging-defects
description: Use to work through entries in the root DEFECTS.md. Picks one entry, classifies it as fix-in-place / promote-to-spec / won't-fix-by-design, executes the resolution, and deletes the entry. The discipline that keeps DEFECTS.md from becoming a TODO graveyard.
---

# Triaging Defects

Work through entries in the root `DEFECTS.md` one at a time. For each entry, classify, resolve, and delete. The file should want to be empty by the time you stop.

`DEFECTS.md` holds **sub-spec rough edges** — things the cross-cutting spec deliberately doesn't speak to: a known-not-yet-fixed quirk, a Swift-toolchain-version wrinkle, an acceptable performance trade-off. The point of this skill is the **drain**. Without disciplined triage, `DEFECTS.md` becomes a TODO graveyard — a pile that grows faster than it shrinks, signalling "we have problems" without ever resolving them.

For a library this file should be nearly always empty: most real issues are either bugs the spec already requires (just fix them) or missing behavioral contracts (promote to spec). A defect is the narrow residue that's neither.

## When to use

- The root `DEFECTS.md` is non-empty and you're in a cleanup or polish pass.
- The user explicitly asks to triage defects, drain the file, or work through `DEFECTS.md`.
- A non-empty defect file has been sitting long enough that the entries are stale.

**Do NOT use this skill for:**

- Filing a new entry — that's `/sdd-defect`. This skill empties the file; the slash command fills it.
- Spec/impl drift — that's `/sdd-drift` and `/sdd-reconcile`. If the entry is "spec says X but the code does Y," it doesn't belong in `DEFECTS.md`; surface it and reclassify.
- Spec gaps — that's `[NEEDS CLARIFICATION]` during authoring or a spec amendment afterward. If you're triaging and realize the entry is a spec gap, that's the `promote-to-spec` path.

## The classifier — three buckets

For each entry, classify into exactly one of:

### 1. Fix in place

The defect is genuinely sub-spec: an internal rough edge with no observable behavioral contract — the spec deliberately doesn't speak to it, and a caller can't depend on either behavior.

Resolution:

1. Reproduce (write a failing test if it's testable behavior).
2. Fix it under `Sources/`.
3. Verify with `mise run test`.
4. Delete the entry.
5. Commit per `.claude/rules/commit-discipline.md` — scope `swift` (or the relevant spec ID), subject `<scope>: <short description>`. The body briefly notes the defect that prompted the fix; that's the durable record.

### 2. Promote to spec

While reproducing, you realize the spec actually _should_ speak to this — there's a missing scenario, an unspecified ordering guarantee, an unhandled failure mode, a behavioral contract callers will depend on.

Stop the fix. "Fix in place" is wrong here, because the behavior is a contract, not an internal choice — that's a spec change.

Resolution:
Specs/
1. Identify the spec(s) that should grow to cover it: a missing scenario in the relevant `story.*`, a new entry under `errors/`, a sharpened invariant in the relevant `domain.*`.
2. Draft the amendment. Add Gherkin scenarios with stable sub-IDs per `specs/CONVENTIONS.md`.
3. Surface to the user for approval before the spec edit lands — promotion is a deliberate act.
4. Once approved, commit the spec change (`specs: …` or the spec-id scope).
5. Run `/sdd-apply <spec-id>` to land the implementation + tests, mediated by the spec.
6. Delete the original `DEFECTS.md` entry — the spec change plus the implementation commit are the record.

### 3. Won't fix by design

The defect is real but acceptable: a deliberate trade-off, a known limitation the user is comfortable with.

Resolution:

1. State the rationale clearly: why is this acceptable?
2. Delete the entry.
3. Note the rationale _briefly_ in the deletion commit (`swift: drop <title> from defects — <one-line reason>`).
4. Do **not** add a "won't fix" section to `DEFECTS.md`. The commit is the record. Re-adding the entry later (if it turns out to matter) is cheaper than letting the file grow a graveyard column.

If you keep classifying the same kind of defect as "won't fix," that's a signal — the relevant spec should explicitly acknowledge the trade-off. Surface that pattern to the user.

## Process per entry

1. **Read the entry** fully. If repro steps are unclear, ask the user — don't guess.
2. **Reproduce.** For non-trivial defects, invoke `systematic-debugging` and follow the four-phase discipline. A reactive-behavior defect should become a failing test (run counts / ordering / values).
3. **Classify.** State the bucket and the reasoning before acting. Apply the promotion test (below) explicitly — don't default to "fix in place" just because it's fastest.
4. **Execute** the resolution for that bucket.
5. **Delete** the entry from `DEFECTS.md`.
6. **Commit** per `.claude/rules/commit-discipline.md`. One defect, one fix, one commit.

## The promotion test

Before classifying as "fix in place," explicitly ask:

> Is this an observable behavioral contract a caller can depend on — a value, a run count, an ordering, an error — or an internal choice the library is free to change?

If it's a **contract** — callers can observe and rely on it — it belongs in the spec, not in `DEFECTS.md`. Promote. This is the sameSpecs/`specs/CONVENTIONS.md` uses to decide what is and isn't a spec.

If it's a genuinely **internal** choice with no observable contract, fix in place.

This test is the most important step in the skill. Skipping it produces a `DEFECTS.md` full of entries that are quietly behavioral contracts, and a spec that doesn't say so.

## The drain principle

Entries should leave `DEFECTS.md` faster than they enter. The file is a drain, not a tracker. If you notice it growing across sessions, surface the pattern — either triage isn't happening often enough, or what's landing in the file should be specs (you're mostly promoting), which means the spec is under-specified for this area.

## Red flags — stop and reclassify

| Symptom                                                                | What it means                                                                          |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| You're about to write a test tagged with a spec ID to cover the defect | It's a behavioral contract. Promote.                                                   |
| The "fix" changes an observable value, run count, ordering, or error   | It's a behavioral contract. Promote.                                                   |
| You're tempted to add `// SPEC: manual` to justify the fix             | Allowed for genuine internals — double-check there's no caller-visible contract first. |
| The entry has been sitting across multiple sessions                    | Triage it now or promote it. Don't leave it.                                           |
| You're tempted to mark the entry "deferred" or "needs investigation"   | That's `DEFECTS.md` becoming a tracker. Delete or commit to a bucket.                  |
| Multiple entries describe the same underlying issue                    | One root cause. Fix or promote once; delete all entries.                               |

## Anti-patterns

- **"Closed" markers.** Don't accumulate fixed entries with a "closed" annotation. Delete them. The commit is the record.
- **Severity, priority, assignee.** Don't add these fields. If you find yourself wanting them, you're rebuilding Jira.
- **Batched fixes.** Don't bundle unrelated entries into one commit just because they share `DEFECTS.md`. One defect, one fix, one commit.
- **Speculative entries.** If you can't reproduce, you can't classify. Ask the user for clearer repro.
- **Skipping the promotion test.** "Just fix it locally" is the wrong default. The test is short; run it.

## Related skills

- `systematic-debugging` — the four-phase discipline for reproducing and root-causing each entry before classifying.
- `brainstorming-feature` — for the promote-to-spec path when the amendment is large enough to warrant spec-style exploration (a new story). Smaller amendments (a scenario, an error entry) can be edited directly.
- `verification-before-completion` — the gate before claiming an entry is fixed. Run `mise run test`; read its output; only then delete the entry.
- `implementing-a-spec` — the workflow `/sdd-apply` uses to land a promoted spec change.
