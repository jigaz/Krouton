@preconcurrency import DiscRecording
import Foundation
import OpticalCore

// MARK: - Physical burn lifecycle
//
// One `KroutonActiveBurnSession` owns everything a burn acquires: the media
// reservation, the temporary stage directory, the DRBurn, and the completion
// handler. Every way a burn can end (success, drive failure, staging failure,
// user abort) goes through `finishBurnSession`, which releases all of it and
// calls the completion handler exactly once.

struct KroutonBurnJobContext {
    let driveKey: String
    let driveName: String
    let firmware: String
    let mediaType: String
    let isErasable: Bool
    let volumeTitle: String
    let itemCount: Int
    let totalBytes: Int64
    let totalLBA: Int64
    let requestedSpeedLabel: String
    let simulationMode: Bool
    let verifyDisc: Bool
    let overwriteExistingData: Bool
    /// Leave the disc open for later sessions (DRBurnAppendableKey), as Puppy Linux multisession needs.
    var leaveDiscOpen: Bool = false
    /// Set when the one staged item is a disc image: it is burned as an image, sector for sector,
    /// instead of being copied onto a data disc as a file.
    var imageFileURL: URL? = nil

    /// KB/s at 1x for this media family.
    var speedDivisor: Double {
        mediaType.contains("BD") ? 4500.0 : (mediaType.contains("DVD") ? 1385.0 : 176.4)
    }
    var laserText: String {
        mediaType.contains("BD") ? "405 nm Violet (BD)" : (mediaType.contains("DVD") ? "650 nm Red (DVD)" : "780 nm IR (CD)")
    }
    var strategyText: String {
        isErasable ? "Phase-Change CLV/Z-CLV" : "Organic Dye P-CAV"
    }
}

@MainActor
final class KroutonActiveBurnSession {
    let context: KroutonBurnJobContext
    let device: DRDevice
    let stageURL: URL
    var burn: DRBurn?
    var stagingTask: Task<Void, Never>?
    var abortRequestedAt: Date?
    var speedSumX: Double = 0.0
    var speedSampleCount: Int = 0
    var completion: (@MainActor (KroutonBurnSessionReport) -> Void)?

    init(
        context: KroutonBurnJobContext,
        device: DRDevice,
        stageURL: URL,
        completion: @escaping @MainActor (KroutonBurnSessionReport) -> Void
    ) {
        self.context = context
        self.device = device
        self.stageURL = stageURL
        self.completion = completion
    }
}
