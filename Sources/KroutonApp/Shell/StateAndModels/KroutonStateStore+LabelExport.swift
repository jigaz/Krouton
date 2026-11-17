import CoreImage
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

// MARK: - KroutonStateStore Label Destination Export

extension KroutonStateStore {
    @MainActor
    func executeLabelDestinationExport() {
        let idx = min(max(0, self.selectedLabelPresetIndex), max(0, self.labelPresets.count - 1))
        let preset = labelWorkspaceSubStore.workingGeometryOverride ?? (self.labelPresets.isEmpty
            ? KroutonDiscLabelGeometry(name: "Standard 120mm Disc", outerDiameterMM: 120, innerDiameterMM: 18, offsetXMM: 0, offsetYMM: 0)
            : self.labelPresets[idx])
        let exportPixels: CGFloat = preset.outerDiameterMM <= 85.0 ? 945.0 : 1417.0
        let exportCanvas = KroutonDiscLabelArtworkCanvas(
            preset: preset,
            template: self.selectedLabelTemplate,
            title: self.labelDiscTitle,
            subtitle: self.labelSubtitle,
            performer: discPerformer,
            mcnBarcode: discMCNBarcode,
            trackLines: [],
            showTracklist: false,
            primaryColor: activeAccent,
            harmonyColor: uiSecondaryAccent,
            isExportMode: true,
            diameterPoints: exportPixels,
            backgroundStyle: self.labelBackgroundStyle,
            bgPrimaryColor: self.labelBgPrimaryColor,
            bgSecondaryColor: self.labelBgSecondaryColor,
            gradientMidpoint: self.labelGradientMidpoint,
            gradientAngle: self.labelGradientAngle,
            gpuSeedPattern: self.labelGPUSeedPattern,
            kaleidoscopeFacets: self.labelKaleidoscopeFacets,
            kaleidoscopeRig: self.labelKaleidoscopeRig,
            chamberTumble: self.labelChamberTumble,
            tinyPlanetRadius: self.labelTinyPlanetRadius,
            bgAdjustments: self.labelBgAdjustments,
            vectorShapes: self.labelVectorShapes,
            textElements: self.labelTextElements
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
