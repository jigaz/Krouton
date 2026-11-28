import AVFoundation
import Combine
import CryptoKit
import Foundation
import SwiftUI

// MARK: - Staged files

/// A file or folder staged for a data disc, with what the deck shows about it and where it goes.
public struct KroutonStagedFileEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The source on this Mac.
    public let url: URL
    /// The name it gets on the disc.
    public let name: String
    /// True for a folder.
    public let isDirectory: Bool
    /// Size in bytes; for a folder, everything inside it.
    public let byteSize: Int64
    /// Items inside a folder; 1 for a file.
    public let itemCount: Int
    /// The permissions as text, such as "rw-r--r--", for display.
    public let posixPermissions: String
    /// When the source was last modified.
    public let modifiedDate: Date
    /// Visible in the HFS+ side of a hybrid disc.
    public var showOnMac: Bool
    /// Visible in the ISO 9660, Joliet and UDF side of a hybrid disc.
    public var showOnPC: Bool
    /// True when the user put a disc break before this entry.
    public var startsNewDisc: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        byteSize: Int64,
        itemCount: Int,
        posixPermissions: String,
        modifiedDate: Date,
        showOnMac: Bool = true,
        showOnPC: Bool = true,
        startsNewDisc: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.itemCount = itemCount
        self.posixPermissions = posixPermissions
        self.modifiedDate = modifiedDate
        self.showOnMac = showOnMac
        self.showOnPC = showOnPC
        self.startsNewDisc = startsNewDisc
    }

    /// 2,048-byte sectors the entry needs, at least one. Directory records are not counted.
    public var sectorsLBA: Int64 {
        max(1, (byteSize + 2047) / 2048)
    }

    /// True when the file is too large for one ISO 9660 extent.
    public var exceedsISO9660FourGiBLimit: Bool {
        byteSize >= 4_294_967_295
    }

    /// True when the name is longer than Joliet's 64 characters.
    public var exceedsJoliet64CharLimit: Bool {
        name.count > 64
    }

    /// True when the name is longer than ISO 9660 Level 2's 31 characters.
    public var exceedsISO9660ThirtyOneCharLimit: Bool {
        name.count > 31
    }

    /// True for a .bin, .iso or .cue file, which the deck offers to burn as an image.
    public var isConvertibleBinOrIso: Bool {
        let l = name.lowercased()
        return l.hasSuffix(".bin") || l.hasSuffix(".iso") || l.hasSuffix(".cue")
    }
}

// MARK: - Burn telemetry

/// One point of a burn's speed graph.
public struct KroutonBurnTelemetrySample: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// How far the burn was, 0 to 1.
    public let progressFraction: Double
    /// Write speed as a multiple of the medium's 1x.
    public let speedMultiplierX: Double
    /// Always 0 today: DiscRecording doesn't report spindle speed.
    public let spindleRPM: Double
    /// Write speed in KB/s, as DiscRecording reports it.
    public let throughputKBs: Double

    public init(
        id: UUID = UUID(),
        progressFraction: Double,
        speedMultiplierX: Double,
        spindleRPM: Double,
        throughputKBs: Double
    ) {
        self.id = id
        self.progressFraction = progressFraction
        self.speedMultiplierX = speedMultiplierX
        self.spindleRPM = spindleRPM
        self.throughputKBs = throughputKBs
    }
}

/// One drive's progress through a run of copies of the same disc.
public struct KroutonBatchBurnState: Identifiable, Hashable, Sendable {
    /// The drive's ID.
    public let id: String
    /// The drive's display name.
    public var driveName: String
    /// The copy being burned, from 1.
    public var currentCopyIndex: Int
    /// How many copies the run makes.
    public var totalCopies: Int
    /// True while the drive waits for the next blank disc.
    public var isWaitingForBlankDisc: Bool
    /// True once the burned disc was ejected.
    public var hasDetectedDiscEject: Bool = false
    /// Seconds until the next copy starts, while counting down.
    public var countdownSecondsRemaining: Int?
    /// One line of status, for display.
    public var statusMessage: String
    /// Always false: Krouton sends no book-type (bitsetting) command.
    public var bitsetDVDROMActive: Bool

    public init(
        id: String,
        driveName: String,
        currentCopyIndex: Int = 1,
        totalCopies: Int = 1,
        isWaitingForBlankDisc: Bool = false,
        countdownSecondsRemaining: Int? = nil,
        statusMessage: String = "Ready",
        bitsetDVDROMActive: Bool = false
    ) {
        self.id = id
        self.driveName = driveName
        self.currentCopyIndex = currentCopyIndex
        self.totalCopies = totalCopies
        self.isWaitingForBlankDisc = isWaitingForBlankDisc
        self.countdownSecondsRemaining = countdownSecondsRemaining
        self.statusMessage = statusMessage
        self.bitsetDVDROMActive = bitsetDVDROMActive
    }
}

/// Live state of one drive for the burn graph ("phase scope"): progress, speeds and the graph's
/// samples.
public struct KroutonDrivePhaseScopeTelemetry: Identifiable, Hashable, Sendable {
    /// The drive's ID.
    public let id: String
    /// The drive's display name.
    public var driveName: String
    /// True while a job runs on the drive.
    public var isActive: Bool
    /// True when the user pinned the graph into the workspace.
    public var isManuallyPinnedInline: Bool
    /// True while the graph is open in its own window.
    public var isFloatingWindowOpen: Bool
    /// What the drive is doing, such as "Writing track 2".
    public var phaseTitle: String
    /// Progress of the current job, 0 to 1.
    public var progressFraction: Double
    /// Write speed now, as a multiple of 1x.
    public var currentSpeedX: Double
    /// Write speed now, in KB/s.
    public var currentSpeedKBs: Double
    /// The highest speed seen in this job.
    public var peakSpeedX: Double
    /// The average of the samples so far.
    public var averageSpeedX: Double
    /// The speed the burn asked for.
    public var targetSpeedX: Double
    /// Always 0 today: DiscRecording doesn't report spindle speed.
    public var currentSpindleRPM: Int
    /// The sector being written, when known.
    public var currentSectorLBA: Int64
    /// Sectors the job writes.
    public var totalSectorsLBA: Int64
    /// The drive's buffer fill, in percent; 0 while DiscRecording doesn't report it.
    public var bufferFillPercent: Double
    /// The laser wavelength for the medium, for display (derived from the media type).
    public var laserWavelengthText: String
    /// The write strategy, for display.
    public var writeStrategyText: String
    /// Seconds since the job started.
    public var elapsedSeconds: Int
    /// The graph's points, in order of progress.
    public var samples: [KroutonBurnTelemetrySample]

    public init(
        id: String,
        driveName: String,
        isActive: Bool = false,
        isManuallyPinnedInline: Bool = false,
        isFloatingWindowOpen: Bool = false,
        phaseTitle: String = "Idle",
        progressFraction: Double = 0.0,
        currentSpeedX: Double = 0.0,
        currentSpeedKBs: Double = 0.0,
        peakSpeedX: Double = 0.0,
        averageSpeedX: Double = 0.0,
        targetSpeedX: Double = 16.0,
        currentSpindleRPM: Int = 0,
        currentSectorLBA: Int64 = 0,
        totalSectorsLBA: Int64 = 359_847,
        bufferFillPercent: Double = 98.0,
        laserWavelengthText: String = "780 nm IR",
        writeStrategyText: String = "P-CAV",
        elapsedSeconds: Int = 0,
        samples: [KroutonBurnTelemetrySample] = []
    ) {
        self.id = id
        self.driveName = driveName
        self.isActive = isActive
        self.isManuallyPinnedInline = isManuallyPinnedInline
        self.isFloatingWindowOpen = isFloatingWindowOpen
        self.phaseTitle = phaseTitle
        self.progressFraction = progressFraction
        self.currentSpeedX = currentSpeedX
        self.currentSpeedKBs = currentSpeedKBs
        self.peakSpeedX = peakSpeedX
        self.averageSpeedX = averageSpeedX
        self.targetSpeedX = targetSpeedX
        self.currentSpindleRPM = currentSpindleRPM
        self.currentSectorLBA = currentSectorLBA
        self.totalSectorsLBA = totalSectorsLBA
        self.bufferFillPercent = bufferFillPercent
        self.laserWavelengthText = laserWavelengthText
        self.writeStrategyText = writeStrategyText
        self.elapsedSeconds = elapsedSeconds
        self.samples = samples
    }

    /// Roughly where the laser is, in mm from the disc's centre: 24 mm at the start of the data
    /// area, 58 mm at the end.
    public var radialMillimeters: Double {
        24.0 + (34.0 * min(1.0, max(0.0, progressFraction)))
    }

    /// Adds a graph point without letting progress go backwards: a point within 0.3 % of the
    /// last one replaces it, a small step back is held at the last progress, and a step back of
    /// more than 8 % (a new pass, such as verify) starts the graph again.
    public mutating func appendMonotonicSample(
        rawFraction: Double,
        speedX: Double,
        rpm: Int,
        kbs: Double
    ) {
        let clamped = min(1.0, max(0.0, rawFraction))
        if let last = samples.last {
            if clamped < last.progressFraction - 0.08 {
                samples.removeAll()
                peakSpeedX = speedX
            } else if abs(clamped - last.progressFraction) < 0.003 {
                samples[samples.count - 1] = KroutonBurnTelemetrySample(
                    progressFraction: last.progressFraction,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(rpm),
                    throughputKBs: kbs
                )
                progressFraction = last.progressFraction
                let sumX = samples.reduce(0.0) { $0 + $1.speedMultiplierX }
                averageSpeedX = sumX / Double(max(1, samples.count))
                return
            }
        }
        let monotonicFrac = max(samples.last?.progressFraction ?? 0.0, clamped)
        progressFraction = monotonicFrac
        samples.append(KroutonBurnTelemetrySample(
            progressFraction: monotonicFrac,
            speedMultiplierX: speedX,
            spindleRPM: Double(rpm),
            throughputKBs: kbs
        ))
        let sumX = samples.reduce(0.0) { $0 + $1.speedMultiplierX }
        averageSpeedX = sumX / Double(max(1, samples.count))
    }
}

// MARK: - Burn reports

/// The summary shown after a burn: what was written, how fast, and what to do if it failed.
public struct KroutonBurnSessionReport: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// True when the burn finished without error.
    public let isSuccess: Bool
    public let title: String
    public let summary: String
    public let driveModel: String
    public let firmwareRevision: String
    public let mediaFormattedName: String
    public let volumeName: String
    public let sectorsWrittenLBA: Int64
    public let bytesWritten: Int64
    public let averageSpeedText: String
    public let peakSpeedText: String
    public let elapsedDurationText: String
    /// What to try next, for a failed burn.
    public let diagnosticAdvice: String

    public init(
        id: UUID = UUID(),
        isSuccess: Bool,
        title: String,
        summary: String,
        driveModel: String,
        firmwareRevision: String,
        mediaFormattedName: String,
        volumeName: String,
        sectorsWrittenLBA: Int64,
        bytesWritten: Int64,
        averageSpeedText: String,
        peakSpeedText: String,
        elapsedDurationText: String,
        diagnosticAdvice: String
    ) {
        self.id = id
        self.isSuccess = isSuccess
        self.title = title
        self.summary = summary
        self.driveModel = driveModel
        self.firmwareRevision = firmwareRevision
        self.mediaFormattedName = mediaFormattedName
        self.volumeName = volumeName
        self.sectorsWrittenLBA = sectorsWrittenLBA
        self.bytesWritten = bytesWritten
        self.averageSpeedText = averageSpeedText
        self.peakSpeedText = peakSpeedText
        self.elapsedDurationText = elapsedDurationText
        self.diagnosticAdvice = diagnosticAdvice
    }
}

/// Something that holds live drive telemetry keyed by drive ID (the drive bank).
@MainActor
public protocol KroutonDriveTelemetryStore: AnyObject, Sendable {
    /// Telemetry per drive ID.
    var driveTelemetry: [String: KroutonDrivePhaseScopeTelemetry] { get set }
}
