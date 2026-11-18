import Foundation

// MARK: - Deterministic PRNG

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}

// MARK: - Simulated Faulty Transport

struct SimulatedFaultyTransport {
    struct Faults {
        var disconnectAtByte: Int?
        var flipBitAtByte: Int?
        var dropBytes: Range<Int>?
    }

    private var rng: SplitMix64
    private let maxFragment: Int
    private var faults: Faults
    private var forwardOffset = 0
    private(set) var isConnected = true

    init(seed: UInt64, maxFragment: Int, faults: Faults = Faults()) {
        self.rng = SplitMix64(seed: seed)
        self.maxFragment = max(1, maxFragment)
        self.faults = faults
    }

    mutating func carry(_ bytes: [UInt8]) -> [[UInt8]] {
        guard isConnected else { return [] }
        var delivered: [UInt8] = []
        delivered.reserveCapacity(bytes.count)
        var processed = 0
        for byte in bytes {
            let offset = forwardOffset + processed
            if let cut = faults.disconnectAtByte, offset >= cut {
                faults.disconnectAtByte = nil
                isConnected = false
                break
            }
            processed += 1
            if let drop = faults.dropBytes, drop.contains(offset) { continue }
            if faults.flipBitAtByte == offset {
                delivered.append(byte ^ 0x10)
                continue
            }
            delivered.append(byte)
        }
        forwardOffset += processed
        if let drop = faults.dropBytes, forwardOffset >= drop.upperBound { faults.dropBytes = nil }
        if let flip = faults.flipBitAtByte, forwardOffset > flip { faults.flipBitAtByte = nil }
        return fragment(delivered)
    }

    mutating func carryBack(_ bytes: [UInt8]) -> [[UInt8]] {
        isConnected ? fragment(bytes) : []
    }

    mutating func reconnect() {
        isConnected = true
    }

    private mutating func fragment(_ bytes: [UInt8]) -> [[UInt8]] {
        var pieces: [[UInt8]] = []
        var start = 0
        while start < bytes.count {
            let end = min(bytes.count, start + rng.next(in: 1...maxFragment))
            pieces.append(Array(bytes[start..<end]))
            start = end
        }
        return pieces
    }
}
