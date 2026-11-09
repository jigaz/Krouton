#!/bin/zsh
set -e

cd ~/Developer/krouton

cat << 'EOF_MODELS' > Sources/KroutonApp/KroutonModels.swift
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
EOF_MODELS
echo "[OK] Wrote Sources/KroutonApp/KroutonModels.swift"

cat << 'EOF_SETTINGS' > Sources/KroutonApp/KroutonSettingsWindow.swift
import SwiftUI
import AppKit

public enum KroutonSettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case formatChooser = "Format Chooser"
    case discImageDepot = "Disc Image Depot"
    case audioVideo = "Audio & Video"
    case rippingTranscoding = "Ripping & Transcoding"
    case burnersNetwork = "Burners & Network"
    case labelsPrinters = "Labels & Printers"
    case notifications = "Notifications"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .general: return "gearshape"
        case .formatChooser: return "list.bullet.rectangle"
        case .discImageDepot: return "arrow.down.doc.fill"
        case .audioVideo: return "waveform"
        case .rippingTranscoding: return "arrow.triangle.2.circlepath"
        case .burnersNetwork: return "externaldrive.connected.to.line.below"
        case .labelsPrinters: return "printer.dotmatrix"
        case .notifications: return "bell"
        }
    }
}

public struct KroutonSettingsWindowView: View {
    @ObservedObject var store: KroutonStateStore
    @State private var selectedPane: KroutonSettingsCategory = .general
    @State private var searchText: String = ""

    // Finder-Style Table Sort & Filter State for Format Chooser
    @State private var formatFilter: FormatFilterGroup = .all
    @State private var formatSortOrder: [KeyPathComparator<DiscFormatSpec>] = [
        .init(\.technicalName, order: .forward)
    ]
    @State private var selectedFormatIDs: Set<DiscFormatSpec.ID> = []
    @AppStorage("KroutonFormatTableColumnCustomization") private var columnCustomization: TableColumnCustomization<DiscFormatSpec>

    // Labels & Printers New Preset State
    @State private var newPresetName: String = "Custom Disc Tray Preset"
    @State private var newOuterMM: Double = 120.0
    @State private var newInnerMM: Double = 18.0
    @State private var newOffsetX: Double = 0.0
    @State private var newOffsetY: Double = 0.0

    public init(store: KroutonStateStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search settings", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
                .padding(.horizontal, 10)
                .padding(.top, 8)

                List(KroutonSettingsCategory.allCases, selection: $selectedPane) { pane in
                    HStack(spacing: 10) {
                        Image(systemName: pane.sfSymbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedPane == pane ? store.activeAccent : .secondary)
                            .frame(width: 20)
                        Text(pane.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.vertical, 4)
                    .tag(pane)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 250)
        } detail: {
            Group {
                if selectedPane == .formatChooser {
                    // Full-height native Finder List View table for Format Chooser
                    formatChooserPane
                        .padding(24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(selectedPane.rawValue)
                                .font(.title2.bold())

                            switch selectedPane {
                            case .general:
                                generalPane
                            case .formatChooser:
                                EmptyView()
                            case .discImageDepot:
                                discImageDepotPane
                            case .audioVideo:
                                audioVideoPane
                            case .rippingTranscoding:
                                rippingTranscodingPane
                            case .burnersNetwork:
                                burnersNetworkPane
                            case .labelsPrinters:
                                labelsPrintersPane
                            case .notifications:
                                notificationsPane
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 980, idealWidth: 1120, minHeight: 600, idealHeight: 720)
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .tint(store.activeAccent)
    }

    // MARK: - 1. GENERAL PANE (Rainbow Order Accent Dots, No Menu Bar Clutter, Choose Folder Button)
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Appearance & Accent Color") {
                HStack {
                    Text("Appearance")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            pillToggleButton(
                                title: mode.rawValue,
                                sfSymbol: mode.sfSymbol,
                                isSelected: store.appearanceMode == mode
                            ) {
                                store.appearanceMode = mode
                            }
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Accent Color")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(AccentColorPreset.allPresets) { preset in
                            Button {
                                store.selectedAccentIndex = preset.id
                            } label: {
                                ZStack {
                                    if preset.isMonochrome {
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    colors: [.white, .white, .black, .black],
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 22, height: 22)
                                    } else {
                                        Circle()
                                            .fill(preset.primary)
                                            .frame(width: 22, height: 22)
                                    }
                                    Circle()
                                        .stroke(
                                            store.selectedAccentIndex == preset.id ? Color.primary : Color.secondary.opacity(0.35),
                                            lineWidth: store.selectedAccentIndex == preset.id ? 2.5 : 1.0
                                        )
                                        .frame(width: 26, height: 26)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            settingsCard(title: "Startup & Units") {
                Toggle("Remember Last Used Task on Launch", isOn: $store.rememberLastTaskOnLaunch)
                Divider()
                HStack {
                    Text("Capacity & Addressing Units")
                    Spacer()
                    HStack(spacing: 8) {
                        pillToggleButton(title: "Base-10 (4.7 GB / 25 GB)", sfSymbol: "opticaldisc", isSelected: store.useBase10Units) {
                            store.useBase10Units = true
                        }
                        pillToggleButton(title: "Binary (4.37 GiB / LBA)", sfSymbol: "number.square", isSelected: !store.useBase10Units) {
                            store.useBase10Units = false
                        }
                    }
                }
            }

            settingsCard(title: "Scratch Disk & System Permissions") {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temporary Mastering Cache")
                        Text("Available Free Space: 412.8 GB on Macintosh HD (APFS)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Path", text: $store.scratchDiskPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    pillToggleButton(title: "Choose...", sfSymbol: "folder.fill", isSelected: false) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            store.scratchDiskPath = url.path
                        }
                    }
                }
                Divider()
                Toggle("Automatically purge temporary muxing files after verified burn", isOn: $store.autoPurgeScratch)
                Divider()
                HStack(spacing: 18) {
                    Label("Optical MMC Access: Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label("Local Network Discovery: Active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label("FSKit Mount Extension: Registered", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - 2. FORMAT CHOOSER PANE (True macOS Finder List View Table: Sort, Resize & Rearrange Columns)
    private var filteredAndSortedFormats: [DiscFormatSpec] {
        let filtered = store.discFormats.filter { fmt in
            switch formatFilter {
            case .all: return true
            case .enabled: return fmt.showInTaskChooser
            default: return fmt.filterGroup == formatFilter
            }
        }
        return filtered.sorted(using: formatSortOrder)
    }

    private var formatChooserPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Format Chooser")
                        .font(.title2.bold())
                    Text("Click any column header to sort, drag column dividers to resize width, or drag headers to rearrange columns (just like Finder List View).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                pillToggleButton(title: "Enable All", sfSymbol: "checkmark.circle", isSelected: false) {
                    for i in store.discFormats.indices { store.discFormats[i].showInTaskChooser = true }
                }
            }

            // Filter Pills Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FormatFilterGroup.allCases) { group in
                        pillToggleButton(
                            title: group.rawValue,
                            sfSymbol: "line.3.horizontal.decrease.circle",
                            isSelected: formatFilter == group
                        ) {
                            formatFilter = group
                        }
                    }
                }
            }

            // Native macOS Finder List View Table
            Table(of: DiscFormatSpec.self, selection: $selectedFormatIDs, sortOrder: $formatSortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Show", value: \.visibilitySortKey) { fmt in
                    Toggle("", isOn: Binding(
                        get: { fmt.showInTaskChooser },
                        set: { _ in store.toggleFormatVisibility(id: fmt.id) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .width(min: 46, ideal: 54, max: 64)
                .customizationID("col-show")

                // Two-line Format column: Line 1 = Official Technical Name, Line 2 = Colloquial Name underneath
                TableColumn("Format", value: \.technicalName) { fmt in
                    HStack(spacing: 8) {
                        Image(systemName: fmt.sfSymbol)
                            .foregroundStyle(store.activeAccent)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fmt.technicalName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(fmt.colloquialName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .width(min: 200, ideal: 265, max: 420)
                .customizationID("col-format")

                TableColumn("Year", value: \.launchYear) { fmt in
                    Text(fmt.launchYear)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 50, ideal: 58, max: 80)
                .customizationID("col-year")

                TableColumn("Capacity", value: \.capacityGB) { fmt in
                    Text(fmt.capacity)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 95, ideal: 115, max: 160)
                .customizationID("col-capacity")

                TableColumn("Laser", value: \.laserType) { fmt in
                    Text(fmt.laserType)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 80, ideal: 95, max: 140)
                .customizationID("col-laser")

                TableColumn("Platform / Plays On", value: \.platform) { fmt in
                    Text(fmt.platform)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .width(min: 140, ideal: 185, max: 300)
                .customizationID("col-platform")

                TableColumn("Status", value: \.deprecationStatus) { fmt in
                    Text(fmt.deprecationStatus)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fmt.deprecationStatus == "Current" ? .green : .secondary)
                }
                .width(min: 85, ideal: 105, max: 150)
                .customizationID("col-status")

                TableColumn("Standard / Mode", value: \.bookOrFileSystem) { fmt in
                    Text("\(fmt.sourceSupport) • \(fmt.bookOrFileSystem)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .width(min: 170, ideal: 230, max: 380)
                .customizationID("col-standard")
            } rows: {
                ForEach(filteredAndSortedFormats) { fmt in
                    TableRow(fmt)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - 3. DISC IMAGE DEPOT PANE (Curated OS, Rescue & Archive.org Channels)
    private var discImageDepotPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Disc Image Depot — Subscribed Channels & Repositories") {
                ForEach(Array(store.depotChannels.enumerated()), id: \.element.id) { idx, channel in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: channel.sfSymbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(channel.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("\(channel.itemCount) Images")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(store.activeAccent.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                Text(channel.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $store.depotChannels[idx].isEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        if idx < store.depotChannels.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "Verification, Virtualization Test-Boot & Custom Feeds") {
                Toggle("Automatically verify SHA-256 / PGP signatures on downloaded Depot images before burning", isOn: $store.autoVerifyDepotSHA256)
                Divider()
                Toggle("Enable Apple Virtualization.framework 'Test-Boot in VM' button for El Torito / UEFI images", isOn: $store.enableVMTestBootInDepot)
                Divider()
                HStack {
                    Text("Custom Community Depot Manifest URL")
                    Spacer()
                    TextField("https://...", text: $store.customDepotFeedURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                }
            }
        }
    }

    // MARK: - 4. AUDIO & VIDEO PANE (Includes Fit-to-Disc Defaults)
    private var audioVideoPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Red Book Audio CD & Jam Crossfade Defaults") {
                Toggle("Analyze BPM & Beat Grid automatically via Apple SoundAnalysis on import", isOn: $store.autoBeatmatchSoundAnalysis)
                Divider()
                HStack {
                    Text(String(format: "Default Equal-Power Crossfade Overlap: %.1f seconds", store.defaultCrossfadeSec))
                    Spacer()
                    Slider(value: $store.defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                        .frame(width: 220)
                }
                Divider()
                Toggle("Car-Stereo Safe MP3 Mode (Enforce ID3v2.3 & strip hidden macOS ._* files)", isOn: $store.carSafeMP3Mode)
            }

            settingsCard(title: "Video Authoring & Menu Defaults") {
                Toggle("Single Video Track: Play immediately on disc insert (skip menu)", isOn: $store.singleVideoFirstPlay)
                Divider()
                Toggle("Use Apple Silicon VideoToolbox 2-Pass Hardware VBR for Blu-ray & DVD encoding", isOn: $store.videoToolboxTwoPassVBR)
            }

            settingsCard(title: "Fit-to-Disc Compression Defaults (DVD-9 to 4.7 GB DVD-5 & BD-50 to BD-25)") {
                Toggle("Always preserve interactive Menus, Chapter Tables & Bonus Featurettes when shrinking", isOn: $store.fitToDiscPreserveMenus)
                Divider()
                Toggle("Automatically strip foreign audio dubs (retain Original Language + English) to maximize video bitrate", isOn: $store.fitToDiscStripForeignDubs)
            }
        }
    }

    // MARK: - 5. RIPPING & TRANSCODING PANE (With Interactive Active Token Tray)
    private var rippingTranscodingPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Optical Drive Read Offset & Error Recovery (CD / DVD / BD Ripping)") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Drive Sample Read Offset Correction")
                        Text("Compensates for physical laser lead-in/lead-out offset on Pioneer/LG drives")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Offset", value: $store.driveReadOffsetSamples, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("samples")
                        .font(.caption)
                }
                Divider()
                HStack {
                    Text("Paranoia Scratched Sector Re-Read Retries")
                    Spacer()
                    Stepper("\(store.paranoiaErrorRetries) passes", value: $store.paranoiaErrorRetries, in: 1...64)
                }
                Divider()
                Toggle("Verify ripped audio tracks against AccurateRip & MusicBrainz database", isOn: $store.verifyAccurateRip)
                Divider()
                Toggle("Generate archival .cue sheet and extraction .log alongside ALAC / FLAC rips", isOn: $store.writeCueSheetLog)
            }

            settingsCard(title: "Video Disc Extraction & Hardware VideoToolbox") {
                Toggle("Hardware Motion-Compensated Deinterlacing (480i / 1080i -> Progressive H.265)", isOn: $store.hardwareDeinterlaceVideo)
                Divider()
                Toggle("Passthrough lossless Dolby Atmos / TrueHD / DTS-HD Master Audio bitstreams", isOn: $store.passthroughAtmosTrueHD)
            }

            settingsCard(title: "Smart File & Track Naming Pattern (Zero-Script Token Builder)") {
                Text("Click tokens below to append to your active naming pattern, or click any active token pill to remove it:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(["[Track 01]", "[Artist]", "[Album]", "[Title]", "[Year]", " - ", "/"], id: \.self) { token in
                        pillToggleButton(title: token, sfSymbol: "plus.circle", isSelected: false) {
                            store.namingTokens.append(token)
                        }
                    }
                    Spacer()
                    Button("Reset Default") {
                        store.namingTokens = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
                    }
                }

                Divider()

                // Active Token Sequence Tray
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Active Pattern:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(Array(store.namingTokens.enumerated()), id: \.offset) { idx, tok in
                            Button {
                                store.namingTokens.remove(at: idx)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tok)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.activeAccent.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Live Output Preview: \(store.namingPreviewString)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
        }
    }

    // MARK: - 6. BURNERS & NETWORK PANE (With Discovered Hardware Status Table)
    private var burnersNetworkPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Discovered Local & Network Optical Burners") {
                ForEach(Array(store.discoveredBurners.enumerated()), id: \.element.id) { idx, drive in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: drive.isNetworkNode ? "server.rack" : "opticaldiscdrive.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(drive.name)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(drive.firmware)
                                        .font(.system(size: 10, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                Text("\(drive.connectionBus) • \(drive.capabilities)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(drive.statusBadge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if idx < store.discoveredBurners.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "Network Optical Server (krouton-node) & Buffer Protection") {
                Toggle("Share this Mac's connected optical drives on the local network", isOn: $store.enableNetworkServerSharing)
                Divider()
                HStack {
                    Text("Server RAM Ring Buffer Allocation: \(Int(store.serverRingBufferMB)) MB")
                    Spacer()
                    Slider(value: $store.serverRingBufferMB, in: 64...1024, step: 64)
                        .frame(width: 220)
                }
                Divider()
                Toggle("Pre-stage full compiled disc image to remote server SSD before igniting laser", isOn: $store.preStageImageToServerSSD)
            }

            settingsCard(title: "Optical Drive Hardware & MMC Bitsetting") {
                Toggle("Force DVD+R / DVD+R DL BookType to DVD-ROM (Maximizes standalone player compatibility)", isOn: $store.forceDVDROMBookType)
                Divider()
                Toggle("Disable BD-R Defect Management Spare Area on Video Blu-rays (Enables full rated write speed)", isOn: $store.disableBDDefectManagementForVideo)
            }
        }
    }

    // MARK: - 7. LABELS & PRINTERS PANE (Dedicated Category)
    private var labelsPrintersPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Saved Disc Label Geometry & Tray Offset Presets (Epson EcoTank ET-8550 & Standard Trays)") {
                ForEach(Array(store.labelPresets.enumerated()), id: \.element.id) { idx, preset in
                    HStack {
                        Image(systemName: "circle.circle")
                            .foregroundStyle(store.activeAccent)
                        Text(preset.name)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "Outer: %.1fmm | Hole: %.1fmm | Offset X:%.1f Y:%.1fmm", preset.outerDiameterMM, preset.innerDiameterMM, preset.offsetXMM, preset.offsetYMM))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if store.labelPresets.count > 1 {
                            Button {
                                store.labelPresets.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Divider()
                }

                HStack(spacing: 10) {
                    TextField("Preset Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                    Text("Outer:")
                        .font(.caption)
                    TextField("120", value: $newOuterMM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                    Text("Inner:")
                        .font(.caption)
                    TextField("18", value: $newInnerMM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("X/Y Offset:")
                        .font(.caption)
                    TextField("0.0", value: $newOffsetX, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 45)
                    TextField("0.0", value: $newOffsetY, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 45)
                    Spacer()
                    Button {
                        store.labelPresets.append(
                            LabelGeometryPreset(
                                name: newPresetName,
                                outerDiameterMM: newOuterMM,
                                innerDiameterMM: newInnerMM,
                                offsetXMM: newOffsetX,
                                offsetYMM: newOffsetY
                            )
                        )
                    } label: {
                        Label("Save Preset", systemImage: "plus.circle.fill")
                    }
                }
            }

            settingsCard(title: "Automatic Label Artwork Lookup & Vision Hole-Avoidance") {
                Toggle("Use Apple Vision Subject Detection to keep faces/logos out of the 18mm center hole", isOn: $store.visionHoleAvoidance)
                Divider()
                Text("Zero-Key Databases Enabled: MusicBrainz / Cover Art Archive, Apple iTunes, TVMaze, GameTDB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField("Optional TMDB API Key (Movies & TV)", text: $store.customTMDBKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Optional Fanart.tv Key (Transparent Circular Disc Art)", text: $store.customFanartKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - 8. NOTIFICATIONS PANE (CCC 4-Icon Toggle Row)
    private var notificationsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Alerts, iPhone Live Activities & Apple Watch Notifications") {
                ForEach(Array(store.notificationMatrix.enumerated()), id: \.element.id) { idx, row in
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.eventTitle)
                                    .font(.system(size: 13, weight: .medium))
                                Text(row.eventSubtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                iconCircleToggle(
                                    sfSymbol: "bell.fill",
                                    helpText: "macOS Notification Banner",
                                    isOn: $store.notificationMatrix[idx].bannerEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "iphone",
                                    helpText: "iPhone Live Activity",
                                    isOn: $store.notificationMatrix[idx].iPhoneEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "applewatch",
                                    helpText: "Apple Watch Smart Stack & Wrist Tap",
                                    isOn: $store.notificationMatrix[idx].watchEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "speaker.wave.2.fill",
                                    helpText: "Play Audio Alert Sound",
                                    isOn: $store.notificationMatrix[idx].soundEnabled
                                )
                            }
                        }
                        if idx < store.notificationMatrix.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                Label("macOS Notification Center", systemImage: "bell.fill")
                Label("iPhone Live Activity", systemImage: "iphone")
                Label("Apple Watch Alert", systemImage: "applewatch")
                Label("Sound Effect", systemImage: "speaker.wave.2.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func pillToggleButton(title: String, sfSymbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? store.activeAccent.opacity(0.22) : Color(NSColor.windowBackgroundColor))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? store.activeAccent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.5 : 1.0)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconCircleToggle(sfSymbol: String, helpText: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: sfSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isOn.wrappedValue ? store.activeAccent : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
EOF_SETTINGS
echo "[OK] Wrote Sources/KroutonApp/KroutonSettingsWindow.swift"

cat << 'EOF_APP' > Sources/KroutonApp/KroutonApp.swift
import SwiftUI
import AppKit
import OpticalDough

@MainActor
final class KroutonWindowManager {
    static let shared = KroutonWindowManager()
    private var settingsWindow: NSWindow?

    func openSettingsWindow(store: KroutonStateStore) {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: KroutonSettingsWindowView(store: store))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Krouton Settings"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("KroutonSettingsWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }
}

final class KroutonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

@main
struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) var appDelegate
    @StateObject private var store = KroutonStateStore()
    @StateObject private var driveManager = DriveManager()

    var body: some Scene {
        WindowGroup("Krouton") {
            KroutonMainWorkspaceView(store: store, driveManager: driveManager)
                .preferredColorScheme(store.appearanceMode.colorScheme)
                .tint(store.activeAccent)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    KroutonWindowManager.shared.openSettingsWindow(store: store)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

struct KroutonMainWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: DriveManager

    @State private var enableCustomFinderLayoutTab: Bool = false
    @State private var activeDataWorkspaceTab: Int = 0
    @State private var finderBgColor: Color = Color(red: 0.13, green: 0.17, blue: 0.24)
    @State private var finderIconSize: Double = 256
    @State private var fitToDiscDVD9Shrink: Bool = true
    @State private var preserveMenusAndExtras: Bool = true
    @State private var labelDiscTitle: String = "THE KROUTON ARCHIVE"
    @State private var labelSubtitle: String = "2026 MASTER EDITION"
    @State private var autoLabelSearchQuery: String = "Dark Side of the Moon"
    @State private var depotSearchQuery: String = ""

    var body: some View {
        VStack(spacing: 0) {
            topProToolbar
            Divider()

            HSplitView {
                leftFormatChooserColumn
                    .frame(minWidth: 265, idealWidth: 285, maxWidth: 325)

                centerAdaptableWorkspace
                    .frame(minWidth: 580, maxWidth: .infinity, maxHeight: .infinity)

                rightDestinationColumn
                    .frame(minWidth: 320, idealWidth: 350, maxWidth: 390)
            }
        }
        .frame(minWidth: 1280, idealWidth: 1380, minHeight: 820, idealHeight: 880)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var topProToolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("KROUTON")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("Optical Mastering & Archival Suite")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(store.activeAccent)
                    .font(.system(size: 11))
                Text(store.useBase10Units ? "3.42 GB of 4.7 GB Staged" : "3.18 GiB of 4.37 GiB (1,793,024 LBA)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                ProgressView(value: 3.42, total: 4.7)
                    .tint(store.activeAccent)
                    .frame(width: 120)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Capsule())

            Spacer()

            HStack(spacing: 8) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text("Settings...")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(store.activeAccent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - LEFT COLUMN: FORMAT CHOOSER (BURN / DISC IMAGE DEPOT / COPY / LABEL)
    private var leftFormatChooserColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("FORMAT CHOOSER", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Configure visible formats in Settings -> Format Chooser")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. BURN CATEGORY
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BURN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(store.discFormats.filter { $0.showInTaskChooser }) { fmt in
                            taskRowButton(
                                id: fmt.id,
                                category: .burn,
                                title: fmt.technicalName,
                                colloquial: fmt.colloquialName,
                                badge: fmt.sourceSupport,
                                sfSymbol: fmt.sfSymbol
                            )
                        }
                    }

                    // 2. DISC IMAGE DEPOT CATEGORY (App Store for Bootable / Rescue / Archival ISOs)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DISC IMAGE DEPOT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "depot-rescue",
                            category: .depot,
                            title: "System Rescue & BIOS",
                            colloquial: "SystemRescue, GParted, FreeDOS 1.4",
                            badge: "Get ISO",
                            sfSymbol: "cross.case.fill"
                        )
                        taskRowButton(
                            id: "depot-linux-win",
                            category: .depot,
                            title: "Live OS & Installers",
                            colloquial: "Ubuntu, Fedora, Windows 11 API",
                            badge: "Get ISO",
                            sfSymbol: "terminal.fill"
                        )
                        taskRowButton(
                            id: "depot-archive-mac",
                            category: .depot,
                            title: "Vintage Apple & Archive.org",
                            colloquial: "Mac OS 9.2.2, System 7.5, Shareware",
                            badge: "Vault",
                            sfSymbol: "desktopcomputer"
                        )
                    }

                    // 3. COPY CATEGORY
                    VStack(alignment: .leading, spacing: 4) {
                        Text("COPY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "copy-duplicate",
                            category: .copy,
                            title: "Duplicate Disc",
                            colloquial: "Fit-to-Disc DVD-9 / BD Shrink",
                            badge: "1:1 / Fit",
                            sfSymbol: "doc.on.doc.fill"
                        )
                        taskRowButton(
                            id: "copy-rip-audio",
                            category: .copy,
                            title: "Rip Audio CD",
                            colloquial: "ALAC, AAC, FLAC + AccurateRip",
                            badge: "Extract",
                            sfSymbol: "waveform.badge.plus"
                        )
                        taskRowButton(
                            id: "copy-rip-video",
                            category: .copy,
                            title: "Extract Video Disc",
                            colloquial: "Hardware H.265 / HEVC Passthrough",
                            badge: "H.265",
                            sfSymbol: "film.stack"
                        )
                    }

                    // 4. LABEL CATEGORY
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LABEL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "label-auto",
                            category: .label,
                            title: "Automatic Disc Label",
                            colloquial: "Artwork Lookup + Hole Avoidance",
                            badge: "120mm",
                            sfSymbol: "wand.and.stars"
                        )
                        taskRowButton(
                            id: "label-manual",
                            category: .label,
                            title: "Manual Disc Label",
                            colloquial: "120mm / 18mm Canvas Studio",
                            badge: "Custom",
                            sfSymbol: "printer.dotmatrix.fill"
                        )
                    }
                }
                .padding(10)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func taskRowButton(id: String, category: TaskMasterCategory, title: String, colloquial: String, badge: String, sfSymbol: String) -> some View {
        let isSelected = (store.selectedTaskID == id)
        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            syncDefaultDestinationForCategory(category, taskID: id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : store.activeAccent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                    Text(colloquial)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? store.activeAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE
    private var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch store.selectedCategory {
            case .burn:
                burnWorkspaceView
            case .depot:
                depotWorkspaceView
            case .copy:
                copyWorkspaceView
            case .label:
                labelWorkspaceView
            }
        }
        .padding(18)
    }

    // Storefront Workspace for Disc Image Depot
    private var depotWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disc Image Depot — Verified Bootable & Archival Storefront")
                        .font(.title3.bold())
                    Text("One-click download, SHA-256 verification, Virtualization.framework VM test-boot, and direct hardware burning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Depot & archive.org...", text: $depotSearchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.depotItems) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                                .frame(width: 36, height: 36)
                                .background(store.activeAccent.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(item.version)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                    Text(item.channel)
                                        .font(.system(size: 10))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text(item.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("Boot Spec: \(item.bootStandard) • Arch: \(item.architecture) • Size: \(item.sizeDisplay) • SHA-256: \(item.sha256Short)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if store.enableVMTestBootInDepot {
                                Button {
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.desktopcomputer")
                                        Text("Test in VM")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.windowBackgroundColor))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: item.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                    Text(item.isDownloaded ? "Staged Ready" : "Get & Stage")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(item.isDownloaded ? Color.green.opacity(0.2) : store.activeAccent)
                                .foregroundStyle(item.isDownloaded ? .green : .white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var burnWorkspaceView: some View {
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID }) ?? store.discFormats[0]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: activeSpec.sfSymbol)
                            .foregroundStyle(store.activeAccent)
                        Text(activeSpec.technicalName)
                            .font(.title3.bold())
                        Text(activeSpec.colloquialName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Spec: \(activeSpec.bookOrFileSystem) • Laser: \(activeSpec.laserType) • Launched: \(activeSpec.launchYear) • Source: \(activeSpec.sourceSupport)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.folder.fill")
                        Text(activeSpec.sourceSupport == "Image Only" ? "Select Disc Image / ROM..." : "Add Media or Files...")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider()

            if activeSpec.isMediaPlaylist {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Track Playlist & Subcode / Chapter Inspector", systemImage: "music.note.list")
                            .font(.headline)
                        Spacer()
                        Label(String(format: "Auto-Crossfade: %.1fs (SoundAnalysis Active)", store.defaultCrossfadeSec), systemImage: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundStyle(store.activeAccent)
                    }

                    VStack(spacing: 0) {
                        playlistRow(num: "01", title: "Analogue Horizon (Master Take)", duration: "04:18:22", transition: "2.0s Pre-Gap", info: "ISRC: US-KR1-26-00001 • CD-TEXT")
                        Divider()
                        playlistRow(num: "02", title: "Oakland Midnight Transit", duration: "05:02:10", transition: String(format: "%.1fs Equal-Power Crossfade", store.defaultCrossfadeSec), info: "ISRC: US-KR1-26-00002 • 124 BPM")
                        Divider()
                        playlistRow(num: "03", title: "Pacific Fog & Neon", duration: "06:44:00", transition: "0.0s Gapless Lock", info: "ISRC: US-KR1-26-00003 • 124 BPM")
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Transition Crossfade Envelope (Track 01 -> Track 02)")
                                .font(.caption.bold())
                            Spacer()
                            Slider(value: $store.defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                                .frame(width: 180)
                        }
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.75))
                                .frame(height: 110)
                            HStack(spacing: 0) {
                                Text("Outgoing Track 01 Fade-Out")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .padding(.leading, 14)
                                Spacer()
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 36))
                                    .foregroundStyle(store.activeAccent)
                                Spacer()
                                Text("Incoming Track 02 Beat-Locked Fade-In")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                                    .padding(.trailing, 14)
                            }
                        }
                    }
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            activeDataWorkspaceTab = 0
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet.indent")
                                Text(activeSpec.filterGroup == .console ? "ROM Sector & Partition Inspector" : "File System Tree")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activeDataWorkspaceTab == 0 ? store.activeAccent.opacity(0.22) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if activeSpec.isDataDisc {
                            Toggle("Customize Finder & Explorer Window Layout", isOn: $enableCustomFinderLayoutTab)
                                .toggleStyle(.checkbox)
                                .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                    activeDataWorkspaceTab = enabled ? 1 : 0
                                }

                            if enableCustomFinderLayoutTab {
                                Button {
                                    activeDataWorkspaceTab = 1
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "macwindow.badge.plus")
                                        Text("Custom Window & Icons Tab")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(activeDataWorkspaceTab == 1 ? store.activeAccent.opacity(0.22) : Color.clear)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                    }

                    if activeDataWorkspaceTab == 1 && enableCustomFinderLayoutTab && activeSpec.isDataDisc {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 20) {
                                ColorPicker("Finder Window Background:", selection: $finderBgColor)
                                HStack {
                                    Text("Icon Size: \(Int(finderIconSize)) px")
                                        .font(.caption)
                                    Slider(value: $finderIconSize, in: 64...512, step: 32)
                                        .frame(width: 160)
                                }
                            }
                            RoundedRectangle(cornerRadius: 12)
                                .fill(finderBgColor)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay(
                                    HStack(spacing: 42) {
                                        VStack {
                                            Image(systemName: "app.gift.fill")
                                                .font(.system(size: min(finderIconSize * 0.28, 96)))
                                                .foregroundStyle(.white)
                                            Text("Krouton_Archive.pkg")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                        VStack {
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: min(finderIconSize * 0.28, 96)))
                                                .foregroundStyle(store.activeAccent)
                                            Text("Extras & Artwork")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                )
                        }
                    } else {
                        VStack(spacing: 0) {
                            playlistRow(num: "SEC", title: activeSpec.filterGroup == .console ? "Disc Header & Region Boot Sector" : "/Applications & Utilities", duration: "1.84 GB", transition: activeSpec.bookOrFileSystem, info: "Verified")
                            Divider()
                            playlistRow(num: "DAT", title: activeSpec.filterGroup == .console ? "Primary Game Partition Stream" : "/Project_Masters_2026", duration: "1.58 GB", transition: activeSpec.laserType, info: "SHA-256 Verified")
                            Divider()
                            playlistRow(num: "SYS", title: activeSpec.filterGroup == .console ? "EDC / ECC Subchannel Integrity" : ".DS_Store & autorun.inf", duration: "64 KB", transition: "Ready", info: "Auto-Generated")
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                }
            }
        }
    }

    private var copyWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedTaskID == "copy-duplicate" ? "Duplicate Disc & Fit-to-Disc Requantizer" : "Optical Media Extractor & Archival Ripper")
                        .font(.title3.bold())
                    Text("Source Drive: Pioneer BDR-S13U-X — Disc Detected: Dual-Layer Movie DVD-9 (7.94 GB)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Fit to Disc — Automatically shrink DVD-9 (8.5 GB) to standard 4.7 GB DVD-5", isOn: $fitToDiscDVD9Shrink)
                    .font(.headline)
                Toggle("Preserve Interactive Menus, Chapter Tables & Bonus Extras", isOn: $preserveMenusAndExtras)
                Divider()
                playlistRow(num: "VTS_01", title: "Main Feature Movie (1080p / 480p MPEG-2)", duration: "01:58:14", transition: fitToDiscDVD9Shrink ? "Requantized -> 3.62 GB" : "Original 6.40 GB", info: "AC-3 5.1 + Subtitles")
                playlistRow(num: "VMGM", title: "Interactive Motion Menus & Chapter Selector", duration: "00:04:12", transition: "100% Intact (340 MB)", info: "Zero Menu Loss")
                playlistRow(num: "VTS_02", title: "Director Commentary & Making-Of Featurettes", duration: "00:32:40", transition: "Requantized -> 420 MB", info: "Preserved")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
    }

    private var labelWorkspaceView: some View {
        let preset = store.labelPresets[min(store.selectedLabelPresetIndex, store.labelPresets.count - 1)]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: store.selectedTaskID == "label-auto" ? "wand.and.stars" : "printer.dotmatrix.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedTaskID == "label-auto" ? "Automatic Disc Label (Artwork Lookup)" : "Manual 120mm Disc Label Canvas")
                        .font(.title3.bold())
                    Text(String(format: "Active Geometry Preset: %@ (Outer: %.1fmm / Hole: %.1fmm)", preset.name, preset.outerDiameterMM, preset.innerDiameterMM))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset:", selection: $store.selectedLabelPresetIndex) {
                    ForEach(Array(store.labelPresets.enumerated()), id: \.offset) { idx, item in
                        Text(item.name).tag(idx)
                    }
                }
                .frame(width: 260)
            }
            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    if store.selectedTaskID == "label-auto" {
                        Text("Automatic Album / Movie / Game Cover Lookup")
                            .font(.headline)
                        HStack {
                            TextField("Search Album, Movie, TV Show, or Game...", text: $autoLabelSearchQuery)
                                .textFieldStyle(.roundedBorder)
                            Button("Fetch Art") {}
                        }
                        Text("Queries MusicBrainz, iTunes, TVMaze & GameTDB. Uses Apple Vision to prevent the \(Int(preset.innerDiameterMM))mm hole from cropping faces.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                    }
                    Text("Disc Face Typography")
                        .font(.headline)
                    TextField("Primary Arc Title", text: $labelDiscTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bottom Subtitle / Track Summary", text: $labelSubtitle)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                }
                .frame(width: 300)

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [store.activeAccent.opacity(0.85), Color.black.opacity(0.92)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 150
                            )
                        )
                        .frame(width: 280, height: 280)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))

                    VStack {
                        Text(labelDiscTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 28)
                        Spacer()
                        Text(labelSubtitle)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 28)
                    }
                    .frame(width: 280, height: 280)

                    Circle()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(
                            width: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 280.0,
                            height: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 280.0
                        )
                        .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                }
                Spacer()
            }
            Spacer()
        }
    }

    private func playlistRow(num: String, title: String, duration: String, transition: String, info: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(store.activeAccent)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(info)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transition)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(store.activeAccent.opacity(0.15))
                .clipShape(Capsule())
            Text(duration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var rightDestinationColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("DESTINATIONS (\(store.destinationQueue.count))", systemImage: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appendContextAwareDestination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Output")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(store.destinationQueue.enumerated()), id: \.element.id) { idx, item in
                        destinationCard(index: idx, item: item)
                    }
                }
                .padding(12)
            }

            Divider()

            VStack(spacing: 8) {
                Button {
                } label: {
                    HStack {
                        Image(systemName: primaryActionSymbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(primaryActionTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(store.activeAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Server Ring Buffer: \(Int(store.serverRingBufferMB)) MB Ready • BookType: DVD-ROM")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func destinationCard(index: Int, item: DestinationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(store.activeAccent)
                Picker("", selection: $store.destinationQueue[index].kind) {
                    ForEach(allowedDestinationsForCurrentCategory) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                Spacer()
                if store.destinationQueue.count > 1 {
                    Button {
                        store.destinationQueue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(item.hardwareOrPath)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            HStack {
                Text("Profile / Speed:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.speedOrCodec)
                    .font(.caption.bold())
            }

            if item.kind == .physicalBurner || item.kind == .networkBurner {
                HStack(spacing: 12) {
                    Toggle("Simulate", isOn: $store.destinationQueue[index].simulationMode)
                        .font(.caption)
                    Toggle("Verify", isOn: $store.destinationQueue[index].verifyAfterBurn)
                        .font(.caption)
                }
            } else if item.kind == .discImage {
                Toggle("Compress Image After Creation", isOn: $store.destinationQueue[index].compressAfterCreation)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(store.activeAccent.opacity(0.35), lineWidth: 1)
        )
    }

    private var allowedDestinationsForCurrentCategory: [DestinationOutputKind] {
        switch store.selectedCategory {
        case .burn, .depot:
            return [.networkBurner, .physicalBurner, .discImage]
        case .copy:
            return [.networkBurner, .physicalBurner, .discImage, .audioRip, .videoExtract]
        case .label:
            return [.discPrinter, .pdfVector]
        }
    }

    private func syncDefaultDestinationForCategory(_ category: TaskMasterCategory, taskID: String) {
        switch category {
        case .burn, .depot:
            store.destinationQueue = [
                DestinationQueueItem(kind: .networkBurner, hardwareOrPath: "Pioneer BDR-S13U-X (krouton-server.local)", speedOrCodec: "8x CAV (Optimal)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            ]
        case .copy:
            if taskID == "copy-rip-audio" {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .audioRip, hardwareOrPath: "~/Music/Krouton Rips/Apple Lossless", speedOrCodec: "ALAC (.m4a) + AccurateRip", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            } else if taskID == "copy-rip-video" {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .videoExtract, hardwareOrPath: "~/Movies/Krouton Extracts", speedOrCodec: "H.265 (HEVC 10-bit Hardware)", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
                ]
            } else {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .networkBurner, hardwareOrPath: "Pioneer BDR-S13U-X (krouton-server.local)", speedOrCodec: "Fit-to-Disc 4.7 GB DVD-5", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            }
        case .label:
            store.destinationQueue = [
                DestinationQueueItem(kind: .discPrinter, hardwareOrPath: "Epson EcoTank Photo ET-8550 (CD/DVD Tray)", speedOrCodec: "Claria ET 6-Ink • 120mm / 18mm", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            ]
        }
    }

    private func appendContextAwareDestination() {
        switch store.selectedCategory {
        case .burn, .depot:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .discImage, hardwareOrPath: "~/Desktop/Krouton_Master.dmg", speedOrCodec: "Hybrid UDF / HFS+ Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: true)
            )
        case .copy:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .discImage, hardwareOrPath: "~/Desktop/Disc_Backup.iso", speedOrCodec: "1:1 Archival Sector Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            )
        case .label:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .pdfVector, hardwareOrPath: "~/Desktop/Epson_ET8550_Label_120mm.pdf", speedOrCodec: "300 DPI Vector PDF Proof", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            )
        }
    }

    private var primaryActionTitle: String {
        switch store.selectedCategory {
        case .burn: return "BURN (\(store.destinationQueue.count))"
        case .depot: return "GET & BURN ISO (\(store.destinationQueue.count))"
        case .copy: return "START COPY / EXTRACT (\(store.destinationQueue.count))"
        case .label: return "PRINT LABEL (\(store.destinationQueue.count))"
        }
    }

    private var primaryActionSymbol: String {
        switch store.selectedCategory {
        case .burn: return "flame.fill"
        case .depot: return "arrow.down.doc.fill"
        case .copy: return "doc.on.doc.fill"
        case .label: return "printer.fill"
        }
    }
}
EOF_APP
echo "[OK] Wrote Sources/KroutonApp/KroutonApp.swift"

swift build
git add -A
git commit -m "feat(ui): implement v0.1.0-alpha.6 Finder Table Format Chooser, Disc Image Depot, and 8-pane Settings" || true
echo "===================================================="
echo " [SUCCESS] Krouton v0.1.0-alpha.6 built & committed!"
echo " Switch to Xcode and press Command + R to launch."
echo "===================================================="
