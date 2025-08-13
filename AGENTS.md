# Swift Fine Grained Reactivity library - Agent Instructions

This package contains the API and implemented tests for a fine-grained reactive system for Swift, similar to that of [Solid.js](https://www.solidjs.com).

## Reactive Algorithm

I want to base the algorithm on that of [Alien Signals](https://github.com/stackblitz/alien-signals). I've included the entire implementation of Alien Signals (originally TypeScript) and other documentation on their algorithm in `./Resources/alien-signals/`. Read these resources thoroughly before implementing the reactive algorithm.

[Leptos](https://github.com/leptos-rs/leptos/tree/main/reactive_graph), a Rust library that implements a very similar reactivity algorithm, leans into idiomatic Rust by making its nodes value types in the graph and embracing the limitations the borrow checker imposes for a faster result in a language that has these levers to pull. I want to mimic that part of the Leptos architecture in Swift, which has almost all of the same levers as Rust, while keeping the superior Alien Signals algorithm. I've included the entire implementation of Leptos' Reactive Graph (originally Rust) and other documentation on their algorithm in `./Resources/leptos_reactive_graph/`. Read these resources thoroughly before implementing the reactive algorithm.

Reactivity thrives on shared state, but Rust fights uncontrolled mutability. Framework authors resolve this by localizing side effects or using message passing. Ownership rules thus shape the entire reactive design. When done well, it yields an architecture with clear data flow and minimal confusion about who can mutate what.

## Swift Concurrency

Since we're using Swift 6's strict concurrency mode we need to make sure this all works well with Swift concurrency. Ideally, we would be able to have several different `@State` values being written to on different actor isolations and read inside of several different `observe` blocks on different actor isolations and they could all run concurrently without any data race corruptions.

My thought is that we should protect the `@State` storage by a `Mutex` from the built-in `Synchronization` package and then propagate "global" contexts needed for `observe` blocks through `@TaskLocal` storage `.withValue` calls hidden inside of `observe` and `withReactiveScope` (and `withoutTracking`?) calls.

`Thread.threadDictionary` doesn’t properly work with Swift Concurrency so it’s not an option. `Thread.threadDictionary` is **NEVER** an option.

That way, nothing is explicitly tied to the MainActor, we can run `observe` computations or `@DerivedState` derivations in parallel on multiple different actors or we can force them onto the MainActor if e.g. UIKit requires that.

Another thing I want to consider here is that the Leptos creator once said that the Leptos signals, since they're `Copy` instead of `Clone`, can be serialized easily to send across the wire... This is something I'd eventually like to explore so it would be cool if the nodes in our graph were not just `Sendable`, but also `Codable`... Think on it, doesn't have to be immediately.

## General Notes

- If it seems suitable and an internal part or feature is large enough, consider creating a separate target and library for in in `./Sources/` to keep the architecture modular.
- For `./Sources/ReactiveGraph`: Group related types in the same file, but create separate files for each category of "thing". We shouldn't have an `API.swift` file once everything is implemented.
- Don't forget that the `package` access level is available in Swift now.
- Use inferred types whenever possible (e.g. prefer `var foo = 0` to `var foo: Int = 0`).
- Elide closure arguments whenever possible (e.g. prefer `{` to `{ _ in`).
- Prefer expressiveness and clarity over terseness.
- Remove any unnecessary function or method overloads. I'm coming back to Swift after spending a while with TypeScript and I don't remember what is needed in Swift and what isn't, so the API may not be as clean as it could be.
- When writing new APIs (internal or external), reference the Swift API Design Guidelines found in `./Resources/api-design-guidelines.md` when making decisions
