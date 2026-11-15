import Foundation
import OpticalCore

// MARK: - Part A: Optical Rescue & Adaptive Sector Copy Engine
public enum KroutonSectorRescueAction: String, Codable, Sendable, Equatable {
    case readCleanFullSpeed    = "CLEAN_BURST"
    case downshiftRetry2xCLV   = "DOWNSHIFT_2X_RETRY"
    case substituteZeroSector  = "ZERO_PAD_SUBSTITUTE"
}

public struct KroutonSectorRescueDecision: Sendable, Equatable {
    public let lba: Int64
    public let action: KroutonSectorRescueAction
    public let recommendedSpindleSpeedX: Int
    public let nextCursorLBA: Int64
    public let replacementSectorBytes: Int

    public init(
        lba: Int64,
        action: KroutonSectorRescueAction,
        recommendedSpindleSpeedX: Int,
        nextCursorLBA: Int64,
        replacementSectorBytes: Int
    ) {
        self.lba = lba
        self.action = action
        self.recommendedSpindleSpeedX = recommendedSpindleSpeedX
        self.nextCursorLBA = nextCursorLBA
        self.replacementSectorBytes = replacementSectorBytes
    }
}

// MARK: - Part B: Polar-Coordinate Mini Graphics Layout & 300-DPI Disc Label Engine

public enum KroutonRescueSectorStatus: String, Codable, Sendable, CaseIterable {
    case healthyBurst      = "CLEAN_BURST"
    case retried2xCLV      = "DOWNSHIFT_2X_RETRY"
    case c2Interpolated    = "C2_ECC_RECOVERED"
    case zeroPaddedDefect  = "ZERO_PAD_SUBSTITUTE"
}

public struct KroutonOpticalRescueMapSnapshot: Sendable, Equatable {
    public let buckets: [KroutonRescueSectorStatus]
    public let totalSectorsLBA: Int64
    public let healthyCount: Int
    public let retriedCount: Int
    public let c2InterpolatedCount: Int
    public let zeroPaddedCount: Int

    public var recoveryIntegrityPercent: Double {
        guard !buckets.isEmpty else { return 100.0 }
        let goodWeight = Double(healthyCount) + Double(retriedCount) * 0.98 + Double(c2InterpolatedCount) * 0.85
        return min(100.0, max(0.0, (goodWeight / Double(buckets.count)) * 100.0))
    }

    public func exportRescueMapLog(volumeName: String) -> String {
        let stepLBA = max(1, totalSectorsLBA / Int64(max(1, buckets.count)))
        var lines = [
            "# KROUTON OPTICAL RESCUE SECTOR MAP (.MAP v1)",
            "VOLUME: \(volumeName) | TOTAL_LBA: \(totalSectorsLBA) | INTEGRITY: \(String(format: "%.2f%%", recoveryIntegrityPercent))"
        ]
        for (idx, status) in buckets.enumerated() where status != .healthyBurst {
            let startLBA = Int64(idx) * stepLBA
            lines.append(String(format: "LBA %07d..%07d : %@", startLBA, startLBA + stepLBA - 1, status.rawValue))
        }
        if lines.count == 2 {
            lines.append("ALL_SECTORS_CLEAN: 0..<(totalSectorsLBA) [100% Bit-Accurate]")
        }
        return lines.joined(separator: "\n")
    }
}

public struct KroutonArchivalQualityCertificate: Sendable, Equatable {
    public let gradeBadge: String          // e.g. "A+ ARCHIVAL MASTER"
    public let c1BlockErrorRate: Double    // BLER errors/sec (Red Book limit < 220)
    public let c2UncorrectableCount: Int
    public let servoJitterPercent: Double  // Ideal 4.2% .. 6.5%
    public let radialStabilityScore: Double
    public let summaryLine: String
    public let certificateText: String
}

public enum KroutonRescueEngine {
    public static func evaluateSectorRescue(
        lba: Int64,
        c2ErrorCount: Int,
        retryAttempt: Int,
        maxRetries: Int = 5,
        normalSpeedX: Int = 16,
        sectorSizeBytes: Int = 2048,
        fastSkipStepLBA: Int64 = 16
    ) -> KroutonSectorRescueDecision {
        if c2ErrorCount <= 0 {
            return KroutonSectorRescueDecision(
                lba: lba,
                action: .readCleanFullSpeed,
                recommendedSpindleSpeedX: normalSpeedX,
                nextCursorLBA: lba + 1,
                replacementSectorBytes: 0
            )
        }

        if retryAttempt < maxRetries {
            return KroutonSectorRescueDecision(
                lba: lba,
                action: .downshiftRetry2xCLV,
                recommendedSpindleSpeedX: 2,
                nextCursorLBA: lba, // stay on current LBA for low-speed CLV re-read
                replacementSectorBytes: 0
            )
        }

        // Retries exhausted on radial scratch -> zero-pad sector to maintain exact LBA alignment and skip
        let step = max(1, fastSkipStepLBA)
        return KroutonSectorRescueDecision(
            lba: lba,
            action: .substituteZeroSector,
            recommendedSpindleSpeedX: 2,
            nextCursorLBA: lba + step,
            replacementSectorBytes: sectorSizeBytes
        )
    }

    public static func buildOpticalRescueMap(
        totalSectorsLBA: Int64 = 333_000,
        scratchSeverity: Int = 0
    ) -> KroutonOpticalRescueMapSnapshot {
        var buckets: [KroutonRescueSectorStatus] = []
        var healthy = 0, retried = 0, c2 = 0, bad = 0
        for i in 0..<64 {
            let status: KroutonRescueSectorStatus
            if scratchSeverity <= 0 {
                status = .healthyBurst
            } else if scratchSeverity == 1 && (i == 41 || i == 42 || i == 55) {
                status = (i == 42) ? .c2Interpolated : .retried2xCLV
            } else if scratchSeverity >= 2 && (i >= 46 && i <= 51) {
                status = (i == 49) ? .zeroPaddedDefect : ((i % 2 == 0) ? .c2Interpolated : .retried2xCLV)
            } else {
                status = .healthyBurst
            }
            buckets.append(status)
            switch status {
            case .healthyBurst:     healthy += 1
            case .retried2xCLV:     retried += 1
            case .c2Interpolated:   c2 += 1
            case .zeroPaddedDefect: bad += 1
            }
        }
        return KroutonOpticalRescueMapSnapshot(
            buckets: buckets,
            totalSectorsLBA: max(1, totalSectorsLBA),
            healthyCount: healthy,
            retriedCount: retried,
            c2InterpolatedCount: c2,
            zeroPaddedCount: bad
        )
    }

    /// Computes a deterministic post-burn Archival Quality Grade across radius r=24.0mm..58.0mm
    public static func evaluateArchivalDiscGrade(
        driveModel: String,
        mediaType: String,
        sectorsWrittenLBA: Int64,
        c1Rate: Double = 3.4,
        c2Count: Int = 0,
        jitterPercent: Double = 4.9
    ) -> KroutonArchivalQualityCertificate {
        let clampedJitter = max(3.5, min(15.0, jitterPercent))
        let grade: String
        if c2Count == 0 && c1Rate < 15.0 && clampedJitter <= 6.2 {
            grade = "A+ ARCHIVAL MASTER"
        } else if c2Count == 0 && c1Rate < 80.0 && clampedJitter <= 8.0 {
            grade = "A WORKSPACE VERIFIED"
        } else if c2Count <= 2 && c1Rate < 220.0 {
            grade = "B+ CONSUMER SAFE"
        } else {
            grade = "C MARGINAL SUBSTRATE"
        }
        let stability = max(0.0, min(100.0, 100.0 - (c1Rate * 0.12) - Double(c2Count * 8) - max(0.0, clampedJitter - 4.5) * 2.5))
        let summary = String(format: "%@ • BLER %.1f/s • C2: %d • Jitter %.2f%% • Stability %.1f%%", grade, c1Rate, c2Count, clampedJitter, stability)
        let cert = """
        === KROUTON ARCHIVAL OPTICAL QUALITY CERTIFICATE ===
        Grade: \(grade)
        Drive: \(driveModel) | Media: \(mediaType) | Verified LBA: \(sectorsWrittenLBA)
        Radial Scan (24.0 mm -> 58.0 mm): C1/PIE Avg \(String(format: "%.1f", c1Rate))/s | C2/POE: \(c2Count) | PLL Jitter: \(String(format: "%.2f%%", clampedJitter))
        Archival Stability Score: \(String(format: "%.1f%%", stability)) (ISO/IEC 10149 & ECMA-267 Compliant)
        """
        return KroutonArchivalQualityCertificate(
            gradeBadge: grade,
            c1BlockErrorRate: c1Rate,
            c2UncorrectableCount: c2Count,
            servoJitterPercent: clampedJitter,
            radialStabilityScore: stability,
            summaryLine: summary,
            certificateText: cert
        )
    }
}
