package class Box<Wrapped>: Identifiable {
    package var id: Int { ObjectIdentifier(self).hashValue }
    
    package var wrappedValue: Wrapped
    
    package init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}
