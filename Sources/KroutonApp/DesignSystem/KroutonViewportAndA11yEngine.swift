import SwiftUI
import Foundation
import OpticalDough

// MARK: - 4-Tier Adaptive Viewport Layout Engine (Small / Medium / Large / Full-Screen)

public enum KroutonViewportTier: String, CaseIterable, Sendable {
    case compact     // < 520 pt center width (Small window)
    case medium      // 520 ..< 780 pt center width (Medium studio window)
    case wideStudio  // 780 ..< 1080 pt center width (Large default window)
    case ultraWide   // >= 1080 pt center width (Full-Screen / 5K Display)

    public static func from(centerWidth: CGFloat) -> KroutonViewportTier {
        if centerWidth < 520 { return .compact }
        if centerWidth < 780 { return .medium }
        if centerWidth < 1080 { return .wideStudio }
        return .ultraWide
    }

    public var isCompact: Bool { self == .compact }
    public var isMediumOrWider: Bool { self != .compact }
    public var isWideOrUltraWide: Bool { self == .wideStudio || self == .ultraWide }
}

// MARK: - VoiceOver Telemetry & Control Accessibility Modifiers

public extension View {
    /// Attaches a complete VoiceOver label, live value, and action hint to an interactive studio control.
    func kroutonAccessibleControl(label: String, value: String? = nil, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(KroutonL10n.tr(label))
            .accessibilityValue(value.map { KroutonL10n.tr($0) } ?? "")
            .accessibilityHint(hint.map { KroutonL10n.tr($0) } ?? "")
    }
}
