import Foundation

// MARK: - Receiver (remote node): verify, persist, acknowledge, grant credit

public struct SpoolStagingReceiver: Sendable {
    public let manifest: SpoolTransferManifest
    public let windowExtents: Int
    public private(set) var committed: ExtentBitmap
    public private(set) var rejectedExtents = 0
    private var decoder = SpoolFrameDecoder()

    public init(manifest: SpoolTransferManifest, committed: ExtentBitmap, windowExtents: Int = 4) {
        self.manifest = manifest
        self.committed = committed
        self.windowExtents = max(1, windowExtents)
    }

    public mutating func connectionReset() {
        decoder.reset()
    }

    public mutating func receive(_ bytes: [UInt8], persist: (Int, [UInt8]) -> Bool) throws(SpoolWireError) -> [SpoolFrame] {
        var replies: [SpoolFrame] = []
        for frame in try decoder.push(bytes) {
            switch frame.header.kind {
            case .bitmapQuery:
                guard frame.payload == manifest.root else {
                    replies.append(.signal(.manifestMismatch))
                    continue
                }
                replies.append(SpoolFrame(header: SpoolFrameHeader(kind: .bitmapReply), payload: committed.bytes))
                replies.append(.signal(.credit, extentIndex: windowExtents))
            case .extentData:
                replies.append(contentsOf: accept(frame, persist: persist))
            default:
                continue
            }
        }
        return replies
    }

    private mutating func accept(_ frame: SpoolFrame, persist: (Int, [UInt8]) -> Bool) -> [SpoolFrame] {
        let index = Int(frame.header.extentIndex)
        let valid = index < manifest.extentCount
            && Int(frame.header.sectorSize) == manifest.sectorSize
            && frame.payload.count == manifest.byteRange(ofExtent: index).count
            && frame.header.digest == manifest.leafDigests[index]
            && SpoolTransferManifest.leafDigest(frame.payload) == manifest.leafDigests[index]
        guard valid, committed.contains(index) || persist(index, frame.payload) else {
            rejectedExtents += 1
            return [.signal(.extentReject, extentIndex: index), .signal(.credit, extentIndex: 1)]
        }
        committed.insert(index)
        return [.signal(.extentAck, extentIndex: index), .signal(.credit, extentIndex: 1)]
    }
}

// MARK: - Sender (workstation): resume from the node's bitmap, obey credit, retransmit rejects

public struct SpoolUploadSender: Sendable {
    public enum Phase: Sendable, Equatable {
        case disconnected
        case awaitingBitmap
        case streaming
        case complete
        case manifestMismatch
        case sourceChanged(extent: Int)
    }

    public static let maxRejectsPerExtent = 3

    public let manifest: SpoolTransferManifest
    public let maxInFlight: Int
    public private(set) var phase: Phase = .disconnected
    public private(set) var acknowledged: ExtentBitmap
    public private(set) var retransmissions = 0
    public private(set) var extentsSent = 0
    public private(set) var peakInFlight = 0
    private var pending: [Int] = []
    private var inFlight: Set<Int> = []
    private var rejects: [Int: Int] = [:]
    private var credits = 0
    private var decoder = SpoolFrameDecoder()

    public init(manifest: SpoolTransferManifest, maxInFlight: Int) {
        self.manifest = manifest
        self.maxInFlight = max(1, maxInFlight)
        self.acknowledged = ExtentBitmap(count: manifest.extentCount)
    }

    public static func maxInFlight(forMemoryBudget bytes: Int, manifest: SpoolTransferManifest) -> Int {
        max(1, bytes / max(1, manifest.extentBytes) - 1)
    }

    public mutating func connect() -> [SpoolFrame] {
        resetConnectionState()
        phase = .awaitingBitmap
        return [SpoolFrame(header: SpoolFrameHeader(kind: .bitmapQuery), payload: manifest.root)]
    }

    public mutating func disconnected() {
        resetConnectionState()
        if phase == .awaitingBitmap || phase == .streaming { phase = .disconnected }
    }

    public mutating func receive(_ bytes: [UInt8], extent: (Int) -> [UInt8]) throws(SpoolWireError) -> [SpoolFrame] {
        for frame in try decoder.push(bytes) {
            let index = Int(frame.header.extentIndex)
            switch frame.header.kind {
            case .bitmapReply:
                guard phase == .awaitingBitmap,
                      let remote = ExtentBitmap(count: manifest.extentCount, bytes: frame.payload) else { continue }
                acknowledged = remote
                pending = remote.missing
                phase = .streaming
            case .manifestMismatch:
                phase = .manifestMismatch
            case .credit:
                credits += index
            case .extentAck:
                guard inFlight.remove(index) != nil else { continue }
                acknowledged.insert(index)
            case .extentReject:
                guard inFlight.remove(index) != nil else { continue }
                rejects[index, default: 0] += 1
                if rejects[index, default: 0] >= Self.maxRejectsPerExtent {
                    phase = .sourceChanged(extent: index)
                } else {
                    pending.insert(index, at: 0)
                    retransmissions += 1
                }
            default:
                continue
            }
        }
        return pump(extent: extent)
    }

    private mutating func pump(extent: (Int) -> [UInt8]) -> [SpoolFrame] {
        guard phase == .streaming else { return [] }
        var out: [SpoolFrame] = []
        while credits > 0, inFlight.count < maxInFlight, !pending.isEmpty {
            let index = pending.removeFirst()
            guard !acknowledged.contains(index) else { continue }
            out.append(Self.dataFrame(index: index, manifest: manifest, payload: extent(index)))
            inFlight.insert(index)
            credits -= 1
            extentsSent += 1
            peakInFlight = max(peakInFlight, inFlight.count)
        }
        if pending.isEmpty, inFlight.isEmpty, acknowledged.isComplete { phase = .complete }
        return out
    }

    private mutating func resetConnectionState() {
        decoder.reset()
        inFlight.removeAll()
        credits = 0
    }

    private static func dataFrame(index: Int, manifest: SpoolTransferManifest, payload: [UInt8]) -> SpoolFrame {
        SpoolFrame(
            header: SpoolFrameHeader(
                kind: .extentData,
                extentIndex: UInt32(index),
                firstLBA: manifest.firstLBA(ofExtent: index),
                sectorSize: UInt16(manifest.sectorSize),
                digest: manifest.leafDigests[index]
            ),
            payload: payload
        )
    }
}
