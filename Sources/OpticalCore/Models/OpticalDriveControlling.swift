import Foundation
import os

/// Strongly-typed optical media classification replacing ad-hoc `.contains("DVD")` string checks.
public enum OpticalMediaKind: String, Codable, Sendable, CaseIterable {
    case cd = "CD-ROM / CD-R"
    case dvdSingleLayer = "DVD-5 (4.7 GB)"
    case dvdDualLayer = "DVD-9 Dual-Layer (8.54 GB)"
    case bluRaySingleLayer = "BD-25 Single-Layer (25 GB)"
    case bluRayDualLayer = "BD-50 Dual-Layer (50 GB)"
    case unknown = "Unclassified Optical Media"

    public init(mediaDescription: String) {
        let upper = mediaDescription.uppercased()
        if upper.contains("BD-50") || upper.contains("BD-R DL") || upper.contains("DUAL LAYER BD") {
            self = .bluRayDualLayer
        } else if upper.contains("BD") || upper.contains("BLU-RAY") {
            self = .bluRaySingleLayer
        } else if upper.contains("DVD-9") || upper.contains("DVD+R DL") || upper.contains("DVD-R DL") || upper.contains("8.5") {
            self = .dvdDualLayer
        } else if upper.contains("DVD") {
            self = .dvdSingleLayer
        } else if upper.contains("CD") {
            self = .cd
        } else {
            self = .unknown
        }
    }

    var nominalCapacityBytes: Int64 {
        switch self {
        case .cd:                return 737_280_000
        case .dvdSingleLayer:    return 4_700_372_992
        case .dvdDualLayer:       return 8_543_666_176
        case .bluRaySingleLayer: return 25_025_314_816
        case .bluRayDualLayer:   return 50_050_629_632
        case .unknown:           return 4_700_372_992
        }
    }

    var isDVDClass: Bool {
        self == .dvdSingleLayer || self == .dvdDualLayer
    }

    var isBluRayClass: Bool {
        self == .bluRaySingleLayer || self == .bluRayDualLayer
    }
}

/// Centralized `os.Logger` diagnostics for hardware, filesystem, and network operations.
public enum KroutonDiagnostics {
    static let hardwareLogger = Logger(subsystem: "app.krouton.optical", category: "HardwareDrive")
    public static let masteringLogger = Logger(subsystem: "app.krouton.optical", category: "MasteringEngine")
    public static let networkLogger = Logger(subsystem: "app.krouton.optical", category: "NetworkSpool")
}

/// Protocol abstracting physical optical drive state so domain logic and unit tests
/// can inject a fake/mock drive without coupling to `@Published` UI banner properties.
@MainActor
public protocol OpticalDriveControlling: AnyObject {
    var availableDrives: [KroutonOpticalDriveInfo] { get }
    var mediaKind: OpticalMediaKind { get }
}
