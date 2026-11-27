import CoreText
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import os

// MARK: - Disc Label Canvas Curved Text Glyphs, Spindle Cutout & Vector Shapes

extension KroutonDiscLabelArtworkCanvas {
    @ViewBuilder
    func renderTextElementView(_ item: KroutonLabelTextElement) -> some View {
        let pointsPerMM = diameterPoints / CGFloat(outerMM)
        let radiusPts = max(holeDiameter * 0.54, min(diameterPoints * 0.48, CGFloat(item.radiusMM) * pointsPerMM))
        let scaledFontPt = max(7.0, CGFloat(item.fontSizePoints) * (diameterPoints / 360.0))
        let textCol = Color(red: item.color.r, green: item.color.g, blue: item.color.b, opacity: item.color.a)
        let design = Self.resolveFontDesign(item.fontDesignRaw)
        let weight: Font.Weight = item.isBold ? .bold : .regular
        let isSelected = (!isExportMode && item.id == selectedTextID)

        ZStack {
            if isSelected && item.isCurvedArc {
                Circle()
                    .strokeBorder(Color.blue.opacity(0.40), style: StrokeStyle(lineWidth: 1.0, dash: [4, 3]))
                    .frame(width: radiusPts * 2.0, height: radiusPts * 2.0)
            }

            if item.isCurvedArc {
                let glyphs = Self.computeProportionalArcGlyphs(
                    text: item.text,
                    radiusPts: Double(radiusPts),
                    angleDegrees: item.angleDegrees,
                    fontSizePts: Double(scaledFontPt),
                    tracking: item.letterTracking,
                    isBottomUpright: item.isBottomUpright
                )
                ForEach(glyphs, id: \.index) { g in
                    Text(String(g.char))
                        .font(.system(size: scaledFontPt, weight: weight, design: design))
                        .foregroundStyle(textCol)
                        .shadow(color: .black.opacity(item.hasDropShadow ? 0.65 : 0.0), radius: 2.0, x: 1.0, y: 1.0)
                        .rotationEffect(.radians(g.rotationRad))
                        .offset(x: CGFloat(g.dx), y: CGFloat(g.dy))
                }
            } else {
                let posAngleRad = (item.angleDegrees - 90.0) * Double.pi / 180.0
                let dx = CGFloat(cos(posAngleRad)) * radiusPts
                let dy = CGFloat(sin(posAngleRad)) * radiusPts
                Text(item.text)
                    .font(.system(size: scaledFontPt, weight: weight, design: design))
                    .foregroundStyle(textCol)
                    .shadow(color: .black.opacity(item.hasDropShadow ? 0.65 : 0.0), radius: 2.0, x: 1.0, y: 1.0)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.blue.opacity(isSelected ? 0.55 : 0.0), style: StrokeStyle(lineWidth: 1.0, dash: [3, 2]))
                    )
                    .offset(x: dx, y: dy)
            }

            // Center Anchor Handle Dot for Selected Layer
            if isSelected {
                let anchorRad = (item.angleDegrees - 90.0) * Double.pi / 180.0
                let hx = CGFloat(cos(anchorRad)) * radiusPts
                let hy = CGFloat(sin(anchorRad)) * radiusPts
                Circle()
                    .fill(Color.blue)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                    .offset(x: hx, y: hy)
            }
        }
        .allowsHitTesting(false)
        // VoiceOver reads the layer as one element (not letter by letter), selects it, and
        // turns it round the disc with swipe up / down.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.text)
        .accessibilityValue(Self.textLayerDescription(item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelectOrDragText?(item.id, item.radiusMM, item.angleDegrees) }
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 5.0 : -5.0
            onSelectOrDragText?(item.id, item.radiusMM, item.angleDegrees + step)
        }
        .accessibilityHidden(isExportMode)
    }

    /// "Curved text at 12 o'clock, 52 mm from the centre, 18 point bold".
    static func textLayerDescription(_ item: KroutonLabelTextElement) -> String {
        let normalized = (item.angleDegrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let hour = Int((normalized / 30).rounded()) % 12
        let shape = item.isCurvedArc ? "Curved text" : "Straight text"
        return "\(shape) at \(hour == 0 ? 12 : hour) o'clock, \(Int(item.radiusMM.rounded())) mm from the centre, \(Int(item.fontSizePoints.rounded())) point\(item.isBold ? " bold" : "")"
    }

    struct ArcGlyphPlacement {
        let index: Int
        let char: Character
        let dx: Double
        let dy: Double
        let rotationRad: Double
    }

    static func computeProportionalArcGlyphs(
        text: String,
        radiusPts: Double,
        angleDegrees: Double,
        fontSizePts: Double,
        tracking: Double,
        isBottomUpright: Bool
    ) -> [ArcGlyphPlacement] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }
        let safeR = max(12.0, radiusPts)
        let centerAngleRad = (angleDegrees - 90.0) * Double.pi / 180.0
        let advances = chars.map { Double(characterWidthFactor($0, fontDesignRaw: "default", isBold: true)) * fontSizePts * max(0.5, tracking) }
        let totalArcLen = advances.reduce(0.0, +)
        let rawAngleSpan = totalArcLen / safeR
        let maxAllowedSpan = Double.pi * 1.88 // 338 degrees max so start & end never collide
        let compressionScale = rawAngleSpan > maxAllowedSpan ? (maxAllowedSpan / rawAngleSpan) : 1.0
        let totalAngleSpan = min(rawAngleSpan, maxAllowedSpan)

        var out: [ArcGlyphPlacement] = []
        if !isBottomUpright {
            var cursorAngle = centerAngleRad - (totalAngleSpan * 0.5)
            for (idx, ch) in chars.enumerated() {
                let halfStep = (advances[idx] * compressionScale * 0.5) / safeR
                cursorAngle += halfStep
                let dx = cos(cursorAngle) * safeR
                let dy = sin(cursorAngle) * safeR
                let rot = cursorAngle + (Double.pi * 0.5)
                out.append(ArcGlyphPlacement(index: idx, char: ch, dx: dx, dy: dy, rotationRad: rot))
                cursorAngle += halfStep
            }
        } else {
            var cursorAngle = centerAngleRad + (totalAngleSpan * 0.5)
            for (idx, ch) in chars.enumerated() {
                let halfStep = (advances[idx] * compressionScale * 0.5) / safeR
                cursorAngle -= halfStep
                let dx = cos(cursorAngle) * safeR
                let dy = sin(cursorAngle) * safeR
                let rot = cursorAngle - (Double.pi * 0.5)
                out.append(ArcGlyphPlacement(index: idx, char: ch, dx: dx, dy: dy, rotationRad: rot))
                cursorAngle -= halfStep
            }
        }
        return out
    }

    var spindleHoleCutout: some View {
        ZStack {
            if !isExportMode {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 0.9, dash: [4, 3]))
                    .frame(width: holeDiameter + 14, height: holeDiameter + 14)
            }
            Circle()
                .fill(isExportMode ? Color.white : Color(red: 0.11, green: 0.12, blue: 0.14))
                .frame(width: holeDiameter, height: holeDiameter)
            Circle()
                .strokeBorder(Color.black.opacity(isExportMode ? 0.0 : 0.35), lineWidth: 1.0)
                .frame(width: holeDiameter, height: holeDiameter)
        }
        .allowsHitTesting(false)
    }

    /// Pure, unit-testable polar radius clamp shared by drag gesture, hit-testing, and arc rendering.
    static func clampedTextRadiusMM(_ rawRadiusMM: Double, hubDiameterMM: Double, outerDiameterMM: Double) -> Double {
        let minR = max(12.0, hubDiameterMM * 0.54)
        let maxR = max(minR + 4.0, outerDiameterMM * 0.46)
        return max(minR, min(maxR, rawRadiusMM))
    }

    /// Thread-safe cache of CoreText glyph advance factors keyed by `fontKey:char`.
    private static let glyphAdvanceCacheLock = OSAllocatedUnfairLock<[String: CGFloat]>(initialState: [:])

    static func postScriptFontName(fontDesignRaw: String, isBold: Bool) -> CFString {
        switch fontDesignRaw.lowercased() {
        case "serif":
            return (isBold ? "TimesNewRomanPS-BoldMT" : "TimesNewRomanPSMT") as CFString
        case "rounded":
            return (isBold ? "AmericanTypewriter-Bold" : "AmericanTypewriter") as CFString
        case "monospaced":
            return (isBold ? "Menlo-Bold" : "Menlo-Regular") as CFString
        default:
            return (isBold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString
        }
    }

    /// Computes proportional glyph advance factor using CoreText (`CTFont` + `CTLineGetTypographicBounds`)
    /// for the active font family and weight, memoized so CTFont/CTLine are created at most once per glyph.
    static func characterWidthFactor(
        _ ch: Character,
        fontDesignRaw: String = "default",
        isBold: Bool = true
    ) -> CGFloat {
        let key = "\(fontDesignRaw):\(isBold ? 1 : 0):\(ch)"
        if let cached = glyphAdvanceCacheLock.withLock({ $0[key] }) {
            return cached
        }

        let baseSize: CGFloat = 24.0
        let psName = postScriptFontName(fontDesignRaw: fontDesignRaw, isBold: isBold)
        let ctFont = CTFontCreateWithName(psName, baseSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): ctFont
        ]
        let attrStr = NSAttributedString(string: String(ch), attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let factor = max(0.32, min(1.45, advance / (baseSize * 0.62)))

        glyphAdvanceCacheLock.withLock { cache in
            if cache.count > 2048 { cache.removeAll(keepingCapacity: true) }
            cache[key] = factor
        }
        return factor
    }

    static func resolveFontDesign(_ raw: String) -> Font.Design {
        switch raw.lowercased() {
        case "serif":      return .serif
        case "rounded":    return .rounded
        case "monospaced": return .monospaced
        default:           return .default
        }
    }

    static func blendColors(_ c1: Color, _ c2: Color, fraction: Double) -> Color {
        let f = max(0.0, min(1.0, fraction))
        let (r1, g1, b1, a1) = KroutonPureColorMath.extractSRGB(c1)
        let (r2, g2, b2, a2) = KroutonPureColorMath.extractSRGB(c2)
        return Color(
            red: Double(r1) + (Double(r2) - Double(r1)) * f,
            green: Double(g1) + (Double(g2) - Double(g1)) * f,
            blue: Double(b1) + (Double(b2) - Double(b1)) * f,
            opacity: Double(a1) + (Double(a2) - Double(a1)) * f
        )
    }

    static func polarHitDistance(
        item: KroutonLabelTextElement,
        clickR: Double,
        clickDeg: Double,
        hubDiameterMM: Double = 18.0,
        outerDiameterMM: Double = 120.0
    ) -> Double {
        let targetR = clampedTextRadiusMM(item.radiusMM, hubDiameterMM: hubDiameterMM, outerDiameterMM: outerDiameterMM)
        let radialDiff = abs(clickR - targetR)
        var rawAngDiff = abs(clickDeg - item.angleDegrees).truncatingRemainder(dividingBy: 360.0)
        if rawAngDiff > 180.0 { rawAngDiff = 360.0 - rawAngDiff }
        let charCount = max(3.0, Double(item.text.count))
        let halfSpanDeg = min(85.0, (charCount * item.fontSizePoints * 0.14) / max(18.0, targetR) * (180.0 / Double.pi))
        let angularExcess = max(0.0, rawAngDiff - halfSpanDeg)
        let arcDistMM = (angularExcess * Double.pi / 180.0) * targetR
        return hypot(radialDiff, arcDistMM * 0.65)
    }

    @ViewBuilder
    func renderVectorShapeView(_ shape: KroutonVectorShapeLayer) -> some View {
        let halfD = diameterPoints * 0.5
        let scalePts = Double(diameterPoints) / 240.0
        let path = Path { p in
            guard let first = shape.points.first else { return }
            p.move(to: CGPoint(x: halfD + CGFloat(first.nx) * halfD, y: halfD + CGFloat(first.ny) * halfD))
            for pt in shape.points.dropFirst() {
                p.addLine(to: CGPoint(x: halfD + CGFloat(pt.nx) * halfD, y: halfD + CGFloat(pt.ny) * halfD))
            }
            if shape.isClosed { p.closeSubpath() }
        }
        ZStack {
            if let fill = shape.fillColor, shape.isClosed {
                path.fill(Color(red: fill.r, green: fill.g, blue: fill.b, opacity: fill.a))
            }
            path.stroke(
                Color(red: shape.strokeColor.r, green: shape.strokeColor.g, blue: shape.strokeColor.b, opacity: shape.strokeColor.a),
                style: StrokeStyle(lineWidth: max(1.0, CGFloat(shape.strokeWidthPoints * scalePts)), lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shape: \(shape.name)")
        .accessibilityHidden(isExportMode)
    }
}
