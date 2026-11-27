import OpticalCore
import SwiftUI
import os

//
//  KroutonThemeEngine.swift
//  Krouton — Optical Media Mastering Package (Optical Media Mastering Workspace)
//
//  22-Color Display-P3 Perceptual Harmony Engine + Zero-Allocation LUT Cache.
//  100% Pure SwiftUI & CoreGraphics IEEE-754 Color Math (Zero AppKit Dependency).
//

// MARK: - Zero-Allocation Display-P3 Color Harmony LUT Cache (120Hz ProMotion Optimization)
fileprivate final class KroutonColorHarmonyLUT: Sendable {
    static let shared = KroutonColorHarmonyLUT()
    private struct CacheState: Sendable {
        var complement: [Int: Color] = [:]
        var backing: [Int: Color] = [:]
        var surface: [Int: Color] = [:]
    }
    private let state = OSAllocatedUnfairLock(initialState: CacheState())

    private func quantizedKey(for color: Color) -> Int {
        let (r, g, b, _) = KroutonPureColorMath.extractSRGB(color)
        let ri = Int((r * 255.0).rounded()) & 0xFF
        let gi = Int((g * 255.0).rounded()) & 0xFF
        let bi = Int((b * 255.0).rounded()) & 0xFF
        return (ri << 16) | (gi << 8) | bi
    }

    func cachedComplement(for color: Color, compute: () -> Color) -> Color {
        let key = quantizedKey(for: color)
        if let hit = state.withLock({ $0.complement[key] }) { return hit }
        let val = compute()
        state.withLock { $0.complement[key] = val }
        return val
    }

    func cachedBacking(for color: Color, compute: () -> Color) -> Color {
        let key = quantizedKey(for: color)
        if let hit = state.withLock({ $0.backing[key] }) { return hit }
        let val = compute()
        state.withLock { $0.backing[key] = val }
        return val
    }

    func cachedSurface(for color: Color, isDark: Bool = true, compute: () -> Color) -> Color {
        let key = (quantizedKey(for: color) << 1) | (isDark ? 1 : 0)
        if let hit = state.withLock({ $0.surface[key] }) { return hit }
        let val = compute()
        state.withLock { $0.surface[key] = val }
        return val
    }
}

// MARK: - Perceptual Split-Complementary + Warm/Cool Polarity Color Engine (CGColor / P3)
extension Color {
    var perceptualSplitComplement: Color {
        KroutonColorHarmonyLUT.shared.cachedComplement(for: self) {
            let (r, g, b, _) = KroutonPureColorMath.extractSRGB(self)
            let (h, s, v) = KroutonPureColorMath.rgbToHSB(r: r, g: g, b: b)
            let hueDeg = h * 360.0

            func p3(_ pr: CGFloat, _ pg: CGFloat, _ pb: CGFloat) -> Color {
                if let space = CGColorSpace(name: CGColorSpace.displayP3),
                   let cg = CGColor(colorSpace: space, components: [pr, pg, pb, 1.0]) {
                    return Color(cgColor: cg)
                }
                return Color(cgColor: CGColor(srgbRed: pr, green: pg, blue: pb, alpha: 1.0))
            }

            if s < 0.14 {
                return v > 0.88 ? p3(0.60, 0.65, 0.72) : p3(0.98, 0.99, 1.00)
            }
            if hueDeg >= 14.0 && hueDeg < 42.0 {
                let isEarthyBrown = (s < 0.72) || (v < 0.78)
                return isEarthyBrown ? p3(0.98, 0.87, 0.68) : p3(0.72, 1.00, 0.18)
            }
            if hueDeg >= 42.0 && hueDeg < 78.0 {
                return p3(0.56, 0.78, 1.00)
            }
            if hueDeg >= 78.0 && hueDeg < 148.0 {
                return p3(0.20, 0.68, 1.00)
            }
            if hueDeg >= 148.0 && hueDeg < 195.0 {
                return p3(0.98, 0.94, 0.32)
            }
            if hueDeg >= 195.0 && hueDeg < 216.0 {
                return p3(1.00, 0.48, 0.08)
            }
            if hueDeg >= 216.0 && hueDeg < 238.0 {
                return p3(0.98, 0.36, 0.76)
            }
            if hueDeg >= 238.0 && hueDeg < 305.0 {
                return p3(0.26, 0.99, 0.88)
            }
            if hueDeg >= 305.0 && hueDeg < 344.0 {
                return p3(0.24, 0.92, 0.98)
            }
            return p3(0.78, 0.50, 1.00)
        }
    }

}

// MARK: - KroutonStateStore Secondary Accent Harmony Extension
extension KroutonStateStore {
    private static func p3Color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Color {
        if let space = CGColorSpace(name: CGColorSpace.displayP3),
           let cg = CGColor(colorSpace: space, components: [r, g, b, 1.0]) {
            return Color(cgColor: cg)
        }
        return Color(red: r, green: g, blue: b)
    }

    var resolvedColorScheme: ColorScheme {
        switch self.appearanceMode {
        case .light: return .light
        case .dark:  return .dark
        case .auto:
            let isDark = KroutonOSDesktopBridge.isSystemDarkMode()
            return isDark ? .dark : .light
        }
    }

    static func secondaryHarmonyForPresetID(_ id: Int, scheme: ColorScheme = .dark) -> Color {
        if scheme == .light {
            switch id {
            case 0:  return p3Color(0.50, 0.16, 0.84)
            case 1:  return p3Color(0.28, 0.54, 0.00)
            case 2:  return p3Color(0.14, 0.42, 0.82)
            case 3:  return p3Color(0.00, 0.44, 0.78)
            case 4:  return p3Color(0.64, 0.44, 0.00)
            case 5:  return p3Color(0.82, 0.30, 0.00)
            case 6:  return p3Color(0.76, 0.10, 0.48)
            case 7:  return p3Color(0.00, 0.54, 0.46)
            case 8:  return p3Color(0.56, 0.34, 0.10)
            case 9:  return p3Color(0.22, 0.26, 0.32)
            default: return p3Color(0.76, 0.10, 0.48)
            }
        }

        switch id {
        case 0:  return p3Color(0.78, 0.50, 1.00)
        case 1:  return p3Color(0.72, 1.00, 0.18)
        case 2:  return p3Color(0.56, 0.78, 1.00)
        case 3:  return p3Color(0.20, 0.68, 1.00)
        case 4:  return p3Color(0.98, 0.94, 0.32)
        case 5:  return p3Color(1.00, 0.48, 0.08)
        case 6:  return p3Color(0.98, 0.36, 0.76)
        case 7:  return p3Color(0.26, 0.99, 0.88)
        case 8:  return p3Color(0.98, 0.87, 0.68)
        case 9:  return p3Color(0.98, 0.99, 1.00)
        default: return p3Color(0.98, 0.36, 0.76)
        }
    }

    var activeSecondaryAccent: Color {
        let scheme = resolvedColorScheme
        if self.selectedAccentIndex >= 0 && self.selectedAccentIndex <= 9 {
            return Self.secondaryHarmonyForPresetID(self.selectedAccentIndex, scheme: scheme)
        }
        let pid = multicolorPresetID(forTaskID: selectedTaskID, category: selectedCategory)
        return Self.secondaryHarmonyForPresetID(pid, scheme: scheme)
    }

    var uiSecondaryAccent: Color {
        self.enableSecondaryAccentUITints ? activeSecondaryAccent : activeAccent
    }

    var mainPanelTintOverlay: Color {
        guard self.enableSecondaryAccentUITints else { return Color.clear }
        return activeAccent.opacity(resolvedColorScheme == .light ? 0.085 : 0.11)
    }

    var sidebarTintOverlay: Color {
        guard self.enableSecondaryAccentUITints else { return Color.clear }
        return activeAccent.opacity(resolvedColorScheme == .light ? 0.065 : 0.085)
    }

    var harmonizedCardFill: Color {
        self.enableSecondaryAccentUITints ? activeAccent.opacity(0.07) : Color.primary.opacity(0.04)
    }

    var harmonizedCardBorder: Color {
        self.enableSecondaryAccentUITints ? activeSecondaryAccent.opacity(resolvedColorScheme == .light ? 0.42 : 0.28) : Color.primary.opacity(0.08)
    }
}

// MARK: - Native SwiftUI Semantic Surface Colors
extension Color {
    private static var isEffectiveDarkAppearance: Bool {
        if let raw = KroutonPreferences.string(for: .appearanceMode),
           let mode = KroutonRoastAppearanceMode(rawValue: raw) {
            switch mode {
            case .dark: return true
            case .light: return false
            case .auto: break
            }
        }
        return KroutonOSDesktopBridge.isSystemDarkMode()
    }

    static var kroutonWindowSurface: Color {
        isEffectiveDarkAppearance
            ? Color(.sRGB, red: 0.12, green: 0.12, blue: 0.13, opacity: 1.0)
            : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.96, opacity: 1.0)
    }

    static var kroutonControlSurface: Color {
        isEffectiveDarkAppearance
            ? Color(.sRGB, red: 0.16, green: 0.16, blue: 0.18, opacity: 1.0)
            : Color(.sRGB, red: 1.00, green: 1.00, blue: 1.00, opacity: 1.0)
    }
}
