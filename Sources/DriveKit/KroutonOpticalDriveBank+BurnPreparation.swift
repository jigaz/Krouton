import Foundation
import OpticalCore

// MARK: - Preparing a Burn, and Abort

@MainActor
extension KroutonOpticalDriveBank {
    /// Abort: asks the drive to stop a burn, says that an erase can't be interrupted, or marks
    /// the bank idle. Each call is counted in `abortRequestCount`, so work that runs in steps (Run
    /// All over the destination queue, a burn whose disc image is still being built) sees an
    /// abort that came between its steps, when there was nothing for the drive to stop.
    public func abortActiveBurn() {
        abortRequestCount += 1
        stopActiveOperation()
    }

    /// Shows the bank as busy while the app builds what a burn will write (a disc image, an
    /// audio CD's tracks), which can take many minutes: the burn button offers Abort, the Mac
    /// stays awake and a multi-disc set can't take the drives meanwhile. Pair it with
    /// `endPreparingBurn(since:)`.
    /// - Returns: the abort count now. Once `abortRequestCount` differs, Abort was chosen.
    public func beginPreparingBurn(_ phase: String) -> Int {
        preparingBurnCount += 1
        isExecutingQueue = true
        activeJobPhase = phase
        activeJobDetail = ""
        activeJobProgress = 0
        return abortRequestCount
    }

    /// Ends `beginPreparingBurn`. The bank stays busy while a burn, an erase or another
    /// preparation runs; after an abort the phase keeps saying so.
    public func endPreparingBurn(since abortCount: Int) {
        preparingBurnCount = max(0, preparingBurnCount - 1)
        guard preparingBurnCount == 0, activeBurnSession == nil, activeEraseSession == nil else { return }
        isExecutingQueue = false
        if abortRequestCount == abortCount {
            activeJobPhase = "Idle"
            activeJobProgress = 0
        }
    }
}
