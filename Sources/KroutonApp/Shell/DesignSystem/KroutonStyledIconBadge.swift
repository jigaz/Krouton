import DriveKit
import CryptoKit
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalCore
import AudioKit
import VideoKit
import ImageKit
import LabelKit
import RescueKit

// MARK: - Functional Icon & Widget Style Renderer (Default / Dark / Clear / Tinted)
public struct KroutonStyledIconBadge: View {
    public let sfSymbol: String
    public let tintColor: Color
    public let style: KroutonGarnishStyleMode
    public var isSelectedRow: Bool = false
    public var onAccentText: Color = .white
    public var size: CGFloat = 24
    public var symbolSize: CGFloat = 13

    public init(
        sfSymbol: String,
        tintColor: Color,
        style: KroutonGarnishStyleMode,
        isSelectedRow: Bool = false,
        onAccentText: Color = .white,
        size: CGFloat = 24,
        symbolSize: CGFloat = 13
    ) {
        self.sfSymbol = sfSymbol
        self.tintColor = tintColor
        self.style = style
        self.isSelectedRow = isSelectedRow
        self.onAccentText = onAccentText
        self.size = size
        self.symbolSize = symbolSize
    }

    public var body: some View {
        let activeStore = KroutonStateStore.shared
        let isLight = (activeStore?.resolvedColorScheme == .light)
        let useHarmonyBg = (style == .tinted && (activeStore?.enableSecondaryAccentUITints ?? false))
        // In Light Mode, use the bright neon P3 harmony color for the tile fill so yellows/mints look luminous instead of muddy,
        // while using the deep Light Mode harmony color for the crisp border ring!
        let presetID = activeStore?.selectedAccentIndex ?? 6
        let effectiveID = presetID >= 0 ? presetID : (activeStore.map { $0.multicolorPresetID(forTaskID: $0.selectedTaskID, category: $0.selectedCategory) } ?? 6)
        let brightHarmony = KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark)
        let strokeHarmony = activeStore?.activeSecondaryAccent ?? tintColor.perceptualSplitComplement

        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(badgeBackgroundGradient(isLight: isLight))
                .overlay(
                    Group {
                        if useHarmonyBg {
                            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                                .fill(isLight ? brightHarmony.opacity(0.38) : strokeHarmony.opacity(0.28))
                        } else if style == .tinted && isLight {
                            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                                .fill(tintColor.opacity(0.15))
                        }
                    }
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(
                            useHarmonyBg
                                ? strokeHarmony.opacity(isLight ? 0.65 : 0.55)
                                : (isSelectedRow ? Color.white.opacity(0.35) : Color.primary.opacity(isLight ? 0.16 : 0.12)),
                            lineWidth: useHarmonyBg ? 1.25 : 0.8
                        )
                )

            Image(systemName: sfSymbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(symbolForeground(isLight: isLight))
        }
    }

    private func badgeBackgroundGradient(isLight: Bool) -> LinearGradient {
        switch style {
        case .defaultStyle:
            if isSelectedRow {
                return LinearGradient(
                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [tintColor, tintColor.opacity(0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .clear:
            return LinearGradient(
                colors: [
                    Color.primary.opacity(isLight ? 0.10 : 0.14),
                    Color.primary.opacity(isLight ? 0.04 : 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            if isLight {
                // Crisp alabaster/ivory workspace tile in Light Mode so bright Harmony washes + deep Primary icons pop!
                return LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.93)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func symbolForeground(isLight: Bool) -> Color {
        switch style {
        case .defaultStyle:
            return onAccentText
        case .dark:
            return .white
        case .clear:
            return isSelectedRow ? onAccentText : .primary
        case .tinted:
            return tintColor
        }
    }
}
