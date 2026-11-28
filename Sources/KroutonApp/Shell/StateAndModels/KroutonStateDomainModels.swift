import BurnKit
import OpticalCore
import SwiftUI

// MARK: - KroutonStateDomainModels

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
        // 6: Workspace Slate Blue (Default)
        KroutonAccentColorPreset(id: 6, swatchColor: Color(red: 0.35, green: 0.52, blue: 0.78), darkAccent: Color(red: 0.38, green: 0.56, blue: 0.84), lightAccent: Color(red: 0.24, green: 0.42, blue: 0.68), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 7: Indigo / Violet
        KroutonAccentColorPreset(id: 7, swatchColor: Color.indigo, darkAccent: Color(red: 0.46, green: 0.42, blue: 0.92), lightAccent: Color.indigo, darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 8: Toasted Krouton Brown (Replaces Mauve/Pink!)
        KroutonAccentColorPreset(id: 8, swatchColor: Color(red: 0.64, green: 0.42, blue: 0.24), darkAccent: Color(red: 0.72, green: 0.49, blue: 0.30), lightAccent: Color(red: 0.52, green: 0.32, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 9: High-Contrast Black & White Monochrome (Silver-White w/ Black text in Dark mode; Graphite-Black w/ White text in Light mode)
        KroutonAccentColorPreset(id: 9, swatchColor: Color.primary, darkAccent: Color(white: 0.86), lightAccent: Color(white: 0.18), darkOnAccentText: Color.black.opacity(0.92), lightOnAccentText: .white, isMonochrome: true)
    ]
}

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

enum KroutonGarnishStyleMode: String, CaseIterable, Identifiable, Sendable {
    case defaultStyle = "Default"
    case dark = "Dark"
    case clear = "Clear"
    case tinted = "Tinted"
    var id: String { rawValue }
}

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

enum KroutonCroutonLabelStyle: String, CaseIterable, Identifiable, Sendable {
    case synthGrid     = "Synth Technical Grid"
    case vinylGrooves  = "Concentric Workspace Rings"
    case dualHalftone  = "Split-Harmony Radial"
    case archivalSpec  = "Minimalist Archival Spec"
    var id: String { rawValue }
}

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

enum KroutonMasteringStation: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case depot = "DISC IMAGE DEPOT"
    case copy = "COPY"
    case label = "LABEL"
    var id: String { rawValue }
}

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

struct KroutonDepotFeedSubscription: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var description: String
    var itemCount: Int
    var isEnabled: Bool
    var sfSymbol: String
}

struct KroutonDiscLabelGeometry: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var name: String
    var outerDiameterMM: Double
    var innerDiameterMM: Double
    var offsetXMM: Double
    var offsetYMM: Double
}

struct KroutonKitchenEventRow: Identifiable, Hashable, Sendable {
    let id: String
    var eventTitle: String
    var eventSubtitle: String
    var bannerEnabled: Bool
    var soundEnabled: Bool
    var sound: KroutonNotificationSound
}

/// Where a destination card sends the deck.
///
/// The raw values are persisted in saved queues and sessions, so they never change; what the
/// card shows is `title`. Two raw values are left from before the 2026-11 audit and overstate
/// what the card does: `.videoExtract` remuxes to MKV or copies MPEG (no H.265 transcode), and
/// `.discPrinter` writes the same 1:1 PDF + PNG print sheet as `.pdfVector` (it drives no disc
/// printer). Never show `rawValue` to a person.
/// A destination card's kind. The raw values are what saved sessions and projects store;
/// they're identifiers, never shown (`title` is).
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
    /// Non-nil when managed by the multi-disc spanning engine (1 = Disc 1, 2 = Disc 2, etc.)
    var spannedDiscNumber: Int? = nil
    /// Ticket currently assigned to this burner slot in the upper active queue.
    var assignedPoolTicket: KroutonPoolBurnTicket? = nil
    /// Ticket waiting for operator confirmation on this burner slot when in Ask/Manual mode.
    var pendingApprovalTicket: KroutonPoolBurnTicket? = nil
}

// MARK: - Burn Pool

/// A physical burner card takes tickets from the destination queue's burn pool.
extension KroutonBakeBatchItem: KroutonPoolSlotCard {
    var isPooledBurner: Bool { kind == .physicalBurner }
}
