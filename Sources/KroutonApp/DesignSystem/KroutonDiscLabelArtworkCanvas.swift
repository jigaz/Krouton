import CoreText
import SwiftUI
import OpticalDough
import Crustini

// MARK: - Stage 1 Clean Printable Disc Canvas (Live Reactive Inputs + Interactive Drag-on-Disc)

public struct KroutonDiscLabelArtworkCanvas: View {
    @State private var activeDragTargetID: UUID? = nil
    public let preset: KroutonSliceLabelGeometry
    public let template: KroutonCroutonLabelStyle
    public let title: String
    public let subtitle: String
    public let performer: String
    public let mcnBarcode: String
    public let trackLines: [String]
    public let showTracklist: Bool
    public let primaryColor: Color
    public let harmonyColor: Color
    public let isExportMode: Bool
    public let diameterPoints: CGFloat

    // Stage 1 explicit reactive inputs (with defaults for backward compatibility)
    public var backgroundStyle: KroutonVectorBackgroundStyle
    public var bgPrimaryColor: Color
    public var bgSecondaryColor: Color
    public var gradientMidpoint: Double
    public var gradientAngle: Double
    public var gpuSeedPattern: KroutonGPUSeedPattern
    public var kaleidoscopeFacets: Int
    public var kaleidoscopeRig: KroutonKaleidoscopeMirrorRig
    public var chamberTumble: Double
    public var tinyPlanetRadius: Double
    public var bgAdjustments: KroutonBackgroundAdjustments
    public var vectorShapes: [KroutonVectorShapeLayer]
    public var textElements: [KroutonLabelTextElement]
    public var selectedTextID: UUID?
    public var showAlignmentGrid: Bool
    public var onSelectOrDragText: ((UUID, Double, Double) -> Void)?

    public init(
        preset: KroutonSliceLabelGeometry,
        template: KroutonCroutonLabelStyle,
        title: String,
        subtitle: String,
        performer: String,
        mcnBarcode: String,
        trackLines: [String],
        showTracklist: Bool,
        primaryColor: Color,
        harmonyColor: Color,
        isExportMode: Bool = false,
        diameterPoints: CGFloat = 360.0,
        backgroundStyle: KroutonVectorBackgroundStyle = .templateDefault,
        bgPrimaryColor: Color = .white,
        bgSecondaryColor: Color = Color(red: 0.16, green: 0.42, blue: 0.82),
        gradientMidpoint: Double = 0.50,
        gradientAngle: Double = 45.0,
        gpuSeedPattern: KroutonGPUSeedPattern = .neonLaserPrism,
        kaleidoscopeFacets: Int = 8,
        kaleidoscopeRig: KroutonKaleidoscopeMirrorRig = .twoMirrorRosette,
        chamberTumble: Double = 0.35,
        tinyPlanetRadius: Double = 0.75,
        bgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments(),
        vectorShapes: [KroutonVectorShapeLayer] = [],
        textElements: [KroutonLabelTextElement] = [],
        selectedTextID: UUID? = nil,
        showAlignmentGrid: Bool = false,
        onSelectOrDragText: ((UUID, Double, Double) -> Void)? = nil
    ) {
        self.preset = preset
        self.template = template
        self.title = title
        self.subtitle = subtitle
        self.performer = performer
        self.mcnBarcode = mcnBarcode
        self.trackLines = trackLines
        self.showTracklist = showTracklist
        self.primaryColor = primaryColor
        self.harmonyColor = harmonyColor
        self.isExportMode = isExportMode
        self.diameterPoints = diameterPoints
        self.backgroundStyle = backgroundStyle
        self.bgPrimaryColor = bgPrimaryColor
        self.bgSecondaryColor = bgSecondaryColor
        self.gradientMidpoint = gradientMidpoint
        self.gradientAngle = gradientAngle
        self.gpuSeedPattern = gpuSeedPattern
        self.kaleidoscopeFacets = kaleidoscopeFacets
        self.kaleidoscopeRig = kaleidoscopeRig
        self.chamberTumble = chamberTumble
        self.tinyPlanetRadius = tinyPlanetRadius
        self.bgAdjustments = bgAdjustments
        self.vectorShapes = vectorShapes
        self.textElements = textElements
        self.selectedTextID = selectedTextID
        self.showAlignmentGrid = showAlignmentGrid
        self.onSelectOrDragText = onSelectOrDragText
    }

    private var outerMM: Double {
        max(70.0, min(120.0, preset.outerDiameterMM))
    }

    private var innerMM: Double {
        max(15.0, min(54.0, preset.innerDiameterMM))
    }

    private var holeDiameter: CGFloat {
        diameterPoints * CGFloat(innerMM / outerMM)
    }

    public var body: some View {
        ZStack {
            // 1. Printable Disc Surface (Unified CoreImage pipeline when adjustments or procedural styles are active)
            discSurfaceBackground

            // 2. Optional 10mm Alignment Grid
            if showAlignmentGrid && !isExportMode {
                alignmentGridOverlay
            }

            // 2B. Parametric Vector Shapes & Optical Standard Badges
            ForEach(vectorShapes) { shape in
                renderVectorShapeView(shape)
            }

            // 3. User Text Elements (Curved on Disc Arc or Straight Horizontal)
            ForEach(textElements) { item in
                if !item.text.isEmpty {
                    renderTextElementView(item)
                }
            }

            // 4. Center Hub Clamping Guide & Spindle Hole Cutout
            spindleHoleCutout
        }
        .frame(width: diameterPoints, height: diameterPoints)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color.black.opacity(isExportMode ? 0.0 : 0.28), lineWidth: 1.0)
        )
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    guard !isExportMode, let onDrag = onSelectOrDragText, !textElements.isEmpty else { return }
                    let center = CGPoint(x: diameterPoints * 0.5, y: diameterPoints * 0.5)
                    let dx = Double(val.location.x - center.x)
                    let dy = Double(val.location.y - center.y)
                    let distPts = hypot(dx, dy)
                    let pointsPerMM = Double(diameterPoints) / outerMM
                    let clickRadiusMM = distPts / max(0.1, pointsPerMM)
                    let clampedRadiusMM = Self.clampedTextRadiusMM(clickRadiusMM, hubDiameterMM: preset.innerDiameterMM, outerDiameterMM: preset.outerDiameterMM)

                    var deg = (atan2(dy, dx) * 180.0 / Double.pi) + 90.0
                    if deg < 0 { deg += 360.0 }
                    let snappedDeg = (deg / 2.0).rounded() * 2.0

                    // On drag start, hit-test which text layer is closest to the initial click point
                    if activeDragTargetID == nil {
                        let startDX = Double(val.startLocation.x - center.x)
                        let startDY = Double(val.startLocation.y - center.y)
                        let startRMM = hypot(startDX, startDY) / max(0.1, pointsPerMM)
                        var startDeg = (atan2(startDY, startDX) * 180.0 / Double.pi) + 90.0
                        if startDeg < 0 { startDeg += 360.0 }

                        let nearest = textElements.min { a, b in
                            Self.polarHitDistance(item: a, clickR: startRMM, clickDeg: startDeg, hubDiameterMM: preset.innerDiameterMM, outerDiameterMM: preset.outerDiameterMM) <
                            Self.polarHitDistance(item: b, clickR: startRMM, clickDeg: startDeg, hubDiameterMM: preset.innerDiameterMM, outerDiameterMM: preset.outerDiameterMM)
                        }
                        activeDragTargetID = nearest?.id ?? selectedTextID ?? textElements.last?.id
                    }

                    if let targetID = activeDragTargetID {
                        onDrag(targetID, clampedRadiusMM, snappedDeg)
                    }
                }
                .onEnded { _ in
                    activeDragTargetID = nil
                }
        )
    }

    @ViewBuilder
    private var discSurfaceBackground: some View {
        let midRatio = max(0.08, min(0.92, gradientMidpoint))
        let ang = Angle.degrees(gradientAngle)

        let (r1, g1, b1, _) = KroutonPureColorMath.extractSRGB(bgPrimaryColor)
        let (r2, g2, b2, _) = KroutonPureColorMath.extractSRGB(bgSecondaryColor)
        if (!bgAdjustments.isIdentity && backgroundStyle != .templateDefault) || backgroundStyle == .gpuKaleidoscope || backgroundStyle == .tinyPlanetGlobe {
            if let cgImg = KroutonKrustiniModule.renderOpticalPlaygroundCGImage(
                style: backgroundStyle,
                seedPattern: gpuSeedPattern,
                mirrorRig: kaleidoscopeRig,
                chamberTumble: chamberTumble,
                backdropLightness: gradientMidpoint,
                primaryColor: KroutonRGBAColor(r: Double(r1), g: Double(g1), b: Double(b1)),
                secondaryColor: KroutonRGBAColor(r: Double(r2), g: Double(g2), b: Double(b2)),
                angleDegrees: gradientAngle,
                facetCount: kaleidoscopeFacets,
                planetRadiusRatio: tinyPlanetRadius,
                bgAdjustments: bgAdjustments,
                dimensionPixels: Int(max(300, min(1417, diameterPoints * (isExportMode ? 1.0 : 1.4))))
            ) {
                Image(decorative: cgImg, scale: 1.0)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(bgPrimaryColor)
            }
        } else {
            switch backgroundStyle {
        case .templateDefault:
            Circle()
                .fill(Color(red: 0.985, green: 0.985, blue: 0.988))
        case .solidColor:
            Circle()
                .fill(bgPrimaryColor)
        case .radialGradient:
            let midColor = Self.blendColors(bgPrimaryColor, bgSecondaryColor, fraction: 0.5)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: bgPrimaryColor, location: 0.0),
                            .init(color: midColor, location: CGFloat(midRatio)),
                            .init(color: bgSecondaryColor, location: 1.0)
                        ],
                        center: .center,
                        startRadius: holeDiameter * 0.48,
                        endRadius: diameterPoints * 0.50
                    )
                )
        case .linearGradient:
            let midColor = Self.blendColors(bgPrimaryColor, bgSecondaryColor, fraction: 0.5)
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: bgPrimaryColor, location: 0.0),
                            .init(color: midColor, location: CGFloat(midRatio)),
                            .init(color: bgSecondaryColor, location: 1.0)
                        ],
                        startPoint: UnitPoint(x: 0.5 - 0.5 * cos(ang.radians), y: 0.5 - 0.5 * sin(ang.radians)),
                        endPoint: UnitPoint(x: 0.5 + 0.5 * cos(ang.radians), y: 0.5 + 0.5 * sin(ang.radians))
                    )
                )
        case .angularGradient:
            Circle()
                .fill(
                    AngularGradient(
                        colors: [bgPrimaryColor, bgSecondaryColor, bgPrimaryColor],
                        center: .center,
                        angle: ang
                    )
                )
            case .gpuKaleidoscope, .tinyPlanetGlobe:
                Circle().fill(bgPrimaryColor)
            }
        }
    }

    private var alignmentGridOverlay: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let pointsPerMM = size.width / CGFloat(outerMM)
            var gridPath = Path()
            let step = pointsPerMM * 10.0
            var offset: CGFloat = step
            while offset < size.width * 0.5 {
                gridPath.move(to: CGPoint(x: center.x + offset, y: 0))
                gridPath.addLine(to: CGPoint(x: center.x + offset, y: size.height))
                gridPath.move(to: CGPoint(x: center.x - offset, y: 0))
                gridPath.addLine(to: CGPoint(x: center.x - offset, y: size.height))
                gridPath.move(to: CGPoint(x: 0, y: center.y + offset))
                gridPath.addLine(to: CGPoint(x: size.width, y: center.y + offset))
                gridPath.move(to: CGPoint(x: 0, y: center.y - offset))
                gridPath.addLine(to: CGPoint(x: size.width, y: center.y - offset))
                offset += step
            }
            context.stroke(gridPath, with: .color(.gray.opacity(0.32)), style: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))

            var axisPath = Path()
            axisPath.move(to: CGPoint(x: center.x, y: 0))
            axisPath.addLine(to: CGPoint(x: center.x, y: size.height))
            axisPath.move(to: CGPoint(x: 0, y: center.y))
            axisPath.addLine(to: CGPoint(x: size.width, y: center.y))
            context.stroke(axisPath, with: .color(.blue.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func renderTextElementView(_ item: KroutonLabelTextElement) -> some View {
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
    }

    private struct ArcGlyphPlacement {
        let index: Int
        let char: Character
        let dx: Double
        let dy: Double
        let rotationRad: Double
    }

    private static func computeProportionalArcGlyphs(
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

    private var spindleHoleCutout: some View {
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
    public static func clampedTextRadiusMM(_ rawRadiusMM: Double, hubDiameterMM: Double, outerDiameterMM: Double) -> Double {
        let minR = max(12.0, hubDiameterMM * 0.54)
        let maxR = max(minR + 4.0, outerDiameterMM * 0.46)
        return max(minR, min(maxR, rawRadiusMM))
    }

    /// Thread-safe cache of CoreText glyph advance factors keyed by `fontKey:char`.
    private static let glyphCacheLock = NSLock()
    nonisolated(unsafe) private static var glyphAdvanceCache: [String: CGFloat] = [:]

    private static func postScriptFontName(fontDesignRaw: String, isBold: Bool) -> CFString {
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
    private static func characterWidthFactor(
        _ ch: Character,
        fontDesignRaw: String = "default",
        isBold: Bool = true
    ) -> CGFloat {
        let key = "\(fontDesignRaw):\(isBold ? 1 : 0):\(ch)"
        glyphCacheLock.lock()
        if let cached = glyphAdvanceCache[key] {
            glyphCacheLock.unlock()
            return cached
        }
        glyphCacheLock.unlock()

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

        glyphCacheLock.lock()
        if glyphAdvanceCache.count > 2048 { glyphAdvanceCache.removeAll(keepingCapacity: true) }
        glyphAdvanceCache[key] = factor
        glyphCacheLock.unlock()
        return factor
    }

    private static func resolveFontDesign(_ raw: String) -> Font.Design {
        switch raw.lowercased() {
        case "serif":      return .serif
        case "rounded":    return .rounded
        case "monospaced": return .monospaced
        default:           return .default
        }
    }

    private static func blendColors(_ c1: Color, _ c2: Color, fraction: Double) -> Color {
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

    private static func polarHitDistance(
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
    private func renderVectorShapeView(_ shape: KroutonVectorShapeLayer) -> some View {
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
    }
}
