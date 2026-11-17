import Foundation
import IOKit.pwr_mgt
import OSLog

/// Prevents macOS system idle sleep, display sleep, App Nap, and Sudden Termination
/// while a physical optical burn, disc image master, or extraction is actively running.
final class KroutonPowerAndBurnAssertion: @unchecked Sendable {
    static let shared = KroutonPowerAndBurnAssertion()

    static let logger = Logger(subsystem: "com.krouton.opticalstudio", category: "HardwareBurnGuard")
    static let signposter = OSSignposter(logger: logger)

    private let lock = NSLock()
    private var systemSleepAssertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var displaySleepAssertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var processActivityToken: NSObjectProtocol? = nil
    private var signpostState: OSSignpostIntervalState? = nil
    private var isHeld: Bool = false

    private init() {}

    /// Acquires IOKit power assertions + ProcessInfo activity lock for an active optical job.
    func acquire(reason: String = "Krouton Optical Laser Mastering Active") {
        lock.lock()
        defer { lock.unlock() }
        guard !isHeld else { return }

        var sysID = IOPMAssertionID(0)
        let sysRet = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &sysID
        )
        if sysRet == kIOReturnSuccess {
            systemSleepAssertionID = sysID
        }

        var dispID = IOPMAssertionID(0)
        let dispRet = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &dispID
        )
        if dispRet == kIOReturnSuccess {
            displaySleepAssertionID = dispID
        }

        processActivityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .idleDisplaySleepDisabled, .suddenTerminationDisabled],
            reason: reason
        )

        let spID = Self.signposter.makeSignpostID()
        signpostState = Self.signposter.beginInterval("OpticalMasteringJob", id: spID, "\(reason, privacy: .public)")
        Self.logger.notice("Acquired IOKit sleep assertion (sys=\(sysID), disp=\(dispID)) for: \(reason, privacy: .public)")
        isHeld = true
    }

    /// Releases IOKit power assertions and restores normal macOS power management.
    func releaseAssertion() {
        lock.lock()
        defer { lock.unlock() }
        guard isHeld else { return }

        if systemSleepAssertionID != 0 {
            IOPMAssertionRelease(systemSleepAssertionID)
            systemSleepAssertionID = 0
        }
        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
            displaySleepAssertionID = 0
        }
        if let token = processActivityToken {
            ProcessInfo.processInfo.endActivity(token)
            processActivityToken = nil
        }
        if let st = signpostState {
            Self.signposter.endInterval("OpticalMasteringJob", st)
            signpostState = nil
        }
        Self.logger.notice("Released IOKit sleep assertion; normal system sleep restored.")
        isHeld = false
    }

    deinit {
        releaseAssertion()
    }
}
