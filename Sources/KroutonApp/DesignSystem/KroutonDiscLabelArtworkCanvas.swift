import SwiftUI
import OpticalDough
import Crustini

// MARK: - Stage 1 Clean Printable Disc Canvas (Live Reactive Inputs + Interactive Drag-on-Disc)

public struct KroutonDiscLabelArtworkCanvas: View {
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
            // 1. Printable Disc Surface (Blank White Disc, Solid Color, or Circular Radial Gradient)
            discSurfaceBackground

            // 2. Optional 10mm Alignment Grid
            if showAlignmentGrid && !isExportMode {
                alignmentGridOverlay
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
                    let clampedRadiusMM = max(16.0, min(56.0, (distPts / max(0.1, pointsPerMM)).rounded()))

                    // Convert Cartesian (dx, dy) to Clock Angle (0° = 12 o'clock top, 90° = 3 o'clock right)
                    var deg = (atan2(dy, dx) * 180.0 / Double.pi) + 90.0
                    if deg < 0 { deg += 360.0 }
                    let snappedDeg = (deg / 2.0).rounded() * 2.0

                    // If starting a tap/drag, pick the nearest text layer or the currently selected layer
                    let targetID = selectedTextID ?? textElements.last!.id
                    onDrag(targetID, clampedRadiusMM, snappedDeg)
                }
        )
    }

    @ViewBuilder
    private var discSurfaceBackground: some View {
        let midRatio = max(0.08, min(0.92, gradientMidpoint))
        let ang = Angle.degrees(gradientAngle)

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
        case .angularGradient, .gpuKaleidoscope, .tinyPlanetGlobe:
            Circle()
                .fill(
                    AngularGradient(
                        colors: [bgPrimaryColor, bgSecondaryColor, bgPrimaryColor],
                        center: .center,
                        angle: ang
                    )
                )
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.blue.opacity(isSelected ? 0.55 : 0.0), style: StrokeStyle(lineWidth: 1.0, dash: [3, 2]))
                    )
                    .offset(x: dx, y: dy)
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
        let advances = chars.map { Double(characterWidthFactor($0)) * fontSizePts * max(0.5, tracking) }
        let totalArcLen = advances.reduce(0.0, +)
        let totalAngleSpan = totalArcLen / safeR

        var out: [ArcGlyphPlacement] = []
        if !isBottomUpright {
            var cursorAngle = centerAngleRad - (totalAngleSpan * 0.5)
            for (idx, ch) in chars.enumerated() {
                let halfStep = (advances[idx] * 0.5) / safeR
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
                let halfStep = (advances[idx] * 0.5) / safeR
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

    private static func characterWidthFactor(_ ch: Character) -> CGFloat {
        switch ch {
        case "I", "i", "l", "1", "!", "|", ".", ",", ":", ";", "'", " ":
            return 0.38
        case "W", "M", "m", "w", "@", "%", "—":
            return 0.88
        case "f", "j", "r", "t", "(", ")", "[", "]":
            return 0.48
        default:
            return 0.64
        }
    }

    private static func resolveFontDesign(_ raw: String) -> Font.Design {
        switch raw {
        case "Rounded":    return .rounded
        case "Serif":      return .serif
        case "Monospaced": return .monospaced
        default:           return .default
        }
    }

    private static func blendColors(_ c1: Color, _ c2: Color, fraction: Double) -> Color {
        let (r1, g1, b1, a1) = KroutonPureColorMath.extractSRGB(c1)
        let (r2, g2, b2, a2) = KroutonPureColorMath.extractSRGB(c2)
        let t = max(0.0, min(1.0, fraction))
        let r = Double(r1) + (Double(r2) - Double(r1)) * t
        let g = Double(g1) + (Double(g2) - Double(g1)) * t
        let b = Double(b1) + (Double(b2) - Double(b1)) * t
        let a = Double(a1) + (Double(a2) - Double(a1)) * t
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
