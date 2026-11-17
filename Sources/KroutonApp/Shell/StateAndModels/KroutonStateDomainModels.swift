import LabelKit
import RescueKit
import ImageKit
import VideoKit
import AudioKit
import SwiftUI
import OpticalCore

public struct KroutonAccentColorPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let swatchColor: Color
    public let darkAccent: Color
    public let lightAccent: Color
    public let darkOnAccentText: Color
    public let lightOnAccentText: Color
    public let isMonochrome: Bool

    public func effectiveAccent(for scheme: ColorScheme?) -> Color {
        scheme == .light ? lightAccent : darkAccent
    }

    public func effectiveOnAccentText(for scheme: ColorScheme?) -> Color {
        scheme == .light ? lightOnAccentText : darkOnAccentText
    }

    public static let allPresets: [KroutonAccentColorPreset] = [
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

public enum KroutonRoastAppearanceMode: String, CaseIterable, Identifiable, Sendable {
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

public enum KroutonBurnFailureSeverity: String, Sendable {
    case criticalOverburn
    case warning4GBNoUDF
    case warningFilenameLength
    case warningConsoleMedia
}


public enum KroutonGarnishStyleMode: String, CaseIterable, Identifiable, Sendable {
    case defaultStyle = "Default"
    case dark = "Dark"
    case clear = "Clear"
    case tinted = "Tinted"
    public var id: String { rawValue }
}

public enum KroutonTrackIconSizeMode: String, CaseIterable, Identifiable, Sendable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    public var id: String { rawValue }

    public var iconFontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 15
        case .large: return 18
        }
    }

    public var titleFontSize: CGFloat {
        switch self {
        case .small: return 11.5
        case .medium: return 12.5
        case .large: return 14.0
        }
    }

    public var rowVerticalPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 9
        }
    }
}

public enum KroutonStageFolderColorMode: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case classicAqua = "Classic Aqua Blue"
    case accentTinted = "Theme Accent"
    case secondaryHarmony = "Secondary Harmony"
    case amberGold = "Amber Gold"
    case graphite = "Space Gray"
    public var id: String { rawValue }

    @MainActor
    public func resolvedFolderColor(accent: Color) -> Color {
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

public enum KroutonCroutonLabelStyle: String, CaseIterable, Identifiable, Sendable {
    case synthGrid     = "Synth Technical Grid"
    case vinylGrooves  = "Concentric Workspace Rings"
    case dualHalftone  = "Split-Harmony Radial"
    case archivalSpec  = "Minimalist Archival Spec"
    public var id: String { rawValue }
}

public enum KroutonLanguage: String, CaseIterable, Identifiable, Sendable {
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
    public var id: String { rawValue }

    public var isoCode: String {
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

public enum KroutonMasteringStation: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case depot = "DISC IMAGE DEPOT"
    case copy = "COPY"
    case label = "LABEL"
    public var id: String { rawValue }
}

public struct KroutonDepotCatalogItem: Identifiable, Hashable, Sendable {
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

public struct KroutonDepotFeedSubscription: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var itemCount: Int
    public var isEnabled: Bool
    public var sfSymbol: String
}

public struct KroutonDiscLabelGeometry: Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var outerDiameterMM: Double
    public var innerDiameterMM: Double
    public var offsetXMM: Double
    public var offsetYMM: Double
}

public struct KroutonKitchenEventRow: Identifiable, Hashable, Sendable {
    public let id: String
    public var eventTitle: String
    public var eventSubtitle: String
    public var bannerEnabled: Bool
    public var iPhoneEnabled: Bool
    public var watchEnabled: Bool
    public var soundEnabled: Bool
}

public enum KroutonBurnDestinationKind: String, CaseIterable, Identifiable, Codable, Sendable {
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

    public var compactBadgeTitle: String {
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

public struct KroutonBakeBatchItem: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID = UUID()
    public var kind: KroutonBurnDestinationKind
    public var targetDriveID: String = ""
    public var hardwareOrPath: String
    public var speedOrCodec: String
    public var simulationMode: Bool
    public var verifyAfterBurn: Bool
    public var compressAfterCreation: Bool
    public var copiesToBurn: Int = 1
    public var completedCopies: Int = 0
    /// Non-nil when managed by the multi-disc spanning engine (1 = Disc 1, 2 = Disc 2, etc.)
    public var spannedDiscNumber: Int? = nil
}
