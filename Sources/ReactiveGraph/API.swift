import Foundation
import OrderedCollections
import Synchronization

public typealias Dispose = () -> Void

// Helper for tests - allows mutable capture in @Sendable closures
final class SendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Core Reactive System

@TaskLocal var currentObserver: ReactiveNode?
@TaskLocal var isTracking: Bool = true

final class ReactiveNode: Sendable {
    let identifier: UInt64
    let mutex = Mutex<State>(State())

    struct State {
        var flags: ReactiveFlags = []
        var dependencies: OrderedSet<WeakNodeReference> = []
        var subscribers: OrderedSet<WeakNodeReference> = []
        var cleanupCallbacks: [CleanupCallback] = []
        var isDisposed = false
        var generation: UInt64 = 0
        // Optional snapshotter for leaf/derived current value (for bailout)
        var snapshotter: (@Sendable () -> AnyEquatable?)? = nil
        // For derived: last-seen dependency generations and snapshots
        var dependencyGenerations: [UInt64: UInt64] = [:]
        var dependencySnapshots: [UInt64: AnyEquatable] = [:]
    }

    init() {
        self.identifier = NodeIdentifierGenerator.next()
    }

    func markDirty() {
        NotificationQueue.shared.markDirty(self)
    }

    func addDependency(_ dependency: ReactiveNode) {
        _ = mutex.withLock { state in
            state.dependencies.append(WeakNodeReference(dependency))
        }
        dependency.mutex.withLock { dependencyState in
            dependencyState.subscribers.append(WeakNodeReference(self))
            if !dependencyState.flags.contains(.watching) {
                dependencyState.flags.insert(.watching)
            }
        }
    }

    func removeDependency(_ dependency: ReactiveNode) {
        _ = mutex.withLock { state in
            state.dependencies.remove(WeakNodeReference(dependency))
        }
        dependency.mutex.withLock { dependencyState in
            dependencyState.subscribers.remove(WeakNodeReference(self))
            if dependencyState.subscribers.isEmpty {
                dependencyState.flags.remove(.watching)
            }
        }
    }

    func addCleanup(_ cleanup: @escaping () -> Void) {
        mutex.withLock { state in
            guard !state.isDisposed else { return }
            state.cleanupCallbacks.append(CleanupCallback(cleanup))
        }
    }

    func dispose() {
        let callbacks = mutex.withLock { state -> [CleanupCallback] in
            guard !state.isDisposed else { return [] }
            state.isDisposed = true

            for dependencyReference in state.dependencies {
                if let dependency = dependencyReference.node {
                    _ = dependency.mutex.withLock { dependencyState in
                        dependencyState.subscribers.remove(WeakNodeReference(self))
                    }
                }
            }
            state.dependencies.removeAll()

            for subscriberReference in state.subscribers {
                if let subscriber = subscriberReference.node {
                    _ = subscriber.mutex.withLock { subscriberState in
                        subscriberState.dependencies.remove(WeakNodeReference(self))
                    }
                }
            }
            state.subscribers.removeAll()

            return state.cleanupCallbacks
        }

        for wrapper in callbacks {
            wrapper.callback()
        }
    }

    var isDisposed: Bool {
        mutex.withLock { state in
            state.isDisposed
        }
    }

    // Value snapshotting support for bailout checks
    func setSnapshotter(_ f: @escaping @Sendable () -> AnyEquatable?) {
        mutex.withLock { state in
            state.snapshotter = f
        }
    }

    func snapshotValue() -> AnyEquatable? {
        let f: (@Sendable () -> AnyEquatable?)? = mutex.withLock { state in
            state.snapshotter
        }
        return f?()
    }
}

// Wrapper to hold non-Sendable cleanup closures under strict concurrency
final class CleanupCallback: @unchecked Sendable {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
}

struct ReactiveFlags: OptionSet, Sendable {
    let rawValue: UInt8

    static let mutable = ReactiveFlags(rawValue: 1 << 0)
    static let watching = ReactiveFlags(rawValue: 1 << 1)
    static let dirty = ReactiveFlags(rawValue: 1 << 2)
    static let pending = ReactiveFlags(rawValue: 1 << 3)
    static let checking = ReactiveFlags(rawValue: 1 << 4)
}

struct WeakNodeReference: Hashable, Sendable {
    private let identifier: UInt64
    weak var node: ReactiveNode?

    init(_ node: ReactiveNode) {
        self.identifier = node.identifier
        self.node = node
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    static func == (lhs: WeakNodeReference, rhs: WeakNodeReference) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

final class NodeIdentifierGenerator: Sendable {
    private let counter = Mutex<UInt64>(0)
    static let shared = NodeIdentifierGenerator()

    private init() {}

    static func next() -> UInt64 {
        shared.counter.withLock { counter in
            counter += 1
            return counter
        }
    }
}

final class NotificationQueue: Sendable {
    static let shared = NotificationQueue()

    private let mutex = Mutex<State>(State())

    struct State {
        var pendingNotifications: OrderedSet<WeakNodeReference> = []
        var isScheduled = false
        var batchDepth = 0
        var effects: [UInt64: @Sendable () -> Void] = [:]
        // Optional refresh hooks to eagerly clear dirtiness and update gens
        var refreshers: [UInt64: @Sendable () -> Void] = [:]
        // Queue of observer effects to run after propagation, in order
        var queuedObserverEffects: OrderedSet<UInt64> = []
        // Queue of derived/state refreshers to run once per wave
        var scheduledDerivedRefresh: OrderedSet<WeakNodeReference> = []
    }

    private init() {}

    func startBatch() {
        mutex.withLock { state in
            state.batchDepth += 1
        }
    }

    func endBatch() {
        let shouldFlush = mutex.withLock { state -> Bool in
            state.batchDepth -= 1
            return state.batchDepth == 0 && !state.pendingNotifications.isEmpty
        }

        if shouldFlush {
            flush()
        }
    }

    func markDirty(_ node: ReactiveNode) {
        _ = node.mutex.withLock { nodeState in
            nodeState.flags.insert(.dirty)
        }
        print("[RG] markDirty node=\(node.identifier)")

        addPendingNotification(WeakNodeReference(node))
    }

    func registerEffect(for nodeIdentifier: UInt64, effect: @escaping @Sendable () -> Void) {
        mutex.withLock { state in
            state.effects[nodeIdentifier] = effect
        }
    }

    func removeEffect(for nodeIdentifier: UInt64) {
        mutex.withLock { state in
            _ = state.effects.removeValue(forKey: nodeIdentifier)
            _ = state.refreshers.removeValue(forKey: nodeIdentifier)
        }
    }

    func registerRefresher(for nodeIdentifier: UInt64, refresher: @escaping @Sendable () -> Void) {
        mutex.withLock { state in
            state.refreshers[nodeIdentifier] = refresher
        }
    }

    func refreshIfRegistered(nodeIdentifier: UInt64) {
        let refresher = mutex.withLock { state in
            state.refreshers[nodeIdentifier]
        }
        refresher?()
    }

    private func addPendingNotification(_ nodeReference: WeakNodeReference) {
        let shouldFlush = mutex.withLock { state -> Bool in
            state.pendingNotifications.append(nodeReference)
            print(
                "[RG] enqueue notif node=\(nodeReference.node?.identifier ?? 0) pending=\(state.pendingNotifications.count)"
            )
            if state.batchDepth == 0 && !state.isScheduled {
                state.isScheduled = true
                return true
            }
            return false
        }

        if shouldFlush {
            flush()
        }
    }

    private func flush() {
        print("[RG] flush begin")
        while true {
            // We keep processing propagation until there are no pending notifications.
            var effectsSnapshot: [UInt64: @Sendable () -> Void] = [:]
            while true {
                let notifications: [ReactiveNode] = mutex.withLock { state in
                    let notifs = Array(state.pendingNotifications.compactMap { $0.node })
                    state.pendingNotifications.removeAll()
                    state.isScheduled = true
                    effectsSnapshot = state.effects
                    return notifs
                }

                if notifications.isEmpty { break }

                for node in notifications {
                    print(
                        "[RG] propagate from node=\(node.identifier) to \(node.mutex.withLock{ $0.subscribers.count }) subs"
                    )
                    propagateChanges(node, effects: effectsSnapshot)
                }
            }

            // Now run all scheduled derived/state refreshers once per wave, in topological order
            let scheduledNodes: [ReactiveNode] = mutex.withLock { state in
                let nodes = Array(state.scheduledDerivedRefresh.compactMap { $0.node })
                state.scheduledDerivedRefresh.removeAll()
                return nodes
            }
            if !scheduledNodes.isEmpty {
                let ordered = topoOrder(nodes: scheduledNodes)
                for node in ordered {
                    let id = node.identifier
                    print("[RG] run derived refresher id=\(id)")
                    if let effect = effectsSnapshot[id] { effect() }
                }
            }

            // Run queued observer effects in insertion order
            let observerEffectIDs: [UInt64] = mutex.withLock { state in
                let ids = Array(state.queuedObserverEffects)
                state.queuedObserverEffects.removeAll()
                return ids
            }
            for id in observerEffectIDs {
                print("[RG] run observer effect id=\(id)")
                if let effect = effectsSnapshot[id] { effect() }
            }

            // Continue until all queues are empty
            let (hasPending, hasDerived, hasQueued) = mutex.withLock { state in
                (
                    !state.pendingNotifications.isEmpty, !state.scheduledDerivedRefresh.isEmpty,
                    !state.queuedObserverEffects.isEmpty
                )
            }
            if !hasPending && !hasDerived && !hasQueued {
                mutex.withLock { state in state.isScheduled = false }
                print("[RG] flush end")
                break
            }
        }
    }

    private func propagateChanges(_ node: ReactiveNode, effects: [UInt64: @Sendable () -> Void]) {
        let subscribers = node.mutex.withLock { state in
            Array(state.subscribers.compactMap { $0.node })
        }

        for subscriber in subscribers {
            let (shouldUpdate, isMutable) = subscriber.mutex.withLock { state -> (Bool, Bool) in
                guard !state.isDisposed else { return (false, false) }
                return (state.flags.contains(.watching), state.flags.contains(.mutable))
            }

            guard shouldUpdate else { continue }
            if isMutable {
                // Schedule derived/state refresh once in this batch
                mutex.withLock { state in
                    print("[RG] schedule derived/state id=\(subscriber.identifier)")
                    state.scheduledDerivedRefresh.append(subscriber.identifier)
                }
            } else {
                // Observers are queued and run after propagation to stabilize order
                mutex.withLock { state in
                    print("[RG] queue observer id=\(subscriber.identifier)")
                    state.queuedObserverEffects.append(subscriber.identifier)
                }
            }
        }

        // Clear the dirty flag on the source after propagation
        _ = node.mutex.withLock { state in
            state.flags.remove(.dirty)
        }
    }
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping (@escaping Dispose) async throws -> T)
    async rethrows -> T
{
    let scopeNode = ReactiveNode()
    let dispose: Dispose = {
        scopeNode.dispose()
    }

    return try await $currentObserver.withValue(scopeNode) {
        try await root(dispose)
    }
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping (@escaping Dispose) throws -> T) rethrows -> T {
    let scopeNode = ReactiveNode()
    let dispose: Dispose = {
        scopeNode.dispose()
    }

    return try $currentObserver.withValue(scopeNode) {
        try root(dispose)
    }
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping () async throws -> T) async rethrows -> T {
    let scopeNode = ReactiveNode()

    return try await $currentObserver.withValue(scopeNode) {
        try await root()
    }
}

@discardableResult
public func withReactiveScope<T>(_ root: @escaping () throws -> T) rethrows -> T {
    let scopeNode = ReactiveNode()

    return try $currentObserver.withValue(scopeNode) {
        try root()
    }
}

public final class ObservationHandle: @unchecked Sendable {
    private let node: ReactiveNode
    // Keep storage alive for the lifetime of the handle
    private let _retained: AnyObject?

    init(_ node: ReactiveNode, retain retained: AnyObject? = nil) {
        self.node = node
        self._retained = retained
    }

    public func dispose() {
        NotificationQueue.shared.removeEffect(for: node.identifier)
        node.dispose()
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
    let storage = ObservationStorage(onChange: onChange)
    storage.activateInitial()
    return ObservationHandle(storage.node, retain: storage)
}

@discardableResult
public func observe(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping () throws -> Void
) rethrows -> ObservationHandle {
    let storage = ObservationStorage(onChange: {
        do { try onChange() } catch { print("Error in observe: \(error)") }
    })
    storage.activateInitial()
    return ObservationHandle(storage.node, retain: storage)
}

@discardableResult
public func observe<Next>(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Next?) -> Next
) -> ObservationHandle {
    fatalError("Not yet implemented")
}

@discardableResult
public func observe<Next>(
    isolation: isolated (any Actor)? = #isolation,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Next?) throws -> Next
) rethrows -> ObservationHandle {
    fatalError("Not yet implemented")
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init? = nil,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) -> Next
) -> ObservationHandle {
    fatalError("Not yet implemented")
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init? = nil,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) throws -> Next
) rethrows -> ObservationHandle {
    fatalError("Not yet implemented")
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) -> Next
) -> ObservationHandle {
    fatalError("Not yet implemented")
}

@discardableResult
public func observe<Next, Init>(
    isolation: isolated (any Actor)? = #isolation,
    initialValue: Init,
    options: ObservationOptions = .init(),
    _ onChange: @escaping (Init?, Next) throws -> Next
) rethrows -> ObservationHandle {
    fatalError("Not yet implemented")
}

public func onCleanup(_ cleanupCallback: @escaping () -> Void) {
    guard let observer = currentObserver else { return }
    observer.addCleanup(cleanupCallback)
}

public func onCleanup(_ cleanupCallback: @escaping () async -> Void) async {
    guard let observer = currentObserver else { return }
    // Wrap in a sendable box to satisfy strict concurrency capture rules
    let box = SendableBox(cleanupCallback)
    observer.addCleanup { Task { await box.value() } }
}

public func onError(
    _ body: @escaping () throws -> Void, handle handler: @escaping (any Error) -> Void
) {
    do {
        try body()
    } catch {
        handler(error)
    }
}

public func onError(
    _ body: @escaping () async throws -> Void, handle handler: @escaping (any Error) async -> Void
) async {
    do {
        try await body()
    } catch {
        await handler(error)
    }
}

public func onError(
    _ body: @escaping () throws -> Void, handle handler: @escaping (any Error) throws -> Void
) rethrows {
    do {
        try body()
    } catch {
        try handler(error)
    }
}

public func onError(
    _ body: @escaping () async throws -> Void,
    handle handler: @escaping (any Error) async throws -> Void
) async rethrows {
    do {
        try await body()
    } catch {
        try await handler(error)
    }
}

public func withoutTracking<T>(_ body: () throws -> T) rethrows -> T {
    try $isTracking.withValue(false) {
        try body()
    }
}

public func withoutTracking<T>(_ body: () async throws -> T) async rethrows -> T {
    try await $isTracking.withValue(false) {
        try await body()
    }
}

public protocol ReadableSignal<Wrapped> {
    associatedtype Wrapped
    var wrappedValue: Wrapped { get }
}

public protocol WritableSignal<Wrapped>: ReadableSignal {
    associatedtype Wrapped
    var wrappedValue: Wrapped { get nonmutating set }
}

final class StateStorage<Wrapped: Sendable>: Sendable {
    let node: ReactiveNode
    let storage: Mutex<Wrapped>

    init(_ value: Wrapped) {
        self.node = ReactiveNode()
        self.storage = Mutex(value)
        _ = self.node.mutex.withLock { state in
            state.flags.insert(.mutable)
        }

        // Provide snapshotting for equatable state values
        node.setSnapshotter { [weak self] in
            guard let self else { return nil }
            let v = self.storage.withLock { $0 }
            if let eq = v as? any Equatable { return AnyEquatable(eq) }
            return nil
        }
    }
}

@propertyWrapper
public struct State<Wrapped: Sendable>: WritableSignal, Sendable {
    private let storageRef: StateStorage<Wrapped>

    public init(wrappedValue: Wrapped) {
        self.storageRef = StateStorage(wrappedValue)
    }

    public var wrappedValue: Wrapped {
        get {
            trackRead()
            return storageRef.storage.withLock { $0 }
        }
        nonmutating set {
            storageRef.storage.withLock { value in
                let hasChanged = !areEqual(value, newValue)
                value = newValue
                if hasChanged {
                    storageRef.node.mutex.withLock { state in
                        state.generation &+= 1
                    }
                    storageRef.node.markDirty()
                }
            }
        }
    }

    public var projectedValue: Self {
        self
    }

    public func peek() -> Wrapped {
        storageRef.storage.withLock { value in
            value
        }
    }

    private func trackRead() {
        guard isTracking, let observer = currentObserver else { return }
        observer.addDependency(storageRef.node)
    }

    private func areEqual(_ lhs: Wrapped, _ rhs: Wrapped) -> Bool {
        if let lhs = lhs as? any Equatable, let rhs = rhs as? any Equatable {
            return lhs.isEqual(to: rhs)
        }
        return false
    }
}

struct AnyEquatable {
    private let value: Any
    private let equals: (Any) -> Bool

    init<T: Equatable>(_ value: T) {
        self.value = value
        self.equals = { other in
            guard let other = other as? T else { return false }
            return value == other
        }
    }

    func isEqual(to other: AnyEquatable) -> Bool {
        equals(other.value)
    }
}

extension Equatable {
    func isEqual(to other: any Equatable) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

final class DerivedStateStorage<Wrapped: Sendable>: @unchecked Sendable {
    let node: ReactiveNode
    let computation: () throws -> Wrapped
    let cachedValue: Mutex<CachedValue<Wrapped>>
    // Track last-seen dependency state for bailout
    private var lastDependencyGenerations: [UInt64: UInt64] = [:]
    private var lastDependencySnapshots: [UInt64: AnyEquatable] = [:]

    struct CachedValue<T> {
        var value: T?
        var isDirty = true
    }

    init(_ computation: @escaping () throws -> Wrapped) {
        self.node = ReactiveNode()
        self.computation = computation
        self.cachedValue = Mutex(CachedValue<Wrapped>())

        self.node.mutex.withLock { state in
            state.flags.insert(.mutable)
        }

        // When dependencies notify us, reconcile now to keep chain propagation flowing
        NotificationQueue.shared.registerEffect(for: self.node.identifier) { [weak self] in
            self?.refreshIfNeeded()
        }

        // Register a refresher to eagerly update when dependents check dirtiness
        NotificationQueue.shared.registerRefresher(for: self.node.identifier) { [weak self] in
            self?.refreshIfNeeded()
        }

        // Allow dependents to snapshot our current value for bailout
        node.setSnapshotter { [weak self] in
            guard let self else { return nil }
            let value = self.cachedValue.withLock { $0.value }
            if let value, let eq = value as? any Equatable { return AnyEquatable(eq) }
            return nil
        }
    }

    // Cache helpers to satisfy strict concurrency checks
    private func getCached() -> Wrapped? {
        cachedValue.withLock { $0.value }
    }

    private func setCached(_ value: Wrapped) {
        cachedValue.withLock { cache in
            cache.value = value
            cache.isDirty = false
        }
    }

    private func markCacheDirty() {
        cachedValue.withLock { cache in
            cache.isDirty = true
        }
    }

    private func needsComputation() -> Bool {
        cachedValue.withLock { cache in
            cache.isDirty || cache.value == nil
        }
    }

    // removed; moved dependency tracking to node.state

    private func clearDependencies() {
        let dependencies = node.mutex.withLock { state in
            Array(state.dependencies.compactMap { $0.node })
        }
        for dependency in dependencies {
            node.removeDependency(dependency)
        }
    }

    private func areEqual(_ lhs: Wrapped, _ rhs: Wrapped) -> Bool {
        if let lhsString = lhs as? String, let rhsString = rhs as? String {
            return lhsString == rhsString
        }
        if let lhs = lhs as? any Equatable, let rhs = rhs as? any Equatable {
            return lhs.isEqual(to: rhs)
        }
        return false
    }

    // Called by refreshers and when reading value
    func computeIfNeeded() -> Wrapped {
        print("[RG] computeIfNeeded id=\(node.identifier)")

        // If we already have a cached value, always refresh deps and compare gens.
        // Bail out even if we are marked dirty.
        let hasValue = getCached() != nil
        if hasValue {
            let deps = node.mutex.withLock { state in
                Array(state.dependencies.compactMap { $0.node })
            }
            for dep in deps {
                NotificationQueue.shared.refreshIfRegistered(nodeIdentifier: dep.identifier)
            }
            // Build current dep gens and snapshots
            var currentGens: [UInt64: UInt64] = [:]
            var currentSnaps: [UInt64: AnyEquatable] = [:]
            for depRef in node.mutex.withLock({ $0.dependencies }) {
                guard let d = depRef.node else { continue }
                let gen = d.mutex.withLock { $0.generation }
                currentGens[d.identifier] = gen
                if let snap = d.snapshotValue() {
                    currentSnaps[d.identifier] = snap
                }
            }

            let lastGens = lastDependencyGenerations
            let lastSnaps = lastDependencySnapshots

            var anyChange = false
            // If a snapshot exists for a dep, prefer comparing snapshot values.
            // For deps without snapshots, fall back to generation checks.
            for (depID, currGen) in currentGens {
                if let currSnap = currentSnaps[depID], let lastSnap = lastSnaps[depID] {
                    if !lastSnap.isEqual(to: currSnap) {
                        anyChange = true
                        break
                    }
                } else {
                    // No snapshot available; use generation comparison
                    if lastGens[depID] != currGen {
                        anyChange = true
                        break
                    }
                }
            }
            if !anyChange {
                cachedValue.withLock { $0.isDirty = false }
                print("[RG] derived bailout id=\(node.identifier)")
                return getCached()!
            }
        }

        // Recompute since deps changed or we have no cached value
        clearDependencies()

        let newValue: Wrapped
        do {
            newValue = try $currentObserver.withValue(self.node) {
                try $isTracking.withValue(true) {
                    try self.computation()
                }
            }
        } catch {
            let cached = getCached()
            if let cached {
                return cached
            }
            fatalError("DerivedState computation failed with no cached value: \(error)")
        }

        let oldValue = getCached()
        setCached(newValue)
        let hasChanged: Bool = oldValue.map { !areEqual($0, newValue) } ?? true

        if hasChanged {
            node.mutex.withLock { state in
                state.generation &+= 1
            }
            print("[RG] derived changed id=\(node.identifier)")
            node.markDirty()
        }

        // Record current dependency generations and snapshots for bailout checks
        let deps = node.mutex.withLock { state in
            Array(state.dependencies.compactMap { $0.node })
        }
        var genMap: [UInt64: UInt64] = [:]
        var snapMap: [UInt64: AnyEquatable] = [:]
        for dep in deps {
            let gen = dep.mutex.withLock { $0.generation }
            genMap[dep.identifier] = gen
            if let snap = dep.snapshotValue() {
                snapMap[dep.identifier] = snap
            }
        }
        lastDependencyGenerations = genMap
        lastDependencySnapshots = snapMap

        return newValue
    }

    // Minimal refresher used by dependents' checkDirty
    func refreshIfNeeded() {
        _ = computeIfNeeded()
    }
}

@propertyWrapper
public struct DerivedState<Wrapped: Sendable>: ReadableSignal, Sendable {
    private let storageRef: DerivedStateStorage<Wrapped>

    public init(wrappedValue expression: @autoclosure @escaping () throws -> Wrapped) {
        self.storageRef = DerivedStateStorage(expression)
    }

    public var wrappedValue: Wrapped {
        trackRead()
        return storageRef.computeIfNeeded()
    }

    public var projectedValue: Self {
        self
    }

    private func trackRead() {
        guard isTracking, let observer = currentObserver else { return }
        observer.addDependency(storageRef.node)
    }
}

// Simple context storage - not thread-safe, for basic functionality
final class ContextStorage: @unchecked Sendable {
    private var storage: [String: Any] = [:]
    static let shared = ContextStorage()

    func get<T>(key: String, defaultValue: T) -> T {
        return (storage[key] as? T) ?? defaultValue
    }

    func set<T>(key: String, value: T) {
        storage[key] = value
    }

    private init() {}
}

@propertyWrapper
public struct Context<Wrapped>: Sendable where Wrapped: Sendable {
    private let defaultValue: Wrapped
    private let key: String

    public init(wrappedValue: Wrapped) {
        self.defaultValue = wrappedValue
        self.key = String(describing: ObjectIdentifier(Context<Wrapped>.self))
    }

    public var wrappedValue: Wrapped {
        return ContextStorage.shared.get(key: key, defaultValue: defaultValue)
    }

    public var projectedValue: ContextHandle<Wrapped> {
        return ContextHandle(key: key, defaultValue: defaultValue)
    }
}

public struct ContextHandle<Wrapped>: Sendable where Wrapped: Sendable {
    private let key: String
    private let defaultValue: Wrapped

    init(key: String, defaultValue: Wrapped) {
        self.key = key
        self.defaultValue = defaultValue
    }

    @discardableResult
    public func withValue<Passthrough>(_ body: () throws -> Passthrough) rethrows -> Passthrough {
        return try withValue(defaultValue, body)
    }

    @discardableResult
    public func withValue<Passthrough>(_ value: Wrapped, _ body: () throws -> Passthrough) rethrows
        -> Passthrough
    {
        let currentValue = ContextStorage.shared.get(key: key, defaultValue: defaultValue)
        ContextStorage.shared.set(key: key, value: value)
        defer {
            ContextStorage.shared.set(key: key, value: currentValue)
        }
        return try body()
    }

    @discardableResult
    public func withValue<Passthrough>(_ body: () async throws -> Passthrough) async rethrows
        -> Passthrough
    {
        return try await withValue(defaultValue, body)
    }

    @discardableResult
    public func withValue<Passthrough>(_ value: Wrapped, _ body: () async throws -> Passthrough)
        async rethrows
        -> Passthrough
    {
        let currentValue = ContextStorage.shared.get(key: key, defaultValue: defaultValue)
        ContextStorage.shared.set(key: key, value: value)
        defer {
            ContextStorage.shared.set(key: key, value: currentValue)
        }
        return try await body()
    }
}
// MARK: - Observation Storage
final class ObservationStorage: @unchecked Sendable {
    let node: ReactiveNode
    private let onChange: () -> Void
    private var lastDependencyGenerations: [UInt64: UInt64] = [:]
    private var lastDependencySnapshots: [UInt64: AnyEquatable] = [:]
    private var initialized = false

    init(onChange: @escaping () -> Void) {
        self.node = ReactiveNode()
        self.onChange = onChange
        _ = self.node.mutex.withLock { state in
            state.flags.insert(.watching)
        }

        // Register the effect with the queue; it will decide if we actually run
        NotificationQueue.shared.registerEffect(for: self.node.identifier) { [weak self] in
            self?.runIfNeeded()
        }
    }

    func activateInitial() {
        // Run once unconditionally to establish dependencies
        run(force: true)
    }

    private func clearDependencies() {
        let deps = node.mutex.withLock { state in
            Array(state.dependencies.compactMap { $0.node })
        }
        for d in deps {
            node.removeDependency(d)
        }
    }

    private func captureDependencyState() {
        let deps = node.mutex.withLock { state in
            Array(state.dependencies.compactMap { $0.node })
        }
        var gens: [UInt64: UInt64] = [:]
        var snaps: [UInt64: AnyEquatable] = [:]
        for d in deps {
            let gen = d.mutex.withLock { $0.generation }
            gens[d.identifier] = gen
            if let snap = d.snapshotValue() { snaps[d.identifier] = snap }
        }
        lastDependencyGenerations = gens
        lastDependencySnapshots = snaps
    }

    private func dependenciesChanged() -> Bool {
        // Ask dependencies to refresh if applicable (derived/state may respond)
        let deps = node.mutex.withLock { state in
            Array(state.dependencies.compactMap { $0.node })
        }
        for d in deps { NotificationQueue.shared.refreshIfRegistered(nodeIdentifier: d.identifier) }

        // Build current view and compare with last snapshots/gens
        var currGens: [UInt64: UInt64] = [:]
        var currSnaps: [UInt64: AnyEquatable] = [:]
        for d in deps {
            let gen = d.mutex.withLock { $0.generation }
            currGens[d.identifier] = gen
            if let snap = d.snapshotValue() { currSnaps[d.identifier] = snap }
        }
        // Prefer snapshot comparison when available; fall back to generations
        for (depID, gen) in currGens {
            if let cs = currSnaps[depID], let ls = lastDependencySnapshots[depID] {
                if !ls.isEqual(to: cs) { return true }
            } else if lastDependencyGenerations[depID] != gen {
                return true
            }
        }
        return false
    }

    private func run(force: Bool) {
        clearDependencies()
        $currentObserver.withValue(node) {
            $isTracking.withValue(true) {
                onChange()
            }
        }
        captureDependencyState()
        initialized = true
    }

    func runIfNeeded() {
        // If not yet initialized, run once
        if !initialized {
            run(force: true)
            return
        }
        // If deps didn’t change in value, bail
        if !dependenciesChanged() { return }
        run(force: false)
    }
}
