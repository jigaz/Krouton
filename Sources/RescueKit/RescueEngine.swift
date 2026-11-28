import Foundation

// MARK: - Sector Rescue Decisions

/// What `KroutonRescueEngine.evaluateSectorRescue` decides for one sector.
public enum KroutonSectorRescueAction: String, Codable, Sendable, Equatable {
    case readCleanFullSpeed    = "CLEAN_BURST"
    case downshiftRetry2xCLV   = "DOWNSHIFT_2X_RETRY"
    case substituteZeroSector  = "ZERO_PAD_SUBSTITUTE"
}

/// One sector's rescue decision: what to do, at what speed, and where to read next.
public struct KroutonSectorRescueDecision: Sendable, Equatable {
    /// The sector the decision is for.
    public let lba: Int64
    /// What to do with it.
    public let action: KroutonSectorRescueAction
    /// The read speed to use, as a multiple of 1x.
    public let recommendedSpindleSpeedX: Int
    /// The next sector to read.
    public let nextCursorLBA: Int64
    /// Bytes of zeros to write in place of the sector; 0 unless it is substituted.
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

// MARK: - Sample Rescue Map and Archival Grade

/// The state of one cell of the sample rescue map.
public enum KroutonRescueSectorStatus: String, Codable, Sendable, CaseIterable {
    case healthyBurst      = "CLEAN_BURST"
    case retried2xCLV      = "DOWNSHIFT_2X_RETRY"
    case c2Interpolated    = "C2_ECC_RECOVERED"
    case zeroPaddedDefect  = "ZERO_PAD_SUBSTITUTE"
}

/// A 64-cell rescue map for display. `buildOpticalRescueMap` fills it with a fixed sample pattern,
/// not with a disc's read results.
public struct KroutonOpticalRescueMapSnapshot: Sendable, Equatable {
    let buckets: [KroutonRescueSectorStatus]
    /// The disc's size in sectors.
    public let totalSectorsLBA: Int64
    let healthyCount: Int
    let retriedCount: Int
    let c2InterpolatedCount: Int
    let zeroPaddedCount: Int
}

/// The result of `evaluateArchivalDiscGrade`: a grade, a one-line summary and the certificate text.
public struct KroutonArchivalQualityCertificate: Sendable, Equatable {
    /// The grade, such as "A+ ARCHIVAL MASTER", or "NOT MEASURED".
    public let gradeBadge: String
    /// C1 block error rate (BLER) per second; the Red Book limit is 220.
    let c1BlockErrorRate: Double
    let c2UncorrectableCount: Int
    let servoJitterPercent: Double
    let radialStabilityScore: Double
    /// One line for lists.
    public let summaryLine: String
    /// The full text, for saving or copying.
    public let certificateText: String
}

/// Rescue and quality-grading rules that need no drive. The rescue copy itself is
/// `KroutonDiscRescuer`, which doesn't use these.
public enum KroutonRescueEngine {
    /// Decides what to do with a sector from its C2 error count and the retries so far: read on at
    /// full speed, retry at 2x, or give up and substitute zeros. Only krouton-verify calls it
    /// today.
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

        // Out of retries: substitute zeros so every later sector keeps its offset, and skip ahead.
        let step = max(1, fastSkipStepLBA)
        return KroutonSectorRescueDecision(
            lba: lba,
            action: .substituteZeroSector,
            recommendedSpindleSpeedX: 2,
            nextCursorLBA: lba + step,
            replacementSectorBytes: sectorSizeBytes
        )
    }

    /// A sample map with a fixed pattern for `scratchSeverity` 0, 1 or 2+. No disc is read.
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

    /// Grades a burned disc from a C1/C2/jitter scan. Without all three measurements it returns
    /// "NOT MEASURED".
    ///
    /// Status (see dev-notes/open-questions.md #6): no caller passes measurements, because Krouton
    /// can't run such a scan yet, so the grading branch is never reached. The thresholds and the
    /// "ISO/IEC 10149 & ECMA-267 Compliant" line in the certificate were never checked against
    /// those standards; they must not be shown until a real scan exists.
    public static func evaluateArchivalDiscGrade(
        driveModel: String,
        mediaType: String,
        sectorsWrittenLBA: Int64,
        c1Rate: Double? = nil,
        c2Count: Int? = nil,
        jitterPercent: Double? = nil
    ) -> KroutonArchivalQualityCertificate {
        // A grade needs a real error scan. Without all three measurements there is nothing to grade.
        guard let c1Rate, let c2Count, let jitterPercent else {
            let summary = "NOT MEASURED • No C1/C2/jitter scan was run for this disc"
            return KroutonArchivalQualityCertificate(
                gradeBadge: "NOT MEASURED",
                c1BlockErrorRate: 0,
                c2UncorrectableCount: 0,
                servoJitterPercent: 0,
                radialStabilityScore: 0,
                summaryLine: summary,
                certificateText: """
                === KROUTON DISC QUALITY ===
                Grade: NOT MEASURED
                Drive: \(driveModel) | Media: \(mediaType) | Written LBA: \(sectorsWrittenLBA)
                No C1/C2/jitter error scan was run, so this disc has no quality grade.
                """
            )
        }
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
