@preconcurrency import DiscRecording
import Foundation
import OpticalCore
import os

// MARK: - Audio CD burn input

/// One track of an audio CD: raw 16-bit little-endian stereo PCM at 44.1 kHz, a whole number of
/// 2,352-byte frames, as `KroutonAudioDiscRenderer` (AudioKit) writes it.
public struct KroutonAudioBurnTrack: Sendable, Equatable {
    public let pcm: URL
    public let frames: Int64
    public let pregapFrames: Int64
    public let title: String
    public let performer: String
    public let isrc: String

    public init(pcm: URL, frames: Int64, pregapFrames: Int64, title: String, performer: String, isrc: String) {
        self.pcm = pcm
        self.frames = frames
        self.pregapFrames = pregapFrames
        self.title = title
        self.performer = performer
        self.isrc = isrc
    }
}

/// A whole audio CD: its tracks in order, plus the disc-level CD-Text and catalog number.
public struct KroutonAudioBurnDisc: Sendable, Equatable {
    public let tracks: [KroutonAudioBurnTrack]
    public let albumTitle: String
    public let albumPerformer: String
    /// 13 digits, or empty for none.
    public let mediaCatalogNumber: String
    public let writeCDText: Bool

    public init(tracks: [KroutonAudioBurnTrack], albumTitle: String, albumPerformer: String,
                mediaCatalogNumber: String, writeCDText: Bool) {
        self.tracks = tracks
        self.albumTitle = albumTitle
        self.albumPerformer = albumPerformer
        self.mediaCatalogNumber = mediaCatalogNumber
        self.writeCDText = writeCDText
    }

    public var totalFrames: Int64 { tracks.reduce(0) { $0 + $1.frames + $1.pregapFrames } }
}

// MARK: - Audio burn

@MainActor
extension KroutonOpticalDriveBank {
    /// Burns the disc session-at-once, so the pauses are written exactly and crossfaded tracks
    /// join with no gap. Every track is a DRTrack fed by `KroutonPCMTrackProducer`.
    ///
    /// Programmer's notes: the property values are the Mt. Fuji (INF-8090) audio codes Apple's
    /// AudioBurn sample uses — block size 2352, block type 0, data form 0, session format 0,
    /// track mode 0 (two-channel, no pre-emphasis). DiscRecording writes the pregap as digital
    /// silence by calling `producePreGap`, and puts CD-Text in the lead-in when `DRCDTextKey`
    /// is set; a drive that can't write CD-Text fails the burn with kDRDeviceCantWriteCDTextErr
    /// rather than leaving it out silently.
    func beginAudioBurn(_ session: KroutonActiveBurnSession, disc: KroutonAudioBurnDisc) {
        let context = session.context
        func fail(_ title: String, _ summary: String, _ advice: String) {
            finishBurnSession(session, report: makeBurnReport(
                context, isSuccess: false, title: title, summary: summary, sectors: 0, bytes: 0, advice: advice))
        }
        guard context.mediaType.contains("CD") else {
            fail("Audio Needs a CD", "An audio disc can only be written to a CD-R or CD-RW; \(context.driveName) holds \(context.mediaType).",
                 "Nothing was written. Insert a blank CD-R and burn again.")
            return
        }
        var tracks: [DRTrack] = []
        for item in disc.tracks {
            guard let producer = KroutonPCMTrackProducer(url: item.pcm, frames: item.frames) else {
                fail("Could Not Prepare Burn", "Krouton couldn't open the rendered audio for \(item.title).",
                     "Nothing was written. Try the burn again.")
                return
            }
            session.audioProducers.append(producer)
            guard let track = DRTrack(producer: producer),
                  let length = DRMSF(frames: UInt32(item.frames)),
                  let pregap = DRMSF(frames: UInt32(item.pregapFrames)) else {
                fail("Could Not Prepare Burn", "DiscRecording refused track \(tracks.count + 1).", "Nothing was written. Try the burn again.")
                return
            }
            var props: [String: Any] = [
                DRTrackLengthKey: length,
                DRPreGapLengthKey: pregap,
                DRBlockSizeKey: NSNumber(value: 2352),
                DRBlockTypeKey: NSNumber(value: 0),
                DRDataFormKey: NSNumber(value: 0),
                DRSessionFormatKey: NSNumber(value: 0),
                DRTrackModeKey: NSNumber(value: 0),
                DRVerificationTypeKey: DRVerificationTypeNone,
            ]
            let isrc = item.isrc.uppercased().filter { $0.isLetter || $0.isNumber }
            if isrc.count == 12 { props[DRTrackISRCKey] = Data(isrc.utf8) }
            track.setProperties(props)
            tracks.append(track)
        }
        guard let burn = DRBurn(for: session.device) else {
            fail("Could Not Prepare Burn", "DiscRecording could not create a burn for \(context.driveName).",
                 "Nothing was written. Reconnect the drive and try again.")
            return
        }
        var props = burn.properties() as? [String: Any] ?? [:]
        props[DRBurnStrategyKey] = DRBurnStrategyCDSAO
        props[DRBurnStrategyIsRequiredKey] = NSNumber(value: true)
        let mcn = disc.mediaCatalogNumber.filter(\.isNumber)
        if mcn.count == 13 { props[DRMediaCatalogNumberKey] = Data(mcn.utf8) }
        if disc.writeCDText, let block = Self.cdTextBlock(for: disc) { props[DRCDTextKey] = block }
        burn.setProperties(props)
        startWriting(session, burn: burn, layout: tracks)
    }

    /// Index 0 of the track dictionaries is the disc; 1...n are the tracks.
    static func cdTextBlock(for disc: KroutonAudioBurnDisc) -> DRCDTextBlock? {
        let encoding = UInt(DRCDTextEncodingISOLatin1Modified)
        guard let block = DRCDTextBlock(language: "en", encoding: encoding) else { return nil }
        var dictionaries: [[String: Any]] = [[
            DRCDTextTitleKey: KroutonCDTextSanitizer.sanitize(disc.albumTitle),
            DRCDTextPerformerKey: KroutonCDTextSanitizer.sanitize(disc.albumPerformer),
        ]]
        // Plain ASCII, as the sanitizer gives it, so older car stereos show it correctly.
        for track in disc.tracks {
            dictionaries.append([
                DRCDTextTitleKey: KroutonCDTextSanitizer.sanitize(track.title),
                DRCDTextPerformerKey: KroutonCDTextSanitizer.sanitize(track.performer),
            ])
        }
        block.setTrackDictionaries(dictionaries)
        return block
    }
}

// MARK: - PCM producer

/// Feeds one track's PCM to DiscRecording, which calls it from its own burn thread.
///
/// Programmer's notes: the methods are found by Objective-C selector (`initWithProducer:` takes
/// an `id`), so each one is named with `@objc(...)` exactly as `DRTrackDataProduction` declares
/// it. DiscRecording asks for data in order, so a locked running offset is enough; a short read
/// at the end is padded with silence to fill the last frame.
final class KroutonPCMTrackProducer: NSObject, Sendable {
    private let descriptor: Int32
    private let frames: Int64
    private let offset = OSAllocatedUnfairLock(initialState: Int64(0))

    init?(url: URL, frames: Int64) {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { return nil }
        descriptor = fd
        self.frames = frames
    }

    deinit { close(descriptor) }

    @objc(estimateLengthOfTrack:)
    func estimateLength(of track: DRTrack) -> UInt64 { UInt64(frames) }

    @objc(prepareTrack:forBurn:toMedia:)
    func prepare(_ track: DRTrack, burn: DRBurn, media: NSDictionary) -> Bool {
        offset.withLock { $0 = 0 }
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
        let start = offset.withLock { value in
            let current = value
            value += Int64(length)
            return current
        }
        let read = pread(descriptor, buffer, Int(length), off_t(start))
        let got = max(0, read)
        if got < Int(length) { memset(buffer + got, 0, Int(length) - got) }
        return length
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
