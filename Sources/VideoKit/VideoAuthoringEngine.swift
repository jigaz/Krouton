import Foundation

// MARK: - Video Bitrate Budgets

/// The video disc sizes bitrate budgets are worked out for. The raw values are display names.
public enum KroutonVideoTargetMedium: String, Codable, Sendable, CaseIterable {
    case dvd5SingleLayer = "DVD-5 (4.7 GB SL)"
    case dvd9DualLayer   = "DVD-9 (8.5 GB DL)"
    case bd25SingleLayer = "BD-25 (25 GB SL)"
    case bd50DualLayer   = "BD-50 (50 GB DL)"

    /// User data sectors (2,048 bytes) on the medium: ECMA-267 figures for DVD, the Blu-ray
    /// Disc Association's for BD.
    public var totalSectorsLBA: Int64 {
        switch self {
        case .dvd5SingleLayer: return 2_295_104
        case .dvd9DualLayer:   return 4_173_824
        case .bd25SingleLayer: return 12_219_392
        case .bd50DualLayer:   return 24_438_784
        }
    }

    /// `totalSectorsLBA` in bytes.
    public var capacityBytes: Int64 {
        totalSectorsLBA * 2048
    }

    /// The highest video bitrate the format allows, in kbps (DVD-Video 9,800, BD 40,000).
    var maxSpecVideoKbps: Int {
        switch self {
        case .dvd5SingleLayer, .dvd9DualLayer: return 9_800
        case .bd25SingleLayer, .bd50DualLayer: return 40_000
        }
    }

    /// The decoder buffer size in kilobits (DVD 1,835, BD 30,000).
    public var vbvBufferKilobits: Int {
        switch self {
        case .dvd5SingleLayer, .dvd9DualLayer: return 1_835
        case .bd25SingleLayer, .bd50DualLayer: return 30_000
        }
    }
}

/// The result of `computeBitrateBudget`.
public struct KroutonVideoBitrateBudget: Sendable, Equatable {
    /// The disc it is for.
    public let medium: KroutonVideoTargetMedium
    let totalDurationSeconds: Double
    /// The audio bitrate assumed.
    public let audioBitrateKbps: Int
    /// Bytes left for video after overhead and audio.
    public let usableVideoBytes: Int64
    /// The video bitrate to encode at.
    public let targetVideoKbps: Int
    /// The format's highest video bitrate.
    public let maxHardwareCeilingKbps: Int
    /// The format's decoder buffer size.
    public let vbvBufferKilobits: Int
    /// True when the video gets at least 1,500 kbps. Nothing else is checked.
    public let isSpecCompliant: Bool
    /// How full the disc would be, 0 to 1.
    public let estimatedDiscFillRatio: Double
}

/// The result of `planDVD9ToDVD5Shrink`.
public struct KroutonDVD9ShrinkPlan: Sendable, Equatable {
    let sourceMainFeatureBytes: Int64
    /// The menus and extras' size.
    public let sourceMenusAndExtrasBytes: Int64
    /// Whether menus and extras are kept.
    public let preserveMenusAndExtras: Bool
    /// The DVD-5 space the plan aims for (98.5 % of the disc).
    public let targetUsableDVD5Bytes: Int64
    /// The share of the main feature's size to keep: 1 copies it untouched, below 1 requantizes.
    public let requantizationRatio: Double
    /// True when the video must shrink.
    public let requiresRequantization: Bool
    /// The expected size after the shrink.
    public let estimatedOutputBytes: Int64
}

/// Bitrate budgets and DVD-9 to DVD-5 shrinking for video discs.
public struct KroutonVideoAuthoringEngine {
    /// The module version krouton-verify checks.
    public static let version = "0.1.0-alpha.1"

    /// The video bitrate that fills `medium` for a program of `durationSeconds` with `audioKbps`
    /// of audio, keeping 6.5 % for file system and multiplexing overhead, clamped to 1,000 kbps and
    /// the format's ceiling.
    public static func computeBitrateBudget(
        durationSeconds: Double,
        audioKbps: Int = 448, // Dolby Digital 5.1 at 448 kbps
        medium: KroutonVideoTargetMedium = .dvd5SingleLayer
    ) -> KroutonVideoBitrateBudget {
        let clampedDuration = max(1.0, durationSeconds)
        let rawCap = Double(medium.capacityBytes)
        // Keep 6.5 % for the file system and multiplexing overhead.
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

    /// How much a DVD-9 must shrink to fit a DVD-5: if everything fits in 98.5 % of a DVD-5 it is
    /// copied as is; otherwise menus and extras are budgeted at 90 % and the main feature gets the
    /// rest, kept at no less than 35 %.
    public static func planDVD9ToDVD5Shrink(
        mainFeatureBytes: Int64,
        menusAndExtrasBytes: Int64,
        preserveMenusAndExtras: Bool
    ) -> KroutonDVD9ShrinkPlan {
        // Keep 1.5 % of the DVD-5 for IFO and BUP padding.
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

        // Menus and extras are budgeted at 90 %; the main feature takes the rest of the shrink.
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

// MARK: - DVD-9 to DVD-5 Shrink Estimate

/// One cell of a DVD-9's main feature, as the shrink estimate takes it.
public struct KroutonDVD9CellDescriptor: Sendable, Equatable, Identifiable {
    public var id: Int { cellID }
    /// The cell's number.
    public let cellID: Int
    /// Its first sector on the DVD-9.
    public let originalStartSectorLBA: Int64
    /// Its length in sectors.
    public let originalSectorCountLBA: Int64
    /// True on the cell where the DVD-9's layer break was.
    public let hadDualLayerBreakPause: Bool

    public init(cellID: Int, originalStartSectorLBA: Int64, originalSectorCountLBA: Int64, hadDualLayerBreakPause: Bool = false) {
        self.cellID = cellID
        self.originalStartSectorLBA = max(0, originalStartSectorLBA)
        self.originalSectorCountLBA = max(1, originalSectorCountLBA)
        self.hadDualLayerBreakPause = hadDualLayerBreakPause
    }
}

/// One cell's place after the estimated shrink.
public struct KroutonShrunkDVD5CellEntry: Sendable, Equatable, Identifiable {
    public var id: Int { cellID }
    /// The cell's number.
    public let cellID: Int
    /// Its first sector after the shrink, counted from the start of the title VOBs.
    public let relinkedStartSectorLBA: Int64
    /// Its last sector after the shrink.
    public let relinkedEndSectorLBA: Int64
    let shrunkSectorCountLBA: Int64
    /// Always true in the estimate: a single-layer disc has no layer break.
    public let seamlessPlaybackFlagSet: Bool
}

/// The result of `buildDVD9ToDVD5MenuShrinkBlueprint`: an estimate, for display.
public struct KroutonDVD9MenuShrinkBlueprint: Sendable, Equatable {
    /// The source's size.
    public let originalTotalBytes: Int64
    /// The estimated size after the shrink.
    public let shrunkTotalBytes: Int64
    /// True when the estimate fits a DVD-5.
    public let fitsStrictlyOnDVD5: Bool
    /// The share of the menu VOB's size budgeted: 1 when nothing shrinks, 0.9 when it does, 0
    /// without menus.
    public let menuVobRetentionRatio: Double
    /// The main feature's requantization ratio, from `planDVD9ToDVD5Shrink`.
    let mainFeatureDCTRatio: Double
    /// Always true in the estimate; nothing here checks the navigation packs.
    public let navPacksAndButtonHighlightsIntact: Bool
    /// Padding sectors so the IFO and BUP are at least one 32 KiB ECC block apart.
    let ifoBup32KECCPaddingSectors: Int64
    /// True when a source cell had the layer break.
    public let layerBreakPauseRemoved: Bool
    /// Each cell's estimated new range.
    public let relinkedCells: [KroutonShrunkDVD5CellEntry]
}

extension KroutonVideoAuthoringEngine {
    /// One DVD ECC block: 16 sectors, 32 KiB.
    static let dvdECCBlockSectors: Int64 = 16

    /// An estimate of a menu-preserving shrink, for the shrink popover: each cell's new sector
    /// range after requantization, the menu budget, and the total size. Nothing is read or
    /// written; the real shrink is `executeDVD9ToDVD5ShrinkOnDisk`.
    public static func buildDVD9ToDVD5MenuShrinkBlueprint(
        ifoTableBytes: Int64 = 65_536,
        menuVobBytes: Int64,
        preserveMenus: Bool = true,
        sourceCells: [KroutonDVD9CellDescriptor]
    ) -> KroutonDVD9MenuShrinkBlueprint {
        let sourceMainSectors = sourceCells.reduce(Int64(0)) { $0 + $1.originalSectorCountLBA }
        let sourceMainBytes = sourceMainSectors * 2048
        let corePlan = planDVD9ToDVD5Shrink(
            mainFeatureBytes: sourceMainBytes,
            menusAndExtrasBytes: menuVobBytes,
            preserveMenusAndExtras: preserveMenus
        )

        let menuRetention = preserveMenus ? (corePlan.requiresRequantization ? 0.90 : 1.0) : 0.0
        let shrunkMenuSectors = Int64((Double((menuVobBytes + 2047) / 2048) * menuRetention).rounded())

        // Each cell's new sector range, one after another.
        var relinked: [KroutonShrunkDVD5CellEntry] = []
        var cellCursorLBA: Int64 = 0
        var clearedLayerBreak = false

        for cell in sourceCells {
            let scaledSectors = max(1, Int64((Double(cell.originalSectorCountLBA) * corePlan.requantizationRatio).rounded(.down)))
            let startLBA = cellCursorLBA
            let endLBA = startLBA + scaledSectors - 1
            if cell.hadDualLayerBreakPause {
                clearedLayerBreak = true
            }
            relinked.append(
                KroutonShrunkDVD5CellEntry(
                    cellID: cell.cellID,
                    relinkedStartSectorLBA: startLBA,
                    relinkedEndSectorLBA: endLBA,
                    shrunkSectorCountLBA: scaledSectors,
                    seamlessPlaybackFlagSet: true
                )
            )
            cellCursorLBA += scaledSectors
        }

        let totalPayloadSectors = shrunkMenuSectors + cellCursorLBA
        // Keep the IFO and the BUP at least one ECC block (16 sectors) apart.
        let eccPadSectors = max(0, dvdECCBlockSectors - totalPayloadSectors)
        let ifoSectors = max(1, (ifoTableBytes + 2047) / 2048)
        let totalDiscSectors = 288 + (ifoSectors * 2) + totalPayloadSectors + eccPadSectors
        let totalShrunkBytes = totalDiscSectors * 2048

        return KroutonDVD9MenuShrinkBlueprint(
            originalTotalBytes: sourceMainBytes + menuVobBytes + (ifoTableBytes * 2),
            shrunkTotalBytes: totalShrunkBytes,
            fitsStrictlyOnDVD5: totalShrunkBytes <= KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes,
            menuVobRetentionRatio: menuRetention,
            mainFeatureDCTRatio: corePlan.requantizationRatio,
            navPacksAndButtonHighlightsIntact: true,
            ifoBup32KECCPaddingSectors: eccPadSectors,
            layerBreakPauseRemoved: clearedLayerBreak,
            relinkedCells: relinked
        )
    }
}
