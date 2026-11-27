import AVFoundation
import Combine
import CryptoKit
import Foundation
import SwiftUI

// MARK: - Staged files

public struct KroutonStagedFileEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let byteSize: Int64
    public let itemCount: Int
    public let posixPermissions: String
    public let modifiedDate: Date
    public var showOnMac: Bool
    public var showOnPC: Bool
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

    public var sectorsLBA: Int64 {
        max(1, (byteSize + 2047) / 2048)
    }

    public var exceedsISO9660FourGiBLimit: Bool {
        byteSize >= 4_294_967_295
    }

    public var exceedsJoliet64CharLimit: Bool {
        name.count > 64
    }

    public var exceedsISO9660ThirtyOneCharLimit: Bool {
        name.count > 31
    }

    public var isConvertibleBinOrIso: Bool {
        let l = name.lowercased()
        return l.hasSuffix(".bin") || l.hasSuffix(".iso") || l.hasSuffix(".cue")
    }
}

// MARK: - Burn telemetry

public struct KroutonBurnTelemetrySample: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let progressFraction: Double
    public let speedMultiplierX: Double
    public let spindleRPM: Double
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

public struct KroutonBatchBurnState: Identifiable, Hashable, Sendable {
    public let id: String // Drive ID
    public var driveName: String
    public var currentCopyIndex: Int
    public var totalCopies: Int
    public var isWaitingForBlankDisc: Bool
    public var hasDetectedDiscEject: Bool = false
    public var countdownSecondsRemaining: Int?
    public var statusMessage: String
    /// Always false: Krouton sends no book-type (bitsetting) command. Kept so saved states decode.
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

public struct KroutonDrivePhaseScopeTelemetry: Identifiable, Hashable, Sendable {
    public let id: String          // Drive ID
    public var driveName: String
    public var isActive: Bool       // True whenever throughputKBs > 0
    public var isManuallyPinnedInline: Bool
    public var isFloatingWindowOpen: Bool
    public var phaseTitle: String
    public var progressFraction: Double
    public var currentSpeedX: Double
    public var currentSpeedKBs: Double
    public var peakSpeedX: Double
    public var averageSpeedX: Double
    public var targetSpeedX: Double
    public var currentSpindleRPM: Int
    public var currentSectorLBA: Int64
    public var totalSectorsLBA: Int64
    public var bufferFillPercent: Double
    public var laserWavelengthText: String
    public var writeStrategyText: String
    public var elapsedSeconds: Int
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

    public var radialMillimeters: Double {
        24.0 + (34.0 * min(1.0, max(0.0, progressFraction)))
    }

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

public struct KroutonBurnSessionReport: Identifiable, Hashable, Sendable {
    public let id: UUID
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

@MainActor
public protocol KroutonDriveTelemetryStore: AnyObject, Sendable {
    var driveTelemetry: [String: KroutonDrivePhaseScopeTelemetry] { get set }
}
