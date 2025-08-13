import ReactiveGraph
import Testing

@Suite
struct ErrorHandlingTests {
    struct TestError: Error {
        init() {}
    }

    @Test("should keep graph consistent on errors during activation")
    func testKeepsGraphConsistentOnErrorsInActivation() {
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

    @Test("should keep graph consistent on errors in computeds")
    func testKeepsGraphConsistentOnErrorsInDerivedStateComputations() {
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

    @Test("No Handler")
    func testCatchErrorNoHandler() {
        #expect(throws: TestError.self) {
            try withReactiveScope {
                throw TestError()
            }
        }
    }

    @Test("Top level")
    func testCatchErrorTopLevel() {
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

    @Test("Nested in catchError")
    func testCatchErrorNested() {
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

    @Test("In initial effect")
    func testCatchErrorInInitialEffect() {
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

    @Test("In update effect")
    func testCatchErrorInUpdateEffect() {
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

    @Test("In initial nested effect")
    func testCatchErrorInInitialNestedEffect() {
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

    @Test("In nested update effect")
    func testCatchErrorInNestedUpdateEffect() {
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

    @Test("In nested update effect different levels")
    func testCatchErrorNestedUpdateDifferentLevels() {
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

    @Test("In nested memo")
    func testCatchErrorInNestedMemo() {
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
