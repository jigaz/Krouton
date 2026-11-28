import Foundation

// MARK: - Opening Files Saved by Another Version

/// A type saved in projects or sessions that names the value it starts with. When a file lacks
/// one of its fields (saved before the field existed) or holds a value this version can't read,
/// `KroutonPersistedJSON` takes that field from here instead of failing the whole file.
public protocol KroutonPersistedDefault: Codable {
    static var persistedDefault: Self { get }
    /// Fields nothing may fill in, because a guess would turn the record into something else: a
    /// destination card's kind (a guessed card would be a disc burner). A record with one of these
    /// missing or unreadable can't be read, so its list leaves it out. `id` is never taken from
    /// the default either: each record missing one gets a new UUID.
    static var requiredKeys: Set<String> { get }
}

extension KroutonPersistedDefault {
    public static var requiredKeys: Set<String> { [] }
}

/// Reads JSON that Krouton saved, from this version or another.
///
/// It first decodes exactly as `JSONDecoder` does, so a file this version wrote opens as before.
/// Only a file `JSONDecoder` refuses is read a second time, and then:
/// 1. a missing field takes the value of its type's `persistedDefault`, or zero, false, empty
///    or a new UUID where the type names none;
/// 2. an enum value this version doesn't know becomes the enum's `persistedDefault`, an
///    unreadable optional field becomes nil, and any other unreadable field takes the
///    enclosing type's default for it;
/// 3. an element of a list that can't be read is left out, so one bad card or track doesn't
///    lose the rest. A whole record is never swapped for a default one.
///
/// Every such repair is listed in `Result.repairs`, so the app can say what was filled in.
public enum KroutonPersistedJSON {
    public struct Result<Value> {
        public let value: Value
        /// Coding paths that took a default or were left out; empty when the file read as is.
        public let repairs: [String]
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data, iso8601Dates: Bool = false) throws -> Result<T> {
        let strict = JSONDecoder()
        if iso8601Dates { strict.dateDecodingStrategy = .iso8601 }
        let firstError: Error
        do {
            return Result(value: try strict.decode(type, from: data), repairs: [])
        } catch {
            firstError = error
        }
        guard let tree = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { throw firstError }
        let context = KroutonPersistedDecodingContext(iso8601Dates: iso8601Dates)
        do {
            let value = try context.decode(type, from: tree, fallback: nil, path: [])
            return Result(value: value, repairs: context.repairs)
        } catch {
            throw firstError
        }
    }
}

// MARK: - Decoding Context

/// One pass of the lenient read: the defaults already encoded, and the repairs made.
final class KroutonPersistedDecodingContext {
    let iso8601Dates: Bool
    private(set) var repairs: [String] = []
    private var encodedDefaults: [ObjectIdentifier: Any] = [:]

    init(iso8601Dates: Bool) {
        self.iso8601Dates = iso8601Dates
    }

    func note(_ path: [CodingKey], _ what: String) {
        let where_ = path.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        repairs.append("\(where_.isEmpty ? "(file)" : where_): \(what)")
    }

    /// `T.persistedDefault` as JSON, encoded once per type.
    func encodedDefault<T>(of type: T.Type) -> Any? {
        guard let defaulted = type as? any KroutonPersistedDefault.Type else { return nil }
        if let cached = encodedDefaults[ObjectIdentifier(type)] { return cached }
        let encoder = JSONEncoder()
        if iso8601Dates { encoder.dateEncodingStrategy = .iso8601 }
        guard let data = try? encoder.encode(defaulted.persistedDefault),
              var tree = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        if var object = tree as? [String: Any] {
            for key in defaulted.requiredKeys.union(["id"]) { object.removeValue(forKey: key) }
            tree = object
        }
        encodedDefaults[ObjectIdentifier(type)] = tree
        return tree
    }

    /// Decodes `type` from `value`. `fallback` is what the enclosing type's default holds here.
    /// A required field (`repairable: false`) is read as is or not at all.
    func decode<T: Decodable>(_ type: T.Type, from value: Any?, fallback: Any?, path: [CodingKey],
                              repairable: Bool = true) throws -> T {
        let ownDefault = encodedDefault(of: type)
        let present = value.flatMap { $0 is NSNull ? nil : $0 }
        guard repairable else {
            guard let present else {
                throw DecodingError.keyNotFound(path.last ?? KroutonPersistedKey("value"),
                                                .init(codingPath: path, debugDescription: "Required and missing"))
            }
            return try decodeReadable(type, from: present, fallback: nil, path: path)
        }
        guard let present else {
            if let substitute = fallback ?? ownDefault {
                note(path, "missing, took the default")
                return try decode(type, from: substitute, fallback: nil, path: path)
            }
            if let zero = Self.zero(of: T.self) {
                note(path, "missing, took \(zero)")
                return try decode(type, from: zero, fallback: nil, path: path)
            }
            throw DecodingError.keyNotFound(path.last ?? KroutonPersistedKey("value"),
                                            .init(codingPath: path, debugDescription: "No value and no default"))
        }
        do {
            return try decodeReadable(type, from: present, fallback: fallback ?? ownDefault, path: path)
        } catch {
            if let enumDefault = type as? any KroutonPersistedDefault.Type, Self.isEnum(type),
               let value = enumDefault.persistedDefault as? T {
                note(path, "unreadable value, took the default")
                return value
            }
            if let substitute = fallback {
                note(path, "unreadable value, took the default")
                return try decode(type, from: substitute, fallback: nil, path: path)
            }
            throw error
        }
    }

    private func decodeReadable<T: Decodable>(_ type: T.Type, from value: Any, fallback: Any?, path: [CodingKey]) throws -> T {
        // JSONEncoder writes these as strings or numbers, not through their own Codable.
        if let special = try Self.foundationValue(type, from: value, iso8601Dates: iso8601Dates, path: path) {
            return special
        }
        if let list = type as? any _KroutonListDecoding.Type, let kept = try list.decodeKeepingReadable(self, from: value, path: path) as? T {
            return kept
        }
        let required = (type as? any KroutonPersistedDefault.Type)?.requiredKeys ?? []
        return try T(from: KroutonPersistedDecoder(context: self, value: value, fallback: fallback,
                                                   requiredKeys: required, codingPath: path))
    }

    private static func foundationValue<T>(_ type: T.Type, from value: Any, iso8601Dates: Bool, path: [CodingKey]) throws -> T? {
        let mismatch = DecodingError.typeMismatch(type, .init(codingPath: path, debugDescription: "Not a \(type)"))
        if type == Date.self {
            if iso8601Dates, let text = value as? String, let date = ISO8601DateFormatter().date(from: text) { return date as? T }
            if let seconds = value as? NSNumber, !KroutonPersistedDecoder.isBoolean(seconds) { return Date(timeIntervalSinceReferenceDate: seconds.doubleValue) as? T }
            throw mismatch
        }
        if type == URL.self {
            guard let text = value as? String, let url = URL(string: text) else { throw mismatch }
            return url as? T
        }
        if type == Data.self {
            guard let text = value as? String, let data = Data(base64Encoded: text) else { throw mismatch }
            return data as? T
        }
        if type == Decimal.self {
            guard let number = value as? NSNumber else { throw mismatch }
            return number.decimalValue as? T
        }
        return nil
    }

    /// What a field without a value and without a default starts as.
    static func zero(of type: Any.Type) -> Any? {
        if let wrapper = type as? any _KroutonPrimitiveWrapper.Type { return zero(of: wrapper.wrappedType) }
        switch type {
        case is Bool.Type: return false
        case is String.Type: return ""
        case is UUID.Type: return UUID().uuidString
        case is any BinaryInteger.Type, is any BinaryFloatingPoint.Type: return 0
        default: break
        }
        if type is any _KroutonListDecoding.Type { return [Any]() }
        if type is any _KroutonEmptyDictionary.Type { return [String: Any]() }
        return nil
    }

    static func isEnum<T>(_ type: T.Type) -> Bool {
        type is any RawRepresentable.Type || type is any CaseIterable.Type
    }
}

// MARK: - Lists

/// A list read element by element, leaving out the elements that can't be read.
protocol _KroutonListDecoding {
    static func decodeKeepingReadable(_ context: KroutonPersistedDecodingContext, from value: Any, path: [CodingKey]) throws -> Self
}

extension Array: _KroutonListDecoding where Element: Decodable {
    static func decodeKeepingReadable(_ context: KroutonPersistedDecodingContext, from value: Any, path: [CodingKey]) throws -> Array {
        guard let list = value as? [Any] else {
            throw DecodingError.typeMismatch(Array.self, .init(codingPath: path, debugDescription: "Expected a list"))
        }
        var kept: [Element] = []
        for (index, element) in list.enumerated() {
            let elementPath = path + [KroutonPersistedKey(index: index)]
            do {
                kept.append(try context.decode(Element.self, from: element, fallback: nil, path: elementPath))
            } catch {
                context.note(elementPath, "unreadable, left out")
            }
        }
        return kept
    }
}

extension Set: _KroutonListDecoding where Element: Decodable {
    static func decodeKeepingReadable(_ context: KroutonPersistedDecodingContext, from value: Any, path: [CodingKey]) throws -> Set {
        Set(try [Element].decodeKeepingReadable(context, from: value, path: path))
    }
}

protocol _KroutonEmptyDictionary {}
extension Dictionary: _KroutonEmptyDictionary {}

/// A primitive field, read through the context so a missing one can start at zero.
protocol _KroutonPrimitiveWrapper {
    static var wrappedType: Any.Type { get }
}

struct KroutonPersistedKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(_ string: String) { stringValue = string; intValue = nil }
    init(index: Int) { stringValue = "\(index)"; intValue = index }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { self.init(index: intValue) }
}
