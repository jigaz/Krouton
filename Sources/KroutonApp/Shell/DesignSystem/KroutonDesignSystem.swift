import Foundation
import OpticalCore
import SwiftUI

enum KroutonDesign {
    enum Radius {
        static let pill: CGFloat = 999
        static let badge: CGFloat = 6
        static let card: CGFloat = 10
        static let hero: CGFloat = 14
        static let panel: CGFloat = 12
    }

    enum Stroke {
        static let hairline: CGFloat = 0.8
        static let standard: CGFloat = 1.0
        static let emphasized: CGFloat = 1.35
    }

    enum Opacity {
        static let subtleFill: Double = 0.06
        static let badgeFill: Double = 0.14
        static let activeFill: Double = 0.22
        static let badgeBorder: Double = 0.38
        static let activeBorder: Double = 0.82
    }

    enum Typography {
        static let microMono = Font.system(size: 9, weight: .bold, design: .monospaced)
        static let badgeMono = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
        static let telemetryMono = Font.system(size: 10.5, weight: .bold, design: .monospaced)
        static let sectionHeader = Font.system(size: 9.5, weight: .bold, design: .rounded)
        static let cardTitle = Font.system(size: 12.5, weight: .bold)
    }
}

enum KroutonViewportTier: String, CaseIterable, Sendable {
    case compact
    case medium
    case wideWorkspace
    case ultraWide

    static func from(centerWidth: CGFloat) -> KroutonViewportTier {
        if centerWidth < 520 { return .compact }
        if centerWidth < 780 { return .medium }
        if centerWidth < 1080 { return .wideWorkspace }
        return .ultraWide
    }

    var isCompact: Bool { self == .compact }
    var isMediumOrWider: Bool { self != .compact }
    var isWideOrUltraWide: Bool { self == .wideWorkspace || self == .ultraWide }
}
