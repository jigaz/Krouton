import DriveKit
import Foundation
import Observation
import OpticalCore

// MARK: - Burn Coordinator

/// Every burn on a drive of this Mac starts here. Krouton burns in two ways:
///
/// - **The destination queue**: one disc at a time through `KroutonOpticalDriveBank`, which
///   writes data discs, disc images, audio CDs, CD-Extra and DiscJuggler images, with copies
///   and a pool of burner cards (`KroutonBurnQueuePool`).
/// - **A multi-disc set**: frozen disc images on every connected burner at once through
///   `BurnSetScheduler`, journalled so a set can be resumed.
///
/// The coordinator makes sure only one of them has the drives at a time (each used to start
/// whatever the other was doing), runs the queue's burns, and decides what follows a burn: the
/// next pool ticket, the next copy, or nothing. The hardware calls themselves are unchanged.
@Observable
@MainActor
public final class KroutonBurnCoordinator {
    public static let shared = KroutonBurnCoordinator()

    /// Drives of the queue burning right now, by drive key.
    public private(set) var queueBurnsInFlight: Set<String> = []
    /// The title of the multi-disc set that has the drives, if one does.
    public private(set) var runningSetTitle: String?

    public init() {}

    public var isQueueBurning: Bool { !queueBurnsInFlight.isEmpty }
    public var isSetRunning: Bool { runningSetTitle != nil }

    // MARK: - Multi-Disc Sets

    /// Claims the drives for a set. Returns why not when the queue is burning, or when the drive
    /// bank is busy with something else (an erase, a rip, a sector copy).
    public func beginSet(title: String, driveBankIsBusy: Bool) -> String? {
        if isQueueBurning {
            return "A burn from the destination queue is still running. Wait for it to finish, or abort it, then burn the set."
        }
        if driveBankIsBusy {
            return "A drive is busy erasing, ripping or copying a disc. Wait for it to finish, then burn the set."
        }
        if let runningSetTitle {
            return "The set \(runningSetTitle) is still burning."
        }
        runningSetTitle = title
        return nil
    }

    public func endSet() {
        runningSetTitle = nil
    }

    // MARK: - Queue Burns

    /// Burns on a drive of this Mac through the drive bank, and returns its report. Refused,
    /// with a report saying so, while a multi-disc set has the drives.
    public func burnOnThisMac(_ request: KroutonLocalBurnRequest, bank: KroutonOpticalDriveBank) async -> KroutonBurnSessionReport {
        if let runningSetTitle {
            let report = Self.refusal(
                title: "Burners in Use",
                summary: "The multi-disc set \(runningSetTitle) is burning on this Mac's drives.",
                advice: "Wait for the set to finish, or stop it, before burning from the queue.",
                volume: request.volumeTitle)
            bank.completionReport = report
            return report
        }
        let key = request.driveID ?? bank.selectedDrive?.id ?? ""
        queueBurnsInFlight.insert(key)
        defer { queueBurnsInFlight.remove(key) }
        return await withCheckedContinuation { (continuation: CheckedContinuation<KroutonBurnSessionReport, Never>) in
            bank.startPhysicalDataBurn(
                driveID: request.driveID,
                stagedFiles: request.stagedFiles,
                volumeTitle: request.volumeTitle,
                requestedSpeedLabel: request.speedLabel,
                simulationMode: request.simulationMode,
                verifyDisc: request.verifyDisc,
                allowOverwriteOfWrittenMedia: request.allowOverwriteOfWrittenMedia,
                leaveDiscOpen: request.leaveDiscOpen,
                audioDisc: request.audioDisc,
                isoLevel1: request.isoLevel1
            ) { report in
                continuation.resume(returning: report)
            }
        }
    }

    // MARK: - After a Burn

    /// What follows a burner card's burn: with a pool, the card's next ticket; with copies, the
    /// next copy; with Auto-Load, waiting for the next blank in the same drive. Updates `pool`
    /// (the card's ticket and finished copies) and returns the step to take.
    ///
    /// - Parameter card: the card as it was when its burn started.
    public static func stepAfterBurn<Card: KroutonPoolSlotCard>(
        of card: Card,
        copiesToBurn: Int,
        succeeded: Bool,
        pool: inout KroutonBurnQueuePool<Card>,
        mode: KroutonPoolDispatchMode,
        autoLoadNextDisc: Bool
    ) -> KroutonAfterBurnStep {
        guard succeeded else { return .finished }
        if !pool.waiting.isEmpty || card.assignedPoolTicket != nil {
            let next = pool.advanceAfterBurn(cardID: card.id, mode: mode)
            if let next, mode == .autoAssign, autoLoadNextDisc {
                return .waitForNextBlank(completedCopy: max(1, next.sequenceNumber - 1),
                                         totalCopies: max(next.totalCopies, next.totalSpannedDiscs))
            }
            return .finished
        }
        guard copiesToBurn > 1, autoLoadNextDisc else { return .finished }
        let finishedCount = card.completedCopies + 1
        guard let index = pool.cards.firstIndex(where: { $0.id == card.id }) else { return .finished }
        if finishedCount < copiesToBurn {
            pool.cards[index].completedCopies = finishedCount
            return .waitForNextBlank(completedCopy: finishedCount, totalCopies: copiesToBurn)
        }
        pool.cards[index].completedCopies = 0
        return .finished
    }

    // MARK: - Reports

    static func refusal(title: String, summary: String, advice: String, volume: String) -> KroutonBurnSessionReport {
        KroutonBurnSessionReport(
            isSuccess: false, title: title, summary: summary, driveModel: "—", firmwareRevision: "—",
            mediaFormattedName: "—", volumeName: volume, sectorsWrittenLBA: 0, bytesWritten: 0,
            averageSpeedText: "—", peakSpeedText: "—", elapsedDurationText: "00:00", diagnosticAdvice: advice)
    }
}

// MARK: - Requests & Steps

/// One burn from the destination queue on a drive of this Mac.
public struct KroutonLocalBurnRequest: Sendable {
    public var driveID: String?
    public var stagedFiles: [KroutonStagedFileEntry]
    public var volumeTitle: String
    public var speedLabel: String
    public var simulationMode: Bool
    public var verifyDisc: Bool
    /// True only when a person started this burn; an automatic next copy never erases a disc.
    public var allowOverwriteOfWrittenMedia: Bool
    public var leaveDiscOpen: Bool
    public var audioDisc: KroutonAudioBurnDisc?
    public var isoLevel1: Bool

    public init(driveID: String?, stagedFiles: [KroutonStagedFileEntry], volumeTitle: String, speedLabel: String,
                simulationMode: Bool, verifyDisc: Bool, allowOverwriteOfWrittenMedia: Bool, leaveDiscOpen: Bool,
                audioDisc: KroutonAudioBurnDisc?, isoLevel1: Bool) {
        self.driveID = driveID
        self.stagedFiles = stagedFiles
        self.volumeTitle = volumeTitle
        self.speedLabel = speedLabel
        self.simulationMode = simulationMode
        self.verifyDisc = verifyDisc
        self.allowOverwriteOfWrittenMedia = allowOverwriteOfWrittenMedia
        self.leaveDiscOpen = leaveDiscOpen
        self.audioDisc = audioDisc
        self.isoLevel1 = isoLevel1
    }
}

/// What a burner card does after its burn.
public enum KroutonAfterBurnStep: Equatable, Sendable {
    /// Nothing more for this card now.
    case finished
    /// Eject, wait for the next blank in the same drive, then burn this card again.
    case waitForNextBlank(completedCopy: Int, totalCopies: Int)
}
