# Feature Template

This directory holds the **canonical templates** for a new feature. When starting a feature, copy the structure here into `Features/<NNNN>-<slug>/` and replace the placeholders.

## Layout

```
.claude/templates/feature/
├── README.md                ← this file
├── NARRATIVE.md             ← single file per feature
├── behaviors/BEHAVIOR.md    ← copy + rename per behavior
├── models/MODEL.md          ← copy + rename per model
└── errors/ERROR.md          ← copy + rename per error
```

## How to use

1. Pick the next number: `Features/<NNNN>-<slug>/`. Slug is kebab-case.
2. Copy this directory's structure into the new feature directory:
   ```sh
   mkdir -p Features/<NNNN>-<slug>/{behaviors,models,errors}
   cp .claude/templates/feature/NARRATIVE.md Features/<NNNN>-<slug>/NARRATIVE.md
   ```
3. Replace placeholders in the copied files:
   - `<feature-slug>` — the kebab-case slug (e.g. `managing-items`)
   - `<id>` — a stable dotted ID (e.g. `behavior.reactive.glitch-free`)
   - Section content
4. For each new spec instance (behavior, model, error), copy the appropriate `<KIND>.md` template into the matching subdirectory and rename to `<id>.md` (using dots in the filename: `reactive.glitch-free.md`).
5. See `Specs/CONVENTIONS.md` for ID rules.

## Cross-cutting specs

Cross-cutting specs (`ARCHITECTURE.md`, `CONVENTIONS.md`, `STACK.md`) are singletons that already exist, so there's no template for them. For a promoted model, copy the relevant feature template (e.g. `models/MODEL.md`) into `Specs/models/<id>.md` and update the frontmatter.
