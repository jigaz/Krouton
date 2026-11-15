import Foundation
import OpticalCore
import BurnKit
import DriveKit

// MARK: - KroutonStateStore Multi-Disc & Multi-Drive BurnSetScheduler Integration

@MainActor
extension KroutonStateStore {
    /// Partitions the current `stagedFiles` across one or more optical discs using `discCapacityBytes`
    /// (allowing 96% payload fill to reserve room for ISO-9660/Joliet/UDF descriptors and BagIt/SHA256 manifests).
    public func partitionStagedFilesForBurnSet(discCapacityBytes: Int64) -> [[StagedInputFile]] {
        let usableCapacity = max(64 * 1024, Int64(Double(max(1, discCapacityBytes)) * 0.96))
        var bins: [[StagedInputFile]] = []
        var currentBin: [StagedInputFile] = []
        var currentBytes: Int64 = 0

        for entry in stagedFiles {
            let item = StagedInputFile(sourceURL: entry.url, relativePathOnDisc: entry.name)
            let size = max(0, entry.byteSize)
            if !currentBin.isEmpty && (currentBytes + size > usableCapacity) {
                bins.append(currentBin)
                currentBin = [item]
                currentBytes = size
            } else {
                currentBin.append(item)
                currentBytes += size
            }
        }
        if !currentBin.isEmpty {
            bins.append(currentBin)
        }
        return bins
    }

    /// Freezes and stages the current workspace files into hybrid ISO-9660 + Joliet + UDF 1.02 disc images
    /// off the main actor, then orchestrates burning and `/dev/rdiskN` sector-by-sector readback verification
    /// across connected `DiscRecordingOpticalDrive` instances via `BurnSetScheduler`.
    @discardableResult
    public func executeVerifiedBurnSetWithScheduler(
        driveManager: KroutonOpticalDriveBank,
        targetDriveIDs: [String] = [],
        discCapacityBytes: Int64 = 4_700_372_992
    ) async -> Bool {
        guard !stagedFiles.isEmpty else { return false }

        let discBins = partitionStagedFilesForBurnSet(discCapacityBytes: discCapacityBytes)
        guard !discBins.isEmpty else { return false }

        let volumeTitleSnapshot = discVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "KROUTON_ARCHIVE"
            : discVolumeTitle

        driveManager.isExecutingQueue = true
        driveManager.activeJobProgress = 0.03
        driveManager.activeJobPhase = "Freezing & Mastering \(discBins.count) Hybrid Disc Image(s)..."
        driveManager.activeJobDetail = "\(volumeTitleSnapshot) • \(stagedFiles.count) items"

        let stageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonBurnSetStage", isDirectory: true)
        let setID = BurnSetID()

        let stagedResult: (burnSet: BurnSet, setIndex: SpanSetIndex)
        do {
            stagedResult = try await Task.detached(priority: .userInitiated) {
                try BurnSetStager.freezeAndStageSet(
                    setID: setID,
                    title: volumeTitleSnapshot,
                    discs: discBins,
                    stagingRootDirectory: stageRoot,
                    manifestMode: .rootSHA256Sums
                )
            }.value
        } catch {
            driveManager.isExecutingQueue = false
            driveManager.activeJobPhase = "Could Not Master Burn Set"
            let report = KroutonBurnSessionReport(
                isSuccess: false,
                title: "Could Not Freeze Burn Set",
                summary: error.localizedDescription,
                driveModel: "Krouton Hybrid Image Builder",
                firmwareRevision: "hdiutil makehybrid",
                mediaFormattedName: "Hybrid ISO/Joliet/UDF",
                volumeName: volumeTitleSnapshot,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Verify that all staged files exist and that the startup disk has enough free space."
            )
            driveManager.completionReport = report
            return false
        }

        let setDir = stageRoot.appendingPathComponent(setID.raw.uuidString, isDirectory: true)
        defer {
            Task.detached(priority: .utility) {
                try? FileManager.default.removeItem(at: setDir)
            }
        }

        if let firstDisc = stagedResult.burnSet.discs.first {
            burnQueueSubStore.lastMasteredISOURL = firstDisc.imageURL
            burnQueueSubStore.lastMasteredSHA256 = "sha256:" + firstDisc.imageSHA256
        }

        let allConnected = await DiscRecordingOpticalDrive.connectedDrives { [weak driveManager] statusMsg in
            driveManager?.activeJobPhase = statusMsg
        }
        let filteredDrives: [DiscRecordingOpticalDrive]
        if targetDriveIDs.isEmpty {
            filteredDrives = allConnected
        } else {
            let matches = allConnected.filter { targetDriveIDs.contains($0.id.raw) }
            filteredDrives = matches.isEmpty ? allConnected : matches
        }

        guard !filteredDrives.isEmpty else {
            driveManager.isExecutingQueue = false
            let report = KroutonBurnSessionReport(
                isSuccess: false,
                title: "No Optical Burner Connected",
                summary: "Mastered \(stagedResult.burnSet.discs.count) hybrid disc image(s), but no physical optical drive was found on the bus.",
                driveModel: "Optical Drive",
                firmwareRevision: "—",
                mediaFormattedName: "None",
                volumeName: volumeTitleSnapshot,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Connect a USB or SATA optical burner and retry."
            )
            driveManager.completionReport = report
            return false
        }

        let journal = BurnEventJournal(directory: setDir)
        do {
            try await journal.append(.setCreated(stagedResult.burnSet))
        } catch {
            driveManager.isExecutingQueue = false
            return false
        }

        let (replayedSets, _) = BurnSetProgress.replay(await journal.readAll())
        guard let initialProgress = replayedSets.first else {
            driveManager.isExecutingQueue = false
            return false
        }

        let scheduler = BurnSetScheduler(
            progress: initialProgress,
            drives: filteredDrives,
            journal: journal
        )

        let totalDiscs = max(1, stagedResult.burnSet.discs.count)
        let totalBytes = stagedResult.burnSet.discs.reduce(Int64(0)) { $0 + $1.imageBytes }
        let startTime = Date()

        let eventMonitor = Task { @MainActor in
            for await event in scheduler.events {
                switch event {
                case .waitingForBlank(let drive, let req):
                    driveManager.activeJobPhase = "Insert Blank Disc \(req.discIndex)/\(req.discCount) (\(req.volumeLabel)) into \(drive.raw)"
                case .discChanged(let job):
                    let completedDiscs = max(0, job.disc.index - 1)
                    let baseProgress = Double(completedDiscs) / Double(totalDiscs)
                    driveManager.activeJobDetail = "\(job.disc.volumeLabel) • Disc \(job.disc.index)/\(totalDiscs) (Attempt #\(max(1, job.attempts)))"
                    driveManager.activeJobProgress = min(0.98, max(0.05, baseProgress + (0.5 / Double(totalDiscs))))
                    driveManager.activeJobPhase = "Disc \(job.disc.index)/\(totalDiscs) (\(job.disc.volumeLabel)): \(job.state)"
                case .ejected(_, let discIndex, let volumeLabel, let succeeded):
                    driveManager.activeJobPhase = succeeded
                        ? "Ejected Verified Disc \(discIndex)/\(totalDiscs) (\(volumeLabel))"
                        : "Ejected Failed Disc \(discIndex)/\(totalDiscs) (\(volumeLabel))"
                case .finished:
                    break
                }
            }
        }

        let finalProgress = await scheduler.run()
        eventMonitor.cancel()

        let elapsed = max(1, Int(Date().timeIntervalSince(startTime)))
        let allSucceeded = finalProgress.isComplete
        driveManager.isExecutingQueue = false
        driveManager.activeJobProgress = allSucceeded ? 1.0 : driveManager.activeJobProgress
        driveManager.activeJobPhase = allSucceeded
            ? "Burn Set Verified (\(totalDiscs)/\(totalDiscs) Disc(s))"
            : "Burn Set Incomplete (\(finalProgress.remaining.count) Disc(s) Remaining)"

        let report = KroutonBurnSessionReport(
            isSuccess: allSucceeded,
            title: allSucceeded ? "Spanned Burn Set Verified" : "Burn Set Finished With Failures",
            summary: allSucceeded
                ? "Mastered, burned, and sector-verified \(totalDiscs) hybrid disc(s) across \(filteredDrives.count) optical drive(s)."
                : "\(totalDiscs - finalProgress.remaining.count) of \(totalDiscs) disc(s) passed raw sector read-back verification.",
            driveModel: filteredDrives.map(\.displayName).joined(separator: ", "),
            firmwareRevision: "UDF 1.02 + Raw Readback",
            mediaFormattedName: "Hybrid ISO / Joliet / UDF",
            volumeName: volumeTitleSnapshot,
            sectorsWrittenLBA: totalBytes / 2048,
            bytesWritten: totalBytes,
            averageSpeedText: "Hardware Managed",
            peakSpeedText: "Hardware Managed",
            elapsedDurationText: String(format: "%02d:%02d", elapsed / 60, elapsed % 60),
            diagnosticAdvice: allSucceeded
                ? "Every disc in the set matched its frozen SHA-256 image sector-for-sector via /dev/rdiskN."
                : "Retry the remaining disc indices with blank media."
        )
        driveManager.completionReport = report
        return allSucceeded
    }
}
