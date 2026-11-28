import Foundation

// MARK: - Decoder

/// The `Decoder` behind `KroutonPersistedJSON`'s second read: it walks the JSON tree that
/// `JSONSerialization` produced, with the matching part of the enclosing type's default beside
/// it, and asks the context for every value so the repair rules apply at each level.
struct KroutonPersistedDecoder: Decoder {
    let context: KroutonPersistedDecodingContext
    let value: Any
    let fallback: Any?
    /// The keys of the type being decoded that must be read as saved (`requiredKeys`).
    var requiredKeys: Set<String> = []
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let object = value as? [String: Any] else {
            throw DecodingError.typeMismatch([String: Any].self, .init(codingPath: codingPath, debugDescription: "Expected an object"))
        }
        return KeyedDecodingContainer(KeyedContainer<Key>(decoder: self, object: object, fallback: fallback as? [String: Any]))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let array = value as? [Any] else {
            throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "Expected a list"))
        }
        return UnkeyedContainer(decoder: self, elements: array)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleContainer(decoder: self)
    }

    func child(_ value: Any, fallback: Any?, key: CodingKey) -> KroutonPersistedDecoder {
        KroutonPersistedDecoder(context: context, value: value, fallback: fallback, codingPath: codingPath + [key])
    }

    // MARK: - Primitives

    static func primitive<T>(_ type: T.Type, from value: Any, path: [CodingKey]) throws -> T {
        let mismatch = DecodingError.typeMismatch(type, .init(codingPath: path, debugDescription: "Not a \(type)"))
        if type == String.self {
            guard let text = value as? String, let result = text as? T else { throw mismatch }
            return result
        }
        guard let number = value as? NSNumber else { throw mismatch }
        if type == Bool.self {
            guard isBoolean(number), let result = number.boolValue as? T else { throw mismatch }
            return result
        }
        guard !isBoolean(number) else { throw mismatch }
        let result: Any?
        switch type {
        case is Double.Type: result = number.doubleValue
        case is Float.Type: result = number.floatValue
        case is Int.Type: result = exact(Int.self, number)
        case is Int8.Type: result = exact(Int8.self, number)
        case is Int16.Type: result = exact(Int16.self, number)
        case is Int32.Type: result = exact(Int32.self, number)
        case is Int64.Type: result = exact(Int64.self, number)
        case is UInt.Type: result = exact(UInt.self, number)
        case is UInt8.Type: result = exact(UInt8.self, number)
        case is UInt16.Type: result = exact(UInt16.self, number)
        case is UInt32.Type: result = exact(UInt32.self, number)
        case is UInt64.Type: result = exact(UInt64.self, number)
        default: result = nil
        }
        guard let typed = result as? T else { throw mismatch }
        return typed
    }

    /// A whole number that fits, as `JSONDecoder` requires; 1.5 or 300 for a `UInt8` don't.
    private static func exact<I: FixedWidthInteger>(_ type: I.Type, _ number: NSNumber) -> I? {
        let double = number.doubleValue
        guard double.rounded() == double else { return nil }
        return double < 0 ? I(exactly: number.int64Value) : I(exactly: number.uint64Value)
    }

    /// `JSONSerialization` gives true and false as `NSNumber`s that only their type tells apart.
    static func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}

// MARK: - Keyed

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: KroutonPersistedDecoder
    let object: [String: Any]
    let fallback: [String: Any]?
    var codingPath: [CodingKey] { decoder.codingPath }
    // Only what the file holds: a dictionary must not gain the default's entries.
    var allKeys: [Key] { object.keys.compactMap { Key(stringValue: $0) } }

    // An optional field is read only from the file, so a value saved as nil stays nil.
    func contains(_ key: Key) -> Bool { object[key.stringValue] != nil }

    func decodeNil(forKey key: Key) throws -> Bool {
        object[key.stringValue] == nil || object[key.stringValue] is NSNull
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try decoder.context.decode(type, from: object[key.stringValue], fallback: fallback?[key.stringValue],
                                   path: codingPath + [key], repairable: !decoder.requiredKeys.contains(key.stringValue))
    }

    /// An optional field the file holds but this version can't read becomes nil, rather than
    /// costing the record it belongs to.
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        do {
            return try decode(type, forKey: key)
        } catch where !decoder.requiredKeys.contains(key.stringValue) {
            decoder.context.note(codingPath + [key], "unreadable value, left empty")
            return nil
        }
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? { try optional(type, key) }
    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? { try optional(type, key) }
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? { try optional(type, key) }
    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? { try optional(type, key) }
    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? { try optional(type, key) }
    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? { try optional(type, key) }
    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? { try optional(type, key) }
    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? { try optional(type, key) }
    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? { try optional(type, key) }
    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? { try optional(type, key) }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? { try optional(type, key) }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? { try optional(type, key) }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? { try optional(type, key) }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? { try optional(type, key) }

    private func optional<T: Decodable>(_ type: T.Type, _ key: Key) throws -> T? {
        try decodeIfPresent(KroutonPrimitive<T>.self, forKey: key)?.value
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try decode(type, key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try decode(type, key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try decode(type, key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try decode(type, key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try decode(type, key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try decode(type, key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try decode(type, key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try decode(type, key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try decode(type, key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try decode(type, key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try decode(type, key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try decode(type, key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try decode(type, key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try decode(type, key) }

    /// Primitives go through the context too, so a missing or mistyped one takes the default.
    private func decode<T: Decodable>(_ type: T.Type, _ key: Key) throws -> T {
        try decode(KroutonPrimitive<T>.self, forKey: key).value
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try decoder.child(object[key.stringValue] ?? [String: Any](), fallback: fallback?[key.stringValue], key: key)
            .container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try decoder.child(object[key.stringValue] ?? [Any](), fallback: nil, key: key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder { decoder }
    func superDecoder(forKey key: Key) throws -> Decoder {
        decoder.child(object[key.stringValue] ?? [String: Any](), fallback: fallback?[key.stringValue], key: key)
    }
}

/// A primitive read through `KroutonPersistedDecodingContext.decode`, so the repair rules apply.
private struct KroutonPrimitive<T>: Decodable, _KroutonPrimitiveWrapper {
    static var wrappedType: Any.Type { T.self }
    let value: T
    init(from decoder: Decoder) throws {
        guard let persisted = decoder as? KroutonPersistedDecoder else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unexpected decoder"))
        }
        value = try KroutonPersistedDecoder.primitive(T.self, from: persisted.value, path: decoder.codingPath)
    }
}

// MARK: - Unkeyed

private struct UnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: KroutonPersistedDecoder
    let elements: [Any]
    private(set) var currentIndex = 0
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { elements.count }
    var isAtEnd: Bool { currentIndex >= elements.count }

    init(decoder: KroutonPersistedDecoder, elements: [Any]) {
        self.decoder = decoder
        self.elements = elements
    }

    private var key: CodingKey { KroutonPersistedKey(index: currentIndex) }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd, elements[currentIndex] is NSNull else { return false }
        currentIndex += 1
        return true
    }

    /// In order, one element at a time: lists that leave out unreadable elements are read by
    /// `_KroutonListDecoding` instead; this serves the rest, such as a dictionary keyed by
    /// UUID, which JSONEncoder writes as one list of keys and values in turn.
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(type, .init(codingPath: codingPath, debugDescription: "No element left"))
        }
        let value = try decoder.context.decode(type, from: elements[currentIndex], fallback: nil, path: codingPath + [key])
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try decode(KroutonPrimitive<Bool>.self).value }
    mutating func decode(_ type: String.Type) throws -> String { try decode(KroutonPrimitive<String>.self).value }
    mutating func decode(_ type: Double.Type) throws -> Double { try decode(KroutonPrimitive<Double>.self).value }
    mutating func decode(_ type: Float.Type) throws -> Float { try decode(KroutonPrimitive<Float>.self).value }
    mutating func decode(_ type: Int.Type) throws -> Int { try decode(KroutonPrimitive<Int>.self).value }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try decode(KroutonPrimitive<Int8>.self).value }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try decode(KroutonPrimitive<Int16>.self).value }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try decode(KroutonPrimitive<Int32>.self).value }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try decode(KroutonPrimitive<Int64>.self).value }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try decode(KroutonPrimitive<UInt>.self).value }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try decode(KroutonPrimitive<UInt8>.self).value }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try decode(KroutonPrimitive<UInt16>.self).value }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try decode(KroutonPrimitive<UInt32>.self).value }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try decode(KroutonPrimitive<UInt64>.self).value }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        defer { currentIndex += 1 }
        return try decoder.child(elements[currentIndex], fallback: nil, key: key).container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        defer { currentIndex += 1 }
        return try decoder.child(elements[currentIndex], fallback: nil, key: key).unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        defer { currentIndex += 1 }
        return decoder.child(elements[currentIndex], fallback: nil, key: key)
    }
}

// MARK: - Single Value

private struct SingleContainer: SingleValueDecodingContainer {
    let decoder: KroutonPersistedDecoder
    var codingPath: [CodingKey] { decoder.codingPath }

    func decodeNil() -> Bool { decoder.value is NSNull }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if let special = try? KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) {
            return special
        }
        return try decoder.context.decode(type, from: decoder.value, fallback: decoder.fallback, path: codingPath)
    }

    func decode(_ type: Bool.Type) throws -> Bool { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: String.Type) throws -> String { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Double.Type) throws -> Double { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Float.Type) throws -> Float { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Int.Type) throws -> Int { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try KroutonPersistedDecoder.primitive(type, from: decoder.value, path: codingPath) }
}
