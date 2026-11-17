import AVFoundation
import AudioToolbox
import CryptoKit
import Foundation
import SwiftUI
import VideoToolbox

public struct KroutonMountedDiscVolume: Identifiable, Hashable, Sendable {
    public let id: String
    public let volumeName: String
    public let filesystemFormat: String
    public let mountPath: String
    public let itemCount: Int
    public let isAudioCD: Bool
    public let usedBytes: Int64
    public let totalBytes: Int64
    public let creationDateText: String

    public init(
        id: String,
        volumeName: String,
        filesystemFormat: String,
        mountPath: String,
        itemCount: Int,
        isAudioCD: Bool,
        usedBytes: Int64,
        totalBytes: Int64,
        creationDateText: String
    ) {
        self.id = id
        self.volumeName = volumeName
        self.filesystemFormat = filesystemFormat
        self.mountPath = mountPath
        self.itemCount = itemCount
        self.isAudioCD = isAudioCD
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.creationDateText = creationDateText
    }
}

public struct KroutonOpticalDriveInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let vendor: String
    public let product: String
    public let firmware: String
    public let interconnect: String
    public let bsdDeviceNode: String
    public let capabilitiesSummary: String
    public let isNetworkNode: Bool
    public let hostName: String
    public let mediaState: String
    public let mediaType: String
    public let isMediaPresent: Bool
    public let isMediaBlank: Bool
    public let isMediaErasable: Bool
    public let isMediaOverwritable: Bool
    public let isMediaAppendable: Bool
    public let sessionCount: Int
    public let trackCount: Int
    public let freeSectorsLBA: Int64
    public let freeBytes: Int64
    public let usedSectorsLBA: Int64
    public let usedBytes: Int64
    public let mediaManufacturer: String
    public let bookStandard: String
    public let dyeChemistry: String
    public let laserWavelengthNA: String
    public let sectorBlockSize: String
    public let copyProtectionStatus: String
    public let mountedVolumes: [KroutonMountedDiscVolume]
    public let availableWriteSpeeds: [String]

    public init(
        id: String,
        vendor: String,
        product: String,
        firmware: String,
        interconnect: String = "USB",
        bsdDeviceNode: String = "/dev/rdisk",
        capabilitiesSummary: String = "DVD±R DL • CD-R/RW • CD-TEXT",
        isNetworkNode: Bool = false,
        hostName: String = "Local Mac",
        mediaState: String = "Slot Empty",
        mediaType: String = "No Disc",
        isMediaPresent: Bool = false,
        isMediaBlank: Bool = false,
        isMediaErasable: Bool = false,
        isMediaOverwritable: Bool = false,
        isMediaAppendable: Bool = false,
        sessionCount: Int = 0,
        trackCount: Int = 0,
        freeSectorsLBA: Int64 = 0,
        freeBytes: Int64 = 0,
        usedSectorsLBA: Int64 = 0,
        usedBytes: Int64 = 0,
        mediaManufacturer: String = "Unknown ATIP/MID",
        bookStandard: String = "ISO/IEC Standard",
        dyeChemistry: String = "Phase-Change / Organic",
        laserWavelengthNA: String = "780 nm IR (0.45 NA)",
        sectorBlockSize: String = "2,048 Bytes (Mode 1)",
        copyProtectionStatus: String = "Unencrypted ( CSS / AACS Clear )",
        mountedVolumes: [KroutonMountedDiscVolume] = [],
        availableWriteSpeeds: [String] = ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]
    ) {
        self.id = id
        self.vendor = vendor
        self.product = product
        self.firmware = firmware
        self.interconnect = interconnect
        self.bsdDeviceNode = bsdDeviceNode
        self.capabilitiesSummary = capabilitiesSummary
        self.isNetworkNode = isNetworkNode
        self.hostName = hostName
        self.mediaState = mediaState
        self.mediaType = mediaType
        self.isMediaPresent = isMediaPresent
        self.isMediaBlank = isMediaBlank
        self.isMediaErasable = isMediaErasable
        self.isMediaOverwritable = isMediaOverwritable
        self.isMediaAppendable = isMediaAppendable
        self.sessionCount = sessionCount
        self.trackCount = trackCount
        self.freeSectorsLBA = freeSectorsLBA
        self.freeBytes = freeBytes
        self.usedSectorsLBA = usedSectorsLBA
        self.usedBytes = usedBytes
        self.mediaManufacturer = mediaManufacturer
        self.bookStandard = bookStandard
        self.dyeChemistry = dyeChemistry
        self.laserWavelengthNA = laserWavelengthNA
        self.sectorBlockSize = sectorBlockSize
        self.copyProtectionStatus = copyProtectionStatus
        self.mountedVolumes = mountedVolumes
        self.availableWriteSpeeds = availableWriteSpeeds
    }

    public var displayName: String {
        isNetworkNode ? "\(vendor) \(product) (\(hostName))" : "\(vendor) \(product)"
    }

    public var statusBadgeText: String {
        if isMediaPresent {
            let totalDisplayBytes = max(freeBytes, usedBytes)
            let gb = Double(totalDisplayBytes) / 1_000_000_000.0
            let statePrefix: String
            if isMediaBlank {
                statePrefix = "Blank"
            } else if isMediaErasable {
                statePrefix = "Rewritable"
            } else {
                statePrefix = "Mounted"
            }
            if gb >= 0.95 {
                return String(format: "%@ %@ (%.2f GB)", statePrefix, mediaType, gb)
            } else if totalDisplayBytes > 0 {
                let mb = Double(totalDisplayBytes) / 1_000_000.0
                return String(format: "%@ %@ (%.0f MB)", statePrefix, mediaType, mb)
            }
            return "\(statePrefix) \(mediaType)"
        }
        return mediaState
    }

    public var redBookTimecodeCapacity: String {
        let totalSectors = max(freeSectorsLBA + usedSectorsLBA, 1)
        let totalSeconds = Int(totalSectors / 75)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let frames = Int(totalSectors % 75)
        return String(format: "%02d:%02d:%02d (75 fps)", mins, secs, frames)
    }

    public var totalCapacityBytes: Int64 {
        max(1, freeBytes + usedBytes)
    }

    public var usedFraction: Double {
        if isMediaBlank { return 0.0 }
        let total = Double(max(1, freeBytes + usedBytes))
        return min(1.0, max(0.0, Double(usedBytes) / total))
    }
}

// MARK: - Sprint 3: WaveBurner Red Book Audio CD & Car-Safe MP3 Models
public enum KroutonTrackPregapStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard2s = "2.0s Standard Pre-Gap"
    case gapless0s = "0.0s Gapless (Live)"
    case customPause = "Custom INDEX 00 Pause"
    case jamCrossfade = "Equal-Power Crossfade"
    public var id: String { rawValue }
}

public struct KroutonRedBookTrack: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var performer: String
    public var songWriter: String
    public var isrcCode: String          // 12-char ISO 3901 (e.g. US-KRO-26-00001)
    public var durationSeconds: Double
    public var preGapSeconds: Double     // INDEX 00 duration (0.0s gapless .. 4.0s)
    public var crossfadeSeconds: Double  // Jam-style overlap duration
    public var transitionStyle: KroutonTrackPregapStyle
    public var preEmphasisEnabled: Bool
    public var copyPermittedSCMS: Bool
    public var sampleRateHz: Int
    public var bitDepth: Int

    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        performer: String = "Artist",
        songWriter: String = "",
        isrcCode: String = "",
        durationSeconds: Double = 215.0,
        preGapSeconds: Double = 2.0,
        crossfadeSeconds: Double = 0.0,
        transitionStyle: KroutonTrackPregapStyle = .standard2s,
        preEmphasisEnabled: Bool = false,
        copyPermittedSCMS: Bool = true,
        sampleRateHz: Int = 44100,
        bitDepth: Int = 16
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.performer = performer
        self.songWriter = songWriter
        self.isrcCode = isrcCode
        self.durationSeconds = durationSeconds
        self.preGapSeconds = preGapSeconds
        self.crossfadeSeconds = crossfadeSeconds
        self.transitionStyle = transitionStyle
        self.preEmphasisEnabled = preEmphasisEnabled
        self.copyPermittedSCMS = copyPermittedSCMS
        self.sampleRateHz = sampleRateHz
        self.bitDepth = bitDepth
    }

    // Red Book 75 frames/sec (2,352 bytes per 1/75s sector)
    public var totalRedBookFrames: Int64 {
        let activeGap = (transitionStyle == .gapless0s || transitionStyle == .jamCrossfade) ? 0.0 : preGapSeconds
        return max(75, Int64(round((durationSeconds + activeGap) * 75.0)))
    }

    public var redBookByteSize: Int64 {
        totalRedBookFrames * 2352
    }

    public var formattedDurationMMSSFF: String {
        let framesTotal = Int(round(durationSeconds * 75.0))
        let secsTotal = framesTotal / 75
        let mins = secsTotal / 60
        let secs = secsTotal % 60
        let ff = framesTotal % 75
        return String(format: "%02d:%02d:%02d", mins, secs, ff)
    }
}

// Hardware CD-TEXT Sanitizer: Transliterates curly quotes, em-dashes, and diacritics to strict 7-bit ASCII
// so 1990s-2010s Sony/Pioneer/Alpine car stereos never display garbled subcode characters.
public enum KroutonCDTextSanitizer {
    public static func sanitize(_ input: String) -> String {
        var s = input
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "--")
            .replacingOccurrences(of: "\u{2026}", with: "...")
        if let asciiData = s.applyingTransform(.stripCombiningMarks, reverse: false)?.data(using: .ascii, allowLossyConversion: true),
           let clean = String(data: asciiData, encoding: .ascii) {
            s = clean
        }
        return String(s.prefix(60))
    }

    public static func sanitizeISRC(_ raw: String) -> String {
        let alnum = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        return String(alnum.prefix(12))
    }

    public static func sanitizeMCN(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        return String(digits.prefix(13))
    }
}

// WaveBurner 5-Second Transition Audition Preview Engine
// Plays the final 2.5s of Track N -> INDEX 00 Pre-Gap (or Jam Crossfade) -> first 2.5s of Track N+1
@MainActor
public final class KroutonAudioPreviewEngine: ObservableObject {
    @Published public var isAuditioning: Bool = false
    @Published public var auditionStatusText: String = "Idle"
    @Published public var auditioningTrackID: UUID? = nil
    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var auditionTimer: Timer?

    public init() {}

    public func stopAudition() {
        auditionTimer?.invalidate()
        auditionTimer = nil
        playerA?.stop()
        playerB?.stop()
        playerA = nil
        playerB = nil
        isAuditioning = false
        auditioningTrackID = nil
        auditionStatusText = "Idle"
    }

    public func auditionTransition(from trackA: KroutonRedBookTrack, to trackB: KroutonRedBookTrack?) {
        stopAudition()
        isAuditioning = true
        auditioningTrackID = trackA.id

        let gap = (trackB?.transitionStyle == .gapless0s || trackB?.transitionStyle == .jamCrossfade) ? 0.0 : (trackB?.preGapSeconds ?? 2.0)
        let xfade = (trackB?.transitionStyle == .jamCrossfade) ? max(1.0, trackB?.crossfadeSeconds ?? 2.0) : 0.0

        if let nextTrack = trackB {
            auditionStatusText = xfade > 0
                ? String(format: "Auditioning %.1fs Crossfade: %@ -> %@", xfade, trackA.title, nextTrack.title)
                : String(format: "Auditioning Splice (%.1fs INDEX 00 Gap): %@ -> %@", gap, trackA.title, nextTrack.title)
        } else {
            auditionStatusText = "Auditioning Lead-Out Tail: \(trackA.title)"
        }

        // Attempt real AVAudioPlayer playback if files exist on disk
        if let pA = try? AVAudioPlayer(contentsOf: trackA.url) {
            pA.prepareToPlay()
            let startOffset = max(0.0, pA.duration - 2.5)
            pA.currentTime = startOffset
            pA.play()
            self.playerA = pA
        } else {
            /* Acoustic cue handled by KroutonApp UI layer */
        }

        // Schedule transition to Track B after 2.5s + gap
        let switchDelay = max(0.5, 2.5 - (xfade * 0.5) + min(gap, 1.5))
        DispatchQueue.main.asyncAfter(deadline: .now() + switchDelay) { [weak self] in
            guard let self = self, self.isAuditioning else { return }
            if let nextTrack = trackB, let pB = try? AVAudioPlayer(contentsOf: nextTrack.url) {
                pB.prepareToPlay()
                pB.currentTime = 0.0
                pB.play()
                self.playerB = pB
            }
        }

        auditionTimer = Timer.scheduledTimer(withTimeInterval: 5.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopAudition()
            }
        }
    }
}
