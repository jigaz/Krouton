import SwiftUI
import Foundation
import OpticalCore

public enum KroutonDesign {
    public enum Radius {
        public static let pill: CGFloat = 999
        public static let badge: CGFloat = 6
        public static let card: CGFloat = 10
        public static let hero: CGFloat = 14
        public static let panel: CGFloat = 12
    }

    public enum Stroke {
        public static let hairline: CGFloat = 0.8
        public static let standard: CGFloat = 1.0
        public static let emphasized: CGFloat = 1.35
    }

    public enum Opacity {
        public static let subtleFill: Double = 0.06
        public static let badgeFill: Double = 0.14
        public static let activeFill: Double = 0.22
        public static let badgeBorder: Double = 0.38
        public static let activeBorder: Double = 0.82
    }

    public enum Typography {
        public static let microMono = Font.system(size: 9, weight: .bold, design: .monospaced)
        public static let badgeMono = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
        public static let telemetryMono = Font.system(size: 10.5, weight: .bold, design: .monospaced)
        public static let sectionHeader = Font.system(size: 9.5, weight: .bold, design: .rounded)
        public static let cardTitle = Font.system(size: 12.5, weight: .bold)
    }
}

public enum KroutonViewportTier: String, CaseIterable, Sendable {
    case compact
    case medium
    case wideWorkspace
    case ultraWide

    public static func from(centerWidth: CGFloat) -> KroutonViewportTier {
        if centerWidth < 520 { return .compact }
        if centerWidth < 780 { return .medium }
        if centerWidth < 1080 { return .wideWorkspace }
        return .ultraWide
    }

    public var isCompact: Bool { self == .compact }
    public var isMediumOrWider: Bool { self != .compact }
    public var isWideOrUltraWide: Bool { self == .wideWorkspace || self == .ultraWide }
}
