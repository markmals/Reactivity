import ReactiveGraph
import Testing

@Suite(.spec("behavior.reactive.effects"))
struct EffectTests {
    @Test(.scenario("behavior.reactive.effects.dispose-stops"))
    func `stops re-running an effect after it is disposed`() {
        withReactiveScope {
            @State var a = 1
            var computationCount = 0
            @DerivedState var b = {
                computationCount += 1
                return a * 2
            }()

            let handle = observe {
                // Trigger read
                _ = b
            }

            #expect(computationCount == 1)
            a = 2
            #expect(computationCount == 2)
            handle.dispose()
            a = 3
            #expect(computationCount == 2)
        }
    }

    @Test(.scenario("behavior.reactive.effects.settles-unchanged"))
    func `does not re-run an effect when a value settles unchanged`() {
        withReactiveScope {
            @State var a = 0
            @DerivedState var b = a % 2

            var innerTriggerTimes = 0
            observe {
                observe {
                    // Trigger read
                    _ = b
                    innerTriggerTimes += 1
                    #expect(innerTriggerTimes < 2)
                }
            }

            a = 2
        }
    }

    @Test(.scenario("behavior.reactive.effects.change-through-chain"))
    func `re-runs an effect once for a change reached through a chain`() {
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

            var triggers = 0
            observe {
                // Trigger read
                _ = d
                triggers += 1
            }

            #expect(triggers == 1)
            a = true
            #expect(triggers == 2)
        }
    }
}

@Suite(.spec("behavior.reactive.effect-ordering"))
struct EffectOrderingTests {
    @Test(.scenario("behavior.reactive.effect-ordering.registration-order"))
    func `runs sibling effects in registration order`() {
        withReactiveScope {
            @State var a = 0
            @State var b = 0
            var order: [String] = []

            withReactiveScope {
                observe {
                    order.append("first inner")
                    // Trigger read
                    _ = a
                }
                observe {
                    order.append("last inner")
                    // Trigger read
                    _ = a
                    _ = b
                }
            }

            order.removeAll()
            b = 1
            a = 1
            #expect(order == ["first inner", "last inner"])
        }
    }

    @Test(.scenario("behavior.reactive.effect-ordering.nested-registration-order"))
    func `runs nested effects in registration order`() {
        withReactiveScope {
            @State var a = 0
            @State var b = 0
            @DerivedState var c = a - b
            var order: [String] = []

            observe {
                // Trigger read
                _ = c
                observe {
                    order.append("first inner")
                    // Trigger read
                    _ = a
                }
                observe {
                    order.append("last inner")
                    // Trigger read
                    _ = a
                    _ = b
                }
            }

            order.removeAll()
            b = 1
            a = 1
            #expect(order == ["first inner", "last inner"])
        }
    }

    @Test(.scenario("behavior.reactive.effect-ordering.duplicate-subscribers"))
    func `keeps run order when a source has duplicate subscribers`() {
        withReactiveScope {
            @State var source1 = 0
            @State var source2 = 0
            var order: [String] = []

            observe {
                order.append("a")
                if $source2.peek() == 1 {
                    // Trigger read
                    _ = source1
                }
                // Trigger read
                _ = source2
                _ = source1
            }
            observe {
                order.append("b")
                // Trigger read
                _ = source1
            }

            source2 = 1  // establishes a -> b -> a
            order.removeAll()
            source1 = source1 + 1

            #expect(order == ["a", "b"])
        }
    }

    @Test(.scenario("behavior.reactive.effect-ordering.rerun-order"))
    func `re-runs affected effects in registration order`() {
        withReactiveScope {
            @State var a = 0
            @State var b = 0
            var order: [String] = []

            observe {
                observe {
                    // Trigger read
                    _ = a
                    order.append("a")
                }
                observe {
                    // Trigger read
                    _ = b
                    order.append("b")
                }

                #expect(order == ["a", "b"])

                order.removeAll()
                b = 1
                a = 1
                #expect(order == ["b", "a"])
            }
        }
    }
}

@Suite(.spec("behavior.reactive.nested-effects"))
struct NestedEffectTests {
    @Test(.scenario("behavior.reactive.nested-effects.cleanup-before-rerun"))
    func `never runs a disposed inner effect`() {
        withReactiveScope {
            @State var a = 3
            @DerivedState var b = a > 0

            var inner: ObservationHandle?
            observe {
                if b {
                    onCleanup {
                        inner?.dispose()
                        inner = nil
                    }
                    inner = observe {
                        if a == 0 {
                            Issue.record("Must never run when a == 0")
                        }
                    }
                }
            }

            a = 2
            a = 1
            a = 0
        }
    }

    @Test(.scenario("behavior.reactive.nested-effects.outer-first"))
    func `runs the outer effect before its inner effect`() {
        withReactiveScope {
            @State var a = 1
            @State var b = 1

            var inner: ObservationHandle?
            observe {
                if a != 0 {
                    onCleanup {
                        inner?.dispose()
                        inner = nil
                    }
                    inner = observe {
                        // Trigger read
                        _ = b
                        if a == 0 {
                            Issue.record("Must never run when a == 0")
                        }
                    }
                }
            }

            b = 0
            a = 0
        }
    }
}
