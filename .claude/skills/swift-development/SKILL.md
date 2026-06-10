---
name: swift-development
description: Use when writing or modifying library code under `Sources/` or tests under `Tests/`. Covers Swift 6 strict concurrency, value semantics and public-API design, Swift Testing, swift-format, DocC, and SwiftPM idioms for a non-UI reactive library. Complementary to `implementing-a-spec` (process) and `test-driven-development`.
---

# Swift Library Development

How to write Swift in this repo. For the _workflow_ of implementing a spec, see `implementing-a-spec`. For _what to build_, read the spec. This is a **non-UI library** — no UIKit, no SwiftUI, no SwiftData, no networking. The deliverable is a clean, well-tested public API over the reactive graph.

## Stack at a glance

| Concern         | Choice                                                     | Docs                                                                                                             |
| --------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Language        | Swift 6, `StrictConcurrency` enabled                       | [docs.swift.org/swift-book](https://docs.swift.org/swift-book/)                                                  |
| Concurrency     | Swift Concurrency (`async`/`await`, `Sendable`, isolation) | [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) |
| Tests           | Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`)   | [developer.apple.com/documentation/testing](https://developer.apple.com/documentation/testing)                   |
| Package manager | Swift Package Manager                                      | [swift.org/package-manager](https://www.swift.org/package-manager/)                                              |
| Format / lint   | swift-format (`.swift-format.json`)                        | [github.com/swiftlang/swift-format](https://github.com/swiftlang/swift-format)                                   |
| API docs        | DocC (swift-docc-plugin)                                   | [Swift-DocC](https://www.swift.org/documentation/docc/)                                                          |

Apple doesn't publish `/llms.txt` for these — `WebFetch` the canonical URLs when you need a detail.

## Idioms (read before writing code)

### Design the public API first, narrowly

This is a library; its API _is_ the product. Before adding a type or method, decide what's `public` and what isn't. Default to `internal`. Mark internal-only types `// SPEC: manual`; the public types carry their `// SPEC: <id>` reverse pointer. A smaller public surface is a feature — every `public` symbol is a maintenance commitment.

### Value semantics by default; reference types only when identity matters

Prefer `struct`/`enum` with value semantics. The reactive graph has genuine shared mutable identity (a node observed by many computations), so the graph internals are reference types (`final class`) — but the _handles_ users hold (a signal, a memo) should feel value-like and `Sendable`-correct. Make the choice deliberately and state the reasoning in a comment when it's non-obvious.

### Swift 6 concurrency is a contract, not a nuisance

`StrictConcurrency` is on. Sendability and isolation are part of the library's observable behavior:

- Annotate isolation deliberately. If a type is `@MainActor`, that's a contract callers depend on — capture it in the spec, don't add it reflexively to silence a warning.
- `Sendable` conformances are promises. Don't reach for `@unchecked Sendable` to make a warning go away; if you must, justify it in a comment naming the invariant that makes it safe.
- The "currently-tracking observer" ambient context (see `Specs/ARCHITECTURE.md` → Concurrency model) is the load-bearing isolation decision. Treat changes to it as behavior changes: spec first.

### async/await for anything that suspends; no completion handlers

If you bridge a callback API, wrap it once with `withCheckedContinuation` and never expose the callback shape.

### Errors: throw for recoverable, trap for programmer error

A dependency cycle or a read with no reactive context is a defined failure mode — model it as a thrown error or a precondition per its `error.*` spec, not a silent fallback. Don't `try?`-swallow; surface failures (`.claude/rules/code-quality.md` → "No silent fallbacks").

## Tests at the behavior layer

Drive the public API and assert on observable outcomes — values, run counts, ordering — never on graph internals. The graph is pure (see ARCHITECTURE), so tests need no mocks or runtime.

```swift
import Testing

@testable import ReactiveGraph

@Suite(.spec("behavior.reactive.derivation"))
struct Derivation {

    @Test(.scenario("behavior.reactive.derivation.recompute-once"))
    func `a derived value recomputes once when its source changes`() {
        withReactiveScope {
            var runs = 0
            @State var source = 0
            @DerivedState var doubled = { runs += 1; return source * 2 }()

            _ = doubled            // initial computation
            #expect(runs == 1)
            source = 5
            #expect(doubled == 10)
            #expect(runs == 2)     // recomputed once, not twice
        }
    }
}
```

- The spec/scenario IDs ride on `.spec(...)` / `.scenario(...)` traits (defined in `Tests/ReactiveGraphTests/SpecTraits.swift`); the test name is a raw identifier that reads like a sentence. Drift tooling greps the trait args. See `Specs/CONVENTIONS.md`.
- Invariants ("for all") get a parameterized `@Test(arguments:)` or a generated-input property test, not just one example — see `test-driven-development`.
- Run counts and ordering are the soul of a reactive library's tests: a behavior that produces the right value but recomputes twice is a bug a value-only assertion misses.

## DocC

Document every `public` symbol with `///`. A symbol worth exposing is worth a doc comment explaining its contract (especially _when_ effects run and _how often_). Build with `mise run docs`.

## When to invoke a more specific skill

- About to write tests? → `test-driven-development`
- About to claim work is done? → `verification-before-completion`
- Debugging something unexpected? → `systematic-debugging`
- Implementing a spec end-to-end? → `implementing-a-spec`

## Commit

Land focused, atomic commits at natural boundaries — typically per spec ID, or per cohesive refactor. See `.claude/rules/commit-discipline.md`. `Package.swift` changes go in their own commit (scope: `package`); formatter/tooling config changes too (scope: `tooling`).
