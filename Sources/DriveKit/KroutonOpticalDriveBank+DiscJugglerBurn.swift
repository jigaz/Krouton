@preconcurrency import DiscRecording
import Foundation
import OpticalCore
import os

// MARK: - DiscJuggler (.cdi) burn

@MainActor
extension KroutonOpticalDriveBank {
    /// Burns a self-booting Dreamcast `.cdi` as two sessions: the audio, then the data track,
    /// read straight from the image. `KroutonDiscJugglerImage.audioDataPlan` has checked that
    /// the data lands at the address the image was mastered for.
    ///
    /// Programmer's notes: a data track stored as 2,336-byte Mode 2 sectors (the usual case) is
    /// written as Mode 2 raw (`kDRBlockTypeMode2Data`), so the image's own subheaders and
    /// EDC/ECC go to the disc unchanged and the drive adds only sync and header. If this
    /// DiscRecording's Mode 2 block isn't 2,336 bytes, or the image keeps only 2,048 bytes a
    /// sector, the user data is written as Mode 2 Form 1 instead. Nothing here has been burned
    /// on real hardware yet.
    func beginDiscJugglerBurn(_ session: KroutonActiveBurnSession, imageURL: URL) {
        let context = session.context
        func fail(_ title: String, _ summary: String, _ advice: String) {
            finishBurnSession(session, report: makeBurnReport(
                context, isSuccess: false, title: title, summary: summary, sectors: 0, bytes: 0, advice: advice))
        }
        guard context.mediaType.contains("CD") else {
            fail("Dreamcast Needs a CD", "A Dreamcast reads CD-R; \(context.driveName) holds \(context.mediaType).",
                 "Nothing was written. Insert a blank CD-R (not CD-RW, which a Dreamcast reads poorly) and burn again.")
            return
        }
        let plan: (audio: [KroutonDiscJugglerImage.Track], data: KroutonDiscJugglerImage.Track)
        do {
            plan = try KroutonDiscJugglerImage.read(imageURL).audioDataPlan()
        } catch {
            fail("Can't Burn This Image", error.localizedDescription, "Nothing was written.")
            return
        }
        var audioTracks: [DRTrack] = []
        for track in plan.audio {
            guard let made = makeTrack(session, imageURL: imageURL, track: track, layout: Self.audioLayout) else {
                fail("Could Not Prepare Burn", "Krouton couldn't read the audio in \(imageURL.lastPathComponent).", "Nothing was written.")
                return
            }
            audioTracks.append(made)
        }
        guard let dataTrack = makeTrack(session, imageURL: imageURL, track: plan.data, layout: Self.dataLayout(for: plan.data)) else {
            fail("Could Not Prepare Burn", "Krouton couldn't read the data track in \(imageURL.lastPathComponent).", "Nothing was written.")
            return
        }
        guard let burn = DRBurn(for: session.device) else {
            fail("Could Not Prepare Burn", "DiscRecording could not create a burn for \(context.driveName).",
                 "Nothing was written. Reconnect the drive and try again.")
            return
        }
        startWriting(session, burn: burn, layout: [audioTracks, [dataTrack]])
    }

    // MARK: - Tracks

    /// How a track's sectors are written: DiscRecording's block properties and where each
    /// block sits in a file sector.
    struct SectorLayout: Sendable {
        let blockSize: Int
        let blockType: Int
        let dataForm: Int
        let trackMode: Int
        let sessionFormat: Int
        let offsetInSector: Int
    }

    /// Red Book audio, as `beginAudioBurn` writes it.
    static var audioLayout: SectorLayout {
        SectorLayout(blockSize: 2_352, blockType: 0, dataForm: 0, trackMode: 0, sessionFormat: 0, offsetInSector: 0)
    }

    static func dataLayout(for track: KroutonDiscJugglerImage.Track) -> SectorLayout {
        if track.mode == .mode1 {
            return SectorLayout(blockSize: Int(kDRBlockSizeMode1Data), blockType: Int(kDRBlockTypeMode1Data),
                                dataForm: Int(kDRDataFormMode1Data), trackMode: Int(kDRTrackModeMode1Data),
                                sessionFormat: Int(kDRSessionFormatMode1Data), offsetInSector: track.userDataOffset)
        }
        if track.sectorSize >= 2_336, Int(kDRBlockSizeMode2Data) == 2_336 {
            return SectorLayout(blockSize: 2_336, blockType: Int(kDRBlockTypeMode2Data),
                                dataForm: Int(kDRDataFormMode2Data), trackMode: Int(kDRTrackModeMode2Data),
                                sessionFormat: Int(kDRSessionFormatCDXA), offsetInSector: track.sectorSize == 2_352 ? 16 : 0)
        }
        return SectorLayout(blockSize: Int(kDRBlockSizeMode2Form1Data), blockType: Int(kDRBlockTypeMode2Form1Data),
                            dataForm: Int(kDRDataFormMode2Form1Data), trackMode: Int(kDRTrackModeMode2Form1Data),
                            sessionFormat: Int(kDRSessionFormatCDXA), offsetInSector: track.userDataOffset)
    }

    private func makeTrack(_ session: KroutonActiveBurnSession, imageURL: URL,
                           track: KroutonDiscJugglerImage.Track, layout: SectorLayout) -> DRTrack? {
        guard let producer = KroutonSectorTrackProducer(
            url: imageURL, firstByte: track.fileOffset, stride: track.sectorSize,
            offsetInSector: layout.offsetInSector, blockSize: layout.blockSize, blocks: track.frames),
              let drTrack = DRTrack(producer: producer),
              let length = DRMSF(frames: UInt32(track.frames)),
              let pregap = DRMSF(frames: UInt32(track.pregapFrames)) else { return nil }
        session.audioProducers.append(producer)
        drTrack.setProperties([
            DRTrackLengthKey: length,
            DRPreGapLengthKey: pregap,
            DRBlockSizeKey: NSNumber(value: layout.blockSize),
            DRBlockTypeKey: NSNumber(value: layout.blockType),
            DRDataFormKey: NSNumber(value: layout.dataForm),
            DRSessionFormatKey: NSNumber(value: layout.sessionFormat),
            DRTrackModeKey: NSNumber(value: layout.trackMode),
            DRVerificationTypeKey: DRVerificationTypeNone,
        ])
        return drTrack
    }
}

// MARK: - Sector producer

/// Feeds one track from an image file: `blocks` blocks of `blockSize` bytes, each taken from
/// `offsetInSector` within a `stride`-byte sector, starting at `firstByte`.
final class KroutonSectorTrackProducer: NSObject, Sendable {
    private let descriptor: Int32
    private let firstByte: Int64
    private let stride: Int
    private let offsetInSector: Int
    private let blockSize: Int
    private let blocks: Int64
    private let nextBlock = OSAllocatedUnfairLock(initialState: Int64(0))

    init?(url: URL, firstByte: Int64, stride: Int, offsetInSector: Int, blockSize: Int, blocks: Int64) {
        guard offsetInSector + blockSize <= stride else { return nil }
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { return nil }
        descriptor = fd
        self.firstByte = firstByte
        self.stride = stride
        self.offsetInSector = offsetInSector
        self.blockSize = blockSize
        self.blocks = blocks
    }

    deinit { close(descriptor) }

    @objc(estimateLengthOfTrack:)
    func estimateLength(of track: DRTrack) -> UInt64 { UInt64(blocks) }

    @objc(prepareTrack:forBurn:toMedia:)
    func prepare(_ track: DRTrack, burn: DRBurn, media: NSDictionary) -> Bool {
        nextBlock.withLock { $0 = 0 }
        return true
    }

    @objc(cleanupTrackAfterBurn:)
    func cleanupAfterBurn(_ track: DRTrack) {}

    @objc(producePreGapForTrack:intoBuffer:length:atAddress:blockSize:ioFlags:)
    func producePreGap(_ track: DRTrack, buffer: UnsafeMutablePointer<CChar>, length: UInt32,
                       address: UInt64, blockSize: UInt32, flags: UnsafeMutablePointer<UInt32>) -> UInt32 {
        memset(buffer, 0, Int(length))
        return length
    }

    @objc(produceDataForTrack:intoBuffer:length:atAddress:blockSize:ioFlags:)
    func produceData(_ track: DRTrack, buffer: UnsafeMutablePointer<CChar>, length: UInt32,
                     address: UInt64, blockSize: UInt32, flags: UnsafeMutablePointer<UInt32>) -> UInt32 {
        let count = Int(length) / self.blockSize
        let first = nextBlock.withLock { value in
            let current = value
            value += Int64(count)
            return current
        }
        for i in 0..<count {
            let target = buffer + i * self.blockSize
            let at = firstByte + (first + Int64(i)) * Int64(stride) + Int64(offsetInSector)
            let got = max(0, pread(descriptor, target, self.blockSize, off_t(at)))
            if got < self.blockSize { memset(target + got, 0, self.blockSize - got) }
        }
        return UInt32(count * self.blockSize)
    }

    @objc(prepareTrackForVerification:)
    func prepareForVerification(_ track: DRTrack) -> Bool { true }

    @objc(verifyPreGapForTrack:inBuffer:length:atAddress:blockSize:ioFlags:)
    func verifyPreGap(_ track: DRTrack, buffer: UnsafePointer<CChar>, length: UInt32,
                      address: UInt64, blockSize: UInt32, flags: UnsafeMutablePointer<UInt32>) -> Bool { true }

    @objc(verifyDataForTrack:inBuffer:length:atAddress:blockSize:ioFlags:)
    func verifyData(_ track: DRTrack, buffer: UnsafePointer<CChar>, length: UInt32,
                    address: UInt64, blockSize: UInt32, flags: UnsafeMutablePointer<UInt32>) -> Bool { true }

    @objc(cleanupTrackAfterVerification:)
    func cleanupAfterVerification(_ track: DRTrack) -> Bool { true }
}
