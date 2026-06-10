import ReactiveGraph
import Testing

@Suite(.spec("behavior.reactive.cleanup"))
struct CleanupTests {
    @Test(.scenario("behavior.reactive.cleanup.runs-before-rerun"))
    func `runs a cleanup before the effect runs again`() async {
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

    @Test(.scenario("behavior.reactive.cleanup.runs-on-dispose"))
    func `runs a cleanup when the scope is disposed`() {
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
