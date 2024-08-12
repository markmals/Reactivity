# Reactivity

> [!CAUTION]
> This package is still very much a work-in-progress and is not yet fully implemented!

An implementation of a fine-grained reactive system for Swift, similar to that of [Solid.js](https://www.solidjs.com). The algorithm is based on [Leptos' `reactive_graph` crate](https://github.com/leptos-rs/leptos/tree/main/reactive_graph). This package started out as a 1:1 translation of Leptos' Rust source code to Swift.

## Discussion & Questions

-   [Why Thread Local? Technical question about reactivity implementation](https://github.com/leptos-rs/leptos/discussions/2807)
-   [This conversation](https://universeodon.com/@markmalstrom/112932995815099210) between [@markmalstrom@universeodon.com](https://universeodon.com/@markmalstrom) and [@mattiem@mastodon.social](https://mastodon.social/@mattiem)
-   [This gist](https://gist.github.com/markmals/e880043a5f59436b2cc581f9692e6fd6) with an exploration of a minimal auto-tracking reactivity API in Swift and the resulting conversation between Matt and myself in the comments
