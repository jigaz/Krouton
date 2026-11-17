import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

/// Feature model owning the Polar Disc Label Workspace document state and printer presets.
struct LabelDocument: Equatable, Sendable {
    var selectedTemplate: KroutonCroutonLabelStyle = .synthGrid
    var showTracklistOnDisc: Bool = true
    var discTitle: String = ""
    var subtitle: String = ""
    var autoSearchQuery: String = ""
    var backgroundStyle: KroutonVectorBackgroundStyle = .templateDefault
    var bgPrimaryColor: Color = Color(red: 0.09, green: 0.12, blue: 0.20)
    var bgSecondaryColor: Color = Color(red: 0.20, green: 0.48, blue: 0.78)
    var gradientAngle: Double = 45.0
    var gradientMidpoint: Double = 0.85
    var topArcRadiusMM: Double = 47.0
    var bottomArcRadiusMM: Double = 45.0
    var arcLetterSpacing: Double = 1.0
    var vectorShapes: [KroutonVectorShapeLayer] = []
    var drawAutoSnap: Bool = true
    var isVectorDrawMode: Bool = false
    var gpuSeedPattern: KroutonGPUSeedPattern = .neonLaserPrism
    var kaleidoscopeFacets: Int = 8
    var kaleidoscopeRig: KroutonKaleidoscopeMirrorRig = .twoMirrorRosette
    var chamberTumble: Double = 0.35
    var tinyPlanetRadius: Double = 0.75
    var useVisionForeground: Bool = false
    var polarSymmetryCount: Int = 1
    var textElements: [KroutonLabelTextElement] = []
    var selectedTextID: UUID? = nil
    var bgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments()
    var showAlignmentGrid: Bool = false
    var canvasZoom: Double = 1.0

    var presets: [KroutonDiscLabelGeometry] = [
        KroutonDiscLabelGeometry(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    var selectedPresetIndex: Int = 0
    var defaultAutoLabelStyle: String = "Full-Bleed Artwork + Arc Typography"
    var visionHoleAvoidance: Bool = true
    var customTMDBKey: String = ""
    var customFanartKey: String = ""

    init() {}

    mutating func stampTracklist(titleText: String, performerText: String, tracks: [KroutonRedBookTrack]) {
        textElements.removeAll()
        textElements.append(KroutonLabelTextElement(text: titleText, isCurvedArc: true, radiusMM: 44.0, angleDegrees: 0.0, fontSizePoints: 14.0, isBold: true))
        textElements.append(KroutonLabelTextElement(text: performerText, isCurvedArc: true, radiusMM: 38.0, angleDegrees: 180.0, fontSizePoints: 10.5, isBottomUpright: true, isBold: true))
        for (i, cube) in tracks.prefix(5).enumerated() {
            let line = String(format: "%02d. %@ (%@)", i + 1, cube.title, cube.formattedDurationMMSSFF)
            textElements.append(KroutonLabelTextElement(text: line, isCurvedArc: false, radiusMM: 28.0 - Double(i) * 3.0, angleDegrees: 90.0, fontSizePoints: 7.5))
        }
    }
}
