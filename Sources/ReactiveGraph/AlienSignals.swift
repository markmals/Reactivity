// // Alien Signals – Swift 6.2 reimplementation (Value-Handle / Slot-Map)
// // Generated previously in a chat with GPT-5 Thinking
// // ----------------------------------------------------------------------
// // This version keeps the Alien Signals propagation algorithm but shifts the
// // *shape* of the implementation toward Leptos/Rust-style value semantics:
// //  - Public API uses *value* handles (structs) for signals/derived/effects
// //  - Graph data lives in a slot-map inside a single GraphStorage (indices
// //    + generations to avoid ABA and use-after-free)
// //  - Node payloads are type-erased boxes that expose minimal operations the
// //    runtime needs (update/getter/runner). Signal payloads keep a per-node
// //    Mutex; graph algorithms use a global graph Mutex
// //  - Task-local state drives dependency tracking and context, not MainActor
// //  - API surface: Root { ... }, @State, @Derived, @Context, effect { ... },
// //    onCleanup { ... }, $context.withValue { ... } / withValue(_:)
// //
// // Notes:
// //  • This file favors clarity over micro-optimizations; it is fully Sendable-
// //    safe in shape, and uses Synchronization.Mutex for correctness.
// //  • The graph-level lock is only taken for structural ops (link/unlink,
// //    propagation, queues). Per-node value reads/writes use the node mutex.
// //  • Synchronous propagation/flush to mirror Alien Signals semantics.

// import Foundation
// import Synchronization

// // MARK: - Reactive Flags

// public struct ReactiveFlags: OptionSet, Sendable {
//     public let rawValue: UInt32
//     public init(rawValue: UInt32) { self.rawValue = rawValue }

//     public static let none = ReactiveFlags([])
//     public static let mutable = ReactiveFlags(rawValue: 1 << 0)
//     public static let watching = ReactiveFlags(rawValue: 1 << 1)
//     public static let recursedCheck = ReactiveFlags(rawValue: 1 << 2)
//     public static let recursed = ReactiveFlags(rawValue: 1 << 3)
//     public static let dirty = ReactiveFlags(rawValue: 1 << 4)
//     public static let pending = ReactiveFlags(rawValue: 1 << 5)
//     public static let queued = ReactiveFlags(rawValue: 1 << 6)  // effect queue mark
// }

// // MARK: - Slot-map IDs

// public struct NodeID: Sendable, Hashable {
//     let i: Int
//     let gen: UInt32
// }
// public struct LinkID: Sendable, Hashable {
//     let i: Int
//     let gen: UInt32
// }

// // MARK: - Task-Local ambient state (per-task reactivity context)

// @TaskLocal var currentOwner: Owner? = nil
// @TaskLocal var currentSub: NodeID? = nil
// @TaskLocal var currentScope: NodeID? = nil
// @TaskLocal var context: [UUID: Any] = [:]

// // MARK: - Owner / cleanup container

// public final class Owner: @unchecked Sendable {
//     weak var parent: Owner?
//     var cleanups: [() -> Void] = []
//     init(parent: Owner?) { self.parent = parent }
// }

// // MARK: - Type-erased payloads used by the runtime

// private protocol SignalNodeProtocolWrapper: AnyObject { func _update() -> Bool }
// private protocol ComputedNodeProtocolWrapper: AnyObject { func _update(node: NodeID) -> Bool }
// private protocol EffectNodeProtocolWrapper: AnyObject { func _run() }

// // Per-node value storage for signals (typed)
// final class SignalBox<T>: @unchecked Sendable {
//     let lock = Mutex<Void>(())
//     var previous: T
//     var value: T
//     let equals: ((T, T) -> Bool)?
//     init(_ v: T, equals: ((T, T) -> Bool)?) {
//         previous = v
//         value = v
//         self.equals = equals
//     }
//     func updateChangeFromCurrent() -> Bool {
//         var changed = false
//         lock.withLock { _ in
//             if let eq = equals {
//                 changed = !eq(previous, value)
//             } else {
//                 changed = !AnyEquatable.equals(previous, value)
//             }
//             if changed { previous = value }
//         }
//         return changed
//     }
// }

// final class SignalErased: SignalNodeProtocolWrapper {
//     private let impl: () -> Bool
//     init<T>(_ box: SignalBox<T>) { self.impl = { box.updateChangeFromCurrent() } }
//     func _update() -> Bool { impl() }
// }

// final class ComputedErased: @unchecked Sendable, ComputedNodeProtocolWrapper {
//     var value: Any?
//     let getter: (Any?) -> Any
//     init<T>(_ getter: @escaping (T?) -> T) { self.getter = { anyOld in getter(anyOld as? T) } }
//     func _update(node: NodeID) -> Bool {
//         System.startTracking(node)
//         defer { System.endTracking(node) }
//         return $currentSub.withValue(node) {
//             let old = value
//             let new = getter(old)
//             value = new
//             return !AnyOptionalEquality.equals(old, new)
//         }
//     }
// }

// final class EffectErased: EffectNodeProtocolWrapper {
//     let fn: () -> Void
//     init(_ fn: @escaping () -> Void) { self.fn = fn }
//     func _run() { fn() }
// }

// // MARK: - Graph storage

// final class GraphStorage: @unchecked Sendable {
//     struct NodeRecord {
//         var flags: ReactiveFlags = .none
//         var subsHead: LinkID? = nil
//         var subsTail: LinkID? = nil
//         var depsHead: LinkID? = nil
//         var depsTail: LinkID? = nil
//         var kind: NodeKind = .scope
//         var gen: UInt32 = 0
//     }
//     struct LinkRecord {
//         var version: Int
//         var dep: NodeID
//         var sub: NodeID
//         var prevSub: LinkID?
//         var nextSub: LinkID?
//         var prevDep: LinkID?
//         var nextDep: LinkID?
//         var gen: UInt32
//     }

//     enum NodeKind {
//         case signal(SignalErased)
//         case computed(ComputedErased)
//         case effect(EffectErased)
//         case scope
//     }

//     // Global graph state
//     let lock = Mutex<Void>(())
//     var version: Int = 0

//     var nodes: [NodeRecord] = []
//     var links: [LinkRecord] = []
//     var freeNodes: [Int] = []
//     var freeLinks: [Int] = []

//     // Effect queue
//     var queued: [NodeID] = []
//     var notifyIndex: Int = 0

//     // Allocation helpers
//     func allocNode(kind: NodeKind, flags: ReactiveFlags) -> NodeID {
//         lock.withLock { _ in
//             let idx: Int
//             if let f = freeNodes.popLast() {
//                 idx = f
//                 nodes[idx].gen &+= 1
//                 nodes[idx].flags = flags
//                 nodes[idx].subsHead = nil
//                 nodes[idx].subsTail = nil
//                 nodes[idx].depsHead = nil
//                 nodes[idx].depsTail = nil
//                 nodes[idx].kind = kind
//             } else {
//                 nodes.append(
//                     NodeRecord(
//                         flags: flags, subsHead: nil, subsTail: nil, depsHead: nil, depsTail: nil,
//                         kind: kind, gen: 0))
//                 idx = nodes.count - 1
//             }
//             return NodeID(i: idx, gen: nodes[idx].gen)
//         }
//     }

//     func allocLink(dep: NodeID, sub: NodeID) -> LinkID {
//         lock.withLock { _ in
//             let idx: Int
//             if let f = freeLinks.popLast() {
//                 idx = f
//                 links[idx].gen &+= 1
//                 links[idx].dep = dep
//                 links[idx].sub = sub
//                 links[idx].prevDep = nil
//                 links[idx].nextDep = nil
//                 links[idx].prevSub = nil
//                 links[idx].nextSub = nil
//                 links[idx].version = version
//             } else {
//                 links.append(
//                     LinkRecord(
//                         version: version, dep: dep, sub: sub, prevSub: nil, nextSub: nil,
//                         prevDep: nil, nextDep: nil, gen: 0))
//                 idx = links.count - 1
//             }
//             return LinkID(i: idx, gen: links[idx].gen)
//         }
//     }

//     // Node access (with generation check)
//     @discardableResult
//     func withNode<R>(_ id: NodeID, _ body: (inout NodeRecord) -> R) -> R {
//         return lock.withLock { _ in
//             precondition(
//                 nodes.indices.contains(id.i) && nodes[id.i].gen == id.gen, "Invalid NodeID")
//             return body(&nodes[id.i])
//         }
//     }
//     @discardableResult
//     func readNode<R>(_ id: NodeID, _ body: (NodeRecord) -> R) -> R {
//         return lock.withLock { _ in
//             precondition(
//                 nodes.indices.contains(id.i) && nodes[id.i].gen == id.gen, "Invalid NodeID")
//             return body(nodes[id.i])
//         }
//     }

//     func withLink<R>(_ id: LinkID, _ body: (inout LinkRecord) -> R) -> R {
//         return lock.withLock { _ in
//             precondition(
//                 links.indices.contains(id.i) && links[id.i].gen == id.gen, "Invalid LinkID")
//             return body(&links[id.i])
//         }
//     }
//     func readLink<R>(_ id: LinkID, _ body: (LinkRecord) -> R) -> R {
//         return lock.withLock { _ in
//             precondition(
//                 links.indices.contains(id.i) && links[id.i].gen == id.gen, "Invalid LinkID")
//             return body(links[id.i])
//         }
//     }

//     // MARK: Link
//     func link(_ dep: NodeID, _ sub: NodeID) {
//         lock.withLock { _ in
//             version &+= 1
//             var subRec = nodes[sub.i]
//             precondition(subRec.gen == sub.gen)
//             var depRec = nodes[dep.i]
//             precondition(depRec.gen == dep.gen)

//             let prevDep = subRec.depsTail
//             if let p = prevDep, links[p.i].gen == p.gen, links[p.i].dep == dep { return }

//             let nextDep = prevDep != nil ? links[prevDep!.i].nextDep : subRec.depsHead
//             if let nd = nextDep, links[nd.i].dep == dep {
//                 links[nd.i].version = version
//                 subRec.depsTail = nd
//                 nodes[sub.i] = subRec
//                 return
//             }

//             let prevSub = depRec.subsTail
//             if let ps = prevSub, links[ps.i].version == version, links[ps.i].sub == sub { return }

//             let newLink = allocLink(dep: dep, sub: sub)
//             // wire dep dimension
//             if let nd = nextDep { links[nd.i].prevDep = newLink }
//             if let pd = prevDep { links[pd.i].nextDep = newLink } else { subRec.depsHead = newLink }
//             subRec.depsTail = newLink

//             // wire sub dimension
//             if let ps = prevSub { links[ps.i].nextSub = newLink } else { depRec.subsHead = newLink }
//             depRec.subsTail = newLink

//             nodes[sub.i] = subRec
//             nodes[dep.i] = depRec
//         }
//     }

//     // MARK: Unlink
//     @discardableResult
//     func unlink(_ link: LinkID, sub overrideSub: NodeID? = nil) -> LinkID? {
//         var nextDepOut: LinkID? = nil
//         lock.withLock { _ in
//             let lr = links[link.i]
//             precondition(lr.gen == link.gen)
//             let sub = overrideSub ?? lr.sub
//             var subRec = nodes[sub.i]
//             precondition(subRec.gen == sub.gen)
//             let dep = lr.dep
//             var depRec = nodes[dep.i]
//             precondition(depRec.gen == dep.gen)

//             // dep list
//             if let nd = lr.nextDep {
//                 links[nd.i].prevDep = lr.prevDep
//             } else {
//                 subRec.depsTail = lr.prevDep
//             }
//             if let pd = lr.prevDep {
//                 links[pd.i].nextDep = lr.nextDep
//             } else {
//                 subRec.depsHead = lr.nextDep
//             }

//             // sub list
//             if let ns = lr.nextSub {
//                 links[ns.i].prevSub = lr.prevSub
//             } else {
//                 depRec.subsTail = lr.prevSub
//             }
//             if let ps = lr.prevSub {
//                 links[ps.i].nextSub = lr.nextSub
//             } else {
//                 depRec.subsHead = lr.nextSub
//                 if lr.nextSub == nil { unwatched(dep) }
//             }

//             nodes[sub.i] = subRec
//             nodes[dep.i] = depRec
//             nextDepOut = lr.nextDep
//         }
//         return nextDepOut
//     }

//     // MARK: Start/End tracking
//     func startTracking(_ sub: NodeID) {
//         lock.withLock { _ in version &+= 1 }
//         withNode(sub) { n in
//             n.depsTail = nil
//             n.flags.subtract([.recursed, .dirty, .pending])
//             n.flags.insert(.recursedCheck)
//         }
//     }

//     func endTracking(_ sub: NodeID) {
//         var toRemove: LinkID?
//         lock.withLock { _ in
//             let rec = nodes[sub.i]
//             toRemove = (rec.depsTail != nil) ? links[rec.depsTail!.i].nextDep : rec.depsHead
//         }
//         while let rm = toRemove { toRemove = unlink(rm, sub: sub) }
//         withNode(sub) { $0.flags.remove([.recursedCheck]) }
//     }

//     // MARK: Shallow propagate
//     func shallowPropagate(_ start: LinkID) {
//         var cur: LinkID? = start
//         while let link = cur {
//             let sub = readLink(link) { $0.sub }
//             withNode(sub) { node in
//                 let flags = node.flags
//                 if flags.contains(.pending) && !flags.contains(.dirty) {
//                     node.flags.insert(.dirty)
//                     if flags.contains(.watching) { notify(sub) }
//                 }
//             }
//             cur = readLink(link) { $0.nextSub }
//         }
//     }

//     // MARK: Propagate (DFS)
//     func propagate(_ start: LinkID) {
//         var link = start
//         var next = readLink(link) { $0.nextSub }
//         var stack: [LinkID?] = []

//         traversal: while true {
//             let sub = readLink(link) { $0.sub }
//             var localFlags = readNode(sub) { $0.flags }

//             let mask: ReactiveFlags = [.recursedCheck, .recursed, .dirty, .pending]
//             if !localFlags.intersection(mask).isEmpty {
//                 if !localFlags.intersection([.recursed, .recursedCheck]).isEmpty {
//                     if !localFlags.contains(.recursedCheck) {
//                         withNode(sub) {
//                             $0.flags = localFlags.subtracting([.recursed]).union([.pending])
//                         }
//                     } else if !localFlags.intersection([.dirty, .pending]).isEmpty
//                         && isValid(link, sub: sub)
//                     {
//                         withNode(sub) { $0.flags = localFlags.union([.recursed, .pending]) }
//                         localFlags = localFlags.intersection([.mutable])
//                     } else {
//                         localFlags = .none
//                     }
//                 } else {
//                     localFlags = .none
//                 }
//             } else {
//                 withNode(sub) { $0.flags = localFlags.union([.pending]) }
//             }

//             if localFlags.contains(.watching) { notify(sub) }

//             if localFlags.contains(.mutable) {
//                 if let subSubs = readNode(sub, { $0.subsHead }) {
//                     link = subSubs
//                     if let ns = readLink(link, { $0.nextSub }) {
//                         stack.append(next)
//                         next = ns
//                     }
//                     continue
//                 }
//             }

//             if let n = next {
//                 link = n
//                 next = readLink(n) { $0.nextSub }
//                 continue
//             }

//             while let popped = stack.popLast() {
//                 if let p = popped {
//                     link = p
//                     next = readLink(p) { $0.nextSub }
//                     continue traversal
//                 }
//             }
//             break
//         }
//     }

//     private func isValid(_ check: LinkID, sub: NodeID) -> Bool {
//         return readNode(sub) { rec in
//             if let tail = rec.depsTail {
//                 var l: LinkID? = rec.depsHead
//                 while let cur = l {
//                     if cur == check { return true }
//                     if cur == tail { break }
//                     l = links[cur.i].nextDep
//                 }
//             }
//             return false
//         }
//     }

//     // MARK: Dirty checking walk
//     func checkDirty(_ start: LinkID, sub startSub: NodeID) -> Bool {
//         var link = start
//         var sub = startSub
//         var stack: [LinkID] = []
//         var depth = 0

//         while true {
//             let dep = readLink(link) { $0.dep }
//             let depFlags = readNode(dep) { $0.flags }
//             var dirty = false

//             if readNode(sub, { $0.flags }).contains(.dirty) {
//                 dirty = true
//             } else if depFlags.contains([.mutable, .dirty]) {
//                 if update(dep) {
//                     if let subs = readNode(dep, { $0.subsHead }),
//                         readLink(subs, { $0.nextSub }) != nil
//                     {
//                         shallowPropagate(subs)
//                     }
//                     dirty = true
//                 }
//             } else if depFlags.contains([.mutable, .pending]) {
//                 let hasNeighbors =
//                     readLink(link, { $0.nextSub }) != nil || readLink(link, { $0.prevSub }) != nil
//                 if hasNeighbors { stack.append(link) }
//                 if let d = readNode(dep, { $0.depsHead }) {
//                     link = d
//                     sub = dep
//                     depth &+= 1
//                     continue
//                 }
//             }

//             if !dirty {
//                 if let nd = readLink(link, { $0.nextDep }) {
//                     link = nd
//                     continue
//                 }
//             }

//             while depth > 0 {
//                 depth &-= 1
//                 let firstSub = readNode(sub, { $0.subsHead! })
//                 let multiple = readLink(firstSub, { $0.nextSub }) != nil
//                 if multiple { link = stack.removeLast() } else { link = firstSub }

//                 if dirty {
//                     if update(sub) {
//                         if multiple { shallowPropagate(firstSub) }
//                         sub = readLink(link, { $0.sub })
//                         continue
//                     }
//                 } else {
//                     withNode(sub) { $0.flags.remove([.pending]) }
//                 }
//                 sub = readLink(link, { $0.sub })
//                 if let nd = readLink(link, { $0.nextDep }) {
//                     link = nd
//                     continue
//                 }
//                 dirty = false
//             }

//             return dirty
//         }
//     }

//     // MARK: Update dispatch
//     func update(_ node: NodeID) -> Bool {
//         readNode(node) { $0.kind }
//         switch readNode(node, { $0.kind }) {
//         case .computed(let c):
//             return c._update(node: node)
//         case .signal(let s):
//             withNode(node) { $0.flags.insert(.mutable) }
//             return s._update()
//         default:
//             return false
//         }
//     }

//     // MARK: Notify / run / flush
//     func notify(_ node: NodeID) {
//         withNode(node) { rec in
//             if !rec.flags.contains(.queued) {
//                 rec.flags.insert(.queued)
//                 if let parent = rec.subsHead {  // bubble to root effect/scope
//                     let sub = readLink(parent) { $0.sub }
//                     notify(sub)
//                 } else {
//                     queued.append(node)
//                 }
//             }
//         }
//     }

//     func run(_ node: NodeID, flags: ReactiveFlags) {
//         if flags.contains(.dirty)
//             || (flags.contains(.pending)
//                 && readNode(node, { $0.depsHead }).map { checkDirty($0, sub: node) } == true)
//         {
//             $currentSub.withValue(node) {
//                 startTracking(node)
//                 defer { endTracking(node) }
//                 if case .effect(let e) = readNode(node, { $0.kind }) { e._run() }
//             }
//             return
//         } else if flags.contains(.pending) {
//             withNode(node) { $0.flags.remove([.pending]) }
//         }

//         var l = readNode(node, { $0.depsHead })
//         while let link = l {
//             let dep = readLink(link) { $0.dep }
//             let depFlags = readNode(dep) { $0.flags }
//             if depFlags.contains(.queued) {
//                 withNode(dep) { $0.flags.remove([.queued]) }
//                 run(dep, flags: depFlags)
//             }
//             l = readLink(link) { $0.nextDep }
//         }
//     }

//     func flush() {
//         while true {
//             var next: NodeID? = nil
//             lock.withLock { _ in
//                 if notifyIndex < queued.count {
//                     next = queued[notifyIndex]
//                     notifyIndex &+= 1
//                 }
//             }
//             guard let n = next else { break }
//             let flags = readNode(n) { $0.flags }
//             withNode(n) { $0.flags.remove([.queued]) }
//             run(n, flags: flags)
//         }
//         lock.withLock { _ in
//             notifyIndex = 0
//             queued.removeAll(keepingCapacity: false)
//         }
//     }

//     // Called when a node loses all subscribers
//     func unwatched(_ node: NodeID) {
//         switch readNode(node, { $0.kind }) {
//         case .computed:
//             withNode(node) { $0.flags.insert([.mutable, .dirty]) }
//         // deps are already unlinked by caller
//         case .effect, .scope:
//             effectDispose(node)
//         case .signal:
//             break
//         }
//     }

//     // Dispose an effect/scope node
//     func effectDispose(_ node: NodeID) {
//         var dep = readNode(node, { $0.depsHead })
//         while let d = dep { dep = unlink(d, sub: node) }
//         if let sub = readNode(node, { $0.subsHead }) { _ = unlink(sub) }
//         withNode(node) { $0.flags = .none }
//     }

//     // Helper
//     func subsHead(of node: NodeID) -> LinkID? { readNode(node) { $0.subsHead } }
// }

// // Global graph instance
// private let GRAPH = GraphStorage()

// // MARK: - Public API (value-semantic handles)

// @discardableResult
// public func effect(_ fn: @escaping () -> Void) -> () -> Void {
//     let e = GRAPH.allocNode(kind: .effect(EffectErased(fn)), flags: [.watching])
//     if let sub = currentSub {
//         GRAPH.link(e, sub)
//     } else if let scope = currentScope {
//         GRAPH.link(e, scope)
//     }
//     $currentSub.withValue(e) { fn() }
//     return { GRAPH.effectDispose(e) }
// }

// @discardableResult
// public func effectScope(_ body: () -> Void) -> () -> Void {
//     let scope = GRAPH.allocNode(kind: .scope, flags: .none)
//     if let active = currentScope { GRAPH.link(scope, active) }
//     $currentScope.withValue(scope) { body() }
//     return { GRAPH.effectDispose(scope) }
// }

// @discardableResult
// public func Root<T>(_ body: (@escaping () -> Void) -> T) -> T {
//     let owner = Owner(parent: currentOwner)
//     let scope = GRAPH.allocNode(kind: .scope, flags: .none)
//     func dispose() {
//         GRAPH.effectDispose(scope)
//         let cleanups = owner.cleanups
//         owner.cleanups.removeAll()
//         for c in cleanups { c() }
//     }
//     return $currentOwner.withValue(owner) {
//         $currentScope.withValue(scope) {
//             body(dispose)
//         }
//     }
// }

// public func onCleanup(_ fn: @escaping () -> Void) { currentOwner?.cleanups.append(fn) }

// // MARK: - Property wrappers

// // @State – value-semantics handle over shared storage
// @propertyWrapper
// public struct State<T>: Sendable {
//     private let id: NodeID
//     private let box: SignalBox<T>

//     public init(wrappedValue initial: T, equals: ((T, T) -> Bool)? = nil) {
//         self.box = SignalBox(initial, equals: equals)
//         self.id = GRAPH.allocNode(kind: .signal(SignalErased(box)), flags: [.mutable])
//     }

//     public var wrappedValue: T {
//         get {
//             if let sub = currentSub {
//                 GRAPH.link(id, sub)
//             } else if let scope = currentScope {
//                 GRAPH.link(id, scope)
//             }
//             // pull-through dirty → previous sync
//             if GRAPH.readNode(id, { $0.flags.contains(.dirty) }) {
//                 if GRAPH.update(id) {
//                     if let head = GRAPH.subsHead(of: id) { GRAPH.shallowPropagate(head) }
//                 }
//             }
//             return box.lock.withLock { _ in box.value }
//         }
//         nonmutating set {
//             var changed = false
//             box.lock.withLock { _ in
//                 changed =
//                     !(box.equals?(box.value, newValue) ?? AnyEquatable.equals(box.value, newValue))
//                 box.value = newValue
//                 if changed { /* mark */  }
//             }
//             if changed {
//                 GRAPH.withNode(id) { $0.flags.insert([.mutable, .dirty]) }
//                 if let subs = GRAPH.subsHead(of: id) {
//                     GRAPH.propagate(subs)
//                     GRAPH.flush()
//                 }
//             }
//         }
//     }

//     public var projectedValue: SignalAccessor<T> { SignalAccessor(id: id, box: box) }
// }

// public struct SignalAccessor<T>: Sendable {
//     fileprivate let id: NodeID
//     fileprivate let box: SignalBox<T>
//     public func get() -> T { box.lock.withLock { _ in box.value } }
//     public func set(_ newValue: T) {
//         var s = State(wrappedValue: box.lock.withLock { _ in box.value })
//         s = State(wrappedValue: newValue)  // intentionally no-op here; prefer direct mutation via wrapper
//     }
// }

// // @Derived – computed memo
// @propertyWrapper
// public struct Derived<T>: Sendable {
//     private let id: NodeID
//     private let erased: ComputedErased

//     public init(wrappedValue expression: @autoclosure @escaping () -> T) {
//         let e = ComputedErased { (_: T?) in expression() }
//         self.erased = e
//         self.id = GRAPH.allocNode(kind: .computed(e), flags: [.mutable, .dirty])
//     }

//     public var wrappedValue: T {
//         let flags = GRAPH.readNode(id) { $0.flags }
//         if flags.contains(.dirty)
//             || (flags.contains(.pending)
//                 && GRAPH.readNode(id, { $0.depsHead }).map { GRAPH.checkDirty($0, sub: id) } == true)
//         {
//             if GRAPH.update(id) {
//                 if let subs = GRAPH.readNode(id, { $0.subsHead }),
//                     GRAPH.readLink(subs, { $0.nextSub }) != nil
//                 {
//                     GRAPH.shallowPropagate(subs)
//                 }
//             }
//         } else if flags.contains(.pending) {
//             GRAPH.withNode(id) { $0.flags.remove([.pending]) }
//         }
//         if let sub = currentSub {
//             GRAPH.link(id, sub)
//         } else if let scope = currentScope {
//             GRAPH.link(id, scope)
//         }
//         return erased.value as! T
//     }
// }

// // @Context – dynamic task-local context (non-reactive)
// @propertyWrapper
// public struct Context<T: Sendable>: Sendable {
//     private let id = UUID()
//     private let defaultValue: T

//     public init(wrappedValue: T) { self.defaultValue = wrappedValue }

//     public var wrappedValue: T {
//         return context[id] as? T ?? defaultValue
//     }

//     public var projectedValue: ContextHandle<T> {
//         ContextHandle(id: id, defaultValue: defaultValue)
//     }
// }

// public struct ContextHandle<T: Sendable>: Sendable {
//     fileprivate let id: UUID
//     fileprivate let defaultValue: T

//     public func withValue<R>(_ body: () throws -> R) rethrows -> R {
//         try withValue(defaultValue, body)
//     }
//     public func withValue<R>(_ value: T, _ body: () throws -> R) rethrows -> R {
//         var dict = context
//         dict[id] = value
//         return try $context.withValue(dict) { try body() }
//     }
// }

// // MARK: - Helpers

// private enum AnyEquatable {
//     static func equals<T:>(_ a: T, _ b: T) -> Bool {
//         if let aa = a as? any Equatable, let bb = b as? any Equatable {
//             return AnyHashable(aa) == AnyHashable(bb)
//         }
//         return String(describing: a) == String(describing: b)
//     }
// }
// private enum AnyOptionalEquality {
//     static func equals(_ a: Any?, _ b: Any?) -> Bool {
//         switch (a, b) {
//         case (nil, nil): return true
//         case let (x?, y?): return String(describing: x) == String(describing: y)
//         default: return false
//         }
//     }
// }

// // MARK: - System façade (thin wrappers for symmetry with original paper)

// enum System {
//     @inline(__always) static func link(_ dep: NodeID, _ sub: NodeID) { GRAPH.link(dep, sub) }
//     @inline(__always) static func unlink(_ link: LinkID, sub: NodeID? = nil) -> LinkID? {
//         GRAPH.unlink(link, sub: sub)
//     }
//     @inline(__always) static func propagate(_ start: LinkID) { GRAPH.propagate(start) }
//     @inline(__always) static func shallowPropagate(_ start: LinkID) {
//         GRAPH.shallowPropagate(start)
//     }
//     @inline(__always) static func startTracking(_ sub: NodeID) { GRAPH.startTracking(sub) }
//     @inline(__always) static func endTracking(_ sub: NodeID) { GRAPH.endTracking(sub) }
//     @inline(__always) static func checkDirty(_ start: LinkID, sub: NodeID) -> Bool {
//         GRAPH.checkDirty(start, sub: sub)
//     }
//     @inline(__always) static func notify(_ sub: NodeID) { GRAPH.notify(sub) }
//     @inline(__always) static func update(_ node: NodeID) -> Bool { GRAPH.update(node) }
// }
