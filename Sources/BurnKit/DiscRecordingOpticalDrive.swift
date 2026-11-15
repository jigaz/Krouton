import DriveKit
import Foundation
import OpticalCore

// The real drive behind BurnSetScheduler. It contains no DiscRecording calls of its
// own: DriveKit's KroutonDiscImageBurner does the hardware work, so DriveKit stays
// the only module that imports DiscRecording.
//
// Using it:
//
//   let drives = await DiscRecordingOpticalDrive.connectedDrives()
//   let (sets, _) = BurnSetProgress.replay(await journal.readAll())
//   let scheduler = BurnSetScheduler(progress: sets[0], drives: drives, journal: journal)
//   let run = Task { await scheduler.run() }
//   for await event in scheduler.events { model.handle(event) }   // on the main actor
//
//   run.cancel()                                   // finish the discs being written, take no more
//   for drive in drives { drive.abortCurrentDisc() } // stop now; discs being written are spoiled

public actor DiscRecordingOpticalDrive: OpticalDrive {
    public nonisolated let id: DriveID
    public nonisolated let displayName: String
    private nonisolated let abortSwitch = KroutonBurnAbortSwitch()
    private let onStatus: (@MainActor @Sendable (DriveID, String) -> Void)?
    private var imageBeingBurned: URL?

    /// - Parameter onStatus: short messages for one drive's blank-disc prompt, such as
    ///   "The DVD-RW in this drive is not blank."
    public init(
        driveID: String,
        displayName: String,
        onStatus: (@MainActor @Sendable (DriveID, String) -> Void)? = nil
    ) {
        self.id = DriveID(driveID)
        self.displayName = displayName
        self.onStatus = onStatus
    }

    /// One drive per connected burner. Two identical burners get distinct identifiers.
    public static func connectedDrives(
        onStatus: (@MainActor @Sendable (DriveID, String) -> Void)? = nil
    ) async -> [DiscRecordingOpticalDrive] {
        await KroutonDiscImageBurner.connectedDrives().map {
            DiscRecordingOpticalDrive(driveID: $0.id, displayName: $0.displayName, onStatus: onStatus)
        }
    }

    /// Stops this drive's current disc: dismisses a blank-disc prompt, or aborts a write
    /// or verification in progress. A disc that was being written is spoiled.
    public nonisolated func abortCurrentDisc() {
        abortSwitch.request()
    }

    public func waitForBlank(_ request: BlankRequest) async throws(BurnFailure) -> BlankMedia {
        abortSwitch.reset()
        imageBeingBurned = nil
        let driveID = id
        let forward: (@MainActor @Sendable (String) -> Void)?
        if let report = onStatus {
            forward = { message in report(driveID, message) }
        } else {
            forward = nil
        }
        do {
            let disc = try await KroutonDiscImageBurner.waitForBlank(driveID: id.raw, abort: abortSwitch, onStatus: forward)
            // DiscRecording does not expose the manufacturer ID, so the journal records the media type.
            return BlankMedia(mediaID: disc.mediaType, capacityBytes: disc.capacityBytes)
        } catch {
            throw Self.burnFailure(from: error)
        }
    }

    public func write(image: URL, onPhase: @Sendable (BurnPhase) async -> Void) async throws(BurnFailure) {
        imageBeingBurned = image
        do {
            try await KroutonDiscImageBurner.burn(imageURL: image, driveID: id.raw, abort: abortSwitch, onPhase: onPhase)
        } catch {
            throw Self.burnFailure(from: error)
        }
    }

    public func verify(againstSHA256 digest: String, byteCount: Int64) async throws(BurnFailure) {
        guard let image = imageBeingBurned else {
            throw BurnFailure.writeError(sense: "verify was called before write.")
        }
        do {
            try await KroutonDiscImageBurner.verify(
                imageURL: image, driveID: id.raw, expectedSHA256: digest, byteCount: byteCount, abort: abortSwitch
            )
        } catch {
            throw Self.burnFailure(from: error)
        }
    }

    public func eject() async {
        await KroutonDiscImageBurner.eject(driveID: id.raw)
    }

    private static func burnFailure(from error: any Error) -> BurnFailure {
        if let failure = error as? BurnFailure { return failure }
        if error is CancellationError { return .cancelledByUser }
        return .writeError(sense: error.localizedDescription)
    }
}
