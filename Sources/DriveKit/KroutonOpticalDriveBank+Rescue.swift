@preconcurrency import DiscRecording
import Foundation
import OpticalCore

// MARK: - KroutonOpticalDriveBank Rescue Access

@MainActor
extension KroutonOpticalDriveBank {
    /// Opens a drive for sector-by-sector reading: unmounts its disc, then takes exclusive access
    /// through IOKit's MMC interface. Close the session when done, then eject the disc.
    public func openDriveForRescue(driveID: String?) async throws(MMCTransportError) -> KroutonMMCDeviceSession {
        guard let device = resolveDRDevice(id: driveID ?? selectedDrive?.id ?? "") else {
            throw .unavailable("The drive is not connected")
        }
        let info = device.info() as? [String: Any] ?? [:]
        let vendor = (info[DRDeviceVendorNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let product = (info[DRDeviceProductNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let status = device.status() as? [String: Any] ?? [:]
        guard (status[DRDeviceMediaStateKey] as? String) == DRDeviceMediaStateMediaPresent else {
            throw .unavailable("There's no disc in \(product.isEmpty ? "the drive" : product)")
        }
        let media = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        if let bsdName = media[DRDeviceMediaBSDNameKey] as? String, !bsdName.isEmpty {
            try await KroutonDiskArbitration.unmount(bsdName: bsdName)
        }
        let drives = KroutonMMCDirectAccess.authoringDrives()
        let match = drives.first { $0.vendor == vendor && $0.product == product } ?? (drives.count == 1 ? drives.first : nil)
        guard let match else {
            throw .unavailable("Couldn't find \(product.isEmpty ? "the drive" : product) for direct access")
        }
        return try KroutonMMCDeviceSession(registryID: match.id)
    }
}
