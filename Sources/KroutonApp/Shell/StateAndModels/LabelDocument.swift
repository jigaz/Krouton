import SwiftUI
import Foundation
import OpticalCore
import LabelKit
import RescueKit

/// Feature model owning the Polar Disc Label Workspace document state and printer presets.
public struct LabelDocument: Equatable, Sendable {
    public var selectedTemplate: KroutonCroutonLabelStyle = .synthGrid
    public var showTracklistOnDisc: Bool = true
    public var discTitle: String = ""
    public var subtitle: String = ""
    public var autoSearchQuery: String = ""
    public var backgroundStyle: KroutonVectorBackgroundStyle = .templateDefault
    public var bgPrimaryColor: Color = Color(red: 0.09, green: 0.12, blue: 0.20)
    public var bgSecondaryColor: Color = Color(red: 0.20, green: 0.48, blue: 0.78)
    public var gradientAngle: Double = 45.0
    public var gradientMidpoint: Double = 0.85
    public var topArcRadiusMM: Double = 47.0
    public var bottomArcRadiusMM: Double = 45.0
    public var arcLetterSpacing: Double = 1.0
    public var vectorShapes: [KroutonVectorShapeLayer] = []
    public var drawAutoSnap: Bool = true
    public var isVectorDrawMode: Bool = false
    public var gpuSeedPattern: KroutonGPUSeedPattern = .neonLaserPrism
    public var kaleidoscopeFacets: Int = 8
    public var kaleidoscopeRig: KroutonKaleidoscopeMirrorRig = .twoMirrorRosette
    public var chamberTumble: Double = 0.35
    public var tinyPlanetRadius: Double = 0.75
    public var useVisionForeground: Bool = false
    public var polarSymmetryCount: Int = 1
    public var textElements: [KroutonLabelTextElement] = []
    public var selectedTextID: UUID? = nil
    public var bgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments()
    public var showAlignmentGrid: Bool = false
    public var canvasZoom: Double = 1.0

    public var presets: [KroutonDiscLabelGeometry] = [
        KroutonDiscLabelGeometry(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    public var selectedPresetIndex: Int = 0
    public var defaultAutoLabelStyle: String = "Full-Bleed Artwork + Arc Typography"
    public var visionHoleAvoidance: Bool = true
    public var customTMDBKey: String = ""
    public var customFanartKey: String = ""

    public init() {}

    public mutating func stampTracklist(titleText: String, performerText: String, tracks: [KroutonAudioCube]) {
        textElements.removeAll()
        textElements.append(KroutonLabelTextElement(text: titleText, isCurvedArc: true, radiusMM: 44.0, angleDegrees: 0.0, fontSizePoints: 14.0, isBold: true))
        textElements.append(KroutonLabelTextElement(text: performerText, isCurvedArc: true, radiusMM: 38.0, angleDegrees: 180.0, fontSizePoints: 10.5, isBottomUpright: true, isBold: true))
        for (i, cube) in tracks.prefix(5).enumerated() {
            let line = String(format: "%02d. %@ (%@)", i + 1, cube.title, cube.formattedDurationMMSSFF)
            textElements.append(KroutonLabelTextElement(text: line, isCurvedArc: false, radiusMM: 28.0 - Double(i) * 3.0, angleDegrees: 90.0, fontSizePoints: 7.5))
        }
    }
}
