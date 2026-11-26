import Foundation
import IOKit.pwr_mgt
import OSLog
import OpticalCore
import os

/// Prevents macOS system idle sleep, display sleep, App Nap, and Sudden Termination
/// while a physical optical burn, disc image master, or extraction is actively running.
final class KroutonPowerAndBurnAssertion: Sendable {
    static let shared = KroutonPowerAndBurnAssertion()

    static let logger = Logger(subsystem: KroutonDomainIdentity.Module.kroutonApp.subsystem, category: "HardwareBurnGuard")
    static let signposter = OSSignposter(logger: logger)

    private struct AssertionState {
        var systemSleepAssertionID: IOPMAssertionID = IOPMAssertionID(0)
        var displaySleepAssertionID: IOPMAssertionID = IOPMAssertionID(0)
        var processActivityToken: NSObjectProtocol? = nil
        var signpostState: OSSignpostIntervalState? = nil
        var isHeld: Bool = false
    }

    private let stateLock = OSAllocatedUnfairLock(uncheckedState: AssertionState())

    private init() {}

    /// Acquires IOKit power assertions + ProcessInfo activity lock for an active optical job.
    func acquire(reason: String = "Krouton Optical Laser Mastering Active") {
        stateLock.withLockUnchecked { st in
            guard !st.isHeld else { return }

            var sysID = IOPMAssertionID(0)
            let sysRet = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &sysID
            )
            if sysRet == kIOReturnSuccess {
                st.systemSleepAssertionID = sysID
            }

            var dispID = IOPMAssertionID(0)
            let dispRet = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &dispID
            )
            if dispRet == kIOReturnSuccess {
                st.displaySleepAssertionID = dispID
            }

            st.processActivityToken = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled, .idleDisplaySleepDisabled, .suddenTerminationDisabled],
                reason: reason
            )

            let spID = Self.signposter.makeSignpostID()
            st.signpostState = Self.signposter.beginInterval("OpticalMasteringJob", id: spID, "\(reason, privacy: .public)")
            Self.logger.notice("Acquired IOKit sleep assertion (sys=\(sysID), disp=\(dispID)) for: \(reason, privacy: .public)")
            st.isHeld = true
        }
    }

    /// Releases IOKit power assertions and restores normal macOS power management.
    func releaseAssertion() {
        stateLock.withLockUnchecked { st in
            guard st.isHeld else { return }

            if st.systemSleepAssertionID != 0 {
                IOPMAssertionRelease(st.systemSleepAssertionID)
                st.systemSleepAssertionID = 0
            }
            if st.displaySleepAssertionID != 0 {
                IOPMAssertionRelease(st.displaySleepAssertionID)
                st.displaySleepAssertionID = 0
            }
            if let token = st.processActivityToken {
                ProcessInfo.processInfo.endActivity(token)
                st.processActivityToken = nil
            }
            if let spState = st.signpostState {
                Self.signposter.endInterval("OpticalMasteringJob", spState)
                st.signpostState = nil
            }
            Self.logger.notice("Released IOKit sleep assertion; normal system sleep restored.")
            st.isHeld = false
        }
    }

    deinit {
        releaseAssertion()
    }
}
