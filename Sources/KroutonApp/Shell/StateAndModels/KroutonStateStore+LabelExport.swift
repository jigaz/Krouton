import CoreImage
import LabelKit
import OpticalCore
import SwiftUI

// MARK: - KroutonStateStore Label Export

extension KroutonStateStore {
    /// The disc geometry in use: the Disc Size override, else the chosen preset.
    @MainActor
    var activeLabelGeometry: KroutonDiscLabelGeometry {
        let idx = min(max(0, self.selectedLabelPresetIndex), max(0, self.labelPresets.count - 1))
        return self.labelWorkspaceSubStore.workingGeometryOverride ?? (self.labelPresets.isEmpty
            ? KroutonDiscLabelGeometry(name: "Standard 120mm Disc", outerDiameterMM: 120, innerDiameterMM: 18, offsetXMM: 0, offsetYMM: 0)
            : self.labelPresets[idx])
    }

    /// Opens a panorama for the planet background. Returns why it couldn't, or nil.
    @MainActor
    @discardableResult
    func loadPlanetPhoto(_ url: URL) -> String? {
        guard let image = KroutonPlanetSource.loadImage(at: url),
              let source = KroutonPlanetSource(cgImage: image, maxWidth: 2_400) else {
            return "Krouton couldn't open \(url.lastPathComponent) as a photo."
        }
        self.labelPlanetPhotoURL = url
        self.labelPlanetPreviewSource = source
        self.labelPlanetThumbnail = KroutonPlanetSource.loadImage(at: url, maxPixel: 720)
        return nil
    }

    // MARK: - Export

    enum LabelExportKind { case png, pdf }

    /// Renders the label at the print resolution with the print settings (ink, bleed) and saves
    /// it to Downloads. Returns the status line to show.
    @MainActor
    func exportDiscLabel(_ kind: LabelExportKind) -> String {
        let preset = activeLabelGeometry
        let print = self.labelPrint
        let dpi = Double(max(150, min(1_200, print.dotsPerInch)))
        let pixels = CGFloat((preset.outerDiameterMM / 25.4 * dpi).rounded())
        var planetSource = self.labelPlanetPreviewSource
        if self.labelBackgroundStyle == .tinyPlanetGlobe, let url = self.labelPlanetPhotoURL,
           let full = KroutonPlanetSource.loadImage(at: url).flatMap({ KroutonPlanetSource(cgImage: $0, maxWidth: 8_192) }) {
            planetSource = full
        }
        let exportCanvas = KroutonDiscLabelArtworkCanvas(
            preset: preset,
            isExportMode: true,
            diameterPoints: pixels,
            backgroundStyle: self.labelBackgroundStyle,
            bgPrimaryColor: self.labelBgPrimaryColor,
            bgSecondaryColor: self.labelBgSecondaryColor,
            gradientMidpoint: self.labelGradientMidpoint,
            gradientAngle: self.labelGradientAngle,
            gpuSeedPattern: self.labelGPUSeedPattern,
            kaleidoscopeFacets: self.labelKaleidoscopeFacets,
            kaleidoscopeRig: self.labelKaleidoscopeRig,
            chamberTumble: self.labelChamberTumble,
            planet: self.labelPlanet,
            planetSource: planetSource,
            bgAdjustments: self.labelBgAdjustments,
            vectorShapes: self.labelVectorShapes,
            textElements: self.labelTextElements
        )
        let renderer = ImageRenderer(content: exportCanvas)
        renderer.scale = 1.0
        guard let rendered = renderer.cgImage else { return "Krouton couldn't render the label." }
        let inked = KroutonLabelGeometryEngine.applyInk(to: rendered, density: print.inkDensity, blackLift: print.blackLift)
        let bled = KroutonLabelGeometryEngine.addBleed(
            to: inked, outerMM: preset.outerDiameterMM, innerMM: preset.innerDiameterMM,
            bleedOuterMM: print.bleedOuterMM, bleedInnerMM: print.bleedInnerMM)
        let files = KroutonLabelGeometryEngine.writeDiscLabelExportFiles(
            discCGImage: bled,
            presetName: preset.name,
            outerDiameterMM: preset.outerDiameterMM,
            innerDiameterMM: preset.innerDiameterMM,
            offsetXMM: preset.offsetXMM,
            offsetYMM: preset.offsetYMM,
            discTitle: self.discVolumeTitle,
            exportPNG: kind == .png,
            exportPDF: kind == .pdf,
            dpi: dpi,
            bleedOuterMM: print.bleedOuterMM,
            bleedInnerMM: print.bleedInnerMM,
            cropMarks: print.cropMarks)
        if let url = files.pdfURL ?? files.pngURL {
            return "Saved \(url.lastPathComponent) to Downloads"
        }
        return "Krouton couldn't save the label to Downloads."
    }

    /// Saves the alignment test sheet (rings 1 mm apart and a crosshair) to Downloads.
    @MainActor
    func exportAlignmentTest() -> String {
        let preset = activeLabelGeometry
        guard let data = KroutonLabelGeometryEngine.alignmentTestPDF(
            outerMM: preset.outerDiameterMM, innerMM: preset.innerDiameterMM,
            offsetXMM: preset.offsetXMM, offsetYMM: preset.offsetYMM) else { return "Krouton couldn't draw the test sheet." }
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let url = folder.appendingPathComponent("Krouton_Alignment_Test_\(Int(preset.outerDiameterMM))mm.pdf")
        do {
            try data.write(to: url, options: .atomic)
            return "Saved \(url.lastPathComponent) to Downloads"
        } catch {
            return "Krouton couldn't save the test sheet: \(error.localizedDescription)"
        }
    }

    @MainActor
    func executeLabelDestinationExport() {
        _ = exportDiscLabel(.png)
        self.labelWorkspaceSubStore.transientStatusBanner = exportDiscLabel(.pdf)
    }
}
