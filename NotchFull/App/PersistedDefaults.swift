import Foundation

extension UserDefaults {
    /// Stored value for `key`, or `fallback` when the key was never written or holds another type.
    func value<Value>(forKey key: String, default fallback: Value) -> Value {
        object(forKey: key) as? Value ?? fallback
    }

    /// Stored raw value decoded into `Value`, or `fallback` when missing or no longer a valid case.
    func rawValue<Value: RawRepresentable>(forKey key: String, default fallback: Value) -> Value where Value.RawValue == String {
        string(forKey: key).flatMap(Value.init(rawValue:)) ?? fallback
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
