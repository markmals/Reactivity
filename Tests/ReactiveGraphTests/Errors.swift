import ReactiveGraph
import Testing

struct TestError: Error {
    init() {}
}

@Suite(.spec("behavior.reactive.error-propagation"))
struct ErrorPropagationTests {
    @Test(.scenario("behavior.reactive.error-propagation.graph-consistent-on-activation"))
    func `surfaces a first read error and keeps other values working`() {
        @State var a = 0
        @DerivedState var b: Never = try {
            throw TestError()
        }()
        @DerivedState var c = a

        #expect(throws: TestError.self) {
            _ = try b
        }

        a = 1
        #expect(c == 1)
    }

    @Test(.scenario("behavior.reactive.error-propagation.graph-consistent-on-recompute"))
    func `surfaces a recompute error and recovers afterward`() {
        @State var a = 0
        @DerivedState var b = try {
            if a == 1 {
                throw TestError()
            }

            return a
        }()
        @DerivedState var c = b

        #expect(c == 0)

        a = 1
        #expect(throws: TestError.self) {
            _ = try b
        }

        a = 2
        #expect(c == 2)
    }

    @Test(.scenario("behavior.reactive.error-propagation.no-handler-propagates"))
    func `propagates an unhandled error out of the scope`() {
        #expect(throws: TestError.self) {
            try withReactiveScope {
                throw TestError()
            }
        }
    }
}

@Suite(.spec("behavior.reactive.error-boundaries"))
struct ErrorBoundaryTests {
    @Test(.scenario("behavior.reactive.error-boundaries.catches-body"))
    func `delivers a thrown error to its handler`() {
        var errored = false

        #expect(throws: Never.self) {
            withReactiveScope {
                onError(
                    { throw TestError() },
                    handle: { _ in
                        errored = true
                    }
                )
            }
        }

        #expect(errored)
    }

    @Test(.scenario("behavior.reactive.error-boundaries.rethrow-to-outer"))
    func `passes a rethrown error to the next handler`() {
        var errored = false

        #expect(throws: Never.self) {
            withReactiveScope {
                onError(
                    {
                        try onError(
                            { throw TestError() },
                            handle: { err in
                                // rethrow to outer handler
                                throw err
                            }
                        )
                    },
                    handle: { _ in
                        errored = true
                    })
            }
        }

        #expect(errored)
    }

    @Test(.scenario("behavior.reactive.error-boundaries.initial-effect"))
    func `catches an error during an effect first run`() {
        var errored = false

        #expect(throws: Never.self) {
            withReactiveScope {
                observe {
                    onError(
                        { throw TestError() },
                        handle: { _ in errored = true }
                    )
                }
            }
        }

        #expect(errored)
    }

    @Test(.scenario("behavior.reactive.error-boundaries.update-effect"))
    func `catches an error when an effect re-runs`() {
        var errored = false

        withReactiveScope {
            @State var s = 0
            observe {
                // read state in observer scope
                let v = s
                onError(
                    {
                        if v != 0 {
                            throw TestError()
                        }
                    },
                    handle: { _ in
                        errored = true
                    }
                )
            }
            s = 1
        }

        #expect(errored)
    }
}

@Suite(.spec("behavior.reactive.nested-error-boundaries"))
struct NestedErrorBoundaryTests {
    @Test(.scenario("behavior.reactive.nested-error-boundaries.nested-initial-effect"))
    func `catches an error during a nested effect first run`() {
        var errored = false

        #expect(throws: Never.self) {
            withReactiveScope {
                observe {
                    observe {
                        onError(
                            { throw TestError() },
                            handle: { _ in
                                errored = true
                            }
                        )
                    }
                }
            }
        }

        #expect(errored)
    }

    @Test(.scenario("behavior.reactive.nested-error-boundaries.nested-update-effect"))
    func `catches an error when a nested effect re-runs`() {
        var errored = false

        withReactiveScope { _ in
            @State var s = 0
            observe {
                observe {
                    // read state in observer scope
                    let v = s
                    onError(
                        {
                            if v != 0 {
                                throw TestError()
                            }
                        },
                        handle: { _ in
                            errored = true
                        }
                    )
                }
            }
            s = 1
        }

        #expect(errored)
    }

    @Test(.scenario("behavior.reactive.nested-error-boundaries.different-levels"))
    func `catches an error from an effect nested below the handler`() {
        var errored = false

        withReactiveScope {
            @State var s = 0

            observe {
                onError(
                    {
                        try observe {
                            let v = s
                            if v != 0 {
                                throw TestError()
                            }
                        }
                    },
                    handle: { _ in
                        errored = true
                    }
                )
            }

            s = 1
        }

        #expect(errored)
    }

    @Test(.scenario("behavior.reactive.nested-error-boundaries.nested-memo"))
    func `catches an error thrown inside a nested derived computation`() {
        var errored = false

        #expect(throws: Never.self) {
            withReactiveScope {
                // Use a memo-like derived node that schedules an inner effect, then fails.
                @DerivedState var memo = {
                    onError(
                        {
                            observe {}
                            throw TestError()
                        },
                        handle: { _ in
                            errored = true
                        }
                    )

                    // observe { (_: Void?) in }
                    return 0
                }()
            }
        }

        #expect(errored)
    }
}
