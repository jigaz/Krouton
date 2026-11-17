import CoreText
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

// MARK: - Stage 1 Clean Printable Disc Canvas (Live Reactive Inputs + Interactive Drag-on-Disc)

public struct KroutonDiscLabelArtworkCanvas: View {
    @State var activeDragTargetID: UUID?
    @State var freehandDraftPoints: [KroutonNormalizedPoint] = []
    public var onCommitFreehandStroke: (([KroutonNormalizedPoint]) -> Void)? = nil
    public let preset: KroutonDiscLabelGeometry
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
    public var onDragVectorShape: ((UUID, Double, Double) -> Void)?

    public init(
        preset: KroutonDiscLabelGeometry,
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
        onSelectOrDragText: ((UUID, Double, Double) -> Void)? = nil,
        onDragVectorShape: ((UUID, Double, Double) -> Void)? = nil,
        onCommitFreehandStroke: (([KroutonNormalizedPoint]) -> Void)? = nil
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
        self.onDragVectorShape = onDragVectorShape
        self.onCommitFreehandStroke = onCommitFreehandStroke
    }

    var outerMM: Double {
        max(70.0, min(120.0, preset.outerDiameterMM))
    }

    var innerMM: Double {
        max(15.0, min(54.0, preset.innerDiameterMM))
    }

    var holeDiameter: CGFloat {
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

            // 2B. Parametric Vector Shapes & Live Freehand Draft Stroke
            ForEach(vectorShapes) { shape in
                renderVectorShapeView(shape)
            }
            if freehandDraftPoints.count >= 2 {
                renderVectorShapeView(KroutonVectorShapeLayer(
                    name: "Draft", kind: .smoothBezier, points: freehandDraftPoints,
                    strokeWidthPoints: 2.2, isClosed: false,
                    strokeColor: KroutonRGBAColor(r: 0.25, g: 0.92, b: 1.0, a: 0.95)
                ))
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
                    guard !isExportMode else { return }
                    let halfD = max(1.0, Double(diameterPoints) * 0.5)
                    let center = CGPoint(x: diameterPoints * 0.5, y: diameterPoints * 0.5)
                    if onCommitFreehandStroke != nil {
                        let curNX = max(-0.92, min(0.92, Double(val.location.x - center.x) / halfD))
                        let curNY = max(-0.92, min(0.92, Double(val.location.y - center.y) / halfD))
                        freehandDraftPoints.append(KroutonNormalizedPoint(nx: curNX, ny: curNY))
                        return
                    }
                    if let onShapeDrag = onDragVectorShape, !vectorShapes.isEmpty {
                        if activeDragTargetID == nil {
                            let sNX = Double(val.startLocation.x - center.x) / halfD
                            let sNY = Double(val.startLocation.y - center.y) / halfD
                            activeDragTargetID = KroutonLabelGeometryEngine.nearestVectorShapeID(in: vectorShapes, normalizedX: sNX, normalizedY: sNY)
                        }
                        if let shapeID = activeDragTargetID {
                            let curNX = Double(val.location.x - center.x) / halfD
                            let curNY = Double(val.location.y - center.y) / halfD
                            onShapeDrag(shapeID, curNX, curNY)
                        }
                        return
                    }
                    guard let onDrag = onSelectOrDragText, !textElements.isEmpty else { return }
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
                    if let commit = onCommitFreehandStroke, freehandDraftPoints.count >= 3 {
                        commit(freehandDraftPoints)
                    }
                    freehandDraftPoints.removeAll()
                    activeDragTargetID = nil
                }
        )
    }

    @ViewBuilder
    var discSurfaceBackground: some View {
        let midRatio = max(0.08, min(0.92, gradientMidpoint))
        let ang = Angle.degrees(gradientAngle)

        let (r1, g1, b1, _) = KroutonPureColorMath.extractSRGB(bgPrimaryColor)
        let (r2, g2, b2, _) = KroutonPureColorMath.extractSRGB(bgSecondaryColor)
        if (!bgAdjustments.isIdentity && backgroundStyle != .templateDefault) || backgroundStyle == .gpuKaleidoscope || backgroundStyle == .tinyPlanetGlobe {
            if let cgImg = KroutonLabelGeometryEngine.renderOpticalPlaygroundCGImage(
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

    var alignmentGridOverlay: some View {
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
}
