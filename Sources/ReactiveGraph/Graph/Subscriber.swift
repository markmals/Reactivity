import SynchronizationExtras

/// The current reactive observer.
///
/// The observer is whatever reactive node is currently listening for signals that need to be
/// tracked. For example, if an effect is running, that effect is the observer, which means it will
/// subscribe to changes in any signals that are read.
public enum Observer {
    package static let local = ThreadLocal<AnySubscriber>(nil)
    
    /// The current observer, if any.
    public static var current: AnySubscriber? {
        get {
            local.wrappedValue
        }
        set {
            local.wrappedValue = newValue
        }
    }
}

/// Suspends reactive tracking while running the given function.
///
/// This can be used to isolate parts of the reactive graph from one another.
///
/// ```swift
/// let (a, setA) = createSignal(0)
/// let (b, setB) = createSignal(0)
/// let c = createMemo {
///     // this memo will *only* update when `a` changes
///     a() + untrack { b() }
/// }
///
/// #expect(c() == 0)
/// setA(1)
/// #expect(c() == 1)
/// setB(1)
/// // hasn't updated, because we untracked before reading b
/// #expect(c() == 1)
/// setA(2)
/// #expect(c() == 3)
/// ```
//@TrackCaller
public func untrack<T>(nonReactiveReadsFunc: @autoclosure @escaping () -> T) -> T {
//    guard SpecialNonReactiveZone.enter() else { return }
    let _ = Observer.current
    return nonReactiveReadsFunc()
}

/// Converts a [`Subscriber`] to a type-erased [`AnySubscriber`].
public protocol AnySubscriberConvertible {
    var anySubscriber: AnySubscriber { get }
}

/// Any type that can track reactive values (like an effect or a memo).
public protocol Subscriber: ReactiveNode {
    /// Adds a subscriber to this subscriber's list of dependencies.
    mutating func add(source: AnySource)

    /// Clears the set of sources for this subscriber.
    mutating func clearSources(subscriber: inout AnySubscriber)
}

/// A type-erased subscriber.
public struct AnySubscriber: Identifiable, Sendable {
    public var id: Int
    public weak var subscriber: (any Subscriber & Sendable & AnyObject)?
}

extension AnySubscriber: AnySubscriberConvertible {
    public var anySubscriber: AnySubscriber {
        self
    }
}

extension AnySubscriber: Subscriber {
    public mutating func add(source: AnySource) {
        if var inner = subscriber {
            inner.add(source: source)
        }
    }
    
    public mutating func clearSources(subscriber: inout AnySubscriber) {
        if var inner = self.subscriber {
            inner.clearSources(subscriber: &subscriber)
        }
    }
}

extension AnySubscriber: ReactiveNode {
    public mutating func markDirty() {
        if var inner = subscriber {
            inner.markDirty()
        }
    }
    
    public mutating func markCheck() {
        if var inner = subscriber {
            inner.markCheck()
        }
    }
    
    public mutating func markSubscribersCheck() {
        if var inner = subscriber {
            inner.markSubscribersCheck()
        }
    }
    
    public mutating func updateIfNecessary() -> Bool {
        guard var inner = subscriber else {
            return false
        }
        
        return inner.updateIfNecessary()
    }
}

/// Runs code with some subscriber as the thread-local Observer.
public protocol WithObserver {
    /// Runs the given function with this subscriber as the thread-local Observer.
    mutating func withObserver<T>(fn: () -> T) -> T
}

extension AnySubscriber: WithObserver {
    /// Runs the given function with this subscriber as the thread-local Observer.
    public mutating func withObserver<T>(fn: () -> T) -> T {
        let prev = Observer.current
        Observer.current = self
        defer { Observer.current = prev }
        
        return fn()
    }
}

extension AnySubscriber: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        struct AnySubscriber {
            var id = \(id)
        }
        """
    }
}

extension AnySubscriber: Equatable {
    public static func == (lhs: AnySubscriber, rhs: AnySubscriber) -> Bool {
        lhs.id == rhs.id
    }
}

extension AnySubscriber: Hashable {
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}
