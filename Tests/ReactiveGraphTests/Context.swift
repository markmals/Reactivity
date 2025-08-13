import ReactiveGraph
import Testing

@Suite
struct ContextTests {
    @Test("create and use context")
    func testContext() {
        @Context var ctx = 0

        $ctx.withValue {
            #expect(ctx == 0)
        }

        $ctx.withValue(1) {
            #expect(ctx == 1)
        }
    }

    @Test("nested context")
    func testNestedContext() {
        @Context var ctx = 0

        $ctx.withValue {
            #expect(ctx == 0)

            $ctx.withValue(1) {
                #expect(ctx == 1)
            }
        }
    }

    // TODO: Add more tests
}
