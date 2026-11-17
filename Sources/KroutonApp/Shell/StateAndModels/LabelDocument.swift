import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

/// Feature model owning the Polar Disc Label Workspace document state and printer presets.
struct LabelDocument: Equatable, Sendable {
    var selectedLabelTemplate: KroutonCroutonLabelStyle = .synthGrid
    var labelShowTracklistOnDisc: Bool = true
    var labelDiscTitle: String = ""
    var labelSubtitle: String = ""
    var autoLabelSearchQuery: String = ""
    var labelBackgroundStyle: KroutonVectorBackgroundStyle = .templateDefault
    var labelBgPrimaryColor: Color = Color(red: 0.09, green: 0.12, blue: 0.20)
    var labelBgSecondaryColor: Color = Color(red: 0.20, green: 0.48, blue: 0.78)
    var labelGradientAngle: Double = 45.0
    var labelGradientMidpoint: Double = 0.85
    var labelTopArcRadiusMM: Double = 47.0
    var labelBottomArcRadiusMM: Double = 45.0
    var labelArcLetterSpacing: Double = 1.0
    var labelVectorShapes: [KroutonVectorShapeLayer] = []
    var drawAutoSnap: Bool = true
    var isVectorDrawMode: Bool = false
    var labelGPUSeedPattern: KroutonGPUSeedPattern = .neonLaserPrism
    var labelKaleidoscopeFacets: Int = 8
    var labelKaleidoscopeRig: KroutonKaleidoscopeMirrorRig = .twoMirrorRosette
    var labelChamberTumble: Double = 0.35
    var labelTinyPlanetRadius: Double = 0.75
    var labelUseVisionForeground: Bool = false
    var polarSymmetryCount: Int = 1
    var labelTextElements: [KroutonLabelTextElement] = []
    var labelSelectedTextID: UUID? = nil
    var labelBgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments()
    var labelShowAlignmentGrid: Bool = false
    var labelCanvasZoom: Double = 1.0

    var labelPresets: [KroutonDiscLabelGeometry] = [
        KroutonDiscLabelGeometry(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    var selectedLabelPresetIndex: Int = 0
    var defaultAutoLabelStyle: String = "Full-Bleed Artwork + Arc Typography"
    var visionHoleAvoidance: Bool = true
    var customTMDBKey: String = ""
    var customFanartKey: String = ""

    init() {}
}
