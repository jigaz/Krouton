import Foundation
import OpticalDough

public enum KroutonVideoTargetMedium: String, Codable, Sendable, CaseIterable {
    case dvd5SingleLayer = "DVD-5 (4.7 GB SL)"
    case dvd9DualLayer   = "DVD-9 (8.5 GB DL)"
    case bd25SingleLayer = "BD-25 (25 GB SL)"
    case bd50DualLayer   = "BD-50 (50 GB DL)"

    /// Exact physical 2048-byte user data sectors per ECMA-267 / Blu-ray White Paper
    public var totalSectorsLBA: Int64 {
        switch self {
        case .dvd5SingleLayer: return 2_295_104
        case .dvd9DualLayer:   return 4_173_824
        case .bd25SingleLayer: return 12_219_392
        case .bd50DualLayer:   return 24_438_784
        }
    }

    public var capacityBytes: Int64 {
        totalSectorsLBA * 2048
    }

    /// Spec-mandated maximum elementary video stream bitrate in kbps
    public var maxSpecVideoKbps: Int {
        switch self {
        case .dvd5SingleLayer, .dvd9DualLayer: return 9_800
        case .bd25SingleLayer, .bd50DualLayer: return 40_000
        }
    }

    /// Spec-mandated VBV buffer size in kilobits (DVD = 1,835 kb, BD = 30,000 kb)
    public var vbvBufferKilobits: Int {
        switch self {
        case .dvd5SingleLayer, .dvd9DualLayer: return 1_835
        case .bd25SingleLayer, .bd50DualLayer: return 30_000
        }
    }
}

public struct KroutonVideoBitrateBudget: Sendable, Equatable {
    public let medium: KroutonVideoTargetMedium
    public let totalDurationSeconds: Double
    public let audioBitrateKbps: Int
    public let usableVideoBytes: Int64
    public let targetVideoKbps: Int
    public let maxHardwareCeilingKbps: Int
    public let vbvBufferKilobits: Int
    public let isSpecCompliant: Bool
    public let estimatedDiscFillRatio: Double
}

public struct KroutonDVD9ShrinkPlan: Sendable, Equatable {
    public let sourceMainFeatureBytes: Int64
    public let sourceMenusAndExtrasBytes: Int64
    public let preserveMenusAndExtras: Bool
    public let targetUsableDVD5Bytes: Int64
    public let requantizationRatio: Double // 1.0 = untouched passthrough, <1.0 = DCT requant shrink
    public let requiresRequantization: Bool
    public let estimatedOutputBytes: Int64
}

public struct KroutonVideoOvenModule {
    public static let version = "0.1.0-alpha.1"

    /// Computes exact video kbps budget for a given program duration, audio stream bitrate, and optical medium
    public static func computeBitrateBudget(
        durationSeconds: Double,
        audioKbps: Int = 448, // Standard Dolby Digital 5.1 AC-3 @ 448 kbps
        medium: KroutonVideoTargetMedium = .dvd5SingleLayer
    ) -> KroutonVideoBitrateBudget {
        let clampedDuration = max(1.0, durationSeconds)
        let rawCap = Double(medium.capacityBytes)
        // Reserve 6.5% for UDF 1.02/2.50 bridge + VOB/M2TS packet nav-pack mux overhead
        let usableTotalBytes = rawCap * 0.935
        let audioTotalBytes = (Double(max(64, audioKbps)) * 1000.0 / 8.0) * clampedDuration
        let availableForVideoBytes = max(0.0, usableTotalBytes - audioTotalBytes)

        let rawVideoKbps = Int(((availableForVideoBytes * 8.0) / clampedDuration) / 1000.0)
        let clampedKbps = max(1_000, min(medium.maxSpecVideoKbps, rawVideoKbps))

        let actualVideoBytes = (Double(clampedKbps) * 1000.0 / 8.0) * clampedDuration
        let totalUsed = (actualVideoBytes + audioTotalBytes) / 0.935
        let fillRatio = min(1.0, max(0.0, totalUsed / rawCap))

        return KroutonVideoBitrateBudget(
            medium: medium,
            totalDurationSeconds: clampedDuration,
            audioBitrateKbps: audioKbps,
            usableVideoBytes: Int64(availableForVideoBytes),
            targetVideoKbps: clampedKbps,
            maxHardwareCeilingKbps: medium.maxSpecVideoKbps,
            vbvBufferKilobits: medium.vbvBufferKilobits,
            isSpecCompliant: availableForVideoBytes > 0 && clampedKbps >= 1_500,
            estimatedDiscFillRatio: fillRatio
        )
    }

    /// Plans a Toast-style DVD-9 (8.5 GB Dual Layer) -> DVD-5 (4.7 GB Single Layer) Requiem DCT requantization
    public static func planDVD9ToDVD5Shrink(
        mainFeatureBytes: Int64,
        menusAndExtrasBytes: Int64,
        preserveMenusAndExtras: Bool
    ) -> KroutonDVD9ShrinkPlan {
        // Reserve 1.5% safety margin inside 4,700,372,992 B DVD-5 limit for IFO/BUP VTS sector padding
        let dvd5Usable = Int64(Double(KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes) * 0.985)
        let includedExtras = preserveMenusAndExtras ? max(0, menusAndExtrasBytes) : 0
        let totalSource = max(1, mainFeatureBytes + includedExtras)

        if totalSource <= dvd5Usable {
            return KroutonDVD9ShrinkPlan(
                sourceMainFeatureBytes: mainFeatureBytes,
                sourceMenusAndExtrasBytes: menusAndExtrasBytes,
                preserveMenusAndExtras: preserveMenusAndExtras,
                targetUsableDVD5Bytes: dvd5Usable,
                requantizationRatio: 1.0,
                requiresRequantization: false,
                estimatedOutputBytes: totalSource
            )
        }

        // Menus stay at 90% fidelity; main feature absorbs the remainder of the DCT shrink
        let shrunkExtras = Int64(Double(includedExtras) * 0.90)
        let budgetForMain = max(1, dvd5Usable - shrunkExtras)
        let ratio = min(1.0, max(0.35, Double(budgetForMain) / Double(max(1, mainFeatureBytes))))
        let finalBytes = Int64(Double(mainFeatureBytes) * ratio) + shrunkExtras

        return KroutonDVD9ShrinkPlan(
            sourceMainFeatureBytes: mainFeatureBytes,
            sourceMenusAndExtrasBytes: menusAndExtrasBytes,
            preserveMenusAndExtras: preserveMenusAndExtras,
            targetUsableDVD5Bytes: dvd5Usable,
            requantizationRatio: ratio,
            requiresRequantization: true,
            estimatedOutputBytes: min(dvd5Usable, finalBytes)
        )
    }
}
