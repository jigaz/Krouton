import Foundation
import os

/// The kind of disc in a drive, by capacity class. The raw values are display names.
public enum OpticalMediaKind: String, Codable, Sendable, CaseIterable {
    case cd = "CD-ROM / CD-R"
    case dvdSingleLayer = "DVD-5 (4.7 GB)"
    case dvdDualLayer = "DVD-9 Dual-Layer (8.54 GB)"
    case bluRaySingleLayer = "BD-25 Single-Layer (25 GB)"
    case bluRayDualLayer = "BD-50 Dual-Layer (50 GB)"
    case unknown = "Unclassified Optical Media"

    /// Classifies a drive's free-text media description (for example "DVD+R DL") by keyword.
    /// Anything it does not recognize is `.unknown`.
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
}

/// Shared `os.Logger` instances.
public enum KroutonDiagnostics {
    /// Logs mastering work under the `app.krouton.optical` subsystem.
    public static let masteringLogger = Logger(subsystem: "app.krouton.optical", category: "MasteringEngine")
}

/// The drive state domain logic reads, so tests can pass a fake drive instead of the real
/// drive bank.
@MainActor
public protocol OpticalDriveControlling: AnyObject {
    /// The drives connected now.
    var availableDrives: [KroutonOpticalDriveInfo] { get }
    /// The kind of disc in the first connected drive.
    var mediaKind: OpticalMediaKind { get }
}
