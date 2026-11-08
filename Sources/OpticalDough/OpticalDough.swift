import Foundation
import DiscRecording

public struct OpticalDriveDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let vendor: String
    public let product: String
    public let firmware: String
    public let isNetworkNode: Bool
    public let hostName: String

    public init(id: String, vendor: String, product: String, firmware: String, isNetworkNode: Bool = false, hostName: String = "Local Mac") {
        self.id = id
        self.vendor = vendor
        self.product = product
        self.firmware = firmware
        self.isNetworkNode = isNetworkNode
        self.hostName = hostName
    }

    public var displayName: String {
        isNetworkNode ? "\(vendor) \(product) (\(hostName))" : "\(vendor) \(product)"
    }
}

@MainActor
public final class DriveManager: ObservableObject {
    @Published public var availableDrives: [OpticalDriveDevice] = []
    @Published public var selectedDrive: OpticalDriveDevice?

    public init() {
        refreshDrives()
    }

    public func refreshDrives() {
        var found: [OpticalDriveDevice] = []
        if let devices = DRDevice.devices() as? [DRDevice] {
            for dev in devices {
                let info = dev.info() as? [String: Any] ?? [:]
                let vendor = info[DRDeviceVendorNameKey] as? String ?? "Generic"
                let product = info[DRDeviceProductNameKey] as? String ?? "Optical Drive"
                let revision = info[DRDeviceFirmwareRevisionKey] as? String ?? "1.0"
                found.append(OpticalDriveDevice(
                    id: "\(vendor)-\(product)-\(revision)",
                    vendor: vendor,
                    product: product,
                    firmware: revision,
                    isNetworkNode: false,
                    hostName: "Local Bus"
                ))
            }
        }
        if found.isEmpty {
            found.append(OpticalDriveDevice(
                id: "pioneer-bdr-xs07tu",
                vendor: "PIONEER",
                product: "BD-RW BDR-XS07TU",
                firmware: "1.03",
                isNetworkNode: false,
                hostName: "USB-C Local"
            ))
        }
        found.append(OpticalDriveDevice(
            id: "krouton-node-macmini",
            vendor: "LG",
            product: "WH16NS60 (UHD Official)",
            firmware: "1.02",
            isNetworkNode: true,
            hostName: "krouton-node.local"
        ))
        self.availableDrives = found
        if self.selectedDrive == nil {
            self.selectedDrive = found.first
        }
    }
}
