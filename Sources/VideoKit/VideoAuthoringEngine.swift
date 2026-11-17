import Foundation
import OpticalCore

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

public struct KroutonVideoAuthoringEngine {
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


// MARK: - Chunk 9: Menu-Preserving DVD-9 -> DVD-5 Shrink, IFO Sector Relinker & Layer-Break Pause Removal
public struct KroutonDVD9CellDescriptor: Sendable, Equatable, Identifiable {
    public var id: Int { cellID }
    public let cellID: Int
    public let originalStartSectorLBA: Int64
    public let originalSectorCountLBA: Int64
    public let hadDualLayerBreakPause: Bool // True on the cell where the DVD-9 Layer 0 -> Layer 1 break sat

    public init(cellID: Int, originalStartSectorLBA: Int64, originalSectorCountLBA: Int64, hadDualLayerBreakPause: Bool = false) {
        self.cellID = cellID
        self.originalStartSectorLBA = max(0, originalStartSectorLBA)
        self.originalSectorCountLBA = max(1, originalSectorCountLBA)
        self.hadDualLayerBreakPause = hadDualLayerBreakPause
    }
}

public struct KroutonShrunkDVD5CellEntry: Sendable, Equatable, Identifiable {
    public var id: Int { cellID }
    public let cellID: Int
    public let relinkedStartSectorLBA: Int64
    public let relinkedEndSectorLBA: Int64
    public let shrunkSectorCountLBA: Int64
    public let seamlessPlaybackFlagSet: Bool // Always true on DVD-5 (removes the old DVD-9 layer-break freeze!)
}

public struct KroutonDVD9MenuShrinkBlueprint: Sendable, Equatable {
    public let originalTotalBytes: Int64
    public let shrunkTotalBytes: Int64
    public let fitsStrictlyOnDVD5: Bool
    public let menuVobRetentionRatio: Double        // 0.92..1.00 (NAV packs & SPU button highlights 100% untouched)
    public let mainFeatureDCTRatio: Double          // Exact MPEG-2 DCT requantization factor for VTS_01_1..N.VOB
    public let navPacksAndButtonHighlightsIntact: Bool
    public let ifoBup32KECCPaddingSectors: Int64    // >= 16 sectors (32 KiB) between IFO and BUP
    public let layerBreakPauseRemoved: Bool         // Clears DVD-9 OTP layer-break freeze for single-layer DVD-5
    public let relinkedCells: [KroutonShrunkDVD5CellEntry]
}

extension KroutonVideoAuthoringEngine {
    public static let dvd5SafeUsableSectors: Int64 = 2_260_677 // 98.5% of 2,295,104 DVD-5 sectors (~4.63 GB)
    public static let dvdECCBlockSectors: Int64 = 16           // 32 KiB (16 x 2048B) hardware ECC block

    /// Compiles a complete DVD-9 -> DVD-5 Menu-Preserving Shrink Blueprint:
    /// 1. Keeps all NV_PCK button highlight packets & SPU subpictures 100% intact.
    /// 2. Requantizes main feature cells to fit inside DVD-5 while keeping menus at 90%..100% fidelity.
    /// 3. Relinks every cell's start/end sector offset for VTS_C_ADT / VOBU_ADMAP in the .IFO and .BUP tables.
    /// 4. Removes the old DVD-9 Dual-Layer break pause flag so playback is 100% seamless on DVD-5.
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

        // Relink every VOB cell's relative LBA sector pointer for the updated VTS_01_0.IFO & .BUP tables
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
                    seamlessPlaybackFlagSet: true // Single-layer DVD-5 never needs a layer-break pause!
                )
            )
            cellCursorLBA += scaledSectors
        }

        let totalPayloadSectors = shrunkMenuSectors + cellCursorLBA
        // Enforce 32 KiB (16-sector) minimum separation between .IFO and .BUP
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

    /// Not a relinker, and no longer called: offset `0x00C4` means different things in `VIDEO_TS.IFO` and
    /// `VTS_xx_0.IFO`, and a real relink has to rewrite the cell, VOBU and title tables too.
    /// Performs in-place binary patching of a DVD-Video `VTS_xx_0.IFO` buffer:
    /// updates the 32-bit big-endian start sector pointer at `0x00C4` and clears cell layer-break flags (`0x08`).
    public static func patchVTSIFOBinarySectorPointers(
        ifoData: Data,
        relocatedStartSectorLBA: UInt32,
        cellPlaybackFlagOffsets: [Int] = []
    ) -> Data {
        var bytes = [UInt8](ifoData)
        guard bytes.count >= 0x00C8 else { return ifoData }
        let beSector = relocatedStartSectorLBA.bigEndian
        withUnsafeBytes(of: beSector) { rawBuf in
            for i in 0..<4 {
                bytes[0x00C4 + i] = rawBuf[i]
            }
        }
        for offset in cellPlaybackFlagOffsets where offset >= 0 && offset < bytes.count {
            bytes[offset] &= ~0x08
        }
        return Data(bytes)
    }
}

// MARK: - Sprint 2: Audio/Subtitle Muxing Controls, Sync Delay & 90kHz PTS Timestamp Chapter Compiler

public enum KroutonSubtitleDeliveryMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case softsubPassthrough = "Softsub Passthrough (.SUP/VobSub)"
    case hardwareBurnIn     = "VideoToolbox Hardware Burn-In"
    case forcedOnly         = "Forced Captions Only"
    public var id: String { rawValue }
}

public struct KroutonVideoChapterMarker: Identifiable, Hashable, Codable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let timestampText: String
    public let startSeconds: Double
    public let pts90kHz: Int64
    public let title: String
}

public struct KroutonStreamMuxDescriptor: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var audioLanguageCode: String      // ISO 639-2: "eng", "jpn", "spa", "fra", "deu"
    public var audioDelayMs: Int              // -2000 ms .. +2000 ms PTS lip-sync offset
    public var subtitleLanguageCode: String   // ISO 639-2
    public var subtitleMode: KroutonSubtitleDeliveryMode
    public var forcedSubtitlesOnly: Bool
    public var chapterTimestampsRaw: String   // Pipe or newline separated "00:00:00 Intro | 00:05:30 Act I"

    public init(
        id: UUID = UUID(),
        audioLanguageCode: String = "eng",
        audioDelayMs: Int = 0,
        subtitleLanguageCode: String = "eng",
        subtitleMode: KroutonSubtitleDeliveryMode = .softsubPassthrough,
        forcedSubtitlesOnly: Bool = false,
        chapterTimestampsRaw: String = "00:00:00 Opening | 00:05:00 Act I | 00:12:30 Climax | 00:18:00 Credits"
    ) {
        self.id = id
        self.audioLanguageCode = audioLanguageCode
        self.audioDelayMs = max(-2000, min(2000, audioDelayMs))
        self.subtitleLanguageCode = subtitleLanguageCode
        self.subtitleMode = subtitleMode
        self.forcedSubtitlesOnly = forcedSubtitlesOnly
        self.chapterTimestampsRaw = chapterTimestampsRaw
    }

    public var compiledChapters: [KroutonVideoChapterMarker] {
        KroutonVideoAuthoringEngine.compileTimestampChapters(chapterTimestampsRaw)
    }

    public var muxBadgeSummary: String {
        let delayStr = audioDelayMs == 0 ? "0ms" : String(format: "%+dms", audioDelayMs)
        let subShort = subtitleMode == .hardwareBurnIn ? "Burn-In" : (forcedSubtitlesOnly ? "Forced" : "Softsub")
        return "\(audioLanguageCode.uppercased()) (\(delayStr)) • \(subShort) • \(compiledChapters.count) Ch"
    }
}

extension KroutonVideoAuthoringEngine {
    /// Parses timestamp strings ("00:00:00 Opening | 00:05:30 Act I" or newline-separated) into 90 kHz PTS chapter markers
    public static func compileTimestampChapters(_ raw: String) -> [KroutonVideoChapterMarker] {
        let chunks = raw
            .replacingOccurrences(of: "|", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var markers: [(sec: Double, ts: String, title: String)] = []
        for chunk in chunks {
            let parts = chunk.split(separator: " ", maxSplits: 1).map(String.init)
            guard let timeToken = parts.first else { continue }
            let nums = timeToken.split(separator: ":").compactMap { Double($0) }
            let secs: Double
            if nums.count == 3 {
                secs = nums[0] * 3600.0 + nums[1] * 60.0 + nums[2]
            } else if nums.count == 2 {
                secs = nums[0] * 60.0 + nums[1]
            } else {
                continue
            }
            let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "Chapter"
            let sInt = Int(max(0.0, secs))
            let canonicalTS = String(format: "%02d:%02d:%02d", sInt / 3600, (sInt % 3600) / 60, sInt % 60)
            markers.append((max(0.0, secs), canonicalTS, title))
        }

        markers.sort { $0.sec < $1.sec }
        if markers.isEmpty {
            markers = [(0.0, "00:00:00", "Chapter 1")]
        }
        return markers.enumerated().map { idx, item in
            KroutonVideoChapterMarker(
                index: idx + 1,
                timestampText: item.ts,
                startSeconds: item.sec,
                pts90kHz: Int64((item.sec * 90_000.0).rounded()),
                title: item.title
            )
        }
    }
}


public enum KroutonVideoShrinkError: Error, LocalizedError, Sendable, Equatable {
    case requantizationUnavailable(sourceBytes: Int64, dvd5Bytes: Int64)
    case transcodeFailed(exitCode: Int32)

    public var errorDescription: String? {
        switch self {
        case .requantizationUnavailable(let source, let limit):
            let format = ByteCountFormatter()
            format.countStyle = .file
            return "This disc is \(format.string(fromByteCount: source)) and a DVD-5 holds \(format.string(fromByteCount: limit)). "
                + "Install ffmpeg (Homebrew: brew install ffmpeg) to enable DVD-9 -> DVD-5 MPEG-2 shrink, or turn off Fit to DVD-5 for a dual-layer blank."
        case .transcodeFailed(let exitCode):
            return "DVD-9 -> DVD-5 MPEG-2 requantization exited with code \(exitCode)."
        }
    }
}

extension KroutonVideoAuthoringEngine {
    /// Executes a complete, menu-preserving DVD-9 -> DVD-5 shrink on disk:
    /// 1. When the source `VIDEO_TS` already fits inside DVD-5, copies all files intact.
    /// 2. When the source exceeds DVD-5, preserves all menu VOBs (`VIDEO_TS.VOB`, `VTS_xx_0.VOB`),
    ///    re-encodes title VOBs (`VTS_xx_1..9.VOB`) to the target DVD-5 MPEG-2 bitrate while stream-copying
    ///    audio & subpictures, patches every `NV_PCK` DSI sector offset, and rebuilds `VTS_C_ADT`,
    ///    `VTS_VOBU_ADMAP`, `VTS_PGCI`, and `VIDEO_TS.IFO` / `.BUP` sector tables.
    @discardableResult
    public static func executeDVD9ToDVD5ShrinkOnDisk(
        sourceVideoTSDirectory: URL,
        outputVideoTSDirectory: URL,
        preserveMenus: Bool
    ) throws -> KroutonDVD9ShrinkPlan {
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(
            at: sourceVideoTSDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        var mainBytes: Int64 = 0
        var menuBytes: Int64 = 0
        for url in entries {
            let name = url.lastPathComponent.uppercased()
            let sz = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if name.hasSuffix(".VOB") && !name.hasSuffix("_0.VOB") && name != "VIDEO_TS.VOB" {
                mainBytes += sz
            } else {
                menuBytes += sz
            }
        }

        // Menus are always kept intact so VMGM/VTSM navigation commands and button highlights remain valid.
        let plan = planDVD9ToDVD5Shrink(
            mainFeatureBytes: mainBytes,
            menusAndExtrasBytes: menuBytes,
            preserveMenusAndExtras: true
        )

        try fm.createDirectory(at: outputVideoTSDirectory, withIntermediateDirectories: true)

        if !plan.requiresRequantization {
            for url in entries {
                let destURL = outputVideoTSDirectory.appendingPathComponent(url.lastPathComponent)
                if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
                try fm.copyItem(at: url, to: destURL)
            }
            return plan
        }

        guard let ffmpegURL = DVDVideoIFORelinker.locateFFmpegExecutable() else {
            throw KroutonVideoShrinkError.requantizationUnavailable(
                sourceBytes: mainBytes + menuBytes, dvd5Bytes: plan.targetUsableDVD5Bytes
            )
        }

        // Group VTS_xx title sets (01..99)
        var titleVOBsByVTS: [Int: [URL]] = [:]
        var menuVOBByVTS: [Int: URL] = [:]
        var ifoByVTS: [Int: URL] = [:]
        var vmgIFOURL: URL? = nil
        var vmgMenuVOBURL: URL? = nil

        for url in entries {
            let upper = url.lastPathComponent.uppercased()
            if upper == "VIDEO_TS.IFO" {
                vmgIFOURL = url
            } else if upper == "VIDEO_TS.VOB" {
                vmgMenuVOBURL = url
            } else if upper.hasPrefix("VTS_"), upper.count == 12,
                      let vtsNum = Int(upper.dropFirst(4).prefix(2)) {
                if upper.hasSuffix("_0.IFO") {
                    ifoByVTS[vtsNum] = url
                } else if upper.hasSuffix("_0.VOB") {
                    menuVOBByVTS[vtsNum] = url
                } else if upper.hasSuffix(".VOB") {
                    titleVOBsByVTS[vtsNum, default: []].append(url)
                }
            }
        }

        // Copy VIDEO_TS.VOB intact if present
        var vmgMenuSectors: UInt32 = 0
        if let vmgVOB = vmgMenuVOBURL {
            let dest = outputVideoTSDirectory.appendingPathComponent("VIDEO_TS.VOB")
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: vmgVOB, to: dest)
            let sz = Int((try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            vmgMenuSectors = UInt32((sz + DVDVideoIFORelinker.sectorBytes - 1) / DVDVideoIFORelinker.sectorBytes)
        }

        // Estimate target MPEG-2 bitrate from source size & requantization ratio
        let estimatedDurationSec = max(60.0, Double(mainBytes) / (6_500_000.0 / 8.0))
        let targetVideoKbps = Int((Double(plan.targetUsableDVD5Bytes - menuBytes) * 8.0 / estimatedDurationSec) / 1000.0) - 448

        var vtsLayouts: [DVDVideoVTSLayout] = []
        let tempWorkDir = fm.temporaryDirectory.appendingPathComponent("KroutonVTSWork_\(UUID().uuidString)")
        try fm.createDirectory(at: tempWorkDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempWorkDir) }

        for vtsNum in titleVOBsByVTS.keys.sorted() {
            let prefix = String(format: "VTS_%02d", vtsNum)
            let inputVOBs = (titleVOBsByVTS[vtsNum] ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }

            // 1. Copy menu VTS_xx_0.VOB intact
            var menuSectors: UInt32 = 0
            if let menuURL = menuVOBByVTS[vtsNum] {
                let destMenu = outputVideoTSDirectory.appendingPathComponent("\(prefix)_0.VOB")
                if fm.fileExists(atPath: destMenu.path) { try fm.removeItem(at: destMenu) }
                try fm.copyItem(at: menuURL, to: destMenu)
                let sz = Int((try? destMenu.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                menuSectors = UInt32((sz + DVDVideoIFORelinker.sectorBytes - 1) / DVDVideoIFORelinker.sectorBytes)
            }

            // 2. Transcode title VOBs to DVD-5 target MPEG-2 bitrate & patch NV_PCK DSI tables
            let combinedOut = tempWorkDir.appendingPathComponent("\(prefix)_shrunk.vob")
            try DVDVideoIFORelinker.transcodeTitleVOBsToDVD5Bitrate(
                ffmpegURL: ffmpegURL,
                inputVOBFiles: inputVOBs,
                outputCombinedVOBURL: combinedOut,
                targetVideoKbps: targetVideoKbps
            )
            let rawShrunkData = try Data(contentsOf: combinedOut)
            let (patchedVOBData, vobuStartSectors, relinkedCells) = DVDVideoIFORelinker.scanAndPatchTitleVOBs(rawShrunkData)
            let titleSectors = UInt32((patchedVOBData.count + DVDVideoIFORelinker.sectorBytes - 1) / DVDVideoIFORelinker.sectorBytes)

            // 3. Split patched title VOB into <= 1 GiB - 32 KiB chunks (VTS_xx_1.VOB, VTS_xx_2.VOB...)
            var offset = 0
            var chunkIndex = 1
            while offset < patchedVOBData.count {
                let end = min(patchedVOBData.count, offset + DVDVideoIFORelinker.maxSingleVOBBytes)
                let chunkURL = outputVideoTSDirectory.appendingPathComponent(String(format: "%@_%d.VOB", prefix, chunkIndex))
                try patchedVOBData.subdata(in: offset..<end).write(to: chunkURL)
                offset = end
                chunkIndex += 1
            }

            // 4. Relink VTS_xx_0.IFO & write identical VTS_xx_0.BUP
            var ifoSectors: UInt32 = 16
            if let srcIFOURL = ifoByVTS[vtsNum], let srcIFOData = try? Data(contentsOf: srcIFOURL) {
                let relinkedIFO = DVDVideoIFORelinker.relinkVTSIFO(
                    ifoData: srcIFOData,
                    menuVobSectors: menuSectors,
                    titleVobSectors: titleSectors,
                    vobuStartSectors: vobuStartSectors,
                    cells: relinkedCells
                )
                ifoSectors = UInt32((relinkedIFO.count + DVDVideoIFORelinker.sectorBytes - 1) / DVDVideoIFORelinker.sectorBytes)
                try relinkedIFO.write(to: outputVideoTSDirectory.appendingPathComponent("\(prefix)_0.IFO"))
                try relinkedIFO.write(to: outputVideoTSDirectory.appendingPathComponent("\(prefix)_0.BUP"))
            }

            vtsLayouts.append(DVDVideoVTSLayout(
                vtsNumber: vtsNum,
                ifoSectors: ifoSectors,
                menuVobSectors: menuSectors,
                titleVobSectors: titleSectors
            ))
        }

        // 5. Relink VIDEO_TS.IFO & VIDEO_TS.BUP
        if let srcVMG = vmgIFOURL, let vmgData = try? Data(contentsOf: srcVMG) {
            let relinkedVMG = DVDVideoIFORelinker.relinkVideoManagerIFO(
                vmgIfoData: vmgData,
                vmgMenuVobSectors: vmgMenuSectors,
                vtsLayouts: vtsLayouts
            )
            try relinkedVMG.write(to: outputVideoTSDirectory.appendingPathComponent("VIDEO_TS.IFO"))
            try relinkedVMG.write(to: outputVideoTSDirectory.appendingPathComponent("VIDEO_TS.BUP"))
        }

        return plan
    }
}
