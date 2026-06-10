# Reactivity — Spec-Driven Swift Library

A fine-grained reactive system for Swift (`ReactiveGraph`), built **spec-first**. The spec is the source of truth; the Swift implementation in `Sources/` satisfies it and the Swift Testing suite in `Tests/` proves it. There is one platform — Swift — so there is no cross-platform reconciliation; reconciliation here is only ever between the **spec, the tests, and the code**.

This repo is a pruned projection of a multiplatform spec-driven template, scoped to a single non-UI Swift library. Everything app-shaped (UI, design system, backends, simulators, other languages) has been removed. What remains is the verified SDD discipline: specs, stories, reverse pointers, TDD, three-stage review, and drift detection.

@.claude/rules/code-quality.md @.claude/rules/commit-discipline.md @.claude/rules/spec-conventions.md

## How this repo works

**Specs are the source of truth.** Domain models (the reactive primitives and their invariants), stories (behavioral scenarios), use cases, and errors live as markdown in `Specs/` (cross-cutting) and `features/<NNNN>-<slug>/` (feature-scoped). The Swift code is a regeneration target: it is brought into conformance with the spec, never the other way around.

If you are tempted to encode a behavioral contract only in code, write a spec for it instead — then implement against the spec.

**Read these before doing anything substantial:**

1. `Specs/CONVENTIONS.md` — spec format, ID taxonomy, frontmatter, reverse pointers, the `// SPEC:` reverse-pointer form for Swift, drift detection. **This is the contract.**
2. `Specs/ARCHITECTURE.md` — the library's layering (pure reactive core vs. effectful edges), module layout, and the spec → Swift mapping.
3. `Specs/STACK.md` — the Swift toolchain: SwiftPM, Swift Testing, swift-format, DocC, mise, dprint.

### Three places work comes from

The work queue derives from three artifacts, in priority order:

1. **Specs and tests** — building or evolving behavior. `/sdd-apply`, `/sdd-verify`, `/sdd-cover`. Source of truth for behavior.
2. **Drift** — spec and implementation out of sync. `/sdd-drift`, `/sdd-reconcile`. Surfaced mechanically from reverse pointers and mtimes.
3. **Defects** — rough edges the spec deliberately doesn't cover (a known-not-yet-fixed quirk, a platform-version-specific wrinkle). Tracked in `DEFECTS.md`, filed via `/sdd-defect`, drained via the `triaging-defects` skill. This file should want to be empty.

If something doesn't fit any of those, it's either a future feature (write a spec) or out of scope.

## Layout

```
.
├── CLAUDE.md                  ← this file
├── Package.swift              ← SPM manifest (library products + targets)
├── Sources/
│   └── ReactiveGraph/         ← the library; reverse pointers (// SPEC: <id>) live here
├── Tests/
│   └── ReactiveGraphTests/    ← Swift Testing suites, tagged with spec + scenario IDs
├── Specs/                     ← cross-cutting specs (CONVENTIONS, ARCHITECTURE, STACK)
├── features/                  ← (you create) feature-scoped specs as <NNNN>-<slug>/
├── DEFECTS.md                 ← (you create) sub-spec defect log; wants to be empty
├── mise.toml                  ← tool versions + tasks (fmt / lint / test / build / docs)
└── .claude/
    ├── agents/                ← subagents for cross-cutting checks (drift, gaps, reviews)
    ├── commands/              ← slash commands (sdd-apply, sdd-verify, sdd-drift, ...)
    ├── hooks/                 ← shell hooks (format-on-edit, stop-lint, scoped-commits, ...)
    ├── rules/                 ← shared content @included by this file
    ├── skills/                ← procedural workflows (brainstorming, TDD, swift-development)
    └── templates/             ← canonical templates for new features and specs
```

**One library, possibly several Swift targets.** Today there is one product, `ReactiveGraph`. The structure accommodates a _set_ of related Swift libraries (additional SPM targets/products) — they share specs and may share ordinary library code. There are no platform projections to keep in sync; it is all Swift, all in `Sources/`.

## Working with specs

- **Reverse pointers are mandatory.** Every type, function, or extension that realizes a spec carries `// SPEC: <id>` in `Sources/`. Tests are tagged with the spec IDs and scenario sub-IDs they verify. See `Specs/CONVENTIONS.md` for the exact Swift form.
- **Spec → test → implementation.** The spec defines what must hold; the test proves it; the code satisfies it. None is the source of truth alone.
- **Deviations are explicit.** Use `// SPEC: <id> (deviates: <reason>)` when the implementation must differ from the spec, and `// SPEC: manual` for genuinely internal code with no behavioral contract (plumbing, performance shims).
- **Stories use Gherkin acceptance criteria.** See the `writing-user-stories` skill. Scenarios have stable sub-IDs that tests trace back to. For this library a "story" is a behavioral scenario over the reactive graph (e.g. _given a memo over a signal, when the signal changes, then the memo recomputes once_).

## Slash commands

| Command                    | Purpose                                                                        |
| -------------------------- | ------------------------------------------------------------------------------ |
| `/sdd-apply <spec-id>`     | Regenerate a spec's Swift implementation + tests in conformance with the spec. |
| `/sdd-verify`              | Run the Swift Testing suite and report which spec IDs pass.                    |
| `/sdd-drift`               | List spec IDs whose implementation is stale, plus impl files with no pointer.  |
| `/sdd-reconcile`           | Bring the spec in line with the current implementation (impl-led changes).     |
| `/sdd-cover <spec-id>`     | Show whether a spec is implemented and which of its tests pass.                |
| `/sdd-challenge <spec-id>` | Adversarially review a spec's implementation — try to break it. Read-only.     |
| `/sdd-defect <desc>`       | File a sub-spec defect into `DEFECTS.md` without breaking flow.                |
| `/sdd-analyze <feature>`   | Read-only cross-artifact consistency check for a feature folder.               |
| `/sdd-clarify <id>`        | Resolve `[NEEDS CLARIFICATION]` markers in a feature or spec with the user.    |

These are agent-driven (no automation yet — the agent uses `rg`, `Edit`, `AskUserQuestion`, etc.).

## Workflow skills

Procedural skills live under `.claude/skills/`. Use them rather than ad-hoc patterns — they encode the discipline this repo expects.

| Skill                            | When to invoke                                                                                                    |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `brainstorming-feature`          | Before starting any new feature or substantial change. Walks narrative → stories → models → errors.               |
| `writing-user-stories`           | When authoring or reviewing a story file. Enforces Gherkin discipline.                                            |
| `implementing-a-spec`            | The default "how to write code" workflow. Per-spec dispatch + three-stage review. Used by `/sdd-apply`.           |
| `test-driven-development`        | When writing any production code. No production code without a failing test first. Invariants get property tests. |
| `adversarial-review`             | The refutational third review stage, after spec-compliance and code-quality pass. Assumes the code is broken.     |
| `verification-before-completion` | Before claiming any work is complete. Run the verifying command in this turn; evidence before claims.             |
| `systematic-debugging`           | When encountering any bug or unexpected behavior. Find the root cause before proposing a fix.                     |
| `triaging-defects`               | When `DEFECTS.md` is non-empty and you're in a polish pass. Classify each entry; resolve; delete.                 |
| `swift-development`              | When writing library code. Swift 6 concurrency, value semantics, Swift Testing, swift-format, DocC, SPM idioms.   |

## Local tooling

`mise` manages tool versions and tasks.

```sh
mise run build     # swift build
mise run test      # swift test (the spec-bound suite)
mise run lint      # swift-format lint --strict
mise run fmt       # swift-format + dprint; pass paths to format just those
mise run docs      # DocC documentation
mise tasks         # list everything available
```

Builds and tests run through `swift` / `mise` — there is no Xcode project to launch; this is a plain SwiftPM package.

## What lives where

| Question                               | Where to look                                   |
| -------------------------------------- | ----------------------------------------------- |
| "What's a spec ID look like?"          | `Specs/CONVENTIONS.md`                          |
| "How do I add a new feature?"          | `Specs/CONVENTIONS.md` → "Adding a new feature" |
| "What's the reverse-pointer form?"     | `Specs/CONVENTIONS.md` → "Reverse pointers"     |
| "How is the library layered?"          | `Specs/ARCHITECTURE.md`                         |
| "What tool does the repo use for X?"   | `Specs/STACK.md`                                |
| "How do I write a user story?"         | `.claude/skills/writing-user-stories/SKILL.md`  |
| "How do I write Swift here?"           | `.claude/skills/swift-development/SKILL.md`     |
| "Should this rule be a hook or prose?" | `.claude/rules/enforcement-hierarchy.md`        |
