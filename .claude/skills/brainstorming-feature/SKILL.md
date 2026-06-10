---
name: brainstorming-feature
description: Use before starting any new feature or substantial change to an existing one. Walks the user through narrative → stories → models → errors, populating a feature folder. Lifts patterns from superpowers' brainstorming skill but is tuned to our features-vs-specs structure and our `[NEEDS CLARIFICATION]` convention.
---

# Brainstorming a Feature

Help the user shape an idea into a populated feature folder. The feature folder _is_ the spec; there is no separate plan document. By the end of this skill, `features/<NNNN>-<slug>/` should contain a NARRATIVE plus enough stories, models, and errors to drive `/sdd-apply <id>` against the Swift library.

**Default workspace:** the user's current branch (typically `main`). Do not prompt for a worktree, branch, or isolation. If the user explicitly requests an isolated workspace, that's a separate skill and a separate decision.

## When to use

- The user wants to add a new feature to the product.
- The user wants to substantially change an existing feature (more than a bug fix).
- The user has an idea but isn't yet sure what shape the spec should take.

**Do NOT use this skill for:**

- Bug fixes — go straight to systematic-debugging or test-driven-development.
- Small changes within an existing feature (one new scenario, one error catalog entry) — just edit the relevant file directly.
- Cross-cutting architectural decisions — those belong in `specs/ARCHITECTURE.md` and aren't features.

## The hard gate

Do **not** invoke `/sdd-apply` or write any implementation code until the feature folder has at least:

- a `NARRATIVE.md` with substantive content
- one or more `stories/<id>.md` with Gherkin scenarios
- the user has explicitly approved the spec content

Skipping this gate produces specs that look complete but contain hidden assumptions. Implementation built on those assumptions has to be reworked.

## Process

```
1. Scope check       — is this one feature, or several?
2. Explore context   — read existing specs, architecture, related features
3. Question round    — one at a time, multiple-choice when possible
4. Approach round    — propose 2-3 approaches with tradeoffs, recommend one
5. Author the folder — write NARRATIVE first, then stories, then models/errors
6. Self-review       — scan for placeholders, contradictions, scope creep, [NEEDS CLARIFICATION] count
7. User review gate  — user reviews the populated folder; iterate until approved
8. Hand-off          — point user at /sdd-analyze and /sdd-apply
```

### 1. Scope check

If the user's prompt names multiple unrelated capabilities ("items plus calendar plus messaging"), stop. Tell the user the scope is too large for one feature and propose a decomposition: "what's the independent first slice?". Each feature should produce a working, testable capability on its own.

### 2. Explore context

Before asking detailed questions, read:

- `specs/ARCHITECTURE.md` — for the library's layering (pure graph vs. effectful edges) and constraints
- `specs/CONVENTIONS.md` — refresh on ID rules and `[NEEDS CLARIFICATION]` convention
- Any existing `features/<n>/` folders that touch the same area — find related models to depend on

### 3. Question round

Ask **one question at a time**. Use `AskUserQuestion` with multiple-choice options when the answer space is finite. Open-ended is fine when the question is genuinely exploratory.

Cover these dimensions in roughly this order:

1. **Persona and intent** — who is this for, what are they trying to do?
2. **Trigger and goal** — what makes them start, what do they consider success?
3. **Scope boundaries** — what's in, what's deliberately out for v1?
4. **Constraints** — auth, data retention, privacy, performance targets
5. **Dependencies** — does this depend on existing features or specs?

When you don't know an answer and the user hasn't specified, **do not guess**. Either ask, or insert a `[NEEDS CLARIFICATION: <question>]` marker into the spec and move on.

### 4. Approach round

Propose 2-3 approaches with their tradeoffs. Lead with your recommendation and explain why. Examples of approach decisions:

- Eager vs. lazy evaluation of a derived value
- Equality-gated propagation vs. always-notify
- One primitive with options vs. two distinct primitives
- Throwing API vs. `Result`-returning API for a failure mode

Get explicit approval on the approach before writing files.

### 5. Author the folder

Create `features/<NNNN>-<slug>/` if it doesn't exist (next number, kebab-case slug). Copy templates from `.claude/templates/feature/`:

- **`NARRATIVE.md`** — fill in persona, situation, what we're building, why it matters, what it is not. Optionally fill the Success Criteria section.
- **`stories/<id>.md`** — one file per behavioral story. Use the `writing-user-stories` skill. IDs follow `story.<feature>.<capability>`. Include the Independent Test line. Each scenario gets a sub-ID `scenario.<feature>.<capability>.<short-name>`.
- **`models/<id>.md`** — one file per domain model (a reactive primitive or value type). ID prefix `domain.`. State the shape, semantics, and invariants.
- **`errors/<id>.md`** — one per observable failure mode (e.g. a dependency cycle). ID prefix `error.`.

Mark every unspecified detail with `[NEEDS CLARIFICATION: <question>]` rather than guessing. The `/sdd-clarify` slash command resolves these later.

### 6. Self-review

After authoring, do a quick pass for:

- **Placeholders**: `<id>`, `<feature-slug>`, TODO, TBD — replaced or marked.
- **Contradictions**: does NARRATIVE align with STORIES? Do stories reference models that exist?
- **Scope creep**: did stories accumulate scenarios that belong in a different feature?
- **Ambiguity**: any sentence that could be interpreted two ways?
- **Clarification count**: how many `[NEEDS CLARIFICATION]` markers remain? Note the count for the handoff.

Fix issues inline. No need to re-review.

### 7. User review gate

Tell the user the feature folder is ready and list what was authored:

```
Feature folder authored: features/<NNNN>-<slug>/
- NARRATIVE.md
- stories/ (N stories, M scenarios)
- models/ (N domain models)
- errors/ (N error catalog entries)

Outstanding clarifications: K (run /sdd-clarify <slug> to resolve)
```

Wait for user feedback. If they request changes, make them and re-run the self-review. Only proceed once the user approves.

### 8. Hand-off

Once approved, point the user at the next steps:

- **If clarifications remain:** `/sdd-clarify <slug>` to resolve them.
- **Otherwise:** `/sdd-analyze <slug>` to verify cross-artifact consistency, then `/sdd-apply <story-id-or-domain-id>` to implement against the spec. Use the `implementing-a-spec` skill from there.

### 9. Commit

After the user approves the feature folder, commit the spec content. See `.claude/rules/commit-discipline.md` for message style.

Natural boundaries:

- **One commit for the feature scaffold** when the folder is small enough to read as a single unit: `features/<NNNN>-<slug>: scaffold feature`. Body lists what's inside (N stories, M domain models, etc.).
- **Split by artifact kind** when the folder is large: a NARRATIVE+stories commit, then domain models, then errors. Each commit should leave the feature folder in an internally consistent state.

Use the `features/<slug>` scope (a valid Scoped Commit scope — see `.claude/rules/commit-discipline.md`) for everything authored by this skill. Do not include implementation code in the same commit — that's a separate step driven by `/sdd-apply`.

## Key principles

- **One question at a time.** Don't overwhelm.
- **Multiple-choice when possible.** Easier to answer than open-ended.
- **YAGNI ruthlessly.** Don't add scenarios, fields, or errors that aren't necessary for the user-observable capability.
- **Mark, don't guess.** `[NEEDS CLARIFICATION: <question>]` is the honest answer when the user hasn't specified.
- **Specify behavior, not internals.** A story pins observable behavior (values, run counts, ordering, errors), never a particular Swift type name or graph layout — those are the implementation's to choose.

## Red flags — stop and re-scope

| Symptom                                                         | What it means                                                     |
| --------------------------------------------------------------- | ----------------------------------------------------------------- |
| More than ~6 stories per feature                                | Feature too large; decompose.                                     |
| A story has more than ~6 scenarios                              | Story too large; split into multiple stories.                     |
| Many domain models that don't share an aggregate root           | Two features bundled as one; decompose.                           |
| Story scenarios reference internal types or graph layout        | Implementation creep in a spec; rewrite from observable behavior. |
| `[NEEDS CLARIFICATION]` count > 10 after one round of questions | The idea isn't clear enough yet; loop back to the question round. |

## Anti-patterns

- **No design before code.** Every feature goes through this skill, even small ones. The skill itself can be short for small features (a few questions, two stories, one model) — but it must be invoked.
- **Branching ceremony.** No "create a branch first" steps. Default workspace is `main`.
- **Plan documents.** We don't have plan.md / tasks.md. The feature folder _is_ the plan.
