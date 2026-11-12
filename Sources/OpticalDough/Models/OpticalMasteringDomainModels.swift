import Foundation

// MARK: - Phase 3: Strongly-Typed Mastering & Extraction Domain Models

public struct KroutonRipTrackItem: Identifiable, Hashable, Codable, Sendable {
    public var id: Int { num }
    public var num: Int
    public var title: String
    public var performer: String
    public var duration: String
    public var arStatus: String

    public init(num: Int, title: String, performer: String, duration: String, arStatus: String) {
        self.num = num
        self.title = title
        self.performer = performer
        self.duration = duration
        self.arStatus = arStatus
    }

    public static let defaultRedBookTOC: [KroutonRipTrackItem] = [
        KroutonRipTrackItem(num: 1, title: "01. Opening Overture (Red Book PCM)", performer: "Krouton Studio Ensemble", duration: "04:18:22", arStatus: "AR v2 [14/14]"),
        KroutonRipTrackItem(num: 2, title: "02. Midnight Laser Calibration", performer: "Krouton Studio Ensemble", duration: "05:03:60", arStatus: "AR v2 [14/14]"),
        KroutonRipTrackItem(num: 3, title: "03. Polycarbonate Horizon", performer: "Krouton Studio Ensemble", duration: "03:49:15", arStatus: "AR v2 [14/14]"),
        KroutonRipTrackItem(num: 4, title: "04. Subchannel Q Drift", performer: "Krouton Studio Ensemble", duration: "06:12:44", arStatus: "AR v2 [12/12]"),
        KroutonRipTrackItem(num: 5, title: "05. Closing Fade (Index 00 Clean)", performer: "Krouton Studio Ensemble", duration: "04:55:08", arStatus: "AR v2 [14/14]")
    ]

    public static let musicBrainzMatchedTOC: [KroutonRipTrackItem] = [
        KroutonRipTrackItem(num: 1, title: "01. Laser Calibration Overture", performer: "The Optical Pickups", duration: "04:18:22", arStatus: "AR v2 [14/14]"),
        KroutonRipTrackItem(num: 2, title: "02. Eight-to-Fourteen Modulation", performer: "The Optical Pickups", duration: "05:03:60", arStatus: "AR v2 [14/14]"),
        KroutonRipTrackItem(num: 3, title: "03. Red Book Reflections", performer: "The Optical Pickups", duration: "03:49:15", arStatus: "AR v2 [14/14]"),
        KroutonRipTrackItem(num: 4, title: "04. Subchannel Q Drift", performer: "The Optical Pickups", duration: "06:12:44", arStatus: "AR v2 [12/12]"),
        KroutonRipTrackItem(num: 5, title: "05. Lead-Out Silence (Index 00)", performer: "The Optical Pickups", duration: "04:55:08", arStatus: "AR v2 [14/14]")
    ]
}

public struct KroutonVideoExtractTitleItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var streamInfo: String
    public var sizeLabel: String
    public var duration: String
    public var seconds: Int

    public init(id: String, name: String, streamInfo: String, sizeLabel: String, duration: String, seconds: Int) {
        self.id = id
        self.name = name
        self.streamInfo = streamInfo
        self.sizeLabel = sizeLabel
        self.duration = duration
        self.seconds = seconds
    }

    public static let defaultVideoTitles: [KroutonVideoExtractTitleItem] = [
        KroutonVideoExtractTitleItem(id: "TITLE_01", name: "Title 01 — Main Feature (1080p / 480p)", streamInfo: "H.264/MPEG-2 • AC-3 5.1 + DTS + English SRT • 24 Chapters", sizeLabel: "5.84 GB", duration: "01:58:14", seconds: 7094),
        KroutonVideoExtractTitleItem(id: "TITLE_02", name: "Title 02 — Behind the Scenes Documentary", streamInfo: "Stereo PCM + Chapters", sizeLabel: "780 MB", duration: "00:32:40", seconds: 1960),
        KroutonVideoExtractTitleItem(id: "TITLE_03", name: "Title 03 — Theatrical Trailer (Skipped if < 120s)", streamInfo: "AC-3 2.0", sizeLabel: "94 MB", duration: "00:01:48", seconds: 108)
    ]
}

public struct KroutonConsoleMasteringConfig: Equatable, Codable, Sendable {
    public var romWriteModeDAO96SubQ: Bool = true
    public var romBitsetDVDROM: Bool = true
    public var romPerformOPCBeforeWrite: Bool = true
    public var xboxLayerBreakPreset: String = "Auto (.dvd / Calculate Optimal)"
    public var ps1AutoMergeMultiBinAndCHD: Bool = true
    public var ps2ApplyESRPatch: Bool = false
    public var gcPadToOuterEdge3GB: Bool = true
    public var wiiLayerMode: String = "Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)"
    public var xboxVerifyStealthSectors: Bool = true

    public init() {}
}

public struct KroutonCopyExtractionConfig: Equatable, Codable, Sendable {
    public var fitToDiscDVD9Shrink: Bool = true
    public var preserveMenusAndExtras: Bool = true
    public var audioRipCodec: String = "FLAC (Lossless)"
    public var audioRipAccurateRip: Bool = true
    public var audioRipGenerateCueLog: Bool = true
    public var videoExtractMode: String = "Lossless MKV Remux"
    public var videoExtractMinSeconds: Int = 120
    public var videoExtractKeepChapters: Bool = true
    public var copySourceOverrideLabel: String = ""
    public var copyOutputFolderPath: String = "~/Music/Krouton Rips"

    public init() {}
}

public struct KroutonVideoAuthoringConfig: Equatable, Codable, Sendable {
    public var videoMenuTemplate: String = "Dark Studio Chapter Grid"
    public var videoSystemStandard: String = "NTSC 16:9 (29.97 / 23.976p)"
    public var videoAudioEncoding: String = "AC-3 Dolby Digital 5.1 (448 kbps)"
    public var videoDualLayerBreakSector: String = "Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)"
    public var avchdBitrateCap: String = "18 Mbps (3x DVD-R Safe)"
    public var uhdPreserveHDR10DolbyVision: Bool = true

    public init() {}
}
