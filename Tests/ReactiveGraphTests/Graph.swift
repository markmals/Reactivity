import ReactiveGraph
import Testing

@Suite
struct GraphUpdateTests {
    @Test("should drop A -> B -> A updates")
    func testShouldDropUpdates() {
        //     A
        //   / |
        //  B  | <- Looks like a flag doesn't it? :D
        //   \ |
        //     C
        //     |
        //     D

        withReactiveScope {
            @State var a = 2

            @DerivedState var b = a - 1
            @DerivedState var c = a + b

            var computationCount = 0
            @DerivedState var d = {
                computationCount += 1
                return "d: \(c)"
            }()

            // Trigger read
            #expect(d == "d: 3")
            #expect(computationCount == 1)

            a = 4
            // Trigger read
            _ = d
            #expect(computationCount == 2)
        }
    }

    @Test("should only update each state value once (diamond graph)")
    func testDiamondDependencyProblem() {
        // In this scenario "D" should only update once when "A" receives
        // an update. This is referred to as the "diamond dependency problem".
        //     A
        //   /   \
        //  B     C
        //   \   /
        //     D

        withReactiveScope {
            @State var a = "a"
            @DerivedState var b = a
            @DerivedState var c = a

            var computationCount = 0
            @DerivedState var d = {
                computationCount += 1
                return "\(b) \(c)"
            }()

            #expect(d == "a a")
            #expect(computationCount == 1)

            a = "aa"
            #expect(d == "aa aa")
            #expect(computationCount == 2)
        }
    }

    @Test("should only update every state value once (diamond graph + tail)")
    func testDiamondDependencyProblemWithTail() {
        // "E" will be likely updated twice if our mark+sweep logic is buggy.
        //     A
        //   /   \
        //  B     C
        //   \   /
        //     D
        //     |
        //     E

        withReactiveScope {
            @State var a = "a"
            @DerivedState var b = a
            @DerivedState var c = a
            @DerivedState var d = "\(b) \(c)"

            var computationCount = 0
            @DerivedState var e = {
                computationCount += 1
                return d
            }()

            #expect(e == "a a")
            #expect(computationCount == 1)

            a = "aa"
            #expect(e == "aa aa")
            #expect(computationCount == 2)
        }
    }

    @Test("should bail out if result is the same")
    func testBailOut() {
        // Bail out if value of "B" never changes
        // A -> B -> C

        withReactiveScope {
            @State var a = "a"

            @DerivedState var b = {
                // Trigger read
                _ = a
                return "foo"
            }()

            var computationCount = 0
            @DerivedState var c = {
                computationCount += 1
                return b
            }()

            #expect(c == "foo")
            #expect(computationCount == 1)

            a = "aa"
            #expect(c == "foo")
            #expect(computationCount == 1)
        }
    }

    @Test("should only update every reactive state value once (jagged diamond graph + tails)")
    func testJaggedDiamondUpdatesOnce() {
        withReactiveScope {
            @State var a = "a"

            @DerivedState var b = a
            @DerivedState var c = a
            @DerivedState var d = c

            var step = 0
            var eCalls = 0
            var fCalls = 0
            var gCalls = 0
            var eStep = 0
            var fStep = 0
            var gStep = 0

            @DerivedState var e = {
                step += 1
                eStep = step
                eCalls += 1
                return "\(b) \(d)"
            }()

            @DerivedState var f = {
                step += 1
                fStep = step
                fCalls += 1
                return e
            }()

            @DerivedState var g = {
                step += 1
                gStep = step
                gCalls += 1
                return e
            }()

            #expect(f == "a a")
            #expect(fCalls == 1)

            #expect(g == "a a")
            #expect(gCalls == 1)

            eCalls = 0
            fCalls = 0
            gCalls = 0
            step = 0
            eStep = 0
            fStep = 0
            gStep = 0

            a = "b"

            #expect(e == "b b")
            #expect(eCalls == 1)

            #expect(f == "b b")
            #expect(fCalls == 1)

            #expect(g == "b b")
            #expect(gCalls == 1)

            #expect(eStep < fStep)
            #expect(fStep < gStep)

            eCalls = 0
            fCalls = 0
            gCalls = 0
            step = 0
            eStep = 0
            fStep = 0
            gStep = 0

            a = "c"

            #expect(e == "c c")
            #expect(eCalls == 1)

            #expect(f == "c c")
            #expect(fCalls == 1)

            #expect(g == "c c")
            #expect(gCalls == 1)

            #expect(eStep < fStep)
            #expect(fStep < gStep)
        }
    }

    @Test("should only subscribe to signals listened to")
    func testSubscribeOnlyToListenedSignals() {
        //    *A
        //   /   \
        // *B     C <- we don't listen to C

        withReactiveScope {
            @State var a = "a"
            @DerivedState var b = a

            var computationCount = 0
            @DerivedState var c = {
                computationCount += 1
                return a
            }()

            #expect(b == "a")
            #expect(computationCount == 0)

            a = "aa"
            #expect(b == "aa")
            #expect(computationCount == 0)
        }
    }

    @Test("should only subscribe to signals listened to II")
    func testSubscribeOnlyToListenedSignalsII() {
        // Here both "B" and "C" are active in the beginning, but
        // "B" becomes inactive later. At that point it should
        // not receive any updates anymore.
        //    *A
        //   /   \
        // *B     D <- D doesn't listen to C
        //  |
        // *C

        withReactiveScope {
            @State var a = "a"

            var spyB = 0
            @DerivedState var b = {
                spyB += 1
                return a
            }()

            var spyC = 0
            @DerivedState var c = {
                spyC += 1
                return b
            }()

            @DerivedState var d = a

            var result = ""
            let handle = observe {
                result = c
            }

            #expect(result == "a")
            #expect(d == "a")

            spyB = 0
            spyC = 0
            handle.dispose()

            a = "aa"

            #expect(spyB == 0)
            #expect(spyC == 0)
            #expect(d == "aa")
        }
    }

    @Test("should ensure subs update even if one dep unmarks it")
    func testSubsUpdateWhenOneDepUnmarks() {
        // In this scenario "C" always returns the same value. When "A"
        // changes, "B" will update, then "C" at which point its update
        // to "D" will be unmarked. But "D" must still update because
        // "B" marked it. If "D" isn't updated, then we have a bug.
        //     A
        //   /   \
        //  B     *C <- returns same value every time
        //   \   /
        //     D

        withReactiveScope {
            @State var a = "a"
            @DerivedState var b = a
            @DerivedState var c = {
                // Trigger read
                _ = a
                return "c"
            }()

            var computationCount = 0
            var value = ""
            @DerivedState var d = {
                computationCount += 1
                value = "\(b) \(c)"
                return "\(b) \(c)"
            }()

            #expect(d == "a c")
            computationCount = 0

            a = "aa"
            // Trigger read
            _ = d
            #expect(value == "aa c")
            #expect(computationCount == 1)
        }
    }

    @Test("should ensure subs update even if two deps unmark it")
    func testSubsUpdateWhenTwoDepsUnmark() {
        // In this scenario both "C" and "D" always return the same
        // value. But "E" must still update because "A" marked it.
        // If "E" isn't updated, then we have a bug.
        //     A
        //   / | \
        //  B *C *D
        //   \ | /
        //     E

        withReactiveScope {
            @State var a = "a"
            @DerivedState var b = a
            @DerivedState var c = {
                // Trigger read
                _ = a
                return "c"
            }()
            @DerivedState var d = {
                // Trigger read
                _ = a
                return "d"
            }()

            var computationCount = 0
            @DerivedState var e = {
                computationCount += 1
                return b + " " + c + " " + d
            }()

            #expect(e == "a c d")
            computationCount = 0

            a = "aa"
            // Trigger read
            _ = e
            #expect(e == "aa c d")
            #expect(computationCount == 1)
        }
    }

    @Test("should support lazy branches")
    func testSupportsLazyBranches() {
        withReactiveScope {
            @State var a = 0
            @DerivedState var b = a
            @DerivedState var c = a > 0 ? a : b

            #expect(c == 0)
            a = 1
            #expect(c == 1)

            a = 0
            #expect(c == 0)
        }
    }

    @Test("should not update a sub if all deps unmark it")
    func testNoUpdateIfAllDepsUnmark() {
        // In this scenario "B" and "C" always return the same value. When "A"
        // changes, "D" should not update.
        //     A
        //   /   \
        // *B     *C
        //   \   /
        //     D

        withReactiveScope {
            @State var a = "a"
            @DerivedState var b = {
                // Trigger read
                _ = a
                return "b"
            }()
            @DerivedState var c = {
                // Trigger read
                _ = a
                return "c"
            }()

            var computationCount = 0
            @DerivedState var d = {
                computationCount += 1
                return "\(b) \(c)"
            }()

            #expect(d == "b c")
            computationCount = 0

            a = "aa"
            #expect(computationCount == 0)
        }
    }

}
