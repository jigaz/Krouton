import AudioKit
import BurnKit
import CoreImage
import CryptoKit
import DriveKit
import Foundation
import ImageKit
import LabelKit
import NetworkSpool
import OpticalCore
import Persistence
import RescueKit
import VideoKit

// MARK: - VerifyHarness — HardwareAndBurnSuites

extension KroutonTestHarness {
    mutating func runVerifyHardwareAndBurnSuites() {

    self.runSuite("16. RescueKit Optical Bad-Sector Rescue Copy Engine & Archival Disc Quality Grading") { h in
    // 15a. Optical Rescue 3-stage state machine (Clean -> 2x CLV Downshift -> Zero-Pad Substitute)
    let clean = KroutonLabelGeometryEngine.evaluateSectorRescue(lba: 1000, c2ErrorCount: 0, retryAttempt: 0)
    h.check(clean.action == .readCleanFullSpeed && clean.nextCursorLBA == 1001, "Clean sector advances LBA by 1 at full speed")

    let retry = KroutonLabelGeometryEngine.evaluateSectorRescue(lba: 1000, c2ErrorCount: 4, retryAttempt: 2, maxRetries: 5)
    h.check(retry.action == .downshiftRetry2xCLV && retry.recommendedSpindleSpeedX == 2 && retry.nextCursorLBA == 1000,
            "Damaged sector under retry threshold downshifts to 2x CLV and re-reads same LBA")

    let exhausted = KroutonLabelGeometryEngine.evaluateSectorRescue(
        lba: 1000,
        c2ErrorCount: 12,
        retryAttempt: 5,
        maxRetries: 5,
        sectorSizeBytes: 2048,
        fastSkipStepLBA: 16
    )
    h.check(exhausted.action == .substituteZeroSector && exhausted.replacementSectorBytes == 2048 && exhausted.nextCursorLBA == 1016,
            "Exhausted sector substitutes 2048B zero-pad and fast-skips 16 LBA sectors")

    }

    self.runSuite("17. Frozen BurnSet State Machine, Single-Read Stager & Replay Verification") { h in
        let stageTmp = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonStageVerify_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: stageTmp) }
        try? FileManager.default.createDirectory(at: stageTmp, withIntermediateDirectories: true)
        let srcFile1 = stageTmp.appendingPathComponent("Doc 100%.txt")
        let srcFile2 = stageTmp.appendingPathComponent("Archive_Part2.bin")
        try Data("ALPHA_100_PERCENT_PAYLOAD".utf8).write(to: srcFile1)
        try Data(repeating: 0x5A, count: 8192).write(to: srcFile2)

        let stagedResult = try BurnSetStager.freezeAndStageSet(
            title: "THE_FORTY_CHARACTER_LONG_ARCHIVAL_VAULT_TITLE_2026",
            discs: [
                [StagedInputFile(sourceURL: srcFile1, relativePathOnDisc: "Docs/Doc 100%.txt")],
                [StagedInputFile(sourceURL: srcFile2, relativePathOnDisc: "Bins/Archive_Part2.bin")]
            ],
            stagingRootDirectory: stageTmp,
            manifestMode: .bagItRFC8493
        )
        h.check(stagedResult.burnSet.discs.count == 2, "BurnSetStager must freeze and stage 2 FrozenDisc images")
        h.check(stagedResult.burnSet.discs[0].volumeLabel.hasSuffix("_D01") &&
                stagedResult.burnSet.discs[1].volumeLabel.hasSuffix("_D02") &&
                stagedResult.burnSet.discs[0].volumeLabel.count <= 32,
                "SpanManifest.volumeLabel must produce unique <=32-char labels ending in _D01 and _D02")
        let d1Tags = try SpanManifest.tagFiles(for: 1, in: stagedResult.setIndex)
        let d1ManifestStr = String(data: d1Tags["manifest-sha256.txt"] ?? Data(), encoding: .utf8) ?? ""
        h.check(d1ManifestStr.contains("data/Docs/Doc 100%25.txt"),
                "SpanManifest must percent-encode '%' as '%25' in manifest-sha256.txt paths")
        let d1InfoStr = String(data: d1Tags["bag-info.txt"] ?? Data(), encoding: .utf8) ?? ""
        h.check(d1InfoStr.contains("Bag-Count: 1 of 2") && d1InfoStr.contains("Bag-Group-Identifier:"),
                "RFC 8493 BagIt bag-info.txt must include Bag-Group-Identifier and Bag-Count")

        let bSet = stagedResult.burnSet
        let drv = DriveID("PIONEER-BDR-XS07")
        let validLog: [BurnEvent] = [
            .setCreated(bSet),
            .attemptStarted(set: bSet.id, disc: 1, attempt: 1, drive: drv, mediaID: "MID-1", at: .now),
            .phaseChanged(set: bSet.id, disc: 1, attempt: 1, phase: .verifying, at: .now),
            .attemptSucceeded(set: bSet.id, disc: 1, attempt: 1, at: .now),
            .attemptSucceeded(set: bSet.id, disc: 1, attempt: 1, at: .now),
            .attemptStarted(set: bSet.id, disc: 2, attempt: 1, drive: drv, mediaID: "MID-2A", at: .now),
            .attemptFailed(set: bSet.id, disc: 2, attempt: 1, failure: .writeError(sense: "3/0C/00"), at: .now),
            .attemptStarted(set: bSet.id, disc: 2, attempt: 2, drive: drv, mediaID: "MID-2B", at: .now),
            .attemptSucceeded(set: bSet.id, disc: 2, attempt: 2, at: .now)
        ]
        let (replayedSets, rejectedEvents) = BurnSetProgress.replay(validLog)
        h.check(replayedSets.count == 1 && rejectedEvents.count == 1,
                "BurnSetProgress.replay must reject duplicate attemptSucceeded while replaying valid events")
        if let prog = replayedSets.first {
            h.check(prog.isComplete && prog.jobs[0].attempts == 1 && prog.jobs[1].attempts == 2,
                    "After Disc 2 succeeds on attempt 2, BurnSetProgress.isComplete must be true with attempts == 2")
        }
    }

    self.runSuite("18. Zero Shell-Injection Process Gate & 500-Frame Telemetry State Machine Fuzzing") { h in
    // 16a. Scan all 21 production files to ensure Process never invokes a shell (/bin/sh, /bin/zsh, /bin/bash, -c)
    let forbiddenShellPatterns = ["/bin/sh", "/bin/bash", "/bin/zsh", "/usr/bin/env sh", "Darwin.system(", "popen("]
    let fm = FileManager.default
    let sourcesPath = KroutonTestHarness.repositoryRoot.appendingPathComponent("Sources").path
    var scannedFileCount = 0
    if let enumerator = fm.enumerator(atPath: sourcesPath) {
        while let rel = enumerator.nextObject() as? String {
            guard rel.hasSuffix(".swift"), !rel.contains("KroutonVerify/") else { continue }
            scannedFileCount += 1
            let content = (try? String(contentsOfFile: sourcesPath + "/" + rel, encoding: .utf8)) ?? ""
            for pat in forbiddenShellPatterns {
                h.lint(!content.contains(pat), "Forbidden shell pattern '\(pat)' found in \(rel)")
            }
        }
    }
    h.lint(scannedFileCount > 50, "Shell-pattern scan found no sources under \(sourcesPath)")

    // 16b. Fuzz SpoolTelemetrySanitizer with out-of-order packets, NaN, Infinity, and terminal-state regressions
    var state: SpoolTelemetryPhase = .preheating
    var frac: Double = 0.0
    var progressRegressed = false
    var staleFrameApplied = false
    var unsafeBufferValue = false
    let batchID = UUID()

    for step in 1...250 {
        let progress = Double(step) / 250.0
        let normalFrame = SpoolTelemetryPacket(
            batchId: batchID,
            driveId: "pioneer-01",
            state: .burningProgress,
            fraction: progress,
            currentLba: Int64(step * 100),
            totalLba: 25000,
            effectiveSpeedX: 16.0,
            fifoFill: 0.95,
            driveBufferFill: 0.92,
            c2Errors: 0,
            etaSeconds: 45
        )
        let res = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: normalFrame)
        if res.fraction < frac { progressRegressed = true }
        state = res.state
        frac = res.fraction

        // Inject a stale out-of-order frame with lower fraction + NaN buffer values
        let staleFuzzFrame = SpoolTelemetryPacket(
            batchId: batchID,
            driveId: "pioneer-01",
            state: .burningProgress,
            fraction: max(0.0, progress - 0.15),
            currentLba: 10,
            totalLba: 25000,
            effectiveSpeedX: .nan,
            fifoFill: .nan,
            driveBufferFill: .infinity,
            c2Errors: 0,
            etaSeconds: 99
        )
        let fuzzRes = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: staleFuzzFrame)
        if fuzzRes.fraction != frac { staleFrameApplied = true }
        if fuzzRes.fifoClamp != 0.0 || fuzzRes.driveClamp != 0.0 { unsafeBufferValue = true }
    }
    h.check(!progressRegressed, "Progress must never regress during active burn (250 frames)")
    h.check(!staleFrameApplied, "Stale out-of-order telemetry frames must be ignored (250 frames)")
    h.check(!unsafeBufferValue, "NaN/Infinity buffer fills must clamp safely to 0.0 (250 frames)")

    // Transition to terminal BURN_FAILED and verify late BURNING_PROGRESS cannot resurrect the job
    let failFrame = SpoolTelemetryPacket(
        batchId: batchID,
        driveId: "pioneer-01",
        state: .burnFailed,
        fraction: frac,
        currentLba: 12000,
        totalLba: 25000,
        effectiveSpeedX: 0.0,
        fifoFill: 0.0,
        driveBufferFill: 0.0,
        c2Errors: 99,
        etaSeconds: 0
    )
    let termRes = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: failFrame)
    state = termRes.state
    h.check(state == .burnFailed, "Must transition to terminal .burnFailed state")

    let zombieFrame = SpoolTelemetryPacket(
        batchId: batchID,
        driveId: "pioneer-01",
        state: .burningProgress,
        fraction: 0.99,
        currentLba: 24900,
        totalLba: 25000,
        effectiveSpeedX: 16.0,
        fifoFill: 1.0,
        driveBufferFill: 1.0,
        c2Errors: 0,
        etaSeconds: 1
    )
    let afterZombie = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: zombieFrame)
    h.check(afterZombie.state == .burnFailed, "Terminal state must reject late out-of-order progress frames")
    }
    }
}
