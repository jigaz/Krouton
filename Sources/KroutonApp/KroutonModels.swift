import SwiftUI
import AppKit
import OpticalDough

// MARK: - 10 Rainbow-Ordered Accent Color Presets + Black/White Monochrome
public struct AccentColorPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let primary: Color
    public let secondary: Color
    public let isMonochrome: Bool

    public static let allPresets: [AccentColorPreset] = [
        // 0: Red
        AccentColorPreset(id: 0, primary: Color(red: 0.92, green: 0.24, blue: 0.24), secondary: Color.red, isMonochrome: false),
        // 1: Orange (Toast Amber)
        AccentColorPreset(id: 1, primary: Color.orange, secondary: Color.orange, isMonochrome: false),
        // 2: Yellow
        AccentColorPreset(id: 2, primary: Color.yellow, secondary: Color.orange, isMonochrome: false),
        // 3: Green (Archival Emerald)
        AccentColorPreset(id: 3, primary: Color.green, secondary: Color.mint, isMonochrome: false),
        // 4: Cyan / Teal
        AccentColorPreset(id: 4, primary: Color.cyan, secondary: Color.teal, isMonochrome: false),
        // 5: 405nm Laser Blue
        AccentColorPreset(id: 5, primary: Color.blue, secondary: Color.cyan, isMonochrome: false),
        // 6: CCC Slate Blue (Default)
        AccentColorPreset(id: 6, primary: Color(red: 0.35, green: 0.52, blue: 0.78), secondary: Color.blue, isMonochrome: false),
        // 7: Indigo / Violet
        AccentColorPreset(id: 7, primary: Color.indigo, secondary: Color.purple, isMonochrome: false),
        // 8: Pink / Magenta
        AccentColorPreset(id: 8, primary: Color.pink, secondary: Color.pink, isMonochrome: false),
        // 9: Black & White Monochrome
        AccentColorPreset(id: 9, primary: Color.primary, secondary: Color.secondary, isMonochrome: true)
    ]
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case dark = "Dark"
    case light = "Light"
    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

public enum TaskMasterCategory: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case depot = "DISC IMAGE DEPOT"
    case copy = "COPY"
    case label = "LABEL"
    public var id: String { rawValue }
}

public enum FormatFilterGroup: String, CaseIterable, Identifiable, Sendable {
    case all = "All Formats"
    case enabled = "Enabled Only"
    case audio = "Audio"
    case video = "Video & BD"
    case data = "Data & Archival"
    case console = "Console ROMs"
    case legacy = "Obsolete / Niche"
    public var id: String { rawValue }
}

public struct DiscFormatSpec: Identifiable, Hashable, Sendable {
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
    public var filterGroup: FormatFilterGroup
    public var isMediaPlaylist: Bool
    public var isDataDisc: Bool

    public var visibilitySortKey: Int {
        showInTaskChooser ? 1 : 0
    }
}

public struct DepotCatalogItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var channel: String
    public var version: String
    public var sizeDisplay: String
    public var architecture: String
    public var bootStandard: String
    public var sha256Short: String
    public var sfSymbol: String
    public var isDownloaded: Bool
}

public struct DepotChannelSubscription: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var itemCount: Int
    public var isEnabled: Bool
    public var sfSymbol: String
}

public struct DiscoveredBurnerHardware: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var firmware: String
    public var connectionBus: String
    public var capabilities: String
    public var statusBadge: String
    public var isNetworkNode: Bool
}

public struct LabelGeometryPreset: Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var outerDiameterMM: Double
    public var innerDiameterMM: Double
    public var offsetXMM: Double
    public var offsetYMM: Double
}

public struct NotificationEventRow: Identifiable, Hashable, Sendable {
    public let id: String
    public var eventTitle: String
    public var eventSubtitle: String
    public var bannerEnabled: Bool
    public var iPhoneEnabled: Bool
    public var watchEnabled: Bool
    public var soundEnabled: Bool
}

public enum DestinationOutputKind: String, CaseIterable, Identifiable, Sendable {
    case physicalBurner = "Physical Burner"
    case networkBurner = "Network Server Burner"
    case discImage = "Disc Image File"
    case audioRip = "Audio Rip (ALAC / AAC / FLAC)"
    case videoExtract = "Video Transcode (H.265 / HEVC)"
    case discPrinter = "Disc Printer (Epson ET-8550)"
    case pdfVector = "Vector PDF Label"
    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .physicalBurner: return "opticaldiscdrive.fill"
        case .networkBurner: return "server.rack"
        case .discImage: return "externaldrive.fill.badge.plus"
        case .audioRip: return "waveform.badge.plus"
        case .videoExtract: return "film.stack"
        case .discPrinter: return "printer.dotmatrix.fill"
        case .pdfVector: return "doc.richtext.fill"
        }
    }
}

public struct DestinationQueueItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var kind: DestinationOutputKind
    public var hardwareOrPath: String
    public var speedOrCodec: String
    public var simulationMode: Bool
    public var verifyAfterBurn: Bool
    public var compressAfterCreation: Bool
}

@MainActor
public final class KroutonStateStore: ObservableObject {
    // 1. General Settings (Menu Bar toggle removed; Rainbow index 6 = Slate Blue default)
    @Published public var appearanceMode: AppAppearanceMode = .dark
    @Published public var selectedAccentIndex: Int = 6
    @Published public var rememberLastTaskOnLaunch: Bool = true
    @Published public var useBase10Units: Bool = true
    @Published public var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    @Published public var autoPurgeScratch: Bool = true

    // 2. Active Workspace Selection
    @Published public var selectedCategory: TaskMasterCategory = .burn
    @Published public var selectedTaskID: String = "cd-da"

    // 3. Expanded 27-Format Optical Catalog (1982-2026, Individual Console ROMs, El Torito moved to Disc Image Depot)
    @Published public var discFormats: [DiscFormatSpec] = [
        // Audio Formats
        DiscFormatSpec(id: "cd-da", showInTaskChooser: true, technicalName: "CD-DA (Red Book)", colloquialName: "Audio CD w/ CD-TEXT & ISRC", launchYear: "1982", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "All CD / DVD / BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "IEC 60908 Red Book", sfSymbol: "waveform.circle.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "mp3-cd", showInTaskChooser: true, technicalName: "ISO9660 / UDF Audio", colloquialName: "MP3 / FLAC Car-Safe Audio Disc", launchYear: "1998", capacity: "700 MB / 4.7 GB", capacityGB: 0.7, laserType: "780nm / 650nm", platform: "Car Stereos, Mac/PC, DVD Decks", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "ISO9660 + Joliet (ID3v2.3)", sfSymbol: "music.note.list", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "cd-extra", showInTaskChooser: true, technicalName: "CD-Extra (Blue Book)", colloquialName: "Enhanced Mixed-Mode Audio + Data CD", launchYear: "1995", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "CD Players + Mac/PC", deprecationStatus: "2008 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "Multi-Session Red + Yellow", sfSymbol: "opticaldisc.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: true),
        DiscFormatSpec(id: "dts-cd", showInTaskChooser: false, technicalName: "DTS-CD (5.1 PCM Wrapper)", colloquialName: "5.1 Surround Sound Audio CD", launchYear: "1997", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: " S/PDIF Home Theater Receivers", deprecationStatus: "2006 (Niche)", sourceSupport: "New & Image", bookOrFileSystem: "Red Book 14-bit DTS Coherent", sfSymbol: "hifispeaker.2.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "dvd-audio", showInTaskChooser: false, technicalName: "DVD-Audio (AUDIO_TS)", colloquialName: "24-bit/192kHz Lossless MLP DVD", launchYear: "2000", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "DVD-Audio & Universal Players", deprecationStatus: "2009 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 + Meridian Lossless", sfSymbol: "waveform.badge.magnifyingglass", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "sacd-r", showInTaskChooser: false, technicalName: "Scarlet Book DSD (SACD-R)", colloquialName: "1-Bit 2.8MHz DSD Audiophile Disc", launchYear: "1999", capacity: "4.7 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "SACD-R Compatible Decks", deprecationStatus: "2011 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Scarlet Book (.dsf/.dff)", sfSymbol: "hifispeaker.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),

        // Video & Blu-ray Formats
        DiscFormatSpec(id: "dvd-video", showInTaskChooser: true, technicalName: "DVD-Video (DVD-5 / DVD-9)", colloquialName: "Standard Movie DVD w/ Menus", launchYear: "1996", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Standalone DVD & BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Bridge (VIDEO_TS)", sfSymbol: "film.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-on-dvd", showInTaskChooser: true, technicalName: "AVCHD / BD-5 / BD-9", colloquialName: "1080p Blu-ray Video on 4.7GB DVD", launchYear: "2006", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Blu-ray Players, PS3/PS4/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 (BDMV on DVD)", sfSymbol: "sparkles.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-25", showInTaskChooser: true, technicalName: "BD-R / BD-RE SL (BDMV)", colloquialName: "25 GB Single-Layer Blu-ray Video", launchYear: "2006", capacity: "25.0 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 / 2.60 (BDMV)", sfSymbol: "film.stack.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-50", showInTaskChooser: true, technicalName: "BD-R DL Dual-Layer (BDMV)", colloquialName: "50 GB Dual-Layer Blu-ray Video", launchYear: "2006", capacity: "50.0 GB", capacityGB: 50.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 Seamless Break", sfSymbol: "square.stack.3d.up.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-uhd", showInTaskChooser: true, technicalName: "BDXL / UHD-BD (TL / QL)", colloquialName: "4K UHD HDR10 / Dolby Atmos Blu-ray", launchYear: "2016", capacity: "66 / 100 / 128 GB", capacityGB: 100.0, laserType: "405nm Violet", platform: "4K UHD Players, Xbox/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 HEVC 10-bit HDR", sfSymbol: "4k.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),

        // Data & Archival Formats
        DiscFormatSpec(id: "data-hybrid", showInTaskChooser: true, technicalName: "UDF / HFS+ / APFS / ISO", colloquialName: "Mac & PC Custom View Data Disc", launchYear: "1985", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "macOS, Windows, Linux", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "Hybrid HFS+ / UDF 2.60", sfSymbol: "externaldrive.fill.badge.plus", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "mdisc-vault", showInTaskChooser: true, technicalName: "M-DISC Archival + PAR2", colloquialName: "1,000-Year Inorganic Vault w/ Parity", launchYear: "2009", capacity: "25 / 50 / 100 GB", capacityGB: 25.0, laserType: "405nm / 650nm", platform: "macOS, Windows, Linux", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 + 10% PAR2 Recovery", sfSymbol: "lock.shield.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "dvd-ram", showInTaskChooser: false, technicalName: "DVD-RAM (UDF 1.50 / 2.01)", colloquialName: "Random-Access Zoned Rewritable Disc", launchYear: "1996", capacity: "4.7 GB / 9.4 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Broadcast Recorders, Mac/PC", deprecationStatus: "2015 (Pro Broadcast)", sourceSupport: "New & Image", bookOrFileSystem: "Hardware Defect Mgmt UDF", sfSymbol: "memorychip.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),

        // Broken-Out Individual Console ROM & Optical Formats
        DiscFormatSpec(id: "console-wii", showInTaskChooser: true, technicalName: "Nintendo Wii (RVL-006)", colloquialName: "Wii Optical Disc (.rvz / .wbfs / .iso)", launchYear: "2006", capacity: "4.7 GB / 8.54 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Nintendo Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Wii Partition Table (.rvz/.wbfs)", sfSymbol: "gamecontroller.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-gc", showInTaskChooser: true, technicalName: "Nintendo GameCube (DOL-006)", colloquialName: "80mm GameCube Mini-DVD (.rvz / .gcm)", launchYear: "2001", capacity: "1.46 GB (80mm)", capacityGB: 1.46, laserType: "650nm Red", platform: "GameCube, Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "GCM / RVZ Sector Rebuilder", sfSymbol: "circle.grid.cross.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-ps2", showInTaskChooser: true, technicalName: "PlayStation 2 DVD / CD", colloquialName: "Sony PS2 Game Disc (+ FreeDVDBoot ESR)", launchYear: "2000", capacity: "700 MB / 4.7 GB", capacityGB: 4.7, laserType: "650nm / 780nm", platform: "PlayStation 2 & PCSX2", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "ISO9660 + UDF 1.02 (.iso/.chd)", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-ps1", showInTaskChooser: true, technicalName: "PlayStation CD-ROM XA", colloquialName: "Sony PS1 Mode 2 Form 2 (.bin/.cue/.chd)", launchYear: "1994", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "PlayStation 1/2/3 & DuckStation", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "2352-Byte Raw + Subchannel", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-ps3", showInTaskChooser: false, technicalName: "PlayStation 3 BD-ROM", colloquialName: "Sony PS3 Blu-ray Game Disc (PS3_GAME)", launchYear: "2006", capacity: "25 GB / 50 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "PlayStation 3 & RPCS3", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 PS3 Volume Header", sfSymbol: "opticaldisc", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "console-xbox", showInTaskChooser: true, technicalName: "Xbox XDVDFS (XGD1 / XGD2)", colloquialName: "Original Xbox & Xbox 360 (.xiso)", launchYear: "2001", capacity: "4.7 GB / 7.95 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Original Xbox, 360 & xemu", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "Microsoft XDVDFS Partition", sfSymbol: "xbox.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "console-dc", showInTaskChooser: false, technicalName: "Dreamcast MIL-CD / GD-ROM", colloquialName: "Sega Dreamcast Self-Boot (.cdi / .gdi)", launchYear: "1998", capacity: "700 MB / 1.0 GB", capacityGB: 0.7, laserType: "780nm IR", platform: "Sega Dreamcast & Flycast", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Multi-Session Audio + Data", sfSymbol: "hurricane", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-saturn", showInTaskChooser: false, technicalName: "Sega Saturn / Mega-CD", colloquialName: "Saturn & Sega CD Mixed-Mode (.chd/.cue)", launchYear: "1991", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Sega Saturn, Sega CD & Mednafen", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Track 1 ISO + Red Book Audio", sfSymbol: "globe.asia.australia.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-3do", showInTaskChooser: false, technicalName: "3DO / PC Engine CD-ROM²", colloquialName: "3DO Interactive & TurboGrafx-CD", launchYear: "1988", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "3DO, PC Engine & RetroArch", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Opera FS / Mode 1 Raw", sfSymbol: "sparkles.rectangle.stack.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),

        // Obsolete / Legacy Vault Formats
        DiscFormatSpec(id: "macos9-hfs", showInTaskChooser: false, technicalName: "HFS Standard (Mac OS 9 APM)", colloquialName: "Bootable Classic System 7 / OS 9 CD", launchYear: "1985", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "68k & PowerPC Macintoshes", deprecationStatus: "2002 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Apple Partition Map + Blessed HFS", sfSymbol: "desktopcomputer", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "photo-cd", showInTaskChooser: false, technicalName: "Kodak Photo CD (Beige Book)", colloquialName: "Multi-Resolution .PCD Archival Disc", launchYear: "1992", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Photo CD Decks & Mac/PC", deprecationStatus: "2004 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "CD-ROM XA Bridge (Image Pac)", sfSymbol: "camera.aperture", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "vcd-svcd", showInTaskChooser: false, technicalName: "White Book VCD / SVCD", colloquialName: "Video CD (MPEG-1 / MPEG-2)", launchYear: "1993", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD & DVD Players", deprecationStatus: "2005 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Mode 2 Form 2 (2324-Byte)", sfSymbol: "play.tv.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "cd-g", showInTaskChooser: false, technicalName: "Red Book + R-W Subchannel", colloquialName: "Karaoke CD+G Graphics Disc", launchYear: "1985", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "Karaoke Decks", deprecationStatus: "2010 (Legacy)", sourceSupport: "Image Only", bookOrFileSystem: "Raw 96-Byte R-W Subchannel", sfSymbol: "mic.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false)
    ]

    // 4. Disc Image Depot Storefront Catalog & Subscribed Channels
    @Published public var depotChannels: [DepotChannelSubscription] = [
        DepotChannelSubscription(id: "rescue", name: "System Rescue, Partitioning & Hardware Diagnostics", description: "SystemRescue, GParted Live, Rescuezilla, Memtest86+, FreeDOS 1.4 BIOS Room", itemCount: 14, isEnabled: true, sfSymbol: "cross.case.fill"),
        DepotChannelSubscription(id: "linux", name: "Live Linux & BSD Official Optical Releases", description: "Ubuntu LTS, Fedora Workstation, Debian Live, Arch, FreeBSD Boot-Only & DVD", itemCount: 28, isEnabled: true, sfSymbol: "terminal.fill"),
        DepotChannelSubscription(id: "windows", name: "Microsoft Windows & DOS Official ISO API", description: "Direct Microsoft token downloader for Windows 11 (w/ DVD-5 Splitter) & Windows 10", itemCount: 8, isEnabled: true, sfSymbol: "window.ceiling"),
        DepotChannelSubscription(id: "vintage-mac", name: "Internet Archive — Vintage Apple & Classic Mac OS", description: "Mac OS 9.2.2 Universal, System 7.5.3, Apple Hardware Test, PowerPC Restore Discs", itemCount: 42, isEnabled: true, sfSymbol: "desktopcomputer"),
        DepotChannelSubscription(id: "shareware", name: "Internet Archive — 90s Cover Discs & Shareware Vault", description: "MacAddict, Macworld, Next Generation, and classic demo CDs", itemCount: 65, isEnabled: false, sfSymbol: "opticaldisc.fill")
    ]
    @Published public var customDepotFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    @Published public var autoVerifyDepotSHA256: Bool = true
    @Published public var enableVMTestBootInDepot: Bool = true

    @Published public var depotItems: [DepotCatalogItem] = [
        DepotCatalogItem(id: "sysrescue-11", title: "SystemRescue 11.03 Live", subtitle: "Complete ZFS/Btrfs/APFS recovery, partitioning, ddrescue & network tools", channel: "Rescue & Diagnostics", version: "11.03 (2026)", sizeDisplay: "854 MB", architecture: "x86_64 / UEFI", bootStandard: "El Torito BIOS + UEFI", sha256Short: "8f4a...e91c", sfSymbol: "cross.case.fill", isDownloaded: true),
        DepotCatalogItem(id: "freedos-14", title: "FreeDOS 1.4 Live + BIOS Flasher Room", subtitle: "Classic DOS environment with 600 MB open space to inject motherboard/drive firmware", channel: "Rescue & Diagnostics", version: "1.4 Final", sizeDisplay: "412 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy/HD Emulation", sha256Short: "3c19...b04d", sfSymbol: "cpu.fill", isDownloaded: true),
        DepotCatalogItem(id: "macos922-uni", title: "Mac OS 9.2.2 Universal Boot CD (Classic APM)", subtitle: "Bootable HFS Standard + Apple Partition Map for PowerMac G3/G4 & iBook", channel: "Vintage Apple (archive.org)", version: "9.2.2 (2002)", sizeDisplay: "618 MB", architecture: "PowerPC", bootStandard: "Apple Partition Map + Blessed Folder", sha256Short: "a72e...441f", sfSymbol: "desktopcomputer", isDownloaded: false),
        DepotCatalogItem(id: "ubuntu-2604", title: "Ubuntu Desktop 26.04 LTS Live DVD", subtitle: "Official Canonical Live Desktop & Installer (ARM64 Apple Silicon VM & x86_64)", channel: "Live Linux & BSD", version: "26.04 LTS", sizeDisplay: "4.48 GB", architecture: "ARM64 / x86_64", bootStandard: "UEFI ESP + El Torito", sha256Short: "e901...772a", sfSymbol: "terminal.fill", isDownloaded: false),
        DepotCatalogItem(id: "rescuezilla-26", title: "Rescuezilla Bare-Metal Disk Imager", subtitle: "Graphical Clonezilla-compatible disk cloning and scratch recovery live disc", channel: "Rescue & Diagnostics", version: "2.6.1", sizeDisplay: "1.18 GB", architecture: "x86_64 / UEFI", bootStandard: "UEFI + BIOS Hybrid", sha256Short: "5d88...109e", sfSymbol: "externaldrive.badge.checkmark", isDownloaded: false),
        DepotCatalogItem(id: "win11-26h2", title: "Windows 11 26H2 Official ISO (+ DVD-5 Fit)", subtitle: "Fetched directly via Microsoft API with optional TPM bypass & 4.7GB WIM splitter", channel: "Windows & DOS", version: "26H2", sizeDisplay: "5.12 GB", architecture: "x86_64 / ARM64", bootStandard: "UDF + EFI Boot", sha256Short: "c410...998b", sfSymbol: "window.ceiling", isDownloaded: false)
    ]

    // 5. Audio, Video & Fit-to-Disc Settings
    @Published public var defaultCrossfadeSec: Double = 3.5
    @Published public var autoBeatmatchSoundAnalysis: Bool = true
    @Published public var carSafeMP3Mode: Bool = true
    @Published public var singleVideoFirstPlay: Bool = true
    @Published public var fitToDiscPreserveMenus: Bool = true
    @Published public var fitToDiscStripForeignDubs: Bool = true
    @Published public var videoToolboxTwoPassVBR: Bool = true

    // 6. Ripping, Transcoding & Interactive Token Tray
    @Published public var driveReadOffsetSamples: Int = 48
    @Published public var paranoiaErrorRetries: Int = 16
    @Published public var verifyAccurateRip: Bool = true
    @Published public var writeCueSheetLog: Bool = true
    @Published public var hardwareDeinterlaceVideo: Bool = true
    @Published public var passthroughAtmosTrueHD: Bool = true
    @Published public var namingTokens: [String] = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]

    // 7. Burners & Network Hardware Inventory
    @Published public var discoveredBurners: [DiscoveredBurnerHardware] = [
        DiscoveredBurnerHardware(id: "pioneer-net", name: "Pioneer BDR-S13U-X", firmware: "FW 1.05", connectionBus: "krouton-server.local (1.2 Gbps LAN)", capabilities: "BDXL 128GB • UHD • M-DISC • DVD±R DL • CD-TEXT", statusBadge: "Ready (Server Ring Buffer Armed)", isNetworkNode: true),
        DiscoveredBurnerHardware(id: "lg-local", name: "LG WH16NS60 (UHD Official)", firmware: "FW 1.02", connectionBus: "Thunderbolt / USB 3.2 Local Bus", capabilities: "BDXL 100GB • UHD Read/Write • M-DISC • LightScribe", statusBadge: "Ready (Media: Blank BD-R 25GB)", isNetworkNode: false)
    ]
    @Published public var enableNetworkServerSharing: Bool = true
    @Published public var serverRingBufferMB: Double = 256.0
    @Published public var preStageImageToServerSSD: Bool = true
    @Published public var forceDVDROMBookType: Bool = true
    @Published public var disableBDDefectManagementForVideo: Bool = true

    // 8. Labels & Printers (Dedicated Category)
    @Published public var labelPresets: [LabelGeometryPreset] = [
        LabelGeometryPreset(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        LabelGeometryPreset(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        LabelGeometryPreset(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        LabelGeometryPreset(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    @Published public var selectedLabelPresetIndex: Int = 0
    @Published public var defaultAutoLabelStyle: String = "Full-Bleed Artwork + Arc Typography"
    @Published public var visionHoleAvoidance: Bool = true
    @Published public var customTMDBKey: String = ""
    @Published public var customFanartKey: String = ""

    // 9. Notifications Matrix
    @Published public var notificationMatrix: [NotificationEventRow] = [
        NotificationEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        NotificationEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        NotificationEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "depot", eventTitle: "Disc Image Depot download verified", eventSubtitle: "ISO / image downloaded and SHA-256 verified", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: true)
    ]

    // 10. Right-Column Destination Queue
    @Published public var destinationQueue: [DestinationQueueItem] = [
        DestinationQueueItem(
            kind: .networkBurner,
            hardwareOrPath: "Pioneer BDR-S13U-X (krouton-server.local)",
            speedOrCodec: "8x CAV (Optimal)",
            simulationMode: false,
            verifyAfterBurn: true,
            compressAfterCreation: false
        )
    ]

    public var activeAccent: Color {
        AccentColorPreset.allPresets[selectedAccentIndex].primary
    }

    public var namingPreviewString: String {
        let joined = namingTokens.joined()
            .replacingOccurrences(of: "[Track 01]", with: "01")
            .replacingOccurrences(of: "[Artist]", with: "The Krouton Trio")
            .replacingOccurrences(of: "[Album]", with: "Oakland Sessions")
            .replacingOccurrences(of: "[Title]", with: "Analogue Horizon")
            .replacingOccurrences(of: "[Year]", with: "2026")
        return joined.isEmpty ? "01 - Track.m4a" : "\(joined).m4a"
    }

    public func toggleFormatVisibility(id: String) {
        if let idx = discFormats.firstIndex(where: { $0.id == id }) {
            discFormats[idx].showInTaskChooser.toggle()
        }
    }

    public init() {}
}
