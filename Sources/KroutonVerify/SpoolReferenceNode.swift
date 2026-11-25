import CryptoKit
import Foundation
import NetworkSpool

// MARK: - Swift Reference Model of the Krouton Server Node
//
// The node side of the extent pipeline runs in krouton-server (Rust: krsp::pipeline and
// server-core::store, tested there). This test double mirrors it byte for byte so the suites can
// drive the app's `SpoolUploadSender` through faulty links in Swift, and so Suite 29 can check the
// journal record layout against the shared golden vectors. It is not part of the app.

// MARK: - Reference Node Receiver

struct SpoolStagingReceiver: Sendable {
    let manifest: SpoolTransferManifest
    let windowExtents: Int
    private(set) var committed: ExtentBitmap
    private(set) var rejectedExtents = 0
    private var decoder = SpoolFrameDecoder()

    init(manifest: SpoolTransferManifest, committed: ExtentBitmap, windowExtents: Int = 4) {
        self.manifest = manifest
        self.committed = committed
        self.windowExtents = max(1, windowExtents)
    }

    mutating func connectionReset() {
        decoder.reset()
    }

    mutating func receive(_ bytes: [UInt8], persist: (Int, [UInt8]) -> Bool) throws(SpoolWireError) -> [SpoolFrame] {
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

// MARK: - Reference Node Commit Journal

struct ExtentCommitRecord: Sendable, Equatable {
    static let byteCount = 44

    let extentIndex: UInt32
    let leafDigest: [UInt8]

    init(extentIndex: UInt32, leafDigest: [UInt8]) {
        self.extentIndex = extentIndex
        self.leafDigest = leafDigest
    }

    func encoded() -> [UInt8] {
        var body: [UInt8] = []
        body.append(contentsOf: withUnsafeBytes(of: extentIndex.bigEndian) { Array($0) })
        body.append(contentsOf: leafDigest.prefix(32))
        return body + Self.check(body)
    }

    static func check(_ body: [UInt8]) -> [UInt8] {
        Array(SHA256.hash(data: body).prefix(8))
    }

    static func replay(_ journal: [UInt8], against manifest: SpoolTransferManifest) -> ExtentBitmap {
        var bitmap = ExtentBitmap(count: manifest.extentCount)
        var offset = 0
        while offset + byteCount <= journal.count {
            let body = Array(journal[offset..<(offset + 36)])
            guard Array(journal[(offset + 36)..<(offset + byteCount)]) == check(body) else { break }
            let index = Int(body[0..<4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
            if index < manifest.extentCount, Array(body[4..<36]) == manifest.leafDigests[index] {
                bitmap.insert(index)
            }
            offset += byteCount
        }
        return bitmap
    }
}
