import Foundation
import OpticalCore

// MARK: - Subtitle Delivery, Chapter Markers & Stream Muxing

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
