import ReactiveGraph
import Testing

@Suite(.spec("behavior.reactive.context"))
struct ContextTests {
    @Test(.scenario("behavior.reactive.context.read-in-scope"))
    func `a read yields the value provided for its scope`() {
        @Context var ctx = 0

        $ctx.withValue {
            #expect(ctx == 0)
        }

        $ctx.withValue(1) {
            #expect(ctx == 1)
        }
    }

    @Test(.scenario("behavior.reactive.context.nested-shadowing"))
    func `a nested provider shadows the outer value`() {
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
