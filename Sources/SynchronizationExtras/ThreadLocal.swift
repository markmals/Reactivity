import Foundation

package struct ThreadLocal<Value>: Sendable where Value: Sendable {
    private var threadDictionary: NSMutableDictionary {
        Thread.current.threadDictionary
    }
    
    private let key: Int
    
    package init(_ wrappedValue: Value?) {
        let box = Box(wrappedValue)
        self.key = box.id
        
        guard let wrappedValue else {
            // Is this necessary in the init too?
            threadDictionary.removeObject(forKey: self.key)
            return
        }

        guard let threadBox = threadDictionary.object(forKey: self.key) as? Box<Value> else {
            threadDictionary.setObject(box, forKey: NSString(string: String(self.key)))
            return
        }
        
        threadBox.wrappedValue = wrappedValue
    }
    
    package var wrappedValue: Value? {
        get {
            (threadDictionary.object(forKey: key) as? Box<Value>)?.wrappedValue
        }
        nonmutating set {
            guard let newValue else {
                threadDictionary.removeObject(forKey: key)
                return
            }
            
            guard let box = threadDictionary.object(forKey: key) as? Box<Value> else {
                threadDictionary.setObject(Box(newValue), forKey: NSString(string: String(key)))
                return
            }
            
            box.wrappedValue = newValue
        }
    }
}
