import Foundation

// MARK: - Rescue Map (GNU ddrescue mapfile)

/// Which parts of a disc have been copied, and how hard the rest has been tried. It is written in
/// GNU ddrescue's mapfile format, so a rescue started in Krouton can be finished with ddrescue
/// (or `ddrescueview` can draw it), and the reverse.
public struct KroutonRescueMap: Sendable, Equatable {
    /// ddrescue's block states.
    public enum Status: Character, Sendable, CaseIterable {
        case nonTried = "?"
        case nonTrimmed = "*"
        case nonScraped = "/"
        case badSector = "-"
        case finished = "+"
    }

    /// ddrescue's current-phase letters, for the mapfile's status line.
    public enum Phase: Character, Sendable {
        case copying = "?"
        case trimming = "*"
        case scraping = "/"
        case retrying = "-"
        case finished = "+"
    }

    /// A run of bytes in one state.
    public struct Block: Sendable, Equatable {
        /// The block's first byte.
        public let position: Int64
        /// The block's length in bytes.
        public let size: Int64
        /// The block's state.
        public let status: Status

        public init(position: Int64, size: Int64, status: Status) {
            self.position = position
            self.size = size
            self.status = status
        }

        /// The byte after the block.
        public var end: Int64 { position + size }
    }

    /// The blocks in disc order, covering the whole disc, with neighbours in the same state merged.
    public private(set) var blocks: [Block]
    /// Where the rescue is reading now, in bytes.
    public var currentPosition: Int64 = 0
    /// The rescue's current phase.
    public var phase: Phase = .copying
    /// The pass number within the phase, from 1.
    public var pass: Int = 1

    /// A map of an untried disc of `totalBytes` bytes.
    public init(totalBytes: Int64) {
        blocks = totalBytes > 0 ? [Block(position: 0, size: totalBytes, status: .nonTried)] : []
    }

    /// The disc's size in bytes.
    public var totalBytes: Int64 { blocks.last?.end ?? 0 }

    /// Bytes in a state.
    public func bytes(_ status: Status) -> Int64 {
        blocks.filter { $0.status == status }.reduce(0) { $0 + $1.size }
    }

    /// True once nothing is left untried; bad sectors may remain.
    public var isComplete: Bool { blocks.allSatisfy { $0.status == .finished || $0.status == .badSector } }

    /// Blocks in a state, in disc order.
    public func blocks(_ status: Status) -> [Block] { blocks.filter { $0.status == status } }

    // MARK: - Marking

    /// Sets `status` on the byte range, splitting and merging blocks as needed.
    public mutating func mark(_ range: Range<Int64>, as status: Status) {
        let range = range.clamped(to: 0..<totalBytes)
        guard !range.isEmpty else { return }
        var result: [Block] = []
        result.reserveCapacity(blocks.count + 2)
        for block in blocks {
            if block.end <= range.lowerBound || block.position >= range.upperBound {
                result.append(block)
                continue
            }
            if block.position < range.lowerBound {
                result.append(Block(position: block.position, size: range.lowerBound - block.position, status: block.status))
            }
            if block.end > range.upperBound {
                result.append(Block(position: range.upperBound, size: block.end - range.upperBound, status: block.status))
            }
        }
        result.append(Block(position: range.lowerBound, size: range.upperBound - range.lowerBound, status: status))
        result.sort { $0.position < $1.position }
        blocks = Self.merged(result)
    }

    static func merged(_ sorted: [Block]) -> [Block] {
        var merged: [Block] = []
        for block in sorted where block.size > 0 {
            if let last = merged.last, last.status == block.status, last.end == block.position {
                merged[merged.count - 1] = Block(position: last.position, size: last.size + block.size, status: last.status)
            } else {
                merged.append(block)
            }
        }
        return merged
    }

    // MARK: - Mapfile Text

    /// The map as a GNU ddrescue mapfile.
    public func mapfile(comment: String = "Krouton disc rescue") -> String {
        var lines = [
            "# Mapfile. Created by Krouton (GNU ddrescue mapfile format)",
            "# \(comment.replacingOccurrences(of: "\n", with: " "))",
            "# current_pos  current_status  current_pass",
            "\(Self.hex(currentPosition))     \(phase.rawValue)               \(pass)",
            "#      pos        size  status",
        ]
        lines += blocks.map { "\(Self.hex($0.position))  \(Self.hex($0.size))  \($0.status.rawValue)" }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Reads a mapfile written by Krouton or ddrescue. Returns nil if it isn't one.
    public static func parse(mapfile text: String) -> KroutonRescueMap? {
        var map = KroutonRescueMap(totalBytes: 0)
        var sawStatusLine = false
        var blocks: [Block] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            if !sawStatusLine {
                guard fields.count >= 2, let position = number(fields[0]), let phase = fields[1].first.flatMap(Phase.init) else { return nil }
                map.currentPosition = position
                map.phase = phase
                map.pass = fields.count >= 3 ? Int(fields[2]) ?? 1 : 1
                sawStatusLine = true
                continue
            }
            guard fields.count >= 3, let position = number(fields[0]), let size = number(fields[1]),
                  let status = fields[2].first.flatMap(Status.init), size > 0 else { return nil }
            if let last = blocks.last, last.end != position { return nil }
            blocks.append(Block(position: position, size: size, status: status))
        }
        guard sawStatusLine, blocks.first?.position == 0 else { return nil }
        map.blocks = merged(blocks)
        return map
    }

    static func hex(_ value: Int64) -> String { String(format: "0x%08llX", value) }

    static func number(_ text: String) -> Int64? {
        if text.lowercased().hasPrefix("0x") { return Int64(text.dropFirst(2), radix: 16) }
        return Int64(text)
    }
}
