import ReactiveGraph
import Testing

@Suite(.spec("behavior.reactive.derivation"))
struct DerivedTests {
    @Test(.scenario("behavior.reactive.derivation.chained-propagation"))
    func `propagates a change through a chain of derived values`() {
        withReactiveScope {
            @State var source = 0
            @DerivedState var c1 = source % 2
            @DerivedState var c2 = c1
            @DerivedState var c3 = c2

            // Trigger read
            _ = c3
            source = 1  // c1 -> dirty, c2 -> toCheckDirty, c3 -> toCheckDirty
            // Trigger read
            _ = c2  // c1 -> none, c2 -> none
            source = 3  // c1 -> dirty, c2 -> toCheckDirty
            #expect(c3 == 1)
        }
    }

    @Test(.scenario("behavior.reactive.derivation.multi-path-source"))
    func `reflects a source change reached by two paths`() {
        withReactiveScope {
            @State var source = 0
            @DerivedState var a = source
            @DerivedState var b = a % 2
            @DerivedState var c = source
            @DerivedState var d = b + c

            #expect(d == 0)
            source = 2
            #expect(d == 2)
        }
    }
}

@Suite(.spec("behavior.reactive.equality-gating"))
struct DerivedEqualityGatingTests {
    @Test(.scenario("behavior.reactive.equality-gating.indirect-check"))
    func `settles a value correctly when an intermediate input is re-checked`() {
        withReactiveScope {
            @State var a = false
            @DerivedState var b = a

            @DerivedState var c = {
                // Trigger read
                _ = b
                return 0
            }()

            @DerivedState var d = {
                // Trigger read
                _ = c
                return b
            }()

            #expect(d == false)
            a = true
            #expect(d == true)
        }
    }

    @Test(.scenario("behavior.reactive.equality-gating.reverted-source"))
    func `does not recompute when a source is changed and reverted`() {
        withReactiveScope {
            var computationCount = 0

            @State var source = 0

            @DerivedState var derived = {
                computationCount += 1
                return source
            }()

            // Trigger read
            _ = derived
            #expect(computationCount == 1)
            source = 1
            source = 0
            // Trigger read
            _ = derived
            #expect(computationCount == 1)
        }
    }
}
