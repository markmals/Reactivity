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

A non-destructive consistency check across all spec files in `Features/<NNNN>-<slug>/`. Identify gaps, contradictions, and dangling references **without modifying anything**. Inspired by spec-kit's `/speckit.analyze`.

## Operating constraint

**STRICTLY READ-ONLY.** Do not edit any files. Output a structured report. Offer remediation suggestions, but the user must invoke `/sdd-clarify`, edit manually, or invoke `/sdd-apply` to act on findings.

## Checks to perform

### 1. Coverage

- Does `NARRATIVE.md` exist and have substantive content (not just placeholder comments)?
- Does `behaviors/` contain at least one behavior?
- For every entity referenced in the narrative or behaviors, does `models/` contain a corresponding `domain.<entity>.md`? (Or is it expected to be cross-cutting in `Specs/models/`?)
- For every error mentioned in behaviors, does `errors/` contain a matching `error.<domain>.<kind>.md`?

### 2. Reference integrity

- Walk every `depends-on:` entry in every spec file's frontmatter. Does the referenced ID exist somewhere in `Features/` or `Specs/`?
- Walk every inline reference (e.g. "see `domain.item`") in spec body text. Does the referenced ID exist?

### 3. Behavior / scenario consistency

- Every behavior has at least one Acceptance Criteria scenario.
- Every scenario has a `<!-- id: behavior.<feature>.<capability>.<short-name> -->` marker.
- Scenario IDs are unique within the feature.
- Scenario IDs follow the convention (lowercase, dotted, descriptive).
- Each behavior's `**Independent test:**` line is non-empty (or absent and acknowledged).

### 4. Outstanding clarifications

- Count `[NEEDS CLARIFICATION: ...]` markers per file.
- A feature with any outstanding markers is **not ready for `/sdd-apply`**.

### 5. Behavior / domain alignment

- Every behavior's `depends-on` includes the domain models it operates on.
- Every observable outcome in a behavior maps to either a domain field or a derived value.

### 6. Constitutional compliance

(See `Specs/CONVENTIONS.md`.)

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
❌ MISSING: behaviors/ (no behavior files)
✅ models/ has 2 entries: domain.signal, domain.computed
⚠ models/ missing: domain.<entity> referenced in behavior.<id>

Reference integrity
-------------------
❌ behavior.signal.create depends-on: domain.signal (NOT FOUND in Features/0001/Specs/)
✅ all other depends-on references resolve

Behavior / scenario consistency
----------------------------
⚠ behavior.signal.create scenario 2 missing scenario sub-ID
✅ all other scenarios have IDs and are unique

Outstanding clarifications
--------------------------
⚠ 3 [NEEDS CLARIFICATION] markers remaining (run /sdd-clarify <feature>):
  - Features/0001/behaviors/signal.create.md:14 — propagation order not specified
  - Features/0001/models/signal.md:22 — equality semantics
  - Features/0001/errors/signal.cycle.md:9 — recovery affordance

Behavior / domain alignment
---------------------------
✅ behavior.graph.recompute depends on domain.signal (exists)

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
