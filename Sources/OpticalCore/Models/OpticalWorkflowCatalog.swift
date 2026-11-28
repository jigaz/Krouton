import Foundation

// MARK: - Format and Task Identifiers

/// Every disc format Krouton lists, by its saved identifier. The raw values are stored in projects
/// and must not change.
public enum KroutonFormatID: String, CaseIterable, Codable, Sendable {
    case cdDA = "cd-da"
    case mp3CD = "mp3-cd"
    case cdExtra = "cd-extra"
    case dtsCD = "dts-cd"
    case dvdAudio = "dvd-audio"

    case dvdVideo = "dvd-video"
    case bdOnDVD = "bd-on-dvd"
    case bd25 = "bd-25"
    case bd50 = "bd-50"
    case bdUHD = "bd-uhd"

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
    case consoleXbox = "console-xbox"
    case consoleDC = "console-dc"
    case consoleSaturn = "console-saturn"
    case console3DO = "console-3do"

    case macos9HFS = "macos9-hfs"
    case photoCD = "photo-cd"
    case vcdSVCD = "vcd-svcd"

    /// True for formats whose disc-image destination saves a raw 2,352-byte .cue/.bin (audio and
    /// the CD-based consoles).
    public var usesRawCueBinImage: Bool {
        switch self {
        case .cdDA, .cdExtra, .dtsCD, .consolePS1, .consoleSaturn, .console3DO, .consoleDC:
            return true
        default:
            return false
        }
    }

    /// True for formats whose disc-image destination saves an Apple disk image (.dmg).
    public var usesAppleDiskImage: Bool {
        switch self {
        case .dataAppleAPFS, .macos9HFS:
            return true
        default:
            return false
        }
    }

    /// The short name the sidebar and the task chooser show.
    public var exactShortDisplayName: String {
        switch self {
        case .cdDA: return "Audio CD"
        case .mp3CD: return "MP3 CD"
        case .cdExtra: return "CD-Extra"
        case .dtsCD: return "DTS-CD"
        case .dvdAudio: return "DVD-Audio"
        case .dvdVideo: return "DVD-Video"
        case .bdOnDVD: return "AVCHD"
        case .bd25: return "BD-R SL"
        case .bd50: return "BD-R DL"
        case .bdUHD: return "BDXL UHD"
        case .imageBurn: return "Burn Image"
        case .dataHybrid: return "Hybrid Data"
        case .dataUDFModern: return "UDF 2.50"
        case .dataAppleAPFS: return "Apple HFS+"
        case .dataRetroISO: return "DOS 8.3"
        case .vcdSVCD: return "VCD"
        case .mdiscVault: return "M-DISC"
        case .dvdRAM: return "DVD-RAM"
        case .consoleWii: return "Wii"
        case .consoleGC: return "GameCube"
        case .consolePS2: return "PS2"
        case .consolePS1: return "PS1"
        case .consoleXbox: return "Xbox"
        case .consoleDC: return "Dreamcast"
        case .consoleSaturn: return "Saturn"
        case .console3DO: return "3DO / PCE"
        case .macos9HFS: return "HFS"
        case .photoCD: return "Photo CD"
        }
    }
}

/// The tasks in the Copy section that read a disc instead of making one.
public enum KroutonCopyTaskID: String, CaseIterable, Codable, Sendable {
    case duplicateDisc = "copy-duplicate"
    case ripAudioCD = "copy-rip-audio"
    case extractVideoDisc = "copy-rip-video"
    case rescueDisc = "copy-rescue"
}

/// The workspace a format opens in the app.
public enum KroutonMasteringWorkspaceKind: String, CaseIterable, Codable, Sendable {
    case discImageInspector
    case redBookAudio
    case carSafeMP3Audio
    case videoAuthoring
    case retroConsole
    case dataAndArchival
}

/// The filters of the format list. The raw values are display names.
public enum KroutonWorkflowFilterGroup: String, CaseIterable, Identifiable, Sendable {
    case all = "All Formats"
    case enabled = "Enabled Only"
    case audio = "Audio"
    case video = "Video & BD"
    case data = "Data & Archival"
    case console = "Console ROMs"
    case legacy = "Obsolete / Niche"
    public var id: String { rawValue }
}

/// One row of the format catalog: what the format is, for the format list and its detail pane, and
/// which workspace it opens. The descriptive strings are display text, not checked facts.
public struct KroutonOpticalWorkflowSpec: Identifiable, Hashable, Sendable {
    /// The format's identifier; a `KroutonFormatID` raw value.
    public let id: String
    /// True when the format appears in the task chooser, not only in the full list.
    public var showInTaskChooser: Bool
    /// The format's technical name.
    public var technicalName: String
    /// A plain description of the format.
    public var colloquialName: String
    /// The year the format appeared.
    public var launchYear: String
    /// Capacity, as display text.
    public var capacity: String
    /// Capacity of the usual medium in GB, for sorting.
    public var capacityGB: Double
    /// The laser the medium uses, as display text.
    public var laserType: String
    /// What plays or reads the disc, as display text.
    public var platform: String
    /// Whether the format is current, legacy or obsolete, as display text.
    public var deprecationStatus: String
    /// What the format starts from; "Disc Image" routes it to the image workspace.
    public var sourceSupport: String
    /// The specification or file systems, as display text.
    public var bookOrFileSystem: String
    /// The SF Symbols name for the format's icon.
    public var sfSymbol: String
    /// The filter group the format belongs to.
    public var filterGroup: KroutonWorkflowFilterGroup
    var isMediaPlaylist: Bool
    var isDataDisc: Bool

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
        filterGroup: KroutonWorkflowFilterGroup,
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

    /// The typed identifier, or nil for an unknown `id`.
    public var formatID: KroutonFormatID? {
        KroutonFormatID(rawValue: id)
    }

    /// 1 for formats in the task chooser, 0 for the rest.
    public var visibilitySortKey: Int {
        showInTaskChooser ? 1 : 0
    }

    /// The workspace the format opens. krouton-verify Suite 3 checks the routing.
    public var workspaceKind: KroutonMasteringWorkspaceKind {
        if id == KroutonFormatID.imageBurn.rawValue || sourceSupport == "Disc Image" {
            return .discImageInspector
        }
        if id == KroutonFormatID.mp3CD.rawValue {
            return .carSafeMP3Audio
        }
        if filterGroup == .audio {
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

    /// True for the M-DISC archival format, which writes PAR2 recovery files.
    public var isMDiscParityFormat: Bool {
        id == KroutonFormatID.mdiscVault.rawValue || technicalName.contains("M-DISC")
    }
}

// MARK: - Accepted Files

extension KroutonOpticalWorkflowSpec {
    /// The file extensions the format's open panel and drop target accept.
    public var allowedFileExtensions: [String] {
        switch formatID {
        case .cdDA, .cdExtra, .dtsCD, .dvdAudio:
            return ["wav", "aiff", "aif", "flac", "alac", "m4a", "mp3", "ogg", "opus", "wv", "ape", "dsf", "dff", "caf", "ac3", "dts"]
        case .mp3CD:
            return ["mp3", "flac", "m4a", "wav", "ogg", "aac", "wma", "opus"]
        case .dvdVideo, .bdOnDVD, .bd25, .bd50, .bdUHD, .vcdSVCD:
            return ["mkv", "mp4", "m4v", "mov", "m2ts", "mts", "ts", "vob", "IFO", "ifo", "avi", "webm", "mpg", "mpeg", "wmv", "hevc", "h264", "bdmv"]
        case .imageBurn:
            return ["iso", "dmg", "cdr", "bin", "cue", "img", "toast", "nrg", "mds", "mdf", "ccd", "chd", "rvz"]
        case .consoleWii:
            return ["rvz", "wbfs", "iso", "wia", "ciso"]
        case .consoleGC:
            return ["rvz", "gcm", "iso", "ciso", "gcz"]
        case .consolePS2:
            return ["iso", "chd", "bin", "cue", "mdf", "mds"]
        case .consolePS1:
            return ["cue", "bin", "chd", "ccd", "img", "sub"]
        case .consoleXbox:
            return ["iso", "xiso", "dvd"]
        default:
            if filterGroup == .video {
                return ["mkv", "mp4", "m4v", "mov", "m2ts", "mts", "ts", "vob", "IFO", "ifo", "avi", "webm", "mpg", "mpeg", "wmv", "hevc", "h264", "bdmv"]
            }
            if sourceSupport == "Disc Image" {
                return ["iso", "dmg", "cdr", "bin", "cue", "img", "toast", "nrg", "mds", "mdf", "ccd", "chd", "rvz"]
            }
            if filterGroup == .console {
                return ["cue", "bin", "iso", "chd", "cdi", "gdi", "rvz", "gcm"]
            }
            return []
        }
    }

    /// False for image and console formats, which take one image file.
    public var allowsDirectorySelection: Bool {
        if formatID == .imageBurn || filterGroup == .console {
            return false
        }
        return true
    }

    /// What to drop, for the empty deck.
    public var expectedMediaDescription: String {
        if filterGroup == .audio { return "Audio tracks (.wav, .flac, .aiff, .m4a, .mp3)" }
        if filterGroup == .video { return "Video streams (.mkv, .mp4, .mov, .m2ts, VIDEO_TS, BDMV)" }
        switch formatID {
        case .imageBurn: return "Disc images (.iso, .dmg, .bin/.cue, .cdr, .img, .toast)"
        case .consoleWii: return "Nintendo Wii disc images (.rvz, .wbfs, .iso, .wia, .ciso)"
        case .consoleGC: return "Nintendo GameCube disc images (.rvz, .gcm, .iso, .ciso, .gcz)"
        case .consolePS2: return "PlayStation 2 disc images (.iso, .chd, .bin/.cue, .mdf/.mds)"
        case .consolePS1: return "PlayStation 1 disc images (.cue/.bin, .chd, .ccd/.img/.sub)"
        case .consoleXbox: return "Xbox XDVDFS disc images (.iso, .xiso, .dvd)"
        default:
            if filterGroup == .console { return "Console ROM disc images (.cue/.bin, .iso, .chd, .rvz, .gcm, .wbfs)" }
            return "Files and folders"
        }
    }

    public var exactShortDisplayName: String {
        formatID?.exactShortDisplayName ?? technicalName
    }
}

// MARK: - Format Catalog

/// The format catalog the app shows: 28 formats.
public enum KroutonOpticalWorkflowCatalog {
    public static let defaultFormats: [KroutonOpticalWorkflowSpec] = [
        KroutonOpticalWorkflowSpec(id: "cd-da", showInTaskChooser: true, technicalName: "Audio CD (Red Book)", colloquialName: "Red Book Audio CD w/ CD-TEXT & ISRC", launchYear: "1982", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "All CD / DVD / BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "IEC 60908 Red Book", sfSymbol: "waveform.circle.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "mp3-cd", showInTaskChooser: true, technicalName: "ISO9660 / UDF Audio", colloquialName: "MP3 / FLAC Car-Safe Audio Disc", launchYear: "1998", capacity: "700 MB / 4.7 GB", capacityGB: 0.7, laserType: "780nm / 650nm", platform: "Car Stereos, Mac/PC, DVD Decks", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "ISO9660 + Joliet (ID3v2.3)", sfSymbol: "music.note.list", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "cd-extra", showInTaskChooser: true, technicalName: "CD-Extra (Blue Book)", colloquialName: "Enhanced Mixed-Mode Audio + Data CD", launchYear: "1995", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "CD Players + Mac/PC", deprecationStatus: "2008 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "Multi-Session Red + Yellow", sfSymbol: "opticaldisc.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "dts-cd", showInTaskChooser: false, technicalName: "DTS-CD (5.1 PCM Wrapper)", colloquialName: "5.1 Surround Sound Audio CD", launchYear: "1997", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "S/PDIF Home Theater Receivers", deprecationStatus: "2006 (Niche)", sourceSupport: "New & Image", bookOrFileSystem: "Red Book 14-bit DTS Coherent", sfSymbol: "hifispeaker.2.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "dvd-audio", showInTaskChooser: false, technicalName: "DVD-Audio (AUDIO_TS)", colloquialName: "24-bit/192kHz Lossless MLP DVD", launchYear: "2000", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "DVD-Audio & Universal Players", deprecationStatus: "2009 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 + Meridian Lossless", sfSymbol: "waveform.badge.magnifyingglass", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),

        KroutonOpticalWorkflowSpec(id: "dvd-video", showInTaskChooser: true, technicalName: "DVD-Video (DVD-5 / DVD-9)", colloquialName: "Standard Movie DVD w/ Menus", launchYear: "1996", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Standalone DVD & BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Bridge (VIDEO_TS)", sfSymbol: "film.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "bd-on-dvd", showInTaskChooser: true, technicalName: "AVCHD / BD-5 / BD-9", colloquialName: "1080p Blu-ray Video on 4.7GB DVD", launchYear: "2006", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Blu-ray Players, PS3/PS4/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 (BDMV on DVD)", sfSymbol: "sparkles.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "bd-25", showInTaskChooser: true, technicalName: "BD-R / BD-RE SL (BDMV)", colloquialName: "25 GB Single-Layer Blu-ray Video", launchYear: "2006", capacity: "25.0 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 / 2.60 (BDMV)", sfSymbol: "film.stack.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "bd-50", showInTaskChooser: true, technicalName: "BD-R DL Dual-Layer (BDMV)", colloquialName: "50 GB Dual-Layer Blu-ray Video", launchYear: "2006", capacity: "50.0 GB", capacityGB: 50.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 Seamless Break", sfSymbol: "square.stack.3d.up.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "bd-uhd", showInTaskChooser: true, technicalName: "BDXL / UHD-BD (TL / QL)", colloquialName: "4K Ultra HD Blu-ray (an authored BDMV)", launchYear: "2016", capacity: "100 / 128 GB BD-R XL", capacityGB: 100.0, laserType: "405nm Violet", platform: "4K UHD players that accept BD-R XL", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 (BD-ROM Part 2), HEVC 10-bit", sfSymbol: "4k.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),

        KroutonOpticalWorkflowSpec(id: "image-burn", showInTaskChooser: true, technicalName: "Burn Disc Image (.ISO / .BIN / .DMG)", colloquialName: "Sector-Exact Image & Bootable OS Burner", launchYear: "1988", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "Bootable PC, Mac, Linux & Consoles", deprecationStatus: "Current", sourceSupport: "Disc Image", bookOrFileSystem: "El Torito / APM / Raw 2,352B & 2,048B", sfSymbol: "opticaldisc.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "data-hybrid", showInTaskChooser: true, technicalName: "Universal Hybrid Data (Mac + PC + Linux)", colloquialName: "4-Way Bridge (UDF + HFS+ + Joliet + Rock Ridge)", launchYear: "1995", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "Every Mac, Windows & Linux PC", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "UDF 1.02 + HFS+ + ISO9660/Joliet", sfSymbol: "externaldrive.fill.badge.plus", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "data-udf-modern", showInTaskChooser: true, technicalName: "UDF 2.50 Large-File Data (>4 GiB)", colloquialName: "Single Files of Any Size (macOS, Windows 10+, Linux)", launchYear: "2005", capacity: "4.7 GB - 128 GB", capacityGB: 25.0, laserType: "650nm / 405nm", platform: "macOS 10.5+, Windows 7/10/11, Linux", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "ECMA-167 UDF 2.50 (no ISO 9660)", sfSymbol: "internaldrive.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "data-apple-apfs", showInTaskChooser: false, technicalName: "Apple HFS+ Data Disc", colloquialName: "Mac-First Hybrid with an HFS+ Volume", launchYear: "2017", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "macOS (HFS+), others via ISO / Joliet / UDF", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "HFS+ + ISO 9660 + Joliet + UDF 1.02", sfSymbol: "apple.logo", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "data-retro-iso", showInTaskChooser: false, technicalName: "ISO9660 Level 1 (Retro 8.3 DOS / Win9x)", colloquialName: "Strict 8.3 Uppercase for Vintage PCs & System 7", launchYear: "1988", capacity: "650 MB / 700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "MS-DOS, Win 3.1/95, OS/2, Classic Mac", deprecationStatus: "1999 (Vintage)", sourceSupport: "New File Tree", bookOrFileSystem: "ECMA-119 Level 1 (8.3) + HFS Bridge", sfSymbol: "desktopcomputer", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "mdisc-vault", showInTaskChooser: true, technicalName: "M-DISC Archival + PAR2", colloquialName: "1,000-Year Inorganic Vault w/ Parity", launchYear: "2009", capacity: "25 / 50 / 100 GB", capacityGB: 25.0, laserType: "405nm / 650nm", platform: "macOS, Windows, Linux", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 + 10% PAR2 Recovery", sfSymbol: "lock.shield.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "dvd-ram", showInTaskChooser: false, technicalName: "DVD-RAM (UDF 1.50 / 2.01)", colloquialName: "Random-Access Zoned Rewritable Disc", launchYear: "1996", capacity: "4.7 GB / 9.4 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Broadcast Recorders, Mac/PC", deprecationStatus: "2015 (Pro Broadcast)", sourceSupport: "New & Image", bookOrFileSystem: "Hardware Defect Mgmt UDF", sfSymbol: "memorychip.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),

        KroutonOpticalWorkflowSpec(id: "console-wii", showInTaskChooser: true, technicalName: "Nintendo Wii (RVL-006)", colloquialName: "Wii Optical Disc (.rvz / .wbfs / .iso)", launchYear: "2006", capacity: "4.7 GB / 8.54 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Nintendo Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Wii Partition Table (.rvz/.wbfs)", sfSymbol: "gamecontroller.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "console-gc", showInTaskChooser: true, technicalName: "Nintendo GameCube (DOL-006)", colloquialName: "80mm GameCube Mini-DVD (.rvz / .gcm)", launchYear: "2001", capacity: "1.46 GB (80mm)", capacityGB: 1.46, laserType: "650nm Red", platform: "GameCube, Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "GCM / RVZ Sector Rebuilder", sfSymbol: "circle.grid.cross.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "console-ps2", showInTaskChooser: true, technicalName: "PlayStation 2 DVD / CD", colloquialName: "Sony PS2 Game Disc (+ FreeDVDBoot ESR)", launchYear: "2000", capacity: "700 MB / 4.7 GB", capacityGB: 4.7, laserType: "650nm / 780nm", platform: "PlayStation 2 & PCSX2", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "ISO9660 + UDF 1.02 (.iso/.chd)", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "console-ps1", showInTaskChooser: true, technicalName: "PlayStation CD-ROM XA", colloquialName: "Sony PS1 Mode 2 Form 2 (.bin/.cue/.chd)", launchYear: "1994", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "PlayStation 1/2/3 & DuckStation", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "2352-Byte Raw + Subchannel", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "console-xbox", showInTaskChooser: true, technicalName: "Xbox XDVDFS (XGD1 / XGD2)", colloquialName: "Original Xbox & Xbox 360 (.xiso)", launchYear: "2001", capacity: "4.7 GB / 7.95 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Original Xbox, 360 & xemu", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "Microsoft XDVDFS Partition", sfSymbol: "xbox.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "console-dc", showInTaskChooser: false, technicalName: "Dreamcast MIL-CD / GD-ROM", colloquialName: "Sega Dreamcast Self-Boot (.cdi / .gdi)", launchYear: "1998", capacity: "700 MB / 1.0 GB", capacityGB: 0.7, laserType: "780nm IR", platform: "Sega Dreamcast & Flycast", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Multi-Session Audio + Data", sfSymbol: "hurricane", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "console-saturn", showInTaskChooser: false, technicalName: "Sega Saturn / Mega-CD", colloquialName: "Saturn & Sega CD Mixed-Mode (.chd/.cue)", launchYear: "1991", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Sega Saturn, Sega CD & Mednafen", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Track 1 ISO + Red Book Audio", sfSymbol: "globe.asia.australia.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        KroutonOpticalWorkflowSpec(id: "console-3do", showInTaskChooser: false, technicalName: "3DO / PC Engine CD-ROM²", colloquialName: "3DO Interactive & TurboGrafx-CD", launchYear: "1988", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "3DO, PC Engine & RetroArch", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Opera FS / Mode 1 Raw", sfSymbol: "sparkles.rectangle.stack.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),

        KroutonOpticalWorkflowSpec(id: "macos9-hfs", showInTaskChooser: false, technicalName: "HFS Standard (Mac OS 9 APM)", colloquialName: "Classic Mac CD (System 7 to Mac OS 9)", launchYear: "1985", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "68k & PowerPC Macintoshes", deprecationStatus: "2002 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Apple Partition Map + HFS Standard", sfSymbol: "desktopcomputer", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "photo-cd", showInTaskChooser: false, technicalName: "Kodak Photo CD (Beige Book)", colloquialName: "Multi-Resolution .PCD Archival Disc", launchYear: "1992", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Photo CD Decks & Mac/PC", deprecationStatus: "2004 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "CD-ROM XA Bridge (Image Pac)", sfSymbol: "camera.aperture", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        KroutonOpticalWorkflowSpec(id: "vcd-svcd", showInTaskChooser: false, technicalName: "White Book VCD / SVCD", colloquialName: "Video CD (MPEG-1 / MPEG-2)", launchYear: "1993", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD & DVD Players", deprecationStatus: "2005 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Mode 2 Form 2 (2324-Byte)", sfSymbol: "play.tv.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false),
    ]
}
