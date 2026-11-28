import Foundation
import LabelKit
import Observation
import OpticalCore
import SwiftUI

/// Feature model owning the Polar Disc Label Workspace document state and printer presets.
@Observable
@MainActor
final class LabelDocument {
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
    var labelGPUSeedPattern: KroutonGPUSeedPattern = .neonLaserPrism
    var labelKaleidoscopeFacets: Int = 8
    var labelKaleidoscopeRig: KroutonKaleidoscopeMirrorRig = .twoMirrorRosette
    var labelChamberTumble: Double = 0.35
    /// The panorama planet (Background › Panorama Planet) and the photo it wraps.
    var labelPlanet = KroutonPlanetSettings()
    var labelPlanetPhotoURL: URL? = nil
    /// The photo decoded for the canvas, about 2,400 pixels wide; export reads the file again at
    /// full size.
    var labelPlanetPreviewSource: KroutonPlanetSource? = nil
    /// A small copy of the photo for the Planet tool's framing view.
    var labelPlanetThumbnail: CGImage? = nil
    var labelPrint = KroutonLabelPrintSettings()
    /// Shows the print's ink density on the canvas (a soft proof).
    var labelPreviewInkDensity: Bool = false
    var labelUseVisionForeground: Bool = false
    var labelTextElements: [KroutonLabelTextElement] = []
    var labelSelectedTextID: UUID? = nil
    var labelBgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments()
    var labelShowAlignmentGrid: Bool = false
    var labelCanvasZoom: Double = 1.0

    /// Disc sizes and tray offsets (Settings › Labels & Printers), kept between launches and, with
    /// settings in iCloud, on your other Macs.
    var labelPresets: [KroutonDiscLabelGeometry] = LabelDocument.defaultLabelPresets {
        didSet {
            guard KroutonStateStore.shared?.isHydratingPreferences != true,
                  let data = try? JSONEncoder().encode(labelPresets) else { return }
            KroutonPreferences.set(String(decoding: data, as: UTF8.self), for: .labelPresets)
        }
    }
    static let defaultLabelPresets: [KroutonDiscLabelGeometry] = [
        KroutonDiscLabelGeometry(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonDiscLabelGeometry(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    var selectedLabelPresetIndex: Int = 0

    /// The presets saved by `labelPresets`, or the defaults.
    static func savedLabelPresets() -> [KroutonDiscLabelGeometry] {
        guard let text = KroutonPreferences.string(for: .labelPresets), let data = text.data(using: .utf8),
              let saved = try? JSONDecoder().decode([KroutonDiscLabelGeometry].self, from: data), !saved.isEmpty else {
            return defaultLabelPresets
        }
        return saved
    }

    init() {}
}
