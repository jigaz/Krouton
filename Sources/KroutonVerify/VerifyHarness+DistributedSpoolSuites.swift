import Foundation
import NetworkSpool
import OpticalCore

// MARK: - Loopback Run Result

struct SpoolLoopbackRun {
    var sender: SpoolUploadSender
    var receiver: SpoolStagingReceiver
    var staged: [UInt8]
    var journal: [UInt8]
    var reconnects: Int
    var resumeLBAs: [UInt64]
}

// MARK: - VerifyHarness — Suite 27: Distributed Spool Framing, Leases, Resume & Partition Recovery

extension KroutonTestHarness {
    mutating func runVerifyDistributedSpoolSuite() {
        self.runSuite("27. Distributed Spool Framing, Lease Fencing, Resumable Bitmap & Partition Recovery") { h in
            Self.verifySpoolFraming(&h)
            Self.verifySpoolManifestAndJournal(&h)
            Self.verifySpoolLoopbackFaults(&h)
            Self.verifySpoolLeases(&h)
            Self.verifySpoolCutover(&h)
            Self.verifySpoolEndpointPolicy(&h)
            Self.verifySpoolPairingAndTelemetry(&h)
        }
    }

    static func spoolTestImage(sectors: Int = 102, sectorSize: Int = 2352) -> [UInt8] {
        (0..<(sectors * sectorSize)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ ($0 >> 9)) }
    }

    // MARK: - Framing (including every single header split point 1..<64 from Abacus RouteLLM)

    static func verifySpoolFraming(_ h: inout KroutonTestHarness) {
        let extent = SpoolFrame(
            header: SpoolFrameHeader(kind: .extentData, extentIndex: 7, firstLBA: 28, sectorSize: 2352,
                                     digest: [UInt8](repeating: 0xAB, count: 32)),
            payload: [UInt8](repeating: 0x5A, count: 2352 * 2)
        )
        let frames = [SpoolFrame.signal(.credit, extentIndex: 4), extent, .signal(.extentAck, extentIndex: 7)]
        let wire = frames.flatMap { $0.encoded() }

        var whole = SpoolFrameDecoder()
        h.check((try? whole.push(wire)) == frames, "Frames must round-trip through the 64-byte big-endian header")

        let singleWire = extent.encoded()
        var allHeaderSplitsPass = true
        for split in 1..<SpoolFrameHeader.byteCount {
            var splitDecoder = SpoolFrameDecoder()
            let firstHalf = (try? splitDecoder.push(Array(singleWire.prefix(split)))) ?? []
            let secondHalf = (try? splitDecoder.push(Array(singleWire.dropFirst(split)))) ?? []
            if !firstHalf.isEmpty || secondHalf != [extent] || splitDecoder.bufferedByteCount != 0 {
                allHeaderSplitsPass = false
            }
        }
        h.check(allHeaderSplitsPass, "Every single header split point (1..<64) must reassemble the frame cleanly")

        var byteAtATime = SpoolFrameDecoder()
        var reassembled: [SpoolFrame] = []
        for byte in wire { reassembled += (try? byteAtATime.push([byte])) ?? [] }
        h.check(reassembled == frames && byteAtATime.bufferedByteCount == 0,
                "1-byte fragmentation must reassemble identical frames with nothing left buffered")

        var link = SimulatedFaultyTransport(seed: 27, maxFragment: 97)
        var randomCuts = SpoolFrameDecoder()
        var fromLink: [SpoolFrame] = []
        for piece in link.carry(wire) { fromLink += (try? randomCuts.push(piece)) ?? [] }
        h.check(fromLink == frames, "Seeded random fragmentation must reassemble identical frames")

        var hostile = SpoolFrameHeader(kind: .control).encoded()
        hostile.replaceSubrange(24..<28, with: [0xFF, 0xFF, 0xFF, 0xFF])
        var guardDecoder = SpoolFrameDecoder()
        h.check(Self.wireError { try guardDecoder.push(hostile) } == .payloadTooLarge(UInt32.max),
                "A hostile length field must be refused before any allocation")

        var badMagic = SpoolFrame.signal(.credit).encoded()
        badMagic[0] ^= 0xFF
        var magicDecoder = SpoolFrameDecoder()
        h.check(Self.wireError { try magicDecoder.push(badMagic) } == .badMagic, "A misaligned stream must surface as badMagic")

        let ragged = SpoolFrame(header: SpoolFrameHeader(kind: .extentData, sectorSize: 2048), payload: [1, 2, 3])
        var raggedDecoder = SpoolFrameDecoder()
        h.check(Self.wireError { try raggedDecoder.push(ragged.encoded()) } == .malformedExtentFrame,
                "An extent payload that is not whole 2048/2336/2352/2448-byte sectors must be refused")
    }

    static func wireError(_ body: () throws -> [SpoolFrame]) -> SpoolWireError? {
        do {
            _ = try body()
            return nil
        } catch {
            return error as? SpoolWireError
        }
    }

    // MARK: - Manifest, Bitmap & Commit Journal

    static func verifySpoolManifestAndJournal(_ h: inout KroutonTestHarness) {
        let image = spoolTestImage()
        guard let manifest = SpoolTransferManifest(image: image, sectorSize: 2352, sectorsPerExtent: 4) else {
            h.check(false, "Test image must produce a manifest")
            return
        }
        h.check(manifest.extentCount == 26 && manifest.byteRange(ofExtent: 25).count == 2 * 2352
                && manifest.firstLBA(ofExtent: 5) == 20,
                "Extents must be whole sectors, LBA-aligned, with a short tail extent")

        var edited = image
        edited[123_456] ^= 0x01
        let editedRoot = SpoolTransferManifest(image: edited, sectorSize: 2352, sectorsPerExtent: 4)?.root
        h.check(editedRoot != nil && editedRoot != manifest.root, "A one-bit change anywhere must change the Merkle root")

        h.check(ExtentBitmap(count: 26, bytes: [0xFF, 0xFF, 0xFF, 0x04]) == nil,
                "A wire bitmap with bits set past the extent count must be refused")
        h.check(ExtentBitmap(count: 26, bytes: [0, 0, 0]) == nil, "A wire bitmap of the wrong length must be refused")

        var journal: [UInt8] = []
        for index in [0, 2, 5] {
            journal += ExtentCommitRecord(extentIndex: UInt32(index), leafDigest: manifest.leafDigests[index]).encoded()
        }
        let torn = journal + ExtentCommitRecord(extentIndex: 7, leafDigest: manifest.leafDigests[7]).encoded().prefix(20)
        let replayed = ExtentCommitRecord.replay(torn, against: manifest)
        h.check(replayed.committedCount == 3 && replayed.contains(5) && !replayed.contains(7),
                "A torn final journal record (power loss mid-append) must be ignored, never half-trusted")

        var corrupt = journal
        corrupt[ExtentCommitRecord.byteCount + 40] ^= 0xFF
        let stopped = ExtentCommitRecord.replay(corrupt, against: manifest)
        h.check(stopped.committedCount == 1 && stopped.contains(0),
                "Replay must stop at the first corrupt record; everything after it is resent")

        let foreign = ExtentCommitRecord(extentIndex: 3, leafDigest: [UInt8](repeating: 9, count: 32)).encoded()
        h.check(!ExtentCommitRecord.replay(foreign, against: manifest).contains(3),
                "A record whose digest disagrees with the manifest (stale journal) must not mark an extent committed")
    }

    // MARK: - End-to-End Loopback With Faults

    static func verifySpoolLoopbackFaults(_ h: inout KroutonTestHarness) {
        let image = spoolTestImage()
        guard let manifest = SpoolTransferManifest(image: image, sectorSize: 2352, sectorsPerExtent: 4) else { return }
        let frame = SpoolFrameHeader.byteCount + manifest.extentBytes
        let query = SpoolFrameHeader.byteCount + 32

        var guardSender = SpoolUploadSender(manifest: manifest, maxInFlight: 2)
        _ = guardSender.connect()
        let bitmapFrame = SpoolFrame(header: SpoolFrameHeader(kind: .bitmapReply), payload: ExtentBitmap(count: manifest.extentCount).bytes)
        let unsolicitedAck = SpoolFrame.signal(.extentAck, extentIndex: 15)
        _ = try? guardSender.receive(bitmapFrame.encoded() + unsolicitedAck.encoded()) { _ in [] }
        h.check(!guardSender.acknowledged.contains(15), "An unsolicited .extentAck for an extent not in flight must be ignored")

        let clean = runSpoolLoopback(image: image, senderManifest: manifest, receiverManifest: manifest, faults: .init())
        h.check(clean.sender.phase == .complete && clean.staged == image && clean.reconnects == 0
                && clean.sender.extentsSent == manifest.extentCount && clean.sender.peakInFlight <= 3,
                "A clean transfer must stage a byte-identical image, send each extent once and never exceed 3 in flight")

        let budget = 32 * 1_048_576
        let bd25 = SpoolTransferManifest(sectorSize: 2048, totalSectors: 12_219_392,
                                         leafDigests: [[UInt8]](repeating: [UInt8](repeating: 0, count: 32), count: 5967))
        let window = SpoolUploadSender.maxInFlight(forMemoryBudget: budget, manifest: bd25)
        h.check(window == 7 && (window + 1) * bd25.extentBytes <= budget,
                "A BD-25 sender must keep in-flight extents plus its read-ahead buffer within 32 MiB")

        let cut = SimulatedFaultyTransport.Faults(disconnectAtByte: query + 5 * frame + 3_000)
        let resumed = runSpoolLoopback(image: image, senderManifest: manifest, receiverManifest: manifest, faults: cut)
        h.check(resumed.sender.phase == .complete && resumed.staged == image && resumed.reconnects == 1,
                "A cable pull mid-extent must reconnect once and finish with a byte-identical image")
        h.check(resumed.resumeLBAs == [20] && resumed.sender.extentsSent == manifest.extentCount + 1,
                "Resume must start at exactly LBA 20 (extent 5, the torn one); extents 0-4 must never be resent")

        let restarted = runSpoolLoopback(image: image, senderManifest: manifest, receiverManifest: manifest,
                                         faults: cut, restartReceiverOnDisconnect: true)
        h.check(restarted.sender.phase == .complete && restarted.staged == image && restarted.resumeLBAs == [20],
                "A node crash rebuilt from the commit journal must resume at the same LBA")

        let flipped = runSpoolLoopback(image: image, senderManifest: manifest, receiverManifest: manifest,
                                       faults: .init(flipBitAtByte: query + SpoolFrameHeader.byteCount + 500))
        h.check(flipped.sender.phase == .complete && flipped.staged == image && flipped.receiver.rejectedExtents == 1
                && flipped.sender.retransmissions == 1 && flipped.reconnects == 0,
                "A flipped bit must be rejected by SHA-256, retransmitted once, and never reach the staged image")

        let gap = query + SpoolFrameHeader.byteCount + 100
        let dropped = runSpoolLoopback(image: image, senderManifest: manifest, receiverManifest: manifest,
                                       faults: .init(dropBytes: gap..<(gap + 10)))
        h.check(dropped.sender.phase == .complete && dropped.staged == image && dropped.reconnects == 1,
                "Missing bytes must desynchronise framing, force a reconnect, and still finish byte-identical")

        var other = image
        other[0] ^= 0xFF
        if let otherManifest = SpoolTransferManifest(image: other, sectorSize: 2352, sectorsPerExtent: 4) {
            let refused = runSpoolLoopback(image: image, senderManifest: manifest, receiverManifest: otherManifest, faults: .init())
            h.check(refused.sender.phase == .manifestMismatch && refused.sender.extentsSent == 0,
                    "A node holding a different manifest must be refused before a single extent is sent")
        }
    }

    static func runSpoolLoopback(
        image: [UInt8],
        senderManifest: SpoolTransferManifest,
        receiverManifest: SpoolTransferManifest,
        faults: SimulatedFaultyTransport.Faults,
        restartReceiverOnDisconnect: Bool = false
    ) -> SpoolLoopbackRun {
        var sender = SpoolUploadSender(manifest: senderManifest, maxInFlight: 3)
        var receiver = SpoolStagingReceiver(manifest: receiverManifest, committed: ExtentBitmap(count: receiverManifest.extentCount))
        var staged = [UInt8](repeating: 0, count: receiverManifest.imageBytes)
        var journal: [UInt8] = []
        var link = SimulatedFaultyTransport(seed: 0x4B52_5350, maxFragment: 1_500, faults: faults)
        var reconnects = 0
        var resumeLBAs: [UInt64] = []
        var awaitingResume = false
        var toNode = sender.connect()

        for _ in 0..<400 {
            if sender.phase == .complete || sender.phase == .manifestMismatch { break }
            if awaitingResume, let first = toNode.first(where: { $0.header.kind == .extentData }) {
                resumeLBAs.append(first.header.firstLBA)
                awaitingResume = false
            }
            var toWorkstation: [SpoolFrame] = []
            var broken = false
            for piece in link.carry(toNode.flatMap { $0.encoded() }) {
                do {
                    toWorkstation += try receiver.receive(piece) { index, bytes in
                        staged.replaceSubrange(receiverManifest.byteRange(ofExtent: index), with: bytes)
                        journal += ExtentCommitRecord(extentIndex: UInt32(index),
                                                      leafDigest: receiverManifest.leafDigests[index]).encoded()
                        return true
                    }
                } catch {
                    broken = true
                    break
                }
            }
            toNode = []
            if !broken, link.isConnected {
                for piece in link.carryBack(toWorkstation.flatMap { $0.encoded() }) {
                    toNode += (try? sender.receive(piece) { Array(image[senderManifest.byteRange(ofExtent: $0)]) }) ?? []
                }
                if !toNode.isEmpty || sender.phase == .complete || sender.phase == .manifestMismatch { continue }
            }
            sender.disconnected()
            if restartReceiverOnDisconnect {
                receiver = SpoolStagingReceiver(manifest: receiverManifest,
                                                committed: ExtentCommitRecord.replay(journal, against: receiverManifest))
            } else {
                receiver.connectionReset()
            }
            link.reconnect()
            reconnects += 1
            awaitingResume = true
            toNode = sender.connect()
        }
        return SpoolLoopbackRun(sender: sender, receiver: receiver, staged: staged, journal: journal,
                                reconnects: reconnects, resumeLBAs: resumeLBAs)
    }
}
