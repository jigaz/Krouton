import CryptoKit
@preconcurrency import DiscRecording
import Foundation
import OpticalCore
import os

// MARK: - Disc Image Burner
//
// Burns a finished disc image to one drive, then reads the disc back and compares
// it with the image. Every call takes a drive identifier and keeps its own state,
// so several drives can run at once: this is what BurnSetScheduler drives through
// BurnKit's `DiscRecordingOpticalDrive`.
//
// Failures are reported as `BurnFailure` (OpticalCore), the type the burn journal records.

/// A user-initiated stop. Cancelling a task only stops a drive from taking another
/// disc; this switch is what interrupts a disc that is already being written.
public final class KroutonBurnAbortSwitch: Sendable {
    private let requested = OSAllocatedUnfairLock(initialState: false)

    /// A switch that isn't requested.
    public init() {}

    var isRequested: Bool {
        requested.withLock { $0 }
    }

    /// Asks the burn to stop.
    public func request() {
        requested.withLock { $0 = true }
    }

    /// Clears the request, before the next disc.
    public func reset() {
        requested.withLock { $0 = false }
    }
}

/// A burner of this Mac, by the identifier the burn calls take.
public struct KroutonConnectedDrive: Sendable, Equatable {
    /// The drive's identifier (see `KroutonDriveIdentity`).
    public let id: String
    /// Vendor and model.
    public let displayName: String
}

/// The blank a drive found.
public struct KroutonBlankDiscInfo: Sendable, Equatable {
    /// "CD-R", "DVD+R DL", "BD-R", ... as reported for the disc in the tray.
    public let mediaType: String
    /// Free space reported by this disc, not taken from a capacity table.
    public let capacityBytes: Int64
}

/// Burns, verifies and ejects images on drives of this Mac, one call per drive (see the comment at
/// the top of this file).
@MainActor
public enum KroutonDiscImageBurner {
    static let pollSeconds = 0.4
    static let abortGraceSeconds: TimeInterval = 60
    static let remountWaitSeconds = 90

    /// The burners connected now.
    public static func connectedDrives() -> [KroutonConnectedDrive] {
        KroutonOpticalDriveBank.identifiedDevices().map { entry in
            let info = entry.device.info() as? [String: Any] ?? [:]
            let vendor = (info[DRDeviceVendorNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let product = (info[DRDeviceProductNameKey] as? String ?? "Optical Drive").trimmingCharacters(in: .whitespaces)
            let name = [vendor, product].filter { !$0.isEmpty }.joined(separator: " ")
            return KroutonConnectedDrive(id: entry.id, displayName: name)
        }
    }

    /// Waits until a blank disc is in the drive. A disc that is not blank is ejected and
    /// the wait continues. Ends with `.cancelledByUser` when the task is cancelled or the
    /// abort switch is thrown, and `.driveDisconnected` when the drive goes away.
    public static func waitForBlank(
        driveID: String,
        abort: KroutonBurnAbortSwitch,
        onStatus: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> KroutonBlankDiscInfo {
        var ejectedCurrentDisc = false
        while true {
            if Task.isCancelled || abort.isRequested { throw BurnFailure.cancelledByUser }
            let device = try device(for: driveID)
            if let media = presentMedia(in: device) {
                let mediaType = KroutonOpticalDriveBank.formatHumanMediaType(media[DRDeviceMediaTypeKey] as? String ?? "Disc")
                if (media[DRDeviceMediaIsBlankKey] as? Bool) ?? false {
                    let freeBlocks = (media[DRDeviceMediaBlocksFreeKey] as? NSNumber)?.int64Value ?? 0
                    return KroutonBlankDiscInfo(mediaType: mediaType, capacityBytes: freeBlocks * 2048)
                }
                if !ejectedCurrentDisc {
                    ejectedCurrentDisc = true
                    onStatus?("The \(mediaType) in this drive is not blank. Insert a blank disc.")
                    if !device.ejectMedia() { _ = device.openTray() }
                }
            } else {
                ejectedCurrentDisc = false
            }
            await pause(seconds: 1.0)
        }
    }

    /// Writes `imageURL` to the blank disc in the drive and closes it. Task cancellation
    /// does not interrupt a write in progress; only `abort` does.
    public static func burn(
        imageURL: URL,
        driveID: String,
        abort: KroutonBurnAbortSwitch,
        onPhase: @Sendable (BurnPhase) async -> Void
    ) async throws {
        let device = try device(for: driveID)
        guard let media = presentMedia(in: device), (media[DRDeviceMediaIsBlankKey] as? Bool) ?? false else {
            throw BurnFailure.mediaRejected(reason: "The disc was removed or is no longer blank.")
        }
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let layout = DRBurn.layout(forImageFile: imageURL.path) else {
            throw BurnFailure.writeError(sense: "DiscRecording cannot burn the image at \(imageURL.path).")
        }
        guard let burn = DRBurn(for: device) else { throw BurnFailure.driveDisconnected }

        var props = burn.properties() as? [String: Any] ?? [:]
        props[DRBurnTestingKey] = NSNumber(value: false)
        props[DRBurnVerifyDiscKey] = NSNumber(value: false)      // verified separately against the frozen image
        props[DRBurnOverwriteDiscKey] = NSNumber(value: false)   // blank media only
        props[DRBurnCompletionActionKey] = DRBurnCompletionActionMount // keep the disc in for read-back
        props[DRBurnRequestedSpeedKey] = NSNumber(value: Float(65535.0))
        burn.setProperties(props)

        device.acquireMediaReservation()
        defer { device.releaseMediaReservation() }
        burn.writeLayout(layout)

        var lastPhase: BurnPhase?
        var abortSentAt: Date?
        while true {
            await pause(seconds: pollSeconds)
            if abort.isRequested, abortSentAt == nil {
                burn.abort()
                abortSentAt = Date()
            }
            let status = burn.status() as? [String: Any] ?? [:]
            let state = status[DRStatusStateKey] as? String ?? ""

            if state == DRStatusStateDone {
                let reachedEnd = ((status[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0) >= 0.999
                if abortSentAt != nil && !reachedEnd { throw BurnFailure.cancelledByUser }
                return
            }
            if state == DRStatusStateFailed {
                if abortSentAt != nil { throw BurnFailure.cancelledByUser }
                if !KroutonOpticalDriveBank.identifiedDevices().contains(where: { $0.id == driveID }) {
                    throw BurnFailure.driveDisconnected
                }
                let errInfo = status[DRErrorStatusKey] as? [String: Any]
                let message = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware burn failed."
                let sense = errInfo?[DRErrorStatusAdditionalSenseStringKey] as? String ?? ""
                throw BurnFailure.writeError(sense: sense.isEmpty ? message : "\(message) (\(sense))")
            }
            if let sent = abortSentAt, Date().timeIntervalSince(sent) > abortGraceSeconds {
                throw BurnFailure.cancelledByUser
            }

            let closingStates = [DRStatusStateTrackClose, DRStatusStateSessionClose, DRStatusStateFinishing]
            let writingStates = [DRStatusStatePreparing, DRStatusStateSessionOpen, DRStatusStateTrackOpen, DRStatusStateTrackWrite]
            let phase: BurnPhase? = closingStates.contains(state) ? .closing : (writingStates.contains(state) ? .writing : nil)
            if let phase, phase != lastPhase {
                lastPhase = phase
                await onPhase(phase)
            }
        }
    }

    /// Reads the burned disc back from its raw device and compares it with the image.
    public static func verify(
        imageURL: URL,
        driveID: String,
        expectedSHA256: String,
        byteCount: Int64,
        abort: KroutonBurnAbortSwitch
    ) async throws {
        // After the burn the drive re-reads the disc; the device node appears a few seconds later.
        var bsdName: String?
        for _ in 0..<remountWaitSeconds {
            if abort.isRequested { throw BurnFailure.cancelledByUser }
            let device = try device(for: driveID)
            if let media = presentMedia(in: device),
               let name = media[DRDeviceMediaBSDNameKey] as? String, !name.isEmpty {
                bsdName = name
                break
            }
            await pause(seconds: 1.0)
        }
        guard let bsdName else {
            throw BurnFailure.writeError(sense: "The drive did not make the burned disc readable within \(remountWaitSeconds) seconds, so it was not verified.")
        }

        let deviceURL = URL(fileURLWithPath: "/dev/r\(bsdName)")
        try await Task.detached(priority: .userInitiated) {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: deviceURL,
                imageURL: imageURL,
                expectedSHA256: expectedSHA256,
                byteCount: byteCount,
                isCancelled: { abort.isRequested }
            )
        }.value
    }

    /// Ejects the disc, or opens the tray when there is none. Does nothing for a drive that is
    /// gone.
    public static func eject(driveID: String) {
        guard let device = try? device(for: driveID) else { return }
        if !device.ejectMedia() { _ = device.openTray() }
    }

    // MARK: - Helpers

    private static func device(for driveID: String) throws -> DRDevice {
        guard let match = KroutonOpticalDriveBank.identifiedDevices().first(where: { $0.id == driveID }) else {
            throw BurnFailure.driveDisconnected
        }
        return match.device
    }

    /// Media info when a disc is loaded and readable; nil when the tray is empty or still settling.
    private static func presentMedia(in device: DRDevice) -> [String: Any]? {
        let status = device.status() as? [String: Any] ?? [:]
        guard (status[DRDeviceMediaStateKey] as? String) == DRDeviceMediaStateMediaPresent else { return nil }
        return status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
    }

    /// A delay that task cancellation does not cut short, so a cancelled task that is
    /// waiting for the drive to stop does not spin.
    private static func pause(seconds: Double) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                continuation.resume()
            }
        }
    }
}
