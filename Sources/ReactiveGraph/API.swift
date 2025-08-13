private func todo() -> Never {
    fatalError("Not yet implemented")
}

public typealias Dispose = () -> Void

@discardableResult
public func withReactiveScope<T>(_ root: @escaping (@escaping Dispose) async throws -> T)
    async rethrows -> T
{
    todo()
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping (@escaping Dispose) throws -> T) rethrows -> T {
    todo()
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping () async throws -> T) async rethrows -> T {
    todo()
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping () throws -> T) rethrows -> T {
    todo()
}

public struct ObservationHandle: Sendable {
    public func dispose() {
        todo()
    }
}

public struct ObservationOptions: Sendable {
    public var name: String? = nil
    public init() {}
}

@discardableResult
public func observe(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping () -> Void
) -> ObservationHandle {
    todo()
}

@discardableResult
public func observe(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping () async -> Void
) async -> ObservationHandle {
    todo()
}

@discardableResult
public func observe(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping () throws -> Void
) rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping () async throws -> Void
) async rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next>(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Next?) -> Next
) -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next>(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Next?) async -> Next
) async -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next>(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Next?) throws -> Next
) rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next>(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Next?) async throws -> Next
) async rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init? = nil,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) -> Next
) -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init? = nil,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) async -> Next
) async -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init? = nil,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) throws -> Next
) rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init? = nil,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) async throws -> Next
) async rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) -> Next
) -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) async -> Next
) async -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) throws -> Next
) rethrows -> ObservationHandle {
    todo()
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) async throws -> Next
) async rethrows -> ObservationHandle {
    todo()
}

public func onCleanup(_ cleanupCallback: @escaping () -> Void) {
    todo()
}

public func onCleanup(_ cleanupCallback: @escaping () async -> Void) async {
    todo()
}

public func onError(
    _ body: @escaping () throws -> Void, handle handler: @escaping (any Error) -> Void
) {
    todo()
}

public func onError(
    _ body: @escaping () async throws -> Void, handle handler: @escaping (any Error) async -> Void
) async {
    todo()
}

public func onError(
    _ body: @escaping () throws -> Void, handle handler: @escaping (any Error) throws -> Void
) rethrows {
    todo()
}

public func onError(
    _ body: @escaping () async throws -> Void,
    handle handler: @escaping (any Error) async throws -> Void
) async rethrows {
    todo()
}

public func withoutTracking<T>(_ body: () throws -> T) rethrows -> T {
    todo()
}

public func withoutTracking<T>(_ body: () async throws -> T) async rethrows -> T {
    todo()
}

public protocol ReadableSignal<Wrapped> {
    associatedtype Wrapped
    var wrappedValue: Wrapped { get }
}

public protocol WritableSignal<Wrapped>: ReadableSignal {
    associatedtype Wrapped
    var wrappedValue: Wrapped { get nonmutating set }
}

@propertyWrapper
public struct State<Wrapped>: WritableSignal, Sendable {
    public init(wrappedValue: Wrapped) {
        todo()
    }

    public var wrappedValue: Wrapped {
        get {
            todo()
        }
        nonmutating set {
            todo()
        }
    }

    public var projectedValue: Self {
        todo()
    }

    public func peek() -> Wrapped {
        todo()
    }
}

@propertyWrapper
public struct DerivedState<Wrapped>: ReadableSignal, Sendable {
    public init(wrappedValue expression: @autoclosure @escaping () throws -> Wrapped) {
        todo()
    }

    public var wrappedValue: Wrapped {
        todo()
    }

    public var projectedValue: Self {
        todo()
    }
}

@propertyWrapper
public struct Context<Wrapped>: Sendable {
    public init(wrappedValue: Wrapped) {
        todo()
    }

    public var wrappedValue: Wrapped {
        todo()
    }

    public var projectedValue: ContextHandle<Wrapped> {
        todo()
    }
}

public struct ContextHandle<Wrapped>: Sendable {
    @discardableResult
    public func withValue<Passthrough>(_ body: () throws -> Passthrough) rethrows -> Passthrough {
        todo()
    }

    @discardableResult
    public func withValue<Passthrough>(_ value: Wrapped, _ body: () throws -> Passthrough) rethrows
        -> Passthrough
    {
        todo()
    }

    @discardableResult
    public func withValue<Passthrough>(_ body: () async throws -> Passthrough) async rethrows
        -> Passthrough
    {
        todo()
    }

    @discardableResult
    public func withValue<Passthrough>(_ value: Wrapped, _ body: () async throws -> Passthrough)
        async rethrows
        -> Passthrough
    {
        todo()
    }
}
