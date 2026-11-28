import AVFoundation
import AudioToolbox
import CryptoKit
import Foundation
import SwiftUI
import VideoToolbox

// MARK: - Drives and Mounted Volumes

/// A file system macOS mounted from the disc in a drive.
public struct KroutonMountedDiscVolume: Identifiable, Hashable, Sendable {
    /// A stable identifier for the volume.
    public let id: String
    /// The volume's name, as Finder shows it.
    public let volumeName: String
    /// The file system macOS reports, such as "cd9660" or "udf".
    public let filesystemFormat: String
    /// Where the volume is mounted.
    public let mountPath: String
    /// How many items are at the volume's root.
    public let itemCount: Int
    /// True for an audio CD, which macOS mounts as AIFF files.
    public let isAudioCD: Bool
    /// Bytes in use on the volume.
    public let usedBytes: Int64
    /// The volume's size in bytes.
    public let totalBytes: Int64
    /// The volume's creation date, formatted for display.
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

/// One drive and the disc in it, as the drive bank last saw them.
///
/// Several descriptive fields (`mediaManufacturer`, `bookStandard`, `dyeChemistry`,
/// `laserWavelengthNA`, `sectorBlockSize`, `copyProtectionStatus`) are filled in by
/// `KroutonOpticalDriveBank` from the media type when the drive doesn't report them; treat them as
/// descriptions, not measurements.
public struct KroutonOpticalDriveInfo: Identifiable, Hashable, Sendable {
    /// A stable identifier for the drive (see `KroutonOpticalDriveBank`).
    public let id: String
    /// The drive maker, as the drive reports it.
    public let vendor: String
    /// The drive model, as the drive reports it.
    public let product: String
    /// The firmware revision.
    public let firmware: String
    /// How the drive is connected, such as "USB" or "ATAPI".
    public let interconnect: String
    /// The drive's BSD device node.
    public let bsdDeviceNode: String
    /// The media the drive can write, for display.
    public let capabilitiesSummary: String
    /// True for a drive on a Krouton Server.
    public let isNetworkNode: Bool
    /// The computer the drive is attached to.
    public let hostName: String
    /// One line about the disc, for display ("Blank DVD+R Ready").
    public let mediaState: String
    /// The media type, such as "CD-R" or "DVD+R DL".
    public let mediaType: String
    /// True when a disc is in the drive.
    public let isMediaPresent: Bool
    /// True for a blank disc.
    public let isMediaBlank: Bool
    /// True for rewritable media.
    public let isMediaErasable: Bool
    /// True when the disc can be overwritten in place.
    public let isMediaOverwritable: Bool
    /// True when another session can be added.
    public let isMediaAppendable: Bool
    /// Sessions on the disc.
    public let sessionCount: Int
    /// Tracks on the disc.
    public let trackCount: Int
    /// Free 2,048-byte blocks.
    public let freeSectorsLBA: Int64
    /// Free bytes.
    public let freeBytes: Int64
    /// Used 2,048-byte blocks.
    public let usedSectorsLBA: Int64
    /// Used bytes.
    public let usedBytes: Int64
    public let mediaManufacturer: String
    public let bookStandard: String
    public let dyeChemistry: String
    public let laserWavelengthNA: String
    public let sectorBlockSize: String
    public let copyProtectionStatus: String
    /// The file systems macOS mounted from the disc.
    public let mountedVolumes: [KroutonMountedDiscVolume]
    /// The write speeds to offer, as labels ("8x (11080 KB/s)"), with "Max Safe (Auto)" first.
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

    /// Vendor and model, plus the host for a network drive.
    public var displayName: String {
        isNetworkNode ? "\(vendor) \(product) (\(hostName))" : "\(vendor) \(product)"
    }

    /// A short status for drive lists, such as "Blank DVD-R (4.70 GB)".
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

    /// The disc's total blocks as a CD time (minutes:seconds:frames). Only meaningful for CDs.
    public var redBookTimecodeCapacity: String {
        let totalSectors = max(freeSectorsLBA + usedSectorsLBA, 1)
        let totalSeconds = Int(totalSectors / 75)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let frames = Int(totalSectors % 75)
        return String(format: "%02d:%02d:%02d (75 fps)", mins, secs, frames)
    }
}

// MARK: - Audio CD Tracks

/// How a track starts on an audio CD. The raw values are display names and are saved in projects.
public enum KroutonTrackPregapStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard2s = "2.0s Standard Pre-Gap"
    case gapless0s = "0.0s Gapless (Live)"
    case customPause = "Custom INDEX 00 Pause"
    case jamCrossfade = "Equal-Power Crossfade"
    public var id: String { rawValue }
}

/// One track of an audio CD as the burn and CUE code see it, flattened from the Audio CD editor's
/// project.
public struct KroutonRedBookTrack: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    /// The source audio file.
    public let url: URL
    /// CD-Text title.
    public var title: String
    /// CD-Text performer.
    public var performer: String
    /// CD-Text songwriter.
    public var songWriter: String
    /// ISO 3901 ISRC, 12 characters without hyphens (written US-KRO-26-00001 for display).
    public var isrcCode: String
    /// The track's length in seconds.
    public var durationSeconds: Double
    /// The pause before the track (INDEX 00), in seconds.
    public var preGapSeconds: Double
    /// How long the track overlaps the one before it, for `.jamCrossfade`.
    public var crossfadeSeconds: Double
    /// How the track starts.
    public var transitionStyle: KroutonTrackPregapStyle
    /// Sets the pre-emphasis flag in the track's subcode.
    public var preEmphasisEnabled: Bool
    /// Sets the digital copy permitted flag (SCMS).
    public var copyPermittedSCMS: Bool
    /// The source's sample rate.
    public var sampleRateHz: Int
    /// The source's bits per sample.
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

    /// Frames the track takes on the disc, including its pause unless it is gapless or crossfaded;
    /// at least one second.
    public var totalRedBookFrames: Int64 {
        let activeGap = (transitionStyle == .gapless0s || transitionStyle == .jamCrossfade) ? 0.0 : preGapSeconds
        return max(75, Int64(round((durationSeconds + activeGap) * 75.0)))
    }

    /// `totalRedBookFrames` in bytes (2,352 per frame).
    public var redBookByteSize: Int64 {
        totalRedBookFrames * 2352
    }

    /// The length as minutes:seconds:frames.
    public var formattedDurationMMSSFF: String {
        let framesTotal = Int(round(durationSeconds * 75.0))
        let secsTotal = framesTotal / 75
        let mins = secsTotal / 60
        let secs = secsTotal % 60
        let ff = framesTotal % 75
        return String(format: "%02d:%02d:%02d", mins, secs, ff)
    }
}

// MARK: - CD-Text Cleanup

// Many players and car stereos show only ASCII in CD-Text, so Krouton writes plain ASCII.

/// Cleans text for CD-Text and the disc's subcode fields.
public enum KroutonCDTextSanitizer {
    /// Plain ASCII, at most 60 characters: curly quotes and dashes become their ASCII forms,
    /// accents are dropped, and anything else outside ASCII is replaced.
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

    /// Letters and digits only, upper case, at most 12 (the ISRC's length without hyphens).
    public static func sanitizeISRC(_ raw: String) -> String {
        let alnum = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        return String(alnum.prefix(12))
    }

    /// Digits only, at most 13 (the UPC/EAN catalog number).
    public static func sanitizeMCN(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        return String(digits.prefix(13))
    }
}
