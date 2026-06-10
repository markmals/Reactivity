import Testing

// SPEC: manual
// Test-association traits. `.spec(_:)` binds a suite (or test) to the spec ID it
// verifies; `.scenario(_:)` binds a test to the Gherkin scenario sub-ID it pins.
// The dotted IDs are carried verbatim so drift/coverage tooling can grep them.
// See specs/CONVENTIONS.md → "Tests carry the same IDs".

/// Associates a suite or test with the spec ID it verifies.
struct SpecTrait: TestTrait, SuiteTrait {
    let id: String
}

/// Associates a test with the Gherkin scenario sub-ID it pins.
struct ScenarioTrait: TestTrait {
    let id: String
}

extension Trait where Self == SpecTrait {
    /// `.spec("story.reactive.derivation")`
    static func spec(_ id: String) -> Self { SpecTrait(id: id) }
}

extension Trait where Self == ScenarioTrait {
    /// `.scenario("scenario.reactive.derivation.recompute-once")`
    static func scenario(_ id: String) -> Self { ScenarioTrait(id: id) }
}
