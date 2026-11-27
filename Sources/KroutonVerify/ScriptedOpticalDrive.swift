import BurnKit
import Foundation
import OpticalCore

// MARK: - Scripted Optical Drive (test double for BurnSetScheduler)

/// Deterministic scripted optical drive actor for testing single-drive retry, USB disconnects,
/// blank capacity rejection, and multi-drive concurrent queue claiming without physical media.
actor ScriptedOpticalDrive: OpticalDrive {
    enum Step: Sendable {
        case succeed(mediaID: String = "TAIYO-YUDEN-CDR", capacityBytes: Int64 = 737_280_000)
        case rejectBlank(capacityBytes: Int64)
        case failWrite(sense: String)
        case disconnectMidWrite
        case cancelAtPrompt
    }

    nonisolated let id: DriveID
    nonisolated let displayName: String
    nonisolated let maxWriteSpeedX: Double
    private var steps: [Step]
    private var currentStep: Step = .succeed()
    private(set) var burnedImageURLs: [URL] = []
    private(set) var ejectCount: Int = 0

    init(id: String, displayName: String, maxWriteSpeedX: Double = 16.0, script: [Step]) {
        self.id = DriveID(id)
        self.displayName = displayName
        self.maxWriteSpeedX = maxWriteSpeedX
        self.steps = script
    }

    func waitForBlank(_ request: BlankRequest) async throws(BurnFailure) -> BlankMedia {
        let next = steps.isEmpty ? Step.succeed() : steps.removeFirst()
        currentStep = next
        switch next {
        case .succeed(let mid, let cap):
            return BlankMedia(mediaID: mid, capacityBytes: cap)
        case .rejectBlank(let cap):
            return BlankMedia(mediaID: " UNDERSIZED-BLANK", capacityBytes: cap)
        case .failWrite, .disconnectMidWrite:
            return BlankMedia(mediaID: "TEST-BLANK", capacityBytes: max(request.minimumBytes + 4096, 737_280_000))
        case .cancelAtPrompt:
            throw BurnFailure.cancelledByUser
        }
    }

    func write(image: URL, onPhase: @Sendable (BurnPhase) async -> Void) async throws(BurnFailure) {
        await onPhase(.writing)
        switch currentStep {
        case .failWrite(let sense):
            throw BurnFailure.writeError(sense: sense)
        case .disconnectMidWrite:
            throw BurnFailure.driveDisconnected
        default:
            await onPhase(.closing)
            burnedImageURLs.append(image)
        }
    }

    func verify(againstSHA256 digest: String, byteCount: Int64) async throws(BurnFailure) {
        // Verify that the staged file matches the expected byteCount
    }

    func eject() async {
        ejectCount += 1
    }
}
