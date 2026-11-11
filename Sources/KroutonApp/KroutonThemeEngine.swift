//
//  KroutonThemeEngine.swift
//  Krouton — Optical Media Mastering Studio
//
//  22-Color Display-P3 Perceptual Harmony Engine + Zero-Allocation LUT Cache.
//

import SwiftUI
import AppKit

// MARK: - Zero-Allocation Display-P3 Color Harmony LUT Cache (120Hz ProMotion Optimization)
fileprivate final class KroutonColorHarmonyLUT: @unchecked Sendable {
    static let shared = KroutonColorHarmonyLUT()
    private let lock = NSLock()
    private var complementCache: [Int: Color] = [:]
    private var backingCache: [Int: Color] = [:]
    private var surfaceCache: [Int: Color] = [:]

    private func quantizedKey(for color: Color) -> Int {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .systemCyan
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int((r * 255.0).rounded()) & 0xFF
        let gi = Int((g * 255.0).rounded()) & 0xFF
        let bi = Int((b * 255.0).rounded()) & 0xFF
        return (ri << 16) | (gi << 8) | bi
    }

    func cachedComplement(for color: Color, compute: () -> Color) -> Color {
        let key = quantizedKey(for: color)
        lock.lock()
        if let hit = complementCache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let val = compute()
        lock.lock()
        complementCache[key] = val
        lock.unlock()
        return val
    }

    func cachedBacking(for color: Color, compute: () -> Color) -> Color {
        let key = quantizedKey(for: color)
        lock.lock()
        if let hit = backingCache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let val = compute()
        lock.lock()
        backingCache[key] = val
        lock.unlock()
        return val
    }

    func cachedSurface(for color: Color, compute: () -> Color) -> Color {
        let key = quantizedKey(for: color)
        lock.lock()
        if let hit = surfaceCache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let val = compute()
        lock.lock()
        surfaceCache[key] = val
        lock.unlock()
        return val
    }
}

// MARK: - Perceptual Split-Complementary + Warm/Cool Polarity Color Engine (CGColor / P3)
extension Color {
    /// Maps each Krouton appearance swatch to its dedicated Display-P3 secondary harmony color:
    /// - Titanium / Monochrome -> Stark Pure White
    /// - Toasted Brown         -> Champagne Almond / Pale Cream Tan
    /// - Vibrant Tangerine     -> Royal Ultramarine
    /// - Solar Gold / Amber    -> Arctic Periwinkle / Ice Blue
    /// - Oscilloscope Green    -> Electric Cerulean Blue
    /// - CAD Teal & Light Blue -> Teenage-Engineering Safety Orange
    /// - Laser Cobalt Blue     -> Cyber Hot Berry / Electric Magenta
    /// - Deep Indigo / Navy    -> Phosphor Aquamarine / Cyber Mint
    /// - Synth Violet / Purple -> Sunburst Amber
    /// - Cover-Disc Magenta    -> Electric Sky Cyan
    /// - Laser Crimson / Red   -> Electric Amethyst / Lavender Violet
    var perceptualSplitComplement: Color {
        KroutonColorHarmonyLUT.shared.cachedComplement(for: self) {
            let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.systemCyan
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0
            nsColor.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            let hueDeg = h * 360.0

            func p3(_ pr: CGFloat, _ pg: CGFloat, _ pb: CGFloat) -> Color {
                if let space = CGColorSpace(name: CGColorSpace.displayP3),
                   let cg = CGColor(colorSpace: space, components: [pr, pg, pb, 1.0]) {
                    return Color(cgColor: cg)
                }
                return Color(cgColor: CGColor(srgbRed: pr, green: pg, blue: pb, alpha: 1.0))
            }

                        // 1. TITANIUM / MONOCHROME (Low Saturation) -> Stark Pure White
            if s < 0.14 {
                return v > 0.88 ? p3(0.60, 0.65, 0.72) : p3(0.98, 0.99, 1.00)
            }

            // 2. TOASTED KROUTON BROWN vs. VIBRANT TANGERINE / ORANGE (Hue 14°..42°)
            //    - Toasted Brown (s < 0.72 or v < 0.78) -> Champagne Almond Cream
            //    - Vibrant Orange (s >= 0.72, v >= 0.78) -> Royal Ultramarine Blue
            if hueDeg >= 14.0 && hueDeg < 42.0 {
                let isEarthyBrown = (s < 0.72) || (v < 0.78)
                return isEarthyBrown ? p3(0.98, 0.87, 0.68) : p3(0.32, 0.62, 1.00)
            }

            // 3. SOLAR GOLD / AMBER (Hue 42°..78°) -> Arctic Periwinkle / Cool Ice Blue
            if hueDeg >= 42.0 && hueDeg < 78.0 {
                return p3(0.56, 0.78, 1.00)
            }

            // 4. OSCILLOSCOPE GREEN (Hue 78°..164°) -> Electric Cerulean Blue
            if hueDeg >= 78.0 && hueDeg < 164.0 {
                return p3(0.20, 0.68, 1.00)
            }

            // 5. CAD TEAL / SKY CYAN (Hue 164°..202°) -> Teenage-Engineering Safety Orange
            if hueDeg >= 164.0 && hueDeg < 202.0 {
                return p3(1.00, 0.55, 0.14)
            }

            // 6. LASER COBALT BLUE (Hue 202°..216°) -> Sunburst Amber / Warm Gold
            if hueDeg >= 202.0 && hueDeg < 216.0 {
                return p3(1.00, 0.84, 0.28)
            }

            // 7. SLATE INDIGO / STEEL BLUE (Hue 216°..238°) -> Cyber Hot Berry / Electric Magenta
            if hueDeg >= 216.0 && hueDeg < 238.0 {
                return p3(0.98, 0.36, 0.76)
            }

            // 8. SYNTH VIOLET / PURPLE (Hue 238°..305°) -> Phosphor Aquamarine / Cyber Mint
            if hueDeg >= 238.0 && hueDeg < 305.0 {
                return p3(0.26, 0.99, 0.88)
            }

            // 9. COVER-DISC MAGENTA / PINK (Hue 305°..344°) -> Electric Sky Cyan
            if hueDeg >= 305.0 && hueDeg < 344.0 {
                return p3(0.24, 0.92, 0.98)
            }

            // 10. LASER CRIMSON / RED (Hue 344°..360° or 0°..14°) -> Electric Amethyst / Lavender Violet
            return p3(0.78, 0.50, 1.00)
        }
    }

    var blueprintOccludeBacking: Color {
        KroutonColorHarmonyLUT.shared.cachedBacking(for: self) {
            let nsPrimary = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.systemBrown
            var h1: CGFloat = 0, s1: CGFloat = 0, v1: CGFloat = 0, a1: CGFloat = 0
            nsPrimary.getHue(&h1, saturation: &s1, brightness: &v1, alpha: &a1)

            if s1 < 0.14 {
                return Color(cgColor: CGColor(srgbRed: 0.08, green: 0.09, blue: 0.11, alpha: 1.0))
            }

            let hueDeg = h1 * 360.0
            if hueDeg >= 16.0 && hueDeg < 42.0 && ((s1 < 0.82) || (v1 < 0.88)) {
                return Color(cgColor: CGColor(srgbRed: 0.09, green: 0.055, blue: 0.035, alpha: 1.0))
            }

            let nsSec = NSColor(self.perceptualSplitComplement).usingColorSpace(.sRGB) ?? NSColor.systemCyan
            var h2: CGFloat = 0, s2: CGFloat = 0, v2: CGFloat = 0, a2: CGFloat = 0
            nsSec.getHue(&h2, saturation: &s2, brightness: &v2, alpha: &a2)
            let darkNS = NSColor(hue: h2, saturation: min(s2, 0.68), brightness: 0.11, alpha: 1.0).usingColorSpace(.sRGB) ?? NSColor.black
            return Color(cgColor: darkNS.cgColor)
        }
    }
}

// MARK: - KroutonStateStore Secondary Accent Harmony Extension
extension KroutonStateStore {
    var activeSecondaryAccent: Color {
        activeAccent.perceptualSplitComplement
    }

    var uiSecondaryAccent: Color {
        enableSecondaryAccentUITints ? activeAccent.perceptualSplitComplement : activeAccent
    }

    /// Cached window surface tint that blends 12% of the Primary Swatch when Harmony is enabled
    var windowSurfaceTint: Color {
        guard enableSecondaryAccentUITints else {
            return Color(nsColor: .windowBackgroundColor)
        }
        return KroutonColorHarmonyLUT.shared.cachedSurface(for: activeAccent) {
            let base = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) ?? NSColor(calibratedWhite: 0.12, alpha: 1.0)
            let tint = NSColor(activeAccent).usingColorSpace(.sRGB) ?? NSColor.systemGreen
            let blended = base.blended(withFraction: 0.12, of: tint) ?? base
            return Color(nsColor: blended)
        }
    }

    /// Direct SwiftUI overlay tint matching KroutonSettingsWindow (0.11 opacity of activeAccent when Harmony is ON)
    var mainPanelTintOverlay: Color {
        enableSecondaryAccentUITints ? activeAccent.opacity(0.11) : Color.clear
    }

    /// Subtle darker tint for sidebars and header/footer bars when Harmony is ON
    var sidebarTintOverlay: Color {
        enableSecondaryAccentUITints ? activeAccent.opacity(0.085) : Color.clear
    }

    /// Card background fill that picks up a subtle primary/secondary tint when Harmony is ON
    var harmonizedCardFill: Color {
        enableSecondaryAccentUITints ? activeAccent.opacity(0.07) : Color.primary.opacity(0.04)
    }

    /// Card border stroke that shifts to Secondary Harmony when Harmony is ON
    var harmonizedCardBorder: Color {
        enableSecondaryAccentUITints ? activeSecondaryAccent.opacity(0.28) : Color.primary.opacity(0.08)
    }
}
