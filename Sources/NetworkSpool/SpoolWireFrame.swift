import Foundation

// MARK: - Spool Wire Protocol v1
//
// Every message on a spool connection is one frame: a fixed 64-byte big-endian header followed by
// `payloadLength` bytes. An extent's sectors travel as ONE frame payload (never re-chunked), so a
// receiver can hand the payload to the staging writer whole.

public enum SpoolFrameKind: UInt8, Sendable, CaseIterable {
    case bitmapQuery = 1
    case bitmapReply = 2
    case extentData = 3
    case extentAck = 4
    case extentReject = 5
    case credit = 6
    case telemetry = 7
    case control = 8
    case manifestMismatch = 9
}

public enum SpoolWireError: Error, Sendable, Equatable {
    case badMagic
    case unsupportedVersion(UInt8)
    case unknownKind(UInt8)
    case payloadTooLarge(UInt32)
    case malformedExtentFrame
}

// MARK: - Frame Header

public struct SpoolFrameHeader: Sendable, Equatable {
    public static let byteCount = 64
    public static let magic: UInt32 = 0x4B52_5350
    public static let currentVersion: UInt8 = 1
    /// Upper bound on any single frame, so a hostile length field can never make a receiver allocate more.
    public static let maxPayloadBytes: UInt32 = 8 * 1_048_576
    public static let supportedSectorSizes: Set<UInt16> = [2048, 2336, 2352, 2448]

    public var kind: SpoolFrameKind
    public var flags: UInt16
    public var extentIndex: UInt32
    public var firstLBA: UInt64
    public var sectorSize: UInt16
    public var payloadLength: UInt32
    public var digest: [UInt8]

    public init(
        kind: SpoolFrameKind,
        flags: UInt16 = 0,
        extentIndex: UInt32 = 0,
        firstLBA: UInt64 = 0,
        sectorSize: UInt16 = 0,
        payloadLength: UInt32 = 0,
        digest: [UInt8] = [UInt8](repeating: 0, count: 32)
    ) {
        self.kind = kind
        self.flags = flags
        self.extentIndex = extentIndex
        self.firstLBA = firstLBA
        self.sectorSize = sectorSize
        self.payloadLength = payloadLength
        self.digest = digest
    }

    public func encoded() -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(Self.byteCount)
        SpoolBytes.append(Self.magic, to: &out)
        out.append(Self.currentVersion)
        out.append(kind.rawValue)
        SpoolBytes.append(flags, to: &out)
        SpoolBytes.append(extentIndex, to: &out)
        SpoolBytes.append(firstLBA, to: &out)
        SpoolBytes.append(sectorSize, to: &out)
        SpoolBytes.append(UInt16(0), to: &out)
        SpoolBytes.append(payloadLength, to: &out)
        SpoolBytes.append(UInt32(0), to: &out)
        out.append(contentsOf: digest.prefix(32))
        while out.count < Self.byteCount { out.append(0) }
        return out
    }

    /// Decodes the header at `offset`. The caller guarantees `byteCount` bytes are available.
    public static func decode(_ bytes: [UInt8], at offset: Int = 0) throws(SpoolWireError) -> SpoolFrameHeader {
        guard SpoolBytes.read(UInt32.self, from: bytes, at: offset) == magic else { throw .badMagic }
        let version = bytes[offset + 4]
        guard version == currentVersion else { throw .unsupportedVersion(version) }
        guard let kind = SpoolFrameKind(rawValue: bytes[offset + 5]) else { throw .unknownKind(bytes[offset + 5]) }
        let length = SpoolBytes.read(UInt32.self, from: bytes, at: offset + 24)
        guard length <= maxPayloadBytes else { throw .payloadTooLarge(length) }
        let header = SpoolFrameHeader(
            kind: kind,
            flags: SpoolBytes.read(UInt16.self, from: bytes, at: offset + 6),
            extentIndex: SpoolBytes.read(UInt32.self, from: bytes, at: offset + 8),
            firstLBA: SpoolBytes.read(UInt64.self, from: bytes, at: offset + 12),
            sectorSize: SpoolBytes.read(UInt16.self, from: bytes, at: offset + 20),
            payloadLength: length,
            digest: Array(bytes[(offset + 32)..<(offset + byteCount)])
        )
        if kind == .extentData {
            guard supportedSectorSizes.contains(header.sectorSize),
                  length > 0,
                  length % UInt32(header.sectorSize) == 0 else { throw .malformedExtentFrame }
        }
        return header
    }
}

// MARK: - Frame

public struct SpoolFrame: Sendable, Equatable {
    public var header: SpoolFrameHeader
    public var payload: [UInt8]

    public init(header: SpoolFrameHeader, payload: [UInt8] = []) {
        var sized = header
        sized.payloadLength = UInt32(payload.count)
        self.header = sized
        self.payload = payload
    }

    public func encoded() -> [UInt8] {
        header.encoded() + payload
    }

    public static func signal(_ kind: SpoolFrameKind, extentIndex: Int = 0) -> SpoolFrame {
        SpoolFrame(header: SpoolFrameHeader(kind: kind, extentIndex: UInt32(clamping: extentIndex)))
    }
}

// MARK: - Incremental Decoder

public struct SpoolFrameDecoder: Sendable {
    private var buffer: [UInt8] = []

    public init() {}

    public var bufferedByteCount: Int { buffer.count }

    public mutating func push(_ bytes: [UInt8]) throws(SpoolWireError) -> [SpoolFrame] {
        buffer.append(contentsOf: bytes)
        var frames: [SpoolFrame] = []
        var cursor = 0
        while buffer.count - cursor >= SpoolFrameHeader.byteCount {
            let header = try SpoolFrameHeader.decode(buffer, at: cursor)
            let total = SpoolFrameHeader.byteCount + Int(header.payloadLength)
            guard buffer.count - cursor >= total else { break }
            let payload = Array(buffer[(cursor + SpoolFrameHeader.byteCount)..<(cursor + total)])
            frames.append(SpoolFrame(header: header, payload: payload))
            cursor += total
        }
        if cursor > 0 { buffer.removeFirst(cursor) }
        return frames
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}

// MARK: - Big-Endian Helpers

enum SpoolBytes {
    static func append<T: FixedWidthInteger>(_ value: T, to out: inout [UInt8]) {
        withUnsafeBytes(of: value.bigEndian) { out.append(contentsOf: $0) }
    }

    static func read<T: FixedWidthInteger>(_ type: T.Type, from bytes: [UInt8], at offset: Int) -> T {
        var value: T = 0
        for i in 0..<MemoryLayout<T>.size {
            value = (value << 8) | T(bytes[offset + i])
        }
        return value
    }
}
