import SynchronizationExtras

/// The reactive ownership model, which manages effect cancelation, cleanups, and arena allocation.

/// A reactive owner, which manages
/// 1) the cancelation of [`Effect`](crate::effect::Effect)s,
/// 2) providing and accessing environment data via [`provide_context`] and [`use_context`],
/// 3) running cleanup functions defined via [`Owner::on_cleanup`], and
/// 4) an arena storage system to provide `Copy` handles via [`StoredValue`], which is what allows
///    types like [`RwSignal`](crate::signal::RwSignal), [`Memo`](crate::computed::Memo), and so on to be `Copy`.
///
/// Every effect and computed reactive value has an associated `Owner`. While it is running, this
/// is marked as the current `Owner`. Whenever it re-runs, this `Owner` is cleared by calling
/// [`Owner::with_cleanup`]. This runs cleanup functions, cancels any [`Effect`](crate::effect::Effect)s created during the
/// last run, drops signals stored in the arena, and so on, because those effects and signals will
/// be re-created as needed during the next run.
///
/// When the owner is ultimately dropped, it will clean up its owned resources in the same way.
///
/// The "current owner" is set on the thread-local basis: whenever one of these reactive nodes is
/// running, it will set the current owner on its thread with [`Owner::with`] or [`Owner::set`],
/// allowing other reactive nodes implicitly to access the fact that it is currently the owner.
public struct Owner: Sendable, CustomDebugStringConvertible {
    package static let current = ThreadLocal<Owner>(nil)
    
    package var inner: Inner
    
    /// Returns a unique identifier for this owner, which can be used to identify it for debugging
    /// purposes.
    ///
    /// Intended for debugging only; this is not guaranteed to be stable between runs.
    public var debugDescription: String {
        ObjectIdentifier(inner).debugDescription
    }
    
    /// Returns the list of parents, grandparents, and ancestors, with values corresponding to
    /// Owner.debugDescription for each.
    ///
    /// Intended for debugging only; this is not guaranteed to be stable between runs.
    public var ancestry: [String] {
        get async {
            var ancestors: [String] = []
            var currentParent = await inner.parent
            
            while let parent = currentParent {
                ancestors.append(ObjectIdentifier(parent).debugDescription)
                currentParent = await parent.parent
            }
            
            return ancestors
        }
    }
    
    private init(_ inner: Inner) {
        self.inner = inner
    }
    
    /// Creates a new `Owner` and registers it as a child of the current `Owner`, if there is one.
    public init() async {
        self.inner = Inner()
        if let parent = Owner.current.wrappedValue?.inner {
            await parent.add(child: self.inner)
        }
    }
    
    /// Creates a new `Owner` that is the child of the current `Owner`, if any.
    public func createChild() async -> Self {
        let child = Self(Inner(parent: inner))
        await inner.add(child: child.inner)
        return child
    }
    
    /// Sets this as the current `Owner`.
    public func setAsCurrent() {
        Owner.current.wrappedValue = self
    }
    
    /// Runs the given function with this as the current `Owner`.
    @discardableResult
    public func with<T>(_ fn: () -> T) -> T {
        let prev = Owner.current.wrappedValue
        Owner.current.wrappedValue = self
        defer { Owner.current.wrappedValue = prev }
        return fn()
    }
    
    /// Cleans up this owner, the given function with this as the current `Owner`.
    public func withCleanup<T>(_ fn: () -> T) async -> T {
        await cleanup()
        return with(fn)
    }
    
    /// Cleans up this owner in the following order:
    /// 1) Runs `cleanup` on all children,
    /// 2) Runs all cleanup functions registered with [`Owner::on_cleanup`],
    /// 3) Drops the values of any arena-allocated [`StoredValue`]s.
    public func cleanup() async {
        await inner.cleanup()
    }
    
    /// Registers a function to be run the next time the current owner is cleaned up.
    ///
    /// Because the ownership model is associated with reactive nodes, each "decision point" in an
    /// application tends to have a separate `Owner`: as a result, these cleanup functions often
    /// fill the same need as an "on unmount" function in other UI approaches, etc.
    public static func onCleanup(register handler: @escaping CleanupHandler) async {
        if let owner = Owner.current.wrappedValue {
            await owner.inner.add(cleanup: handler)
        }
    }
    
    func register(node: NodeID) async {
        await inner.add(node: node)
    }

    /// The current `Owner`, if any.
    public var current: Self? {
        Owner.current.wrappedValue
    }
    
    // This is probably wrong... I was hoping to use an actor but maybe I just need some locks?
    // What's the Swift equivelant of Rust's `RwLock`?
    package actor Inner {
        package weak var parent: Inner?
        var nodes: [NodeID] = []
        package var contexts: [ObjectIdentifier: (any Sendable & Hashable)] = [:]
        package var cleanups: [CleanupHandler] = []
        package var children: [Inner] = []
        
        init() {}
            
        init(parent: Inner) {
            self.parent = parent
        }
        
        func add(child: Inner) {
            children.append(child)
        }
        
        func add(cleanup: @escaping CleanupHandler) {
            cleanups.append(cleanup)
        }
        
        func add(node: NodeID) {
            nodes.append(node)
        }
        
        func cleanup() async {
            for child in children {
                await child.cleanup()
            }
            
            for handler in cleanups {
                handler()
            }

//            if !nodes.isEmpty {
//                for node in nodes {
//                    Arena.current.remove(node)
//                }
//            }
        }

        deinit {
            Task { await self.cleanup() }
        }
    }
}

public typealias CleanupHandler = @Sendable () -> Void

/// Registers a function to be run the next time the current owner is cleaned up.
///
/// Because the ownership model is associated with reactive nodes, each "decision point" in an
/// application tends to have a separate `Owner`: as a result, these cleanup functions often
/// fill the same need as an "on unmount" function in other UI approaches, etc.
///
/// This is an alias for `Owner.onCleanup`.
public func onCleanup(register handler: @escaping CleanupHandler) async {
    await Owner.onCleanup(register: handler)
}
