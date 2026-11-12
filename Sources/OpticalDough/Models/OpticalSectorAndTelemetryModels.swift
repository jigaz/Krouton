import SwiftUI
import Foundation
import Combine
import DiscRecording
import IOKit
import IOKit.storage
import AVFoundation
import CryptoKit

// MARK: - Sprint 3 Part 2: UltraISO / PowerISO Bootable Sector 17 El Torito & Apple Partition Map Inspector
public enum KroutonLoafBootInspector {
    public static func inspectDiscImageBootability(url: URL) -> String? {
        let lower = url.lastPathComponent.lowercased()
        let isImage = lower.hasSuffix(".iso") || lower.hasSuffix(".img") || lower.hasSuffix(".dmg") || lower.hasSuffix(".cdr") || lower.hasSuffix(".toast") || lower.hasSuffix(".bin") || lower.hasSuffix(".rvz") || lower.hasSuffix(".gcm")
        guard isImage else { return nil }

        // Attempt real binary header inspection on local file
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }

            // 1. Check Sector 0 (Bytes 0..2048) for Apple Partition Map ('ER' / 0x4552 Driver Descriptor Map or 'PM' at 0x200)
            if let sec0 = try? handle.read(upToCount: 2048), sec0.count >= 516 {
                let b0 = sec0[0], b1 = sec0[1]
                let p0 = sec0[512], p1 = sec0[513]
                if (b0 == 0x45 && b1 == 0x52) || (p0 == 0x50 && p1 == 0x4D) {
                    return "Bootable: PowerPC / 68k Apple Partition Map"
                }
                // Check Nintendo GameCube Magic Word (0xC2339F3D at offset 0x1C) or Wii Magic Word (0x5D1C9EA3 at offset 0x18)
                if sec0.count >= 32 {
                    if sec0[28] == 0xC2 && sec0[29] == 0x33 && sec0[30] == 0x9F && sec0[31] == 0x3D {
                        return "Bootable: Nintendo GameCube DOL (80mm Optical)"
                    }
                    if sec0[24] == 0x5D && sec0[25] == 0x1C && sec0[26] == 0x9E && sec0[27] == 0xA3 {
                        return "Bootable: Nintendo Wii RVL-006 Optical Disc"
                    }
                }
            }

            // 2. Check Sector 17 (Offset 17 * 2048 = 34,816) for ISO 9660 El Torito Boot Record Volume Descriptor
            //    Byte 0 = 0x00 (Boot Record), Bytes 1..5 = 'CD001', Bytes 7..30 = 'EL TORITO SPECIFICATION'
            if (try? handle.seek(toOffset: 34_816)) != nil,
               let sec17 = try? handle.read(upToCount: 2048), sec17.count >= 75 {
                let isCD001 = (sec17[1] == 0x43 && sec17[2] == 0x44 && sec17[3] == 0x30 && sec17[4] == 0x30 && sec17[5] == 0x31)
                if sec17[0] == 0x00 && isCD001 {
                    let sysIDData = sec17.subdata(in: 7..<39)
                    let sysID = String(data: sysIDData, encoding: .ascii) ?? ""
                    if sysID.uppercased().contains("EL TORITO") {
                        // Read Boot Catalog pointer at offset 0x47 (71..74, Little-Endian UInt32 LBA)
                        let catLBA = UInt64(sec17[71]) | (UInt64(sec17[72]) << 8) | (UInt64(sec17[73]) << 16) | (UInt64(sec17[74]) << 24)
                        if catLBA > 0, (try? handle.seek(toOffset: catLBA * 2048)) != nil,
                           let catData = try? handle.read(upToCount: 128), catData.count >= 64 {
                            let platformID = catData[1]
                            let hasUEFI = (platformID == 0xEF) || catData.dropFirst(32).contains(0xEF)
                            if hasUEFI && platformID == 0x00 {
                                return "Bootable: x86_64 UEFI + BIOS (El Torito Hybrid)"
                            } else if hasUEFI {
                                return "Bootable: UEFI System Image (El Torito 0xEF)"
                            } else if platformID == 0x01 {
                                return "Bootable: PowerPC El Torito Boot Image"
                            } else if platformID == 0x02 {
                                return "Bootable: Mac El Torito Boot Image"
                            }
                        }
                        return "Bootable: x86_64 UEFI + BIOS (El Torito Sector 17)"
                    }
                }
            }
        }

        // 3. Heuristic fallback for classic OS / rescue filenames when dropped or staged
        if lower.contains("macos9") || lower.contains("os9") || lower.contains("tiger") || lower.contains("leopard") || lower.contains("system7") || lower.contains("ppc") {
            return "Bootable: PowerPC / 68k Apple Partition Map"
        }
        if lower.contains("ubuntu") || lower.contains("fedora") || lower.contains("debian") || lower.contains("win11") || lower.contains("windows") || lower.contains("sysrescue") || lower.contains("gparted") {
            return "Bootable: x86_64 UEFI + BIOS (El Torito)"
        }
        if lower.hasSuffix(".bin") {
            return "Raw 2,352 B/Sector Image (Ready for .ISO Conversion)"
        }
        return nil
    }
}

public struct KroutonLoafFileEntry: Identifiable, Hashable, Sendable {
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
        showOnPC: Bool = true
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

    public var bootabilityBadge: String? {
        KroutonLoafBootInspector.inspectDiscImageBootability(url: url)
    }

    public var isConvertibleBinOrIso: Bool {
        let l = name.lowercased()
        return l.hasSuffix(".bin") || l.hasSuffix(".iso") || l.hasSuffix(".cue")
    }
}

public struct KroutonToastingSample: Identifiable, Hashable, Sendable {
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

public struct KroutonBatchToastState: Identifiable, Hashable, Sendable {
    public let id: String // Drive ID
    public var driveName: String
    public var currentCopyIndex: Int
    public var totalCopies: Int
    public var isWaitingForBlankDisc: Bool
    public var hasDetectedDiscEject: Bool = false
    public var countdownSecondsRemaining: Int?
    public var statusMessage: String
    public var bitsetDVDROMActive: Bool

    public init(
        id: String,
        driveName: String,
        currentCopyIndex: Int = 1,
        totalCopies: Int = 1,
        isWaitingForBlankDisc: Bool = false,
        countdownSecondsRemaining: Int? = nil,
        statusMessage: String = "Ready",
        bitsetDVDROMActive: Bool = true
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

public struct KroutonKitchenThermometer: Identifiable, Hashable, Sendable {
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
    public var samples: [KroutonToastingSample]

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
        samples: [KroutonToastingSample] = []
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
                samples[samples.count - 1] = KroutonToastingSample(
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
        samples.append(KroutonToastingSample(
            progressFraction: monotonicFrac,
            speedMultiplierX: speedX,
            spindleRPM: Double(rpm),
            throughputKBs: kbs
        ))
        let sumX = samples.reduce(0.0) { $0 + $1.speedMultiplierX }
        averageSpeedX = sumX / Double(max(1, samples.count))
    }
}

public struct KroutonToastReport: Identifiable, Hashable, Sendable {
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
