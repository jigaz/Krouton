import BurnKit
import OpticalCore
import SwiftUI

// MARK: - Appearance Models

/// One accent colour in Settings › General, with its shades for dark and light mode and the
/// text colour that reads on it. `id` is what the preference stores; -1 is Multicolor, which
/// follows the system accent.
struct KroutonAccentColorPreset: Identifiable, Hashable, Sendable {
    let id: Int
    let swatchColor: Color
    let darkAccent: Color
    let lightAccent: Color
    let darkOnAccentText: Color
    let lightOnAccentText: Color
    let isMonochrome: Bool

    func effectiveAccent(for scheme: ColorScheme?) -> Color {
        scheme == .light ? lightAccent : darkAccent
    }

    func effectiveOnAccentText(for scheme: ColorScheme?) -> Color {
        scheme == .light ? lightOnAccentText : darkOnAccentText
    }

    static let allPresets: [KroutonAccentColorPreset] = [
        // -1: Multicolor (macOS System Settings Rainbow Wheel)
        KroutonAccentColorPreset(id: -1, swatchColor: Color.blue, darkAccent: Color(red: 0.32, green: 0.62, blue: 0.98), lightAccent: Color(red: 0.0, green: 0.44, blue: 0.92), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 0: Red
        KroutonAccentColorPreset(id: 0, swatchColor: Color(red: 0.90, green: 0.23, blue: 0.23), darkAccent: Color(red: 0.92, green: 0.26, blue: 0.26), lightAccent: Color(red: 0.82, green: 0.16, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 1: Orange
        KroutonAccentColorPreset(id: 1, swatchColor: Color.orange, darkAccent: Color.orange, lightAccent: Color(red: 0.88, green: 0.44, blue: 0.04), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 2: High-Contrast Gold / Yellow (Dark text on bright amber-gold in Dark mode; deep warm gold in Light mode)
        KroutonAccentColorPreset(id: 2, swatchColor: Color(red: 0.96, green: 0.78, blue: 0.12), darkAccent: Color(red: 0.95, green: 0.76, blue: 0.14), lightAccent: Color(red: 0.76, green: 0.53, blue: 0.02), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
        // 3: Green
        KroutonAccentColorPreset(id: 3, swatchColor: Color.green, darkAccent: Color(red: 0.18, green: 0.78, blue: 0.36), lightAccent: Color(red: 0.12, green: 0.62, blue: 0.26), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 4: Cyan / Teal
        KroutonAccentColorPreset(id: 4, swatchColor: Color(red: 0.08, green: 0.82, blue: 0.68), darkAccent: Color(red: 0.08, green: 0.82, blue: 0.68), lightAccent: Color(red: 0.05, green: 0.68, blue: 0.55), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
        // 5: 405nm Laser Blue
        KroutonAccentColorPreset(id: 5, swatchColor: Color.blue, darkAccent: Color.blue, lightAccent: Color(red: 0.0, green: 0.40, blue: 0.88), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 6: Slate Blue
        KroutonAccentColorPreset(id: 6, swatchColor: Color(red: 0.35, green: 0.52, blue: 0.78), darkAccent: Color(red: 0.38, green: 0.56, blue: 0.84), lightAccent: Color(red: 0.24, green: 0.42, blue: 0.68), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 7: Indigo / Violet
        KroutonAccentColorPreset(id: 7, swatchColor: Color.indigo, darkAccent: Color(red: 0.46, green: 0.42, blue: 0.92), lightAccent: Color.indigo, darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 8: Krouton Brown (the default)
        KroutonAccentColorPreset(id: 8, swatchColor: Color(red: 0.64, green: 0.42, blue: 0.24), darkAccent: Color(red: 0.72, green: 0.49, blue: 0.30), lightAccent: Color(red: 0.52, green: 0.32, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 9: High-Contrast Black & White Monochrome (Silver-White w/ Black text in Dark mode; Graphite-Black w/ White text in Light mode)
        KroutonAccentColorPreset(id: 9, swatchColor: Color.primary, darkAccent: Color(white: 0.86), lightAccent: Color(white: 0.18), darkOnAccentText: Color.black.opacity(0.92), lightOnAccentText: .white, isMonochrome: true)
    ]
}

/// Light, dark, or following the system. The raw values are saved, and shown as the labels.
enum KroutonRoastAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case dark = "Dark"
    case light = "Light"
    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

/// How icons are drawn (Settings › General › Icon & widget style), matching macOS's icon
/// styles. Also picks the Dock icon variant. The raw values are saved, and shown as the labels.
enum KroutonGarnishStyleMode: String, CaseIterable, Identifiable, Sendable {
    case defaultStyle = "Default"
    case dark = "Dark"
    case clear = "Clear"
    case tinted = "Tinted"
    var id: String { rawValue }
}

/// The Format Chooser's row size (Settings › General › Sidebar icon size).
enum KroutonTrackIconSizeMode: String, CaseIterable, Identifiable, Sendable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    var id: String { rawValue }

    var iconFontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 15
        case .large: return 18
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .small: return 11.5
        case .medium: return 12.5
        case .large: return 14.0
        }
    }

    var rowVerticalPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 9
        }
    }
}

/// The colour of folder icons on the deck (Settings › General › Folder color).
enum KroutonStageFolderColorMode: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case classicAqua = "Classic Aqua Blue"
    case accentTinted = "Theme Accent"
    case secondaryHarmony = "Secondary Harmony"
    case amberGold = "Amber Gold"
    case graphite = "Space Gray"
    var id: String { rawValue }

    @MainActor
    func resolvedFolderColor(accent: Color) -> Color {
        let store = KroutonStateStore.shared
        switch self {
        case .automatic:
            if let store, store.enableSecondaryAccentUITints {
                return store.activeSecondaryAccent
            }
            return accent
        case .accentTinted:
            return accent
        case .secondaryHarmony:
            return store?.activeSecondaryAccent ?? accent.perceptualSplitComplement
        case .classicAqua:
            return Color(red: 0.22, green: 0.64, blue: 0.96)
        case .amberGold:
            return Color.orange
        case .graphite:
            return Color.secondary
        }
    }
}

/// The disc label's background template. The raw values are saved in preferences and projects.
enum KroutonCroutonLabelStyle: String, CaseIterable, Identifiable, Sendable {
    case synthGrid     = "Synth Technical Grid"
    case vinylGrooves  = "Concentric Workspace Rings"
    case dualHalftone  = "Split-Harmony Radial"
    case archivalSpec  = "Minimalist Archival Spec"
    var id: String { rawValue }
}

/// The languages offered in Settings. The raw values are saved, and shown in the picker.
enum KroutonLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "System Default (Auto)"
    case english = "English (US)"
    case japanese = "日本語 (Japanese)"
    case german = "Deutsch (German)"
    case french = "Français (French)"
    case spanish = "Español (Spanish)"
    case italian = "Italiano (Italian)"
    case portuguese = "Português (Brasil)"
    case dutch = "Nederlands (Dutch)"
    case chineseSimplified = "简体中文 (Chinese)"
    case korean = "한국어 (Korean)"
    var id: String { rawValue }

    var isoCode: String {
        switch self {
        case .system: return Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        case .english: return "en"
        case .japanese: return "ja"
        case .german: return "de"
        case .french: return "fr"
        case .spanish: return "es"
        case .italian: return "it"
        case .portuguese: return "pt-BR"
        case .dutch: return "nl"
        case .chineseSimplified: return "zh-Hans"
        case .korean: return "ko"
        }
    }
}

// MARK: - Workspace and Depot Models

/// The four groups in the Format Chooser, each with its own workspace: Burn, Disc Image
/// Depot, Copy and Label. The raw values are saved as the last category; don't change them.
enum KroutonMasteringStation: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case depot = "DISC IMAGE DEPOT"
    case copy = "COPY"
    case label = "LABEL"
    var id: String { rawValue }
}

/// One disc image card in the Depot: from the depot.krouton.app feed or an Internet Archive search.
struct KroutonDepotCatalogItem: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var channel: String
    var version: String
    var sizeDisplay: String
    var architecture: String
    var bootStandard: String
    var sha256Short: String
    var sfSymbol: String
    var isDownloaded: Bool
    /// The depot.krouton.app entry this card shows; nil for Internet Archive search results.
    var feed: KroutonDepotFeed.Item? = nil
}

/// A section of the depot feed that can be shown or hidden (Settings › Disc Image Depot).
struct KroutonDepotFeedSubscription: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var description: String
    var itemCount: Int
    var isEnabled: Bool
    var sfSymbol: String
}

/// A disc size and tray offset preset for labels (Settings › Labels & Printers).
struct KroutonDiscLabelGeometry: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var name: String
    var outerDiameterMM: Double
    var innerDiameterMM: Double
    var offsetXMM: Double
    var offsetYMM: Double
}

/// One event in Settings › Notifications (a burn finished, a disc is needed…) with its banner,
/// sound and voice switches. `id` is the event's identifier, used to post it and to save it.
struct KroutonKitchenEventRow: Identifiable, Hashable, Sendable {
    let id: String
    var eventTitle: String
    var eventSubtitle: String
    var bannerEnabled: Bool
    var soundEnabled: Bool
    var sound: KroutonNotificationSound
}

// MARK: - Destination Cards

/// Where a destination card sends the deck. The raw values are what saved sessions and
/// projects store; they're identifiers, never shown (`title` is). Two case names are older
/// than what the cards do now: `.videoExtract` remuxes to MKV or copies MPEG (no transcode),
/// and `.discPrinter` writes a PDF and PNG print sheet (it drives no printer).
enum KroutonBurnDestinationKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case physicalBurner = "physical-burner"
    case networkBurner = "krouton-server"
    case discImage = "disc-image"
    case audioRip = "audio-rip"
    case videoExtract = "video-extract"
    case discPrinter = "label-print-sheet"
    case pdfVector = "label-pdf"
    var id: String { rawValue }

    /// The values saved before 2026-11-27, which described more than Krouton does
    /// ("Video Transcode (H.265 / HEVC)" only ever remuxed; "Disc Printer (Epson ET-8550)"
    /// writes files). Read, never written.
    private static let savedBefore20261127: [String: KroutonBurnDestinationKind] = [
        "Physical Burner": .physicalBurner,
        "Network Server Burner": .networkBurner,
        "Disc Image File": .discImage,
        "Audio Rip (ALAC / AAC / FLAC)": .audioRip,
        "Video Transcode (H.265 / HEVC)": .videoExtract,
        "Disc Printer (Epson ET-8550)": .discPrinter,
        "Vector PDF Label": .pdfVector,
    ]

    /// A kind from saved text, current or from before 2026-11-27; nil for one this version doesn't know.
    init?(storedValue: String) {
        guard let kind = Self(rawValue: storedValue) ?? Self.savedBefore20261127[storedValue] else { return nil }
        self = kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stored = try container.decode(String.self)
        guard let kind = Self(storedValue: stored) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown destination kind \(stored)")
        }
        self = kind
    }

    /// What the destination does, in the words the card and the notifications use.
    var title: String {
        switch self {
        case .physicalBurner: return "Burner on This Mac"
        case .networkBurner: return "Krouton Server"
        case .discImage: return "Disc Image File"
        case .audioRip: return "Audio Rip (FLAC / ALAC / WAV / AIFF)"
        case .videoExtract: return "Video Extract (MKV / MPEG)"
        case .discPrinter: return "Label Print Sheet (PDF + PNG)"
        case .pdfVector: return "Vector PDF Label"
        }
    }

    var sfSymbol: String {
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

    var compactBadgeTitle: String {
        switch self {
        case .physicalBurner: return "USB"
        case .networkBurner:  return "LAN"
        case .discImage:      return "ISO"
        case .audioRip:       return "Rip"
        case .videoExtract:   return "Video"
        case .discPrinter:    return "Print"
        case .pdfVector:      return "PDF"
        }
    }
}

/// One destination card in the queue: its kind, its drive or path, its speed or rip format,
/// and its copy and pool state. Saved with sessions and projects. `speedOrCodec` and
/// `hardwareOrPath` are text for older saved queues; use the typed accessors in
/// `KroutonStateDomainModels+CardPresets.swift`.
struct KroutonBakeBatchItem: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var kind: KroutonBurnDestinationKind
    var targetDriveID: String = ""
    var hardwareOrPath: String
    var speedOrCodec: String
    var simulationMode: Bool
    var verifyAfterBurn: Bool
    var compressAfterCreation: Bool
    var copiesToBurn: Int = 1
    var completedCopies: Int = 0
    /// Which disc of a spanned set this card burns (1 is Disc 1), or nil when there is one disc.
    var spannedDiscNumber: Int? = nil
    /// The pool ticket this burner card is working on.
    var assignedPoolTicket: KroutonPoolBurnTicket? = nil
    /// The next ticket, waiting for you to approve it (Ask / Manual mode).
    var pendingApprovalTicket: KroutonPoolBurnTicket? = nil
}

// MARK: - Burn Pool

/// A physical burner card takes tickets from the destination queue's burn pool.
extension KroutonBakeBatchItem: KroutonPoolSlotCard {
    var isPooledBurner: Bool { kind == .physicalBurner }
}
