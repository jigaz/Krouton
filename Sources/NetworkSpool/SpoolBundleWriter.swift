import Foundation

// MARK: - KRSP Bundle v1

/// How a folder travels to a Krouton Server that builds the disc itself (`files` jobs): a strict
/// subset of POSIX ustar/pax, defined in `krouton-server/crates/krsp/src/bundle.rs`. The writer is
/// deterministic, so `Vectors/krsp-bundle-v1.tar` is byte-identical between this and the Rust
/// writer, and the name rules match `Vectors/krsp-bundle-names-v1.txt`.
public enum SpoolBundleFormat {
    /// The tar block size.
    public static let block: UInt64 = 512
    /// The bundle is padded to whole sectors of this size.
    public static let sector: UInt64 = 2048
    /// The longest path, in UTF-8 bytes.
    public static let maxPathBytes = 1024
    /// The longest single name, in UTF-8 bytes.
    public static let maxNameBytes = 255
    /// The deepest folder nesting.
    public static let maxDepth = 64
    static let octalLimit: UInt64 = 0o777_7777_7777
    static let paxName = "././@PaxHeader"

    /// Why `path` (`/`-separated, relative) cannot go on a disc, or nil if it can.
    public static func problem(with path: String) -> String? {
        if path.isEmpty { return "an empty name" }
        if path.utf8.count > maxPathBytes { return "a path longer than \(maxPathBytes) bytes" }
        if path.hasPrefix("/") { return "an absolute path" }
        let names = path.split(separator: "/", omittingEmptySubsequences: false)
        for name in names {
            if let problem = problem(withName: String(name)) { return problem }
        }
        return names.count > maxDepth ? "folders nested deeper than \(maxDepth) levels" : nil
    }

    /// Why a single file or folder name cannot go on a disc, or nil if it can.
    public static func problem(withName name: String) -> String? {
        if name.isEmpty { return "an empty name" }
        if name == "." || name == ".." { return "a “.” or “..” path segment" }
        if name.utf8.count > maxNameBytes { return "“\(name)” is longer than \(maxNameBytes) bytes" }
        let forbidden = Set("\\/:*?\"<>|".unicodeScalars)
        if let bad = name.unicodeScalars.first(where: { $0.properties.generalCategory == .control || forbidden.contains($0) }) {
            let what = bad.properties.generalCategory == .control ? String(format: "a control character (U+%04X)", bad.value) : "“\(bad)”"
            return "“\(name)” contains \(what)"
        }
        if name.hasSuffix(".") || name.hasSuffix(" ") { return "“\(name)” ends with a dot or a space" }
        var stem = String(name.split(separator: ".", omittingEmptySubsequences: false).first ?? Substring(name))
        while let last = stem.unicodeScalars.last, last.properties.isWhitespace { stem.unicodeScalars.removeLast() }
        // ASCII-only upper-casing, as the server does: the reserved names are all ASCII.
        let upper = String(String.UnicodeScalarView(stem.unicodeScalars.map { scalar in
            (0x61...0x7A).contains(scalar.value) ? Unicode.Scalar(UInt8(scalar.value - 0x20)) : scalar
        }))
        let lastDigit = upper.unicodeScalars.last.map { (0x31...0x39).contains($0.value) } ?? false
        let reserved = ["CON", "PRN", "AUX", "NUL"].contains(upper)
            || ((upper.hasPrefix("COM") || upper.hasPrefix("LPT")) && upper.unicodeScalars.count == 4 && lastDigit)
        return reserved ? "“\(name)” is a reserved device name on Windows" : nil
    }

    /// The key two paths collide on when a disc or file system ignores case.
    public static func collisionKey(_ path: String) -> String { path.lowercased() }
}

// MARK: - Writer

/// Streams a bundle to `sink` in chunks. Call `directory` for a folder before anything inside it.
public struct SpoolBundleWriter {
    /// Bytes written so far.
    public private(set) var written: UInt64 = 0
    private let sink: (Data) throws -> Void

    /// A writer that hands its output to `sink`.
    public init(sink: @escaping (Data) throws -> Void) {
        self.sink = sink
    }

    /// Writes a folder entry.
    public mutating func directory(_ path: String, mtime: UInt64) throws {
        try Self.check(path)
        try header(name: path + "/", kind: UInt8(ascii: "5"), mode: 0o755, size: 0, mtime: mtime)
    }

    /// Writes a file of exactly `size` bytes; `read(n)` returns up to `n` more bytes (empty at the end).
    public mutating func file(_ path: String, size: UInt64, mtime: UInt64, read: (Int) throws -> Data) throws {
        try Self.check(path)
        try header(name: path, kind: UInt8(ascii: "0"), mode: 0o644, size: size, mtime: mtime)
        var remaining = size
        while remaining > 0 {
            let chunk = try read(Int(min(remaining, 1 << 20)))
            guard !chunk.isEmpty, UInt64(chunk.count) <= remaining else { throw SpoolBundleError.changedWhileReading(path) }
            try put(chunk)
            remaining -= UInt64(chunk.count)
        }
        try pad(to: SpoolBundleFormat.block)
    }

    /// End-of-archive blocks, then zero padding to a whole 2048-byte sector.
    public mutating func finish() throws {
        try put(Data(count: Int(2 * SpoolBundleFormat.block)))
        try pad(to: SpoolBundleFormat.sector)
    }

    private static func check(_ path: String) throws {
        if let problem = SpoolBundleFormat.problem(with: path) { throw SpoolBundleError.name(path: path, problem: problem) }
    }

    private mutating func header(name: String, kind: UInt8, mode: UInt64, size: UInt64, mtime: UInt64) throws {
        let short = name.utf8.count <= 100 && name.utf8.allSatisfy { (0x20..<0x7F).contains($0) }
        let big = size > SpoolBundleFormat.octalLimit
        if !short || big {
            var records = ""
            if !short { records += Self.paxRecord("path", name) }
            if big { records += Self.paxRecord("size", String(size)) }
            try put(Self.ustarHeader(name: SpoolBundleFormat.paxName, kind: UInt8(ascii: "x"), mode: 0o644,
                                     size: UInt64(records.utf8.count), mtime: 0))
            try put(Data(records.utf8))
            try pad(to: SpoolBundleFormat.block)
        }
        try put(Self.ustarHeader(name: short ? name : "", kind: kind, mode: mode, size: big ? 0 : size,
                                 mtime: min(mtime, SpoolBundleFormat.octalLimit)))
    }

    /// `"<len> <key>=<value>\n"`, where `<len>` counts the whole record including itself.
    static func paxRecord(_ key: String, _ value: String) -> String {
        let body = key.utf8.count + value.utf8.count + 3
        var length = body + 1
        while length != body + String(length).count { length = body + String(length).count }
        return "\(length) \(key)=\(value)\n"
    }

    static func ustarHeader(name: String, kind: UInt8, mode: UInt64, size: UInt64, mtime: UInt64) -> Data {
        var h = [UInt8](repeating: 0, count: 512)
        func field(_ at: Int, _ width: Int, _ bytes: [UInt8]) {
            for (i, b) in bytes.prefix(width).enumerated() { h[at + i] = b }
        }
        func octal(_ at: Int, _ width: Int, _ value: UInt64) {
            let digits = String(value, radix: 8)
            field(at, width, Array((String(repeating: "0", count: max(0, width - 1 - digits.count)) + digits).utf8) + [0])
        }
        field(0, 100, Array(name.utf8))
        octal(100, 8, mode)
        octal(108, 8, 0)
        octal(116, 8, 0)
        octal(124, 12, size)
        octal(136, 12, mtime)
        field(148, 8, Array("        ".utf8))
        h[156] = kind
        field(257, 8, Array("ustar".utf8) + [0] + Array("00".utf8))
        let sum = h.reduce(UInt64(0)) { $0 + UInt64($1) }
        let digits = String(sum, radix: 8)
        field(148, 8, Array((String(repeating: "0", count: max(0, 6 - digits.count)) + digits).utf8) + [0, 0x20])
        return Data(h)
    }

    private mutating func put(_ data: Data) throws {
        try sink(data)
        written += UInt64(data.count)
    }

    private mutating func pad(to multiple: UInt64) throws {
        let rem = written % multiple
        if rem != 0 { try put(Data(count: Int(multiple - rem))) }
    }
}

/// Why a folder couldn't be bundled. The descriptions are for the user.
public enum SpoolBundleError: Error, Equatable, LocalizedError {
    case name(path: String, problem: String)
    case duplicate(String)
    case unsupportedItem(String)
    case changedWhileReading(String)
    case empty
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .name(let path, let problem): "“\(path)” can’t go on a disc: \(problem)"
        case .duplicate(let path): "“\(path)” appears twice (names that differ only in upper and lower case count as the same name)"
        case .unsupportedItem(let path): "“\(path)” is a link or a special file; only files and folders can be burned"
        case .changedWhileReading(let path): "“\(path)” changed while it was being read"
        case .empty: "The folder has no files to burn"
        case .cancelled: "Cancelled"
        }
    }
}
