import Foundation

// MARK: - Upload Sender (resume from the server's bitmap, obey credit, resend rejects)
//
// The receiving half runs in krouton-server (Rust, `krsp::pipeline::StagingReceiver`); the
// verify target keeps a Swift reference model of it for loopback fault tests.

/// The client side of an image upload, as a state machine fed with received bytes: it asks the
/// server which extents it already has, then sends the missing ones as the server grants credit,
/// and resends rejected ones. It does no I/O itself; `SpoolServerConnection` runs it.
public struct SpoolUploadSender: Sendable {
    /// Where the upload stands.
    public enum Phase: Sendable, Equatable {
        /// Not connected; `connect()` starts or resumes.
        case disconnected
        /// Waiting for the server's bitmap of committed extents.
        case awaitingBitmap
        /// Sending extents.
        case streaming
        /// Every extent is committed.
        case complete
        /// The server holds a different image under this ID.
        case manifestMismatch
        /// An extent was rejected `maxRejectsPerExtent` times: the file no longer matches the
        /// manifest.
        case sourceChanged(extent: Int)
    }

    /// Rejects of one extent before giving up.
    public static let maxRejectsPerExtent = 3

    /// What is being sent.
    public let manifest: SpoolTransferManifest
    /// The most extents sent but not yet acknowledged.
    public let maxInFlight: Int
    /// Where the upload stands.
    public private(set) var phase: Phase = .disconnected
    /// Extents the server has committed.
    public private(set) var acknowledged: ExtentBitmap
    /// Extents resent after a reject.
    public private(set) var retransmissions = 0
    /// Extent frames sent, resends included.
    public private(set) var extentsSent = 0
    /// The most extents in flight at once.
    public private(set) var peakInFlight = 0
    private var pending: [Int] = []
    private var inFlight: Set<Int> = []
    private var rejects: [Int: Int] = [:]
    private var credits = 0
    private var decoder = SpoolFrameDecoder()

    /// A sender for `manifest`.
    public init(manifest: SpoolTransferManifest, maxInFlight: Int) {
        self.manifest = manifest
        self.maxInFlight = max(1, maxInFlight)
        self.acknowledged = ExtentBitmap(count: manifest.extentCount)
    }

    /// How many extents fit in `bytes` of memory, less one, at least one.
    public static func maxInFlight(forMemoryBudget bytes: Int, manifest: SpoolTransferManifest) -> Int {
        max(1, bytes / max(1, manifest.extentBytes) - 1)
    }

    /// Starts a connection: returns the bitmap query (carrying the manifest root).
    public mutating func connect() -> [SpoolFrame] {
        resetConnectionState()
        phase = .awaitingBitmap
        return [SpoolFrame(header: SpoolFrameHeader(kind: .bitmapQuery), payload: manifest.root)]
    }

    /// Forgets in-flight state after the connection dropped; acknowledged extents are kept.
    public mutating func disconnected() {
        resetConnectionState()
        if phase == .awaitingBitmap || phase == .streaming { phase = .disconnected }
    }

    /// Feeds received bytes, and returns the frames to send next. `extent` reads an extent's bytes
    /// from the file.
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
