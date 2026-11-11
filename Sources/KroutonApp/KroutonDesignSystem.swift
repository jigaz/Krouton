//
//  KroutonDesignSystem.swift
//  Krouton — Optical Media Mastering Studio
//
//  Unified Design System Tokens (Typography, Radii, Spacing, Hairlines, and Semantic Surfaces).
//

import SwiftUI

public enum KroutonDesign {
    // MARK: - Corner Radii
    public enum Radius {
        public static let pill: CGFloat = 999
        public static let badge: CGFloat = 6
        public static let card: CGFloat = 10
        public static let hero: CGFloat = 14
        public static let panel: CGFloat = 12
    }

    // MARK: - Hairline & Stroke Widths
    public enum Stroke {
        public static let hairline: CGFloat = 0.8
        public static let standard: CGFloat = 1.0
        public static let emphasized: CGFloat = 1.35
    }

    // MARK: - Surface & Highlight Opacities
    public enum Opacity {
        public static let subtleFill: Double = 0.06
        public static let badgeFill: Double = 0.14
        public static let activeFill: Double = 0.22
        public static let badgeBorder: Double = 0.38
        public static let activeBorder: Double = 0.82
    }

    // MARK: - Studio Typography Tokens
    public enum Typography {
        public static let microMono = Font.system(size: 8.5, weight: .bold, design: .monospaced)
        public static let badgeMono = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
        public static let telemetryMono = Font.system(size: 10.5, weight: .bold, design: .monospaced)
        public static let sectionHeader = Font.system(size: 9.5, weight: .bold, design: .rounded)
        public static let cardTitle = Font.system(size: 12.5, weight: .bold)
    }
}

// MARK: - Reusable Harmonized Badge ViewModifier
struct KroutonHarmonizedPillModifier: ViewModifier {
    @ObservedObject var store: KroutonStateStore
    var prominent: Bool = false

    func body(content: Content) -> some View {
        let color = store.uiSecondaryAccent
        content
            .font(KroutonDesign.Typography.badgeMono)
            .padding(.horizontal, prominent ? 8 : 6)
            .padding(.vertical, prominent ? 3 : 2)
            .background(
                Capsule()
                    .fill(color.opacity(prominent ? KroutonDesign.Opacity.activeFill : KroutonDesign.Opacity.badgeFill))
                    .overlay(
                        Capsule()
                            .strokeBorder(color.opacity(KroutonDesign.Opacity.badgeBorder), lineWidth: KroutonDesign.Stroke.hairline)
                    )
            )
            .foregroundStyle(color)
    }
}

extension View {
    func kroutonHarmonizedPill(store: KroutonStateStore, prominent: Bool = false) -> some View {
        modifier(KroutonHarmonizedPillModifier(store: store, prominent: prominent))
    }
}
