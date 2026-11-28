import AudioKit
import BurnKit
import DriveKit
import Foundation
import OpticalCore
import SwiftUI

// MARK: - Automatic Right-Column Destination Rack & Waiting Burn Pool Synchronization

@MainActor
extension KroutonStateStore {

    /// Computes the active spanning disc count & resolved per-disc volume labels across
    /// Audio CD (`audioController.discPlan`) and all staged file/media workspaces (`dataDiscPlan`).
    func activeSpannedDiscLabels() -> [String] {
        guard selectedCategory == .burn else { return [] }
        let spec = activeFormatSpec()
        if spec.filterGroup == .audio && spec.id != "mp3-cd" {
            let plan = audioController.project.discPlan()
            let total = max(1, plan.discs.count)
            return (1...total).map { dNum in
                let custom = plan.discs.first(where: { $0.number == dNum })?.metadata.volumeLabel
                return DiscSpanningEngine.resolvedDiscVolumeLabel(
                    baseTitle: discVolumeTitle,
                    customTitle: custom,
                    discNumber: dNum,
                    totalDiscs: total,
                    fallback: "AUDIO_CD"
                )
            }
        }
        let plan = dataDiscPlan(forFormatID: spec.id)
        let total = max(1, plan.discs.count)
        let fallback = (selectedFormatID == .dvdVideo) ? "DVD_VIDEO" : "KROUTON_DISC"
        return (1...total).map { dNum in
            DiscSpanningEngine.resolvedDiscVolumeLabel(
                baseTitle: discVolumeTitle,
                customTitle: dataDiscVolumeOverrides[dNum],
                discNumber: dNum,
                totalDiscs: total,
                fallback: fallback
            )
        }
    }

    /// Per-disc byte estimates for the active single-disc or multi-disc plan.
    func activeSpannedDiscByteEstimates() -> [Int64] {
        guard selectedCategory == .burn else { return [max(0, totalStagedBytes)] }
        let spec = activeFormatSpec()
        if spec.filterGroup == .audio && spec.id != "mp3-cd" {
            let plan = audioController.project.discPlan()
            if plan.discs.isEmpty { return [0] }
            return plan.discs.map { Int64($0.usedFrames) * 2352 }
        }
        let plan = dataDiscPlan(forFormatID: spec.id)
        if plan.discs.isEmpty { return [max(0, totalStagedBytes)] }
        return plan.discs.map { $0.usedUnits }
    }

    /// Synchronizes the Right Destination Rack Column:
    /// - If physical burners are present in `destinationQueue`, keeps the physical burner drive slots
    ///   in the upper active zone (sorted fastest-first) and populates `waitingBurnPool` (the lower
    ///   secondary-tinted waiting zone) with all remaining copies (`Copy 2..20`) or spanned discs (`Disc 2..7`).
    /// - If only `.discImage` cards are used, synchronizes one `.discImage` card per spanned disc.
    func syncSpannedDestinations(driveManager: KroutonOpticalDriveBank) {
        guard selectedCategory == .burn || selectedCategory == .depot || selectedCategory == .copy else {
            waitingBurnPool.removeAll()
            return
        }
        let labels = activeSpannedDiscLabels()
        let requiredDiscs = max(1, labels.count)
        let baseTarget = defaultDiscImageTarget
        let ext = (baseTarget.path as NSString).pathExtension

        func sanitizedFileStem(_ raw: String) -> String {
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
            return cleaned.isEmpty ? "KROUTON_DISC" : cleaned
        }

        let hasPhysicalBurnerInQueue = destinationQueue.contains { $0.kind == .physicalBurner }

        if hasPhysicalBurnerInQueue {
            // Remove any legacy auto-spawned .discImage cards that were previously created as overflow for spanned discs
            if requiredDiscs > 1 {
                destinationQueue.removeAll { item in
                    item.kind == .discImage && (item.spannedDiscNumber ?? 0) > 1
                }
            }
            syncBurnPoolTickets(driveManager: driveManager)
            savedQueuesByDomain[currentDestinationDomainKey] = destinationQueue
            return
        }

        // Pure .discImage queue mode: 1 .discImage card per spanned disc
        waitingBurnPool.removeAll()
        destinationQueue.removeAll { item in
            if let dNum = item.spannedDiscNumber, dNum > requiredDiscs { return true }
            return false
        }

        if !destinationQueue.isEmpty {
            if requiredDiscs > 1 {
                if destinationQueue[0].spannedDiscNumber == nil {
                    destinationQueue[0].spannedDiscNumber = 1
                }
            } else if destinationQueue[0].spannedDiscNumber == 1 {
                destinationQueue[0].spannedDiscNumber = nil
            }
        }

        if requiredDiscs > 1 {
            for dNum in 2...requiredDiscs {
                if !destinationQueue.contains(where: { $0.spannedDiscNumber == dNum }) {
                    let stem = sanitizedFileStem(labels[dNum - 1])
                    destinationQueue.append(
                        KroutonBakeBatchItem(
                            kind: .discImage,
                            targetDriveID: "",
                            hardwareOrPath: "~/Desktop/\(stem).\(ext)",
                            speedOrCodec: baseTarget.description,
                            simulationMode: false,
                            verifyAfterBurn: true,
                            compressAfterCreation: false,
                            spannedDiscNumber: dNum
                        )
                    )
                }
            }
        }

        for idx in destinationQueue.indices {
            let dNum = destinationQueue[idx].spannedDiscNumber ?? (idx == 0 ? 1 : nil)
            if destinationQueue[idx].kind == .discImage, let dNum, dNum >= 1, dNum <= labels.count {
                let currentPath = destinationQueue[idx].hardwareOrPath
                let dir = (currentPath as NSString).deletingLastPathComponent
                let baseDir = dir.isEmpty ? "~/Desktop" : dir
                let stem = sanitizedFileStem(labels[dNum - 1])
                destinationQueue[idx].hardwareOrPath = "\(baseDir)/\(stem).\(ext)"
                destinationQueue[idx].speedOrCodec = baseTarget.description
            }
        }

        destinationQueue.sort { lhs, rhs in
            switch (lhs.spannedDiscNumber, rhs.spannedDiscNumber) {
            case let (a?, b?): return a < b
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
        savedQueuesByDomain[currentDestinationDomainKey] = destinationQueue
    }

    // MARK: - Multi-Burner Pool & Lower Waiting Queue Management

    /// Synchronizes the upper assigned physical burner slots and the lower `waitingBurnPool`
    /// based on spanned disc count, requested copy count, and connected burner write speeds.
    func syncBurnPoolTickets(driveManager: KroutonOpticalDriveBank) {
        let burnerIndices = destinationQueue.indices.filter { destinationQueue[$0].kind == .physicalBurner }
        guard !burnerIndices.isEmpty else {
            waitingBurnPool.removeAll()
            return
        }

        // Determine total copies from the maximum copiesToBurn across burner cards or poolTotalCopies
        let maxCardCopies = burnerIndices.map { destinationQueue[$0].copiesToBurn }.max() ?? 1
        let effectiveCopies = max(poolTotalCopies, maxCardCopies)
        if poolTotalCopies != effectiveCopies {
            poolTotalCopies = effectiveCopies
        }

        // Sort physical burner cards in fastest-drive-first order (e.g. 24x -> 10x -> 4x)
        let speedByDriveID: [String: Double] = Dictionary(
            uniqueKeysWithValues: driveManager.availableDrives.map { ($0.id, $0.parsedMaxWriteSpeedX) }
        )
        destinationQueue.sort { lhs, rhs in
            if lhs.kind == .physicalBurner && rhs.kind == .physicalBurner {
                let spdL = speedByDriveID[lhs.targetDriveID] ?? 16.0
                let spdR = speedByDriveID[rhs.targetDriveID] ?? 16.0
                if abs(spdL - spdR) > 0.001 { return spdL > spdR }
            }
            return false
        }

        let labels = activeSpannedDiscLabels()
        let resolvedLabels = labels.isEmpty
            ? [discVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "KROUTON_DISC" : discVolumeTitle]
            : labels
        let byteEstimates = activeSpannedDiscByteEstimates()

        let allTickets = KroutonDrivePoolState.buildTickets(
            spannedVolumeLabels: resolvedLabels,
            perDiscBytes: byteEstimates,
            totalCopies: effectiveCopies
        )

        withBurnPool { $0.fill(with: allTickets) }
    }

    /// Updates the total copy count for the pool and immediately rebuilds the upper assigned slots & lower waiting tasks.
    func setPoolTotalCopies(_ copies: Int, driveManager: KroutonOpticalDriveBank) {
        let clamped = max(1, min(99, copies))
        poolTotalCopies = clamped
        for idx in destinationQueue.indices where destinationQueue[idx].kind == .physicalBurner {
            destinationQueue[idx].copiesToBurn = clamped
        }
        syncBurnPoolTickets(driveManager: driveManager)
    }

    /// Adds all connected physical optical drives into the upper active pool, sorted fastest-first (e.g. 24x, 10x, 4x).
    func poolAllConnectedBurners(driveManager: KroutonOpticalDriveBank) {
        let sortedDrives = driveManager.availableDrives.sorted { $0.parsedMaxWriteSpeedX > $1.parsedMaxWriteSpeedX }
        guard !sortedDrives.isEmpty else { return }
        let usedIDs = Set(destinationQueue.filter { $0.kind == .physicalBurner }.map(\.targetDriveID))
        for drv in sortedDrives where !usedIDs.contains(drv.id) {
            destinationQueue.append(
                KroutonBakeBatchItem(
                    kind: .physicalBurner,
                    targetDriveID: drv.id,
                    hardwareOrPath: drv.displayName,
                    speedOrCodec: "Max Safe (Auto)",
                    simulationMode: false,
                    verifyAfterBurn: true,
                    compressAfterCreation: false,
                    copiesToBurn: poolTotalCopies
                )
            )
        }
        reconcileUniqueDriveAssignments(driveManager: driveManager)
        syncBurnPoolTickets(driveManager: driveManager)
    }

    /// Moves a waiting ticket onto a burner card (or the first idle one when `targetCardID` is
    /// nil); whatever that card held goes back to the waiting tickets.
    func promoteWaitingTicket(_ ticketID: UUID, toCardID targetCardID: UUID? = nil, driveManager: KroutonOpticalDriveBank) {
        withBurnPool { $0.promote(ticketID, toCardID: targetCardID) }
    }

    /// Moves a burner card's tickets back to the waiting tickets.
    func demoteAssignedTicketToWaitingPool(fromCardID cardID: UUID) {
        withBurnPool { $0.demote(cardID: cardID) }
    }

    /// A burner card finished its ticket; it gets the next one (pending approval with Ask / Manual).
    @discardableResult
    func advancePoolAfterCardBurnCompleted(cardID: UUID) -> KroutonPoolBurnTicket? {
        withBurnPool { $0.advanceAfterBurn(cardID: cardID, mode: self.poolDispatchMode) }
    }

    /// Approves the pending ticket on a burner card.
    func approvePendingTicketOnCard(_ cardID: UUID) {
        withBurnPool { $0.approvePending(cardID: cardID) }
    }

    /// Skips this burner for its pending ticket, which goes back to the waiting tickets.
    func skipDriveForPendingTicket(onCardID cardID: UUID) {
        withBurnPool { $0.skipPending(cardID: cardID) }
    }

    /// Runs `body` on the burn pool (the queue's cards, the waiting tickets and the finished
    /// count) and keeps what it changed.
    @discardableResult
    func withBurnPool<Result>(_ body: (inout KroutonBurnQueuePool<KroutonBakeBatchItem>) -> Result) -> Result {
        var pool = KroutonBurnQueuePool(cards: destinationQueue, waiting: waitingBurnPool,
                                        completedTicketCount: completedPoolTicketCount)
        let result = body(&pool)
        if pool.cards != destinationQueue { destinationQueue = pool.cards }
        if pool.waiting != waitingBurnPool { waitingBurnPool = pool.waiting }
        if pool.completedTicketCount != completedPoolTicketCount { completedPoolTicketCount = pool.completedTicketCount }
        return result
    }
}
