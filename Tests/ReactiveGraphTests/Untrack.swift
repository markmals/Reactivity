import ReactiveGraph
import Testing

@Suite(.spec("behavior.reactive.untracking"))
struct WithoutTrackingTests {
    @Test(.scenario("behavior.reactive.untracking.derived-without-tracking"))
    func `creates no dependency for a source read inside withoutTracking in a derived value`() {
        withReactiveScope {
            @State var source = 0

            var computedTriggerCount = 0
            @DerivedState var c = {
                computedTriggerCount += 1
                return withoutTracking { source }
            }()

            #expect(c == 0)
            #expect(computedTriggerCount == 1)

            source = 1
            source = 2
            source = 3

            #expect(c == 0)
            #expect(computedTriggerCount == 1)
        }
    }

    @Test(.scenario("behavior.reactive.untracking.effect-without-tracking"))
    func `creates no dependency for a source read inside withoutTracking in an effect`() {
        withReactiveScope {
            @State var source = 0
            @State var gate = 0

            var observationTriggerCount = 0
            observe {
                observationTriggerCount += 1
                if gate > 0 {
                    withoutTracking {
                        // Trigger read
                        _ = source
                    }
                }
            }

            #expect(observationTriggerCount == 1)

            gate = 1
            #expect(observationTriggerCount == 2)

            source = 1
            source = 2
            source = 3
            #expect(observationTriggerCount == 2)

            gate = 2
            #expect(observationTriggerCount == 3)

            source = 4
            source = 5
            source = 6
            #expect(observationTriggerCount == 3)

            gate = 0
            #expect(observationTriggerCount == 4)

            source = 7
            source = 8
            source = 9
            #expect(observationTriggerCount == 4)
        }
    }
}

@Suite(.spec("behavior.reactive.untracking"))
struct PeekTests {
    @Test(.scenario("behavior.reactive.untracking.derived-peek"))
    func `creates no dependency for a source read through peek in a derived value`() {
        withReactiveScope {
            @State var source = 0

            var computedTriggerCount = 0
            @DerivedState var c = {
                computedTriggerCount += 1
                return $source.peek()
            }()

            #expect(c == 0)
            #expect(computedTriggerCount == 1)

            source = 1
            source = 2
            source = 3

            #expect(c == 0)
            #expect(computedTriggerCount == 1)
        }
    }

    @Test(.scenario("behavior.reactive.untracking.effect-peek"))
    func `creates no dependency for a source read through peek in an effect`() {
        withReactiveScope {
            @State var source = 0
            @State var gate = 0

            var observationTriggerCount = 0
            observe {
                observationTriggerCount += 1
                if gate > 0 {
                    // Trigger read
                    _ = $source.peek()
                }
            }

            #expect(observationTriggerCount == 1)

            gate = 1
            #expect(observationTriggerCount == 2)

            source = 1
            source = 2
            source = 3
            #expect(observationTriggerCount == 2)

            gate = 2
            #expect(observationTriggerCount == 3)

            source = 4
            source = 5
            source = 6
            #expect(observationTriggerCount == 3)

            gate = 0
            #expect(observationTriggerCount == 4)

            source = 7
            source = 8
            source = 9
            #expect(observationTriggerCount == 4)
        }
    }
}
