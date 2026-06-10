---
description: Bring the spec into line with the current implementation (impl-led change).
argument-hint:
---

# /sdd-reconcile

You are reconciling: the current implementation is treated as the **temporary source of truth**, and the spec must come into alignment with it.

## When to use this

Use this when the implementation has been edited directly (a fix, a new behavior, a refactor that changes externals) and the spec is now stale. This is the inverse of `/sdd-apply`: instead of applying the spec to the code, you are applying the code to the spec.

This is **not for fixing bugs that were already in the spec**. Just edit the impl in that case. Reconcile when the _behavior_ changed, not when the implementation was made correct.

Decide first which it is: a divergence is either a **bug to fix** (the spec was right, the code drifted — fix the code, don't touch the spec) or a **behavior change to absorb** (the spec was wrong or incomplete — update the spec to match the new behavior). Only the latter is reconciliation.

## Steps

1. **Determine which spec IDs were touched.** `rg "SPEC: " Sources/` filtered by recently-modified files (`git diff` against the last reconciled state).
2. **For each affected spec ID:** a. Read the current implementation and tests. b. Read the spec. c. Identify the behavioral diff: state, actions, transitions, observable outcomes. d. Decide bug-to-fix vs. behavior-to-absorb (above). If it's a bug, stop and route to a code fix instead. e. Propose a spec update (markdown diff). **Surface this to the user for review.**
3. **Do not auto-merge.** Every spec change is reviewed by the user.

## What gets reconciled

- Spec content (the markdown).

## What does NOT get reconciled

- The implementation (it's the input, not the output).
- Spec IDs (always stable).
- Architecture or conventions documents (those need a deliberate edit, not reconciliation).

## Commit boundaries

Reconciliation produces a spec-update commit, landed after the user approves the markdown diff. Subject: `<spec-id>: reconcile spec with implementation behavior` (the scope is the spec ID — Scoped Commits, see `.claude/rules/commit-discipline.md`). Body explains what the implementation now does that the spec didn't capture.

Never bundle the spec edit with an implementation change — the spec change must be reviewable in isolation. See `.claude/rules/commit-discipline.md`.

## Implementation status

Manual until tooling lands. The agent can drive each step with the existing read/edit tools and `git diff`.
