---
description: Read-only cross-artifact consistency check for a feature folder.
argument-hint: <feature-slug-or-id>
---

# /sdd-analyze $ARGUMENTS

You are analyzing a single feature for cross-artifact consistency: `$ARGUMENTS`.

Argument forms:

- A feature slug: `0001-managing-items`
- A feature ID: `0001`

## Intent

A non-destructive consistency check across all spec files in `features/<NNNN>-<slug>/`. Identify gaps, contradictions, and dangling references **without modifying anything**. Inspired by spec-kit's `/speckit.analyze`.

## Operating constraint

**STRICTLY READ-ONLY.** Do not edit any files. Output a structured report. Offer remediation suggestions, but the user must invoke `/sdd-clarify`, edit manually, or invoke `/sdd-apply` to act on findings.

## Checks to perform

### 1. Coverage

- Does `NARRATIVE.md` exist and have substantive content (not just placeholder comments)?
- Does `stories/` contain at least one story?
- For every entity referenced in the narrative or stories, does `models/` contain a corresponding `domain.<entity>.md`? (Or is it expected to be cross-cutting in `specs/models/`?)
- For every behavior referenced in stories or use-cases, does the feature contain a matching `use-case.<feature>.<name>.md`?
- For every error mentioned in stories, does `errors/` contain a matching `error.<domain>.<kind>.md`?

### 2. Reference integrity

- Walk every `depends-on:` entry in every spec file's frontmatter. Does the referenced ID exist somewhere in `features/` or `specs/`?
- Walk every inline reference (e.g. "see `domain.item`") in spec body text. Does the referenced ID exist?

### 3. Story / scenario consistency

- Every story has at least one Acceptance Criteria scenario.
- Every scenario has a `<!-- id: scenario.<feature>.<capability>.<short-name> -->` marker.
- Scenario IDs are unique within the feature.
- Scenario IDs follow the convention (lowercase, dotted, descriptive).
- Each story's `**Independent test:**` line is non-empty (or absent and acknowledged).

### 4. Outstanding clarifications

- Count `[NEEDS CLARIFICATION: ...]` markers per file.
- A feature with any outstanding markers is **not ready for `/sdd-apply`**.

### 5. Use-case / domain alignment

- Every use-case's `depends-on` includes the domain models it operates on.
- Every use-case's actions correspond to user actions described in at least one story.
- Every observable outcome in a use-case maps to either a domain field or a derived value.

### 6. Constitutional compliance

(See `specs/CONVENTIONS.md`.)

- Every spec file has frontmatter with `id`, `kind`.
- ID matches filename stem (with dots).
- Kind is in the kind taxonomy.
- No spec file in the wrong directory for its kind.

## Output format

```
ANALYSIS REPORT — feature: <slug>
==================================

Coverage
--------
✅ NARRATIVE.md present (N words)
❌ MISSING: stories/ (no story files)
✅ models/ has 2 entries: domain.signal, domain.computed
⚠ models/ missing: domain.<entity> referenced in story.<id>

Reference integrity
-------------------
❌ story.signal.create depends-on: domain.signal (NOT FOUND in features/0001 or specs/)
✅ all other depends-on references resolve

Story / scenario consistency
----------------------------
⚠ story.signal.create scenario 2 missing scenario sub-ID
✅ all other scenarios have IDs and are unique

Outstanding clarifications
--------------------------
⚠ 3 [NEEDS CLARIFICATION] markers remaining (run /sdd-clarify <feature>):
  - features/0001/stories/signal.create.md:14 — propagation order not specified
  - features/0001/models/signal.md:22 — equality semantics
  - features/0001/errors/signal.cycle.md:9 — recovery affordance

Use-case / domain alignment
---------------------------
✅ use-case.graph.recompute depends on domain.signal (exists)

Constitutional compliance
-------------------------
✅ all frontmatter valid

Summary
-------
Findings:  2 critical, 1 warning, 3 clarifications
Status:    NOT READY for /sdd-apply
Suggested next action: /sdd-clarify 0001-managing-items
```

## Severity rules

- **Critical (❌):** missing required artifacts, broken references, frontmatter violations
- **Warning (⚠):** non-blocking inconsistencies, style violations, missing optional artifacts
- **Info (✅):** confirmed-correct items (include for the positive signal)

## Implementation status

Manual: walk the feature directory, read frontmatter from each file, build a reference graph, run the checks above. No external tooling required.
