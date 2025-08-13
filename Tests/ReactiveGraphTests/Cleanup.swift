import ReactiveGraph
import Testing

@Suite
struct CleanupTests {
    @Test("Clean an effect")
    func testCleanEffect() async {
        await withReactiveScope {
            @State var sign = "thoughts"
            var temp: String?

            observe {
                // Trigger read
                _ = sign
                onCleanup {
                    temp = "after"
                }
            }

            #expect(temp == nil)

            // No change yet; allow any scheduled work to run.
            await Task.yield()
            #expect(temp == nil)

            // Trigger re-run; let the scheduler process cleanup.
            sign = "mind"
            await Task.yield()
            #expect(temp == "after")
        }
    }

    @Test("Explicit scope disposal")
    func testExplicitScopeDisposal() {
        var temp: String?
        var disposer: Dispose!

        withReactiveScope { dispose in
            disposer = dispose
            onCleanup {
                temp = "disposed"
            }
        }

        #expect(temp == nil)
        disposer()
        #expect(temp == "disposed")
    }
}
