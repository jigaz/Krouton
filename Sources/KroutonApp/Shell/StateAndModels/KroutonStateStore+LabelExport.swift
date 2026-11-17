import CoreImage
import SwiftUI
import OpticalCore
import LabelKit
import RescueKit

// MARK: - KroutonStateStore Label Destination Export

extension KroutonStateStore {
    @MainActor
    func executeLabelDestinationExport() {
        let idx = min(max(0, selectedLabelPresetIndex), max(0, labelPresets.count - 1))
        let preset = labelWorkspaceSubStore.workingGeometryOverride ?? (labelPresets.isEmpty
            ? KroutonDiscLabelGeometry(name: "Standard 120mm Disc", outerDiameterMM: 120, innerDiameterMM: 18, offsetXMM: 0, offsetYMM: 0)
            : labelPresets[idx])
        let exportPixels: CGFloat = preset.outerDiameterMM <= 85.0 ? 945.0 : 1417.0
        let exportCanvas = KroutonDiscLabelArtworkCanvas(
            preset: preset,
            template: selectedLabelTemplate,
            title: labelDiscTitle,
            subtitle: labelSubtitle,
            performer: discPerformer,
            mcnBarcode: discMCNBarcode,
            trackLines: [],
            showTracklist: false,
            primaryColor: activeAccent,
            harmonyColor: uiSecondaryAccent,
            isExportMode: true,
            diameterPoints: exportPixels,
            backgroundStyle: labelBackgroundStyle,
            bgPrimaryColor: labelBgPrimaryColor,
            bgSecondaryColor: labelBgSecondaryColor,
            gradientMidpoint: labelGradientMidpoint,
            gradientAngle: labelGradientAngle,
            gpuSeedPattern: labelGPUSeedPattern,
            kaleidoscopeFacets: labelKaleidoscopeFacets,
            kaleidoscopeRig: labelKaleidoscopeRig,
            chamberTumble: labelChamberTumble,
            tinyPlanetRadius: labelTinyPlanetRadius,
            bgAdjustments: labelBgAdjustments,
            vectorShapes: labelVectorShapes,
            textElements: labelTextElements
        )
        let renderer = ImageRenderer(content: exportCanvas)
        renderer.scale = 1.0
        if let cgImg = renderer.cgImage {
            let files = KroutonLabelGeometryEngine.writeDiscLabelExportFiles(
                discCGImage: cgImg,
                presetName: preset.name,
                outerDiameterMM: preset.outerDiameterMM,
                innerDiameterMM: preset.innerDiameterMM,
                offsetXMM: preset.offsetXMM,
                offsetYMM: preset.offsetYMM,
                discTitle: discVolumeTitle,
                exportPNG: true,
                exportPDF: true
            )
            let pdfName = files.pdfURL?.lastPathComponent ?? "Krouton_Disc_Label_1to1_PrintSheet.pdf"
            labelWorkspaceSubStore.transientStatusBanner = "Exported 1:1 Print Sheet & 300-DPI PNG -> ~/Downloads/\(pdfName)"
        }
    }
}
