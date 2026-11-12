import Foundation

// MARK: - Strongly-Typed Optical Format & Task Identifiers (Phase 2 Type-Safety Gate)

public enum KroutonFormatID: String, CaseIterable, Codable, Sendable {
    case cdDA = "cd-da"
    case mp3CD = "mp3-cd"
    case cdExtra = "cd-extra"
    case dtsCD = "dts-cd"
    case dvdAudio = "dvd-audio"
    case sacdR = "sacd-r"

    case dvdVideo = "dvd-video"
    case bdOnDVD = "bd-on-dvd"
    case bd25 = "bd-25"
    case bd50 = "bd-50"
    case bdUHD = "bd-uhd"
    case videoSVCD = "video-svcd"

    case imageBurn = "image-burn"
    case dataHybrid = "data-hybrid"
    case dataUDFModern = "data-udf-modern"
    case dataAppleAPFS = "data-apple-apfs"
    case dataRetroISO = "data-retro-iso"
    case mdiscVault = "mdisc-vault"
    case dvdRAM = "dvd-ram"

    case consoleWii = "console-wii"
    case consoleGC = "console-gc"
    case consolePS2 = "console-ps2"
    case consolePS1 = "console-ps1"
    case consolePS3 = "console-ps3"
    case consoleXbox = "console-xbox"
    case consoleDC = "console-dc"
    case consoleSaturn = "console-saturn"
    case console3DO = "console-3do"

    case macos9HFS = "macos9-hfs"
    case photoCD = "photo-cd"
    case vcdSVCD = "vcd-svcd"
    case cdG = "cd-g"
}

public enum KroutonCopyTaskID: String, CaseIterable, Codable, Sendable {
    case duplicateDisc = "copy-duplicate"
    case ripAudioCD = "copy-rip-audio"
    case extractVideoDisc = "copy-rip-video"
}

public enum KroutonMasteringWorkspaceKind: String, CaseIterable, Codable, Sendable {
    case discImageInspector
    case redBookAudio
    case carSafeMP3Audio
    case videoAuthoring
    case retroConsole
    case dataAndArchival
}

public enum KroutonRecipeFilterGroup: String, CaseIterable, Identifiable, Sendable {
    case all = "All Formats"
    case enabled = "Enabled Only"
    case audio = "Audio"
    case video = "Video & BD"
    case data = "Data & Archival"
    case console = "Console ROMs"
    case legacy = "Obsolete / Niche"
    public var id: String { rawValue }
}

public struct KroutonRecipeSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public var showInTaskChooser: Bool
    public var technicalName: String
    public var colloquialName: String
    public var launchYear: String
    public var capacity: String
    public var capacityGB: Double
    public var laserType: String
    public var platform: String
    public var deprecationStatus: String
    public var sourceSupport: String
    public var bookOrFileSystem: String
    public var sfSymbol: String
    public var filterGroup: KroutonRecipeFilterGroup
    public var isMediaPlaylist: Bool
    public var isDataDisc: Bool

    public init(
        id: String,
        showInTaskChooser: Bool,
        technicalName: String,
        colloquialName: String,
        launchYear: String,
        capacity: String,
        capacityGB: Double,
        laserType: String,
        platform: String,
        deprecationStatus: String,
        sourceSupport: String,
        bookOrFileSystem: String,
        sfSymbol: String,
        filterGroup: KroutonRecipeFilterGroup,
        isMediaPlaylist: Bool,
        isDataDisc: Bool
    ) {
        self.id = id
        self.showInTaskChooser = showInTaskChooser
        self.technicalName = technicalName
        self.colloquialName = colloquialName
        self.launchYear = launchYear
        self.capacity = capacity
        self.capacityGB = capacityGB
        self.laserType = laserType
        self.platform = platform
        self.deprecationStatus = deprecationStatus
        self.sourceSupport = sourceSupport
        self.bookOrFileSystem = bookOrFileSystem
        self.sfSymbol = sfSymbol
        self.filterGroup = filterGroup
        self.isMediaPlaylist = isMediaPlaylist
        self.isDataDisc = isDataDisc
    }

    public var formatID: KroutonFormatID? {
        KroutonFormatID(rawValue: id)
    }

    public var visibilitySortKey: Int {
        showInTaskChooser ? 1 : 0
    }

    /// Deterministic workspace classification tested by krouton-verify
    public var workspaceKind: KroutonMasteringWorkspaceKind {
        if id == KroutonFormatID.imageBurn.rawValue || sourceSupport == "Disc Image" {
            return .discImageInspector
        }
        if id == KroutonFormatID.mp3CD.rawValue {
            return .carSafeMP3Audio
        }
        if filterGroup == .audio || id == KroutonFormatID.cdG.rawValue {
            return .redBookAudio
        }
        if filterGroup == .video || id == KroutonFormatID.vcdSVCD.rawValue {
            return .videoAuthoring
        }
        if filterGroup == .console || id.hasPrefix("console-") {
            return .retroConsole
        }
        return .dataAndArchival
    }

    public var isMDiscParityFormat: Bool {
        id == KroutonFormatID.mdiscVault.rawValue || technicalName.contains("M-DISC")
    }
}

// MARK: - Strict Per-Format File Type Compatibility & OpenPanel UTType Rules
extension KroutonRecipeSpec {
    public var allowedFileExtensions: [String] {
        if id == "cd-da" || id == "audio-cdda" || id == "cd-extra" || id == "audio-cdextra" || id == "dts-cd" || id == "audio-dtscd" || id == "dvd-audio" || id == "audio-dvda" || id == "sacd-r" {
            return ["wav", "aiff", "aif", "flac", "alac", "m4a", "mp3", "ogg", "opus", "wv", "ape", "dsf", "dff", "caf", "ac3", "dts"]
        } else if id == "mp3-cd" || id == "audio-mp3" {
            return ["mp3", "flac", "m4a", "wav", "ogg", "aac", "wma", "opus"]
        } else if filterGroup == .video || id.hasPrefix("video-") || id.hasPrefix("bd-") || id == "avchd-dvd" || id == "dvd-video" || id == "vcd-svcd" {
            // Video authoring formats NEVER allow .iso/.dmg/.bin disc images!
            return ["mkv", "mp4", "m4v", "mov", "m2ts", "mts", "ts", "vob", "IFO", "ifo", "avi", "webm", "mpg", "mpeg", "wmv", "hevc", "h264", "bdmv"]
        } else if id == "image-burn" || sourceSupport == "Disc Image" {
            return ["iso", "dmg", "cdr", "bin", "cue", "img", "toast", "nrg", "mds", "mdf", "ccd", "chd", "rvz"]
        } else if id == "console-wii" || id == "game-wii" {
            return ["rvz", "wbfs", "iso", "wia", "ciso"]
        } else if id == "console-gc" || id == "game-gc" {
            return ["rvz", "gcm", "iso", "ciso", "gcz"]
        } else if id == "console-ps2" || id == "game-ps2" {
            return ["iso", "chd", "bin", "cue", "mdf", "mds"]
        } else if id == "console-ps1" || id == "game-ps1" {
            return ["cue", "bin", "chd", "ccd", "img", "sub"]
        } else if id == "console-xbox" || id == "game-xbox" {
            return ["iso", "xiso", "dvd"]
        } else if filterGroup == .console {
            return ["cue", "bin", "iso", "chd", "cdi", "gdi", "rvz", "gcm"]
        }
        return [] // Data & M-DISC formats accept any file or directory
    }

    public var allowsDirectorySelection: Bool {
        if id == "image-burn" || filterGroup == .console {
            return false // Single disc image or ROM file only
        }
        return true // Audio/Video folders (e.g. Album folders, VIDEO_TS, BDMV) and Data folders are allowed
    }

    public var expectedMediaDescription: String {
        if filterGroup == .audio { return "Audio tracks (.wav, .flac, .aiff, .m4a, .mp3)" }
        if filterGroup == .video { return "Video streams (.mkv, .mp4, .mov, .m2ts, VIDEO_TS, BDMV)" }
        if id == "image-burn" { return "Disc images (.iso, .dmg, .bin/.cue, .cdr, .img, .toast)" }
        if id == "console-wii" || id == "game-wii" { return "Nintendo Wii disc images (.rvz, .wbfs, .iso, .wia, .ciso)" }
        if id == "console-gc" || id == "game-gc" { return "Nintendo GameCube disc images (.rvz, .gcm, .iso, .ciso, .gcz)" }
        if id == "console-ps2" || id == "game-ps2" { return "PlayStation 2 disc images (.iso, .chd, .bin/.cue, .mdf/.mds)" }
        if id == "console-ps1" || id == "game-ps1" { return "PlayStation 1 disc images (.cue/.bin, .chd, .ccd/.img/.sub)" }
        if id == "console-xbox" || id == "game-xbox" { return "Xbox XDVDFS disc images (.iso, .xiso, .dvd)" }
        if filterGroup == .console { return "Console ROM disc images (.cue/.bin, .iso, .chd, .rvz, .gcm, .wbfs)" }
        return "Files and folders"
    }

    public var shortDisplayName: String {
        let t = technicalName
        if t.contains("CD-DA") || id == "audio-cdda" || id == "cd-da" { return "Audio CD" }
        if t.contains("ISO9660 / UDF Audio") || id == "audio-mp3" || id == "mp3-cd" { return "MP3 / FLAC CD" }
        if t.contains("CD-Extra") || id == "audio-cdextra" || id == "cd-extra" { return "CD-Extra" }
        if t.contains("DVD-Video") || id == "video-dvd" || id == "dvd-video" { return "DVD-Video" }
        if t.contains("AVCHD") || id == "avchd-dvd" || id == "bd-on-dvd" { return "AVCHD" }
        if t.contains("BD-R DL") || t.contains("Dual-Layer") { return "BD-R DL" }
        if t.contains("BD-R") || t.contains("BD-RE") { return "BD-R" }
        if t.contains("BDXL") || t.contains("UHD-BD") { return "UHD-BD" }
        if t.contains("Super VCD") || t.contains("SVCD") { return "SVCD" }
        if t.contains("Burn Disc Image") || id == "image-burn" { return "Burn Image" }
        if t.contains("Universal Hybrid") || id == "data-hybrid" { return "Data" }
        if t.contains("UDF 2.60") || id == "data-udf-modern" { return "UDF Data" }
        if t.contains("APFS") || t.contains("HFS+") { return "Mac Volume" }
        if t.contains("ISO9660 Level 1") || id == "data-retro-iso" { return "Retro ISO" }
        if t.contains("M-DISC") || id == "mdisc-vault" { return "M-DISC" }
        if t.contains("Wii") { return "Wii" }
        if t.contains("GameCube") { return "GameCube" }
        if t.contains("PlayStation 2") { return "PS2" }
        if t.contains("PlayStation CD") || t.contains("PS1") { return "PS1" }
        if t.contains("Xbox") { return "Xbox" }
        if t.contains("Dreamcast") { return "Dreamcast" }
        if t.contains("3DO") || t.contains("TurboGrafx") { return "3DO / PCE" }
        if t.contains("DTS-CD") { return "DTS-CD" }
        if t.contains("DVD-Audio") { return "DVD-Audio" }
        if t.contains("DVD-RAM") { return "DVD-RAM" }
        if t.contains("Mac OS 9") { return "Mac OS 9 HFS" }
        if t.contains("Photo CD") { return "Photo CD" }
        return technicalName
    }

    public var exactShortDisplayName: String {
        switch id {
        case "cd-da": return "CD-DA"
        case "mp3-cd": return "MP3 CD"
        case "cd-extra": return "CD-Extra"
        case "dts-cd": return "DTS-CD"
        case "dvd-audio": return "DVD-Audio"
        case "sacd-r": return "SACD"
        case "dvd-video": return "DVD-Video"
        case "bd-on-dvd": return "AVCHD"
        case "bd-25": return "BD-R SL"
        case "bd-50": return "BD-R DL"
        case "bd-uhd": return "BDXL UHD"
        case "image-burn": return "Burn Image"
        case "data-hybrid": return "Hybrid Data"
        case "data-udf-modern": return "UDF 2.60"
        case "data-apple-apfs": return "Apple HFS+"
        case "data-retro-iso": return "DOS 8.3"
        case "video-svcd", "vcd-svcd": return "VCD"
        case "mdisc-vault": return "M-DISC"
        case "dvd-ram": return "DVD-RAM"
        case "console-wii": return "Wii"
        case "console-gc": return "GameCube"
        case "console-ps2": return "PS2"
        case "console-ps1": return "PS1"
        case "console-ps3": return "PS3"
        case "console-xbox": return "Xbox"
        case "console-dc": return "Dreamcast"
        case "console-saturn": return "Saturn"
        case "console-3do": return "3DO / PCE"
        case "macos9-hfs": return "HFS"
        case "photo-cd": return "Photo CD"
        case "cd-g": return "Karaoke"
        default: return technicalName
        }
    }
}

// MARK: - Canonical Optical Format Catalog (Testable by KroutonVerify)
public enum KroutonOpticalRecipeCatalog {
    public static let defaultFormats: [KroutonRecipeSpec] = [
        KroutonRecipeSpec(id: "cd-da", showInTaskChooser: true, technicalName: "Audio CD", colloquialName: "", launchYear: "1982", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "All CD / DVD / BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "IEC 60908 Red Book", sfSymbol: "waveform.circle.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "mp3-cd", showInTaskChooser: true, technicalName: "ISO9660 / UDF Audio", colloquialName: "MP3 / FLAC Car-Safe Audio Disc", launchYear: "1998", capacity: "700 MB / 4.7 GB", capacityGB: 0.7, laserType: "780nm / 650nm", platform: "Car Stereos, Mac/PC, DVD Decks", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "ISO9660 + Joliet (ID3v2.3)", sfSymbol: "music.note.list", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "cd-extra", showInTaskChooser: true, technicalName: "CD-Extra (Blue Book)", colloquialName: "Enhanced Mixed-Mode Audio + Data CD", launchYear: "1995", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "CD Players + Mac/PC", deprecationStatus: "2008 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "Multi-Session Red + Yellow", sfSymbol: "opticaldisc.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: true),
        KroutonRecipeSpec(id: "dts-cd", showInTaskChooser: false, technicalName: "DTS-CD (5.1 PCM Wrapper)", colloquialName: "5.1 Surround Sound Audio CD", launchYear: "1997", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "S/PDIF Home Theater Receivers", deprecationStatus: "2006 (Niche)", sourceSupport: "New & Image", bookOrFileSystem: "Red Book 14-bit DTS Coherent", sfSymbol: "hifispeaker.2.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "dvd-audio", showInTaskChooser: false, technicalName: "DVD-Audio (AUDIO_TS)", colloquialName: "24-bit/192kHz Lossless MLP DVD", launchYear: "2000", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "DVD-Audio & Universal Players", deprecationStatus: "2009 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 + Meridian Lossless", sfSymbol: "waveform.badge.magnifyingglass", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "sacd-r", showInTaskChooser: false, technicalName: "Scarlet Book DSD (SACD-R)", colloquialName: "1-Bit 2.8MHz DSD Audiophile Disc", launchYear: "1999", capacity: "4.7 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "SACD-R Compatible Decks", deprecationStatus: "2011 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Scarlet Book (.dsf/.dff)", sfSymbol: "hifispeaker.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),

        KroutonRecipeSpec(id: "dvd-video", showInTaskChooser: true, technicalName: "DVD-Video (DVD-5 / DVD-9)", colloquialName: "Standard Movie DVD w/ Menus", launchYear: "1996", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Standalone DVD & BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Bridge (VIDEO_TS)", sfSymbol: "film.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "bd-on-dvd", showInTaskChooser: true, technicalName: "AVCHD / BD-5 / BD-9", colloquialName: "1080p Blu-ray Video on 4.7GB DVD", launchYear: "2006", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Blu-ray Players, PS3/PS4/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 (BDMV on DVD)", sfSymbol: "sparkles.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "bd-25", showInTaskChooser: true, technicalName: "BD-R / BD-RE SL (BDMV)", colloquialName: "25 GB Single-Layer Blu-ray Video", launchYear: "2006", capacity: "25.0 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 / 2.60 (BDMV)", sfSymbol: "film.stack.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "bd-50", showInTaskChooser: true, technicalName: "BD-R DL Dual-Layer (BDMV)", colloquialName: "50 GB Dual-Layer Blu-ray Video", launchYear: "2006", capacity: "50.0 GB", capacityGB: 50.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 Seamless Break", sfSymbol: "square.stack.3d.up.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "bd-uhd", showInTaskChooser: true, technicalName: "BDXL / UHD-BD (TL / QL)", colloquialName: "4K UHD HDR10 / Dolby Atmos Blu-ray", launchYear: "2016", capacity: "66 / 100 / 128 GB", capacityGB: 100.0, laserType: "405nm Violet", platform: "4K UHD Players, Xbox/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 HEVC 10-bit HDR", sfSymbol: "4k.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),

        KroutonRecipeSpec(id: "image-burn", showInTaskChooser: true, technicalName: "Burn Disc Image (.ISO / .BIN / .DMG)", colloquialName: "Sector-Exact Image & Bootable OS Burner", launchYear: "1988", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "Bootable PC, Mac, Linux & Consoles", deprecationStatus: "Current", sourceSupport: "Disc Image", bookOrFileSystem: "El Torito / APM / Raw 2,352B & 2,048B", sfSymbol: "opticaldisc.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "data-hybrid", showInTaskChooser: true, technicalName: "Universal Hybrid Data (Mac + PC + Linux)", colloquialName: "4-Way Bridge (UDF + HFS+ + Joliet + Rock Ridge)", launchYear: "1995", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "Every Mac, Windows & Linux PC", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "UDF 1.02 + HFS+ + ISO9660/Joliet", sfSymbol: "externaldrive.fill.badge.plus", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "data-udf-modern", showInTaskChooser: true, technicalName: "UDF 2.60 Large-File Data (>4 GiB)", colloquialName: "Unrestricted Single Files up to 128 GB", launchYear: "2005", capacity: "4.7 GB - 128 GB", capacityGB: 25.0, laserType: "650nm / 405nm", platform: "macOS 10.5+, Windows 7/10/11, Linux", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "Pure ECMA-167 UDF 2.50 / 2.60", sfSymbol: "internaldrive.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "data-apple-apfs", showInTaskChooser: false, technicalName: "Apple Native Volume (APFS / HFS+)", colloquialName: "Full macOS Metadata, xattrs & Resource Forks", launchYear: "2017", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "macOS Only (68k/PPC/Intel/Apple Silicon)", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "APFS / HFS+ Journaled Container", sfSymbol: "apple.logo", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "data-retro-iso", showInTaskChooser: false, technicalName: "ISO9660 Level 1 (Retro 8.3 DOS / Win9x)", colloquialName: "Strict 8.3 Uppercase for Vintage PCs & System 7", launchYear: "1988", capacity: "650 MB / 700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "MS-DOS, Win 3.1/95, OS/2, Classic Mac", deprecationStatus: "1999 (Vintage)", sourceSupport: "New File Tree", bookOrFileSystem: "ECMA-119 Level 1 (8.3) + HFS Bridge", sfSymbol: "desktopcomputer", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "video-svcd", showInTaskChooser: false, technicalName: "VCD 2.0 / Super Video CD (White Book)", colloquialName: "MPEG-1 / MPEG-2 Video on Standard CD-R", launchYear: "1993", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD / DVD Players & Retro Consoles", deprecationStatus: "2005 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "IEC 62107 Mode 2 Form 2 (2,324 B/sec)", sfSymbol: "tv.circle.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "mdisc-vault", showInTaskChooser: true, technicalName: "M-DISC Archival + PAR2", colloquialName: "1,000-Year Inorganic Vault w/ Parity", launchYear: "2009", capacity: "25 / 50 / 100 GB", capacityGB: 25.0, laserType: "405nm / 650nm", platform: "macOS, Windows, Linux", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 + 10% PAR2 Recovery", sfSymbol: "lock.shield.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "dvd-ram", showInTaskChooser: false, technicalName: "DVD-RAM (UDF 1.50 / 2.01)", colloquialName: "Random-Access Zoned Rewritable Disc", launchYear: "1996", capacity: "4.7 GB / 9.4 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Broadcast Recorders, Mac/PC", deprecationStatus: "2015 (Pro Broadcast)", sourceSupport: "New & Image", bookOrFileSystem: "Hardware Defect Mgmt UDF", sfSymbol: "memorychip.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),

        KroutonRecipeSpec(id: "console-wii", showInTaskChooser: true, technicalName: "Nintendo Wii (RVL-006)", colloquialName: "Wii Optical Disc (.rvz / .wbfs / .iso)", launchYear: "2006", capacity: "4.7 GB / 8.54 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Nintendo Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Wii Partition Table (.rvz/.wbfs)", sfSymbol: "gamecontroller.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "console-gc", showInTaskChooser: true, technicalName: "Nintendo GameCube (DOL-006)", colloquialName: "80mm GameCube Mini-DVD (.rvz / .gcm)", launchYear: "2001", capacity: "1.46 GB (80mm)", capacityGB: 1.46, laserType: "650nm Red", platform: "GameCube, Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "GCM / RVZ Sector Rebuilder", sfSymbol: "circle.grid.cross.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "console-ps2", showInTaskChooser: true, technicalName: "PlayStation 2 DVD / CD", colloquialName: "Sony PS2 Game Disc (+ FreeDVDBoot ESR)", launchYear: "2000", capacity: "700 MB / 4.7 GB", capacityGB: 4.7, laserType: "650nm / 780nm", platform: "PlayStation 2 & PCSX2", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "ISO9660 + UDF 1.02 (.iso/.chd)", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "console-ps1", showInTaskChooser: true, technicalName: "PlayStation CD-ROM XA", colloquialName: "Sony PS1 Mode 2 Form 2 (.bin/.cue/.chd)", launchYear: "1994", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "PlayStation 1/2/3 & DuckStation", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "2352-Byte Raw + Subchannel", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "console-ps3", showInTaskChooser: false, technicalName: "PlayStation 3 BD-ROM", colloquialName: "Sony PS3 Blu-ray Game Disc (PS3_GAME)", launchYear: "2006", capacity: "25 GB / 50 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "PlayStation 3 & RPCS3", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 PS3 Volume Header", sfSymbol: "opticaldisc", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "console-xbox", showInTaskChooser: true, technicalName: "Xbox XDVDFS (XGD1 / XGD2)", colloquialName: "Original Xbox & Xbox 360 (.xiso)", launchYear: "2001", capacity: "4.7 GB / 7.95 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Original Xbox, 360 & xemu", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "Microsoft XDVDFS Partition", sfSymbol: "xbox.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "console-dc", showInTaskChooser: false, technicalName: "Dreamcast MIL-CD / GD-ROM", colloquialName: "Sega Dreamcast Self-Boot (.cdi / .gdi)", launchYear: "1998", capacity: "700 MB / 1.0 GB", capacityGB: 0.7, laserType: "780nm IR", platform: "Sega Dreamcast & Flycast", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Multi-Session Audio + Data", sfSymbol: "hurricane", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "console-saturn", showInTaskChooser: false, technicalName: "Sega Saturn / Mega-CD", colloquialName: "Saturn & Sega CD Mixed-Mode (.chd/.cue)", launchYear: "1991", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Sega Saturn, Sega CD & Mednafen", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Track 1 ISO + Red Book Audio", sfSymbol: "globe.asia.australia.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonRecipeSpec(id: "console-3do", showInTaskChooser: false, technicalName: "3DO / PC Engine CD-ROM²", colloquialName: "3DO Interactive & TurboGrafx-CD", launchYear: "1988", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "3DO, PC Engine & RetroArch", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Opera FS / Mode 1 Raw", sfSymbol: "sparkles.rectangle.stack.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),

        KroutonRecipeSpec(id: "macos9-hfs", showInTaskChooser: false, technicalName: "HFS Standard (Mac OS 9 APM)", colloquialName: "Bootable Classic System 7 / OS 9 CD", launchYear: "1985", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "68k & PowerPC Macintoshes", deprecationStatus: "2002 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Apple Partition Map + Blessed HFS", sfSymbol: "desktopcomputer", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "photo-cd", showInTaskChooser: false, technicalName: "Kodak Photo CD (Beige Book)", colloquialName: "Multi-Resolution .PCD Archival Disc", launchYear: "1992", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Photo CD Decks & Mac/PC", deprecationStatus: "2004 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "CD-ROM XA Bridge (Image Pac)", sfSymbol: "camera.aperture", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        KroutonRecipeSpec(id: "vcd-svcd", showInTaskChooser: false, technicalName: "White Book VCD / SVCD", colloquialName: "Video CD (MPEG-1 / MPEG-2)", launchYear: "1993", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD & DVD Players", deprecationStatus: "2005 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Mode 2 Form 2 (2324-Byte)", sfSymbol: "play.tv.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false),
        KroutonRecipeSpec(id: "cd-g", showInTaskChooser: false, technicalName: "Red Book + R-W Subchannel", colloquialName: "Karaoke CD+G Graphics Disc", launchYear: "1985", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "Karaoke Decks", deprecationStatus: "2010 (Legacy)", sourceSupport: "Image Only", bookOrFileSystem: "Raw 96-Byte R-W Subchannel", sfSymbol: "mic.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false)
    ]
}
