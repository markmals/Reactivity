# Stack

The toolchain for this repo. It is a single Swift library built with Swift-native tools only — no UI frameworks, no backend, no other languages.

## Specification

| Concern             | Choice                                        |
| ------------------- | --------------------------------------------- |
| Product specs       | Markdown in `Specs/` & `Features/`            |
| Acceptance criteria | Gherkin-in-markdown (see `writing-behaviors`) |
| Reverse pointers    | `// SPEC: <id>` comments in `Sources/`        |
| Agent instructions  | `CLAUDE.md` + `.claude/`                      |

## Language & package

| Concern         | Choice                                                                             | Docs                                                                |
| --------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Language        | Swift 6 (`swift-tools-version: 6.1`), `StrictConcurrency` upcoming-feature enabled | [docs.swift.org/swift-book](https://docs.swift.org/swift-book/)     |
| Package manager | Swift Package Manager                                                              | [swift.org/package-manager](https://www.swift.org/package-manager/) |
| Build           | `swift build` (via `mise run build`)                                               | —                                                                   |
| Deployment      | macOS 15+ · iOS 18+ (library deployment targets in `Package.swift`)                | —                                                                   |

## Testing

| Concern        | Choice                                                                                            | Docs                                                                                           |
| -------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Test framework | Swift Testing (`import Testing`, `@Suite` / `@Test`, `#expect` / `#require`)                      | [developer.apple.com/documentation/testing](https://developer.apple.com/documentation/testing) |
| Runner         | `swift test` (via `mise run test`)                                                                | —                                                                                              |
| Spec tagging   | `.spec(...)` / `.scenario(...)` custom traits + raw-identifier names — see `Specs/CONVENTIONS.md` | —                                                                                              |
| Properties     | Parameterized `@Test(arguments:)` for "for all" invariants — see `test-driven-development`        | —                                                                                              |

## Formatting & linting

| Concern             | Choice                                      | Docs                                                                           |
| ------------------- | ------------------------------------------- | ------------------------------------------------------------------------------ |
| Swift format / lint | swift-format (config: `.swift-format.json`) | [github.com/swiftlang/swift-format](https://github.com/swiftlang/swift-format) |
| Markdown/JSON/TOML  | dprint (config: `dprint.jsonc`)             | [dprint.dev](https://dprint.dev)                                               |

`mise run fmt` formats (swift-format for `.swift`, dprint for `.md`/`.json`/`.toml`); `mise run lint` runs `swift-format lint --strict`. The `format-on-edit` and `stop-lint` hooks dispatch to these.

## Documentation

| Concern  | Choice                                           | Docs                                                                                                          |
| -------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| API docs | DocC via the Swift DocC plugin (`mise run docs`) | [apple.github.io/swift-docc-plugin](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/) |

## Local tooling

| Concern        | Choice                                         | Docs                                 |
| -------------- | ---------------------------------------------- | ------------------------------------ |
| Task / version | mise (`mise.toml`)                             | [mise.jdx.dev](https://mise.jdx.dev) |
| Editor config  | `.vscode/` (tracked: `extensions`, `settings`) | —                                    |

## Lineage

This library is a Swift realization of the fine-grained reactive model from [Solid.js](https://www.solidjs.com) and Leptos' [`reactive_graph`](https://github.com/leptos-rs/leptos/tree/main/reactive_graph) crate — it began as a 1:1 translation of the latter. See `README.md` for the discussion threads behind the design.
