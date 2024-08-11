/**
 Types that hold the set of sources or subscribers affiliated with a reactive node.
 
 At the moment, these are implemented as a wrapper around an `Array`. This is for the sake
 of minimizing binary size as much as possible, and on the assumption that the M:N relationship
 between sources and subscribers usually consists of fairly small numbers, such that the cost of
 a linear search is not significantly more expensive than a hash and lookup.
 */

public struct SourceSet {
    public var sources: [AnySource] = []
    
    public mutating func insert(_ source: AnySource) {
        sources.append(source)
    }
    
    public mutating func remove(_ source: inout AnySource) {
        if let index = sources.firstIndex(of: source) {
            sources.remove(at: index)
        }
    }
    
    public var count: Int {
        sources.count
    }
    
    public mutating func clearSources(subscriber: inout AnySubscriber) {
        for index in sources.indices {
            sources[index].remove(subscriber: &subscriber)
        }
    }
}

extension SourceSet: Sequence {
    public typealias Element = AnySource
    public typealias Iterator = [AnySource].Iterator
    
    public func makeIterator() -> Iterator {
        sources.makeIterator()
    }
}

public struct SubscriberSet {
    public var subscribers: [AnySubscriber] = []
    
    init() {
        subscribers.reserveCapacity(2)
    }
    
    public mutating func subscribe(to subscriber: AnySubscriber) {
        if !subscribers.contains(subscriber) {
            subscribers.append(subscriber)
        }
    }
    
    public mutating func unsubscribe(from subscriber: inout AnySubscriber) {
        if let index = subscribers.firstIndex(of: subscriber) {
            subscribers.remove(at: index)
        }
    }
    
    public var count: Int {
        subscribers.count
    }
}

extension SubscriberSet: Sequence {
    public typealias Element = AnySubscriber
    public typealias Iterator = [AnySubscriber].Iterator
    
    public func makeIterator() -> Iterator {
        subscribers.makeIterator()
    }
}

//ExpressibleByArrayLiteral
//Sequence
//Collection
//Equatable
//Hashable
//SetAlgebra

//CustomStringConvertible, CustomDebugStringConvertible
/// A string that represents the contents of the set.
//public var description: String { get }

/// A string that represents the contents of the set, suitable for debugging.
//public var debugDescription: String { get }
