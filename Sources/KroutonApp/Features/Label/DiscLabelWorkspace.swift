import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Stage 1 Disc Label Designer: Photoshop-Style Left Tool Rail + Blank Disc + Circular Gradient + Curved Text Tool

enum KroutonStage1Tool: String, CaseIterable, Identifiable {
    case select     = "Select"
    case text       = "Text Tool"
    case shapes     = "Vector Shapes"
    case background = "Background"
    case adjust     = "Adjust FX"
    case discSize   = "Disc Size"
    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .select:     return "cursorarrow"
        case .text:       return "textformat"
        case .shapes:     return "seal.fill"
        case .background: return "circle.lefthalf.filled"
        case .adjust:     return "slider.horizontal.3"
        case .discSize:   return "ruler"
        }
    }

    var railLabel: String {
        switch self {
        case .select:     return "Move"
        case .text:       return "Text"
        case .shapes:     return "Shapes"
        case .background: return "Bg"
        case .adjust:     return "Adjust"
        case .discSize:   return "Size"
        }
    }
}

struct KroutonDiscLabelWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @State var activeTool: KroutonStage1Tool = .background
    @State var newPresetName: String = ""
    @State var workingGeometryOverride: KroutonDiscLabelGeometry? = nil
    @State var statusBanner: String = ""

    init(store: KroutonStateStore) {
        self.store = store
    }

    var safePresetIndex: Int {
        min(max(0, store.selectedLabelPresetIndex), max(0, store.labelPresets.count - 1))
    }

    var activePreset: KroutonDiscLabelGeometry {
        if let override = store.labelWorkspaceSubStore.workingGeometryOverride { return override }
        guard !store.labelPresets.isEmpty else {
            return KroutonDiscLabelGeometry(
                name: "Standard 120mm Disc",
                outerDiameterMM: 120.0,
                innerDiameterMM: 18.0,
                offsetXMM: 0.0,
                offsetYMM: 0.0
            )
        }
        return store.labelPresets[safePresetIndex]
    }

    var selectedTextIndex: Int? {
        guard let id = store.labelSelectedTextID else {
            return store.labelTextElements.isEmpty ? nil : 0
        }
        return store.labelTextElements.firstIndex(where: { $0.id == id })
    }

    var activeGeometryBinding: Binding<KroutonDiscLabelGeometry> {
        Binding(
            get: {
                if let override = store.labelWorkspaceSubStore.workingGeometryOverride { return override }
                guard !store.labelPresets.isEmpty else {
                    return KroutonDiscLabelGeometry(
                        name: "Standard 120mm Disc",
                        outerDiameterMM: 120.0,
                        innerDiameterMM: 18.0,
                        offsetXMM: 0.0,
                        offsetYMM: 0.0
                    )
                }
                let idx = min(max(0, store.selectedLabelPresetIndex), store.labelPresets.count - 1)
                return store.labelPresets[idx]
            },
            set: { store.labelWorkspaceSubStore.workingGeometryOverride = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            topHeaderBar(preset: activePreset)
            Divider()

            HStack(spacing: 0) {
                // 1. Photoshop-Style Left-Hand Vertical Icon Rail
                photoshopLeftToolRail()

                Divider()

                // 2. Center Dark Workspace Pasteboard + Blank Disc Canvas + Bottom Zoom/Grid Bar
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        ZStack {
                            Color(red: 0.11, green: 0.12, blue: 0.14)

                            let baseDim = min(max(240, min(geo.size.width - 48, geo.size.height - 48)), 420)
                            KroutonDiscLabelArtworkCanvas(
                                preset: activePreset,
                                template: store.selectedLabelTemplate,
                                title: store.labelDiscTitle,
                                subtitle: store.labelSubtitle,
                                performer: store.discPerformer,
                                mcnBarcode: store.discMCNBarcode,
                                trackLines: [],
                                showTracklist: false,
                                primaryColor: store.activeAccent,
                                harmonyColor: store.uiSecondaryAccent,
                                isExportMode: false,
                                diameterPoints: baseDim * CGFloat(store.labelCanvasZoom),
                                backgroundStyle: store.labelBackgroundStyle,
                                bgPrimaryColor: store.labelBgPrimaryColor,
                                bgSecondaryColor: store.labelBgSecondaryColor,
                                gradientMidpoint: store.labelGradientMidpoint,
                                gradientAngle: store.labelGradientAngle,
                                gpuSeedPattern: store.labelGPUSeedPattern,
                                kaleidoscopeFacets: store.labelKaleidoscopeFacets,
                                kaleidoscopeRig: store.labelKaleidoscopeRig,
                                chamberTumble: store.labelChamberTumble,
                                tinyPlanetRadius: store.labelTinyPlanetRadius,
                                bgAdjustments: store.labelBgAdjustments,
                                vectorShapes: store.labelVectorShapes,
                                textElements: store.labelTextElements,
                                selectedTextID: store.labelSelectedTextID,
                                showAlignmentGrid: store.labelShowAlignmentGrid,
                                onSelectOrDragText: { targetID, newRadiusMM, newAngleDeg in
                                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
                                    if let idx = store.labelTextElements.firstIndex(where: { $0.id == targetID }) {
                                        store.labelSelectedTextID = targetID
                                        if store.labelTextElements.indices.contains(idx) { store.labelTextElements[idx].radiusMM = newRadiusMM }
                                        if store.labelTextElements.indices.contains(idx) { store.labelTextElements[idx].angleDegrees = newAngleDeg }
                                        activeTool = .text
                                    }
                                },
                                onDragVectorShape: (activeTool == .shapes || store.labelTextElements.isEmpty) ? { shapeID, nx, ny in
                                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
                                    if let idx = store.labelVectorShapes.firstIndex(where: { $0.id == shapeID }),
                                       store.labelVectorShapes.indices.contains(idx) {
                                        store.labelVectorShapes[idx] = KroutonLabelGeometryEngine.recenterVectorShape(
                                            store.labelVectorShapes[idx],
                                            toNormalizedX: nx,
                                            normalizedY: ny
                                        )
                                        activeTool = .shapes
                                    }
                                } : nil,
                                onCommitFreehandStroke: (activeTool == .shapes && store.labelWorkspaceSubStore.isFreehandDrawMode) ? { pts in
                                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                                    let (cr, cg, cb, _) = KroutonPureColorMath.extractSRGB(store.activeAccent)
                                    let stroke = KroutonRGBAColor(r: Double(cr), g: Double(cg), b: Double(cb), a: 0.95)
                                    let recognized = KroutonLabelGeometryEngine.recognizeAndVectorizeDrawnStroke(
                                        rawPoints: pts,
                                        autoSnapGeometry: store.labelWorkspaceSubStore.autoSnapFreehandShapes,
                                        strokeColor: stroke
                                    )
                                    store.labelVectorShapes.append(recognized)
                                    showTransientBanner("Added \(recognized.name)")
                                } : nil
                            )
                            .contextMenu {
                                Button(KroutonL10n.tr("Add Curved Text Layer")) { addDefaultCurvedTextLayer() }.keyboardShortcut("t", modifiers: .command)
                                Button(store.labelShowAlignmentGrid ? "Hide 10mm Alignment Grid" : "Show 10mm Alignment Grid") { store.labelShowAlignmentGrid.toggle() }.keyboardShortcut("g", modifiers: .command)
                                Button(KroutonL10n.tr("Actual Size (100%)")) { store.labelCanvasZoom = 1.0 }.keyboardShortcut("0", modifiers: [.command, .option])
                                Divider()
                                Button(KroutonL10n.tr("Delete Selected Text Layer"), role: .destructive) { deleteSelectedLabelTextLayer() }.keyboardShortcut(.delete, modifiers: .command).disabled(store.labelSelectedTextID == nil)
                            }
                            .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
                        }
                    }

                    Divider()
                    bottomCanvasStatusBar(preset: activePreset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // 3. Right Contextual Tool Inspector (Only shows controls for the active tool)
                ScrollView {
                    contextualInspectorPanel()
                        .padding(14)
                }
                .frame(width: 296)
                .background(Color.primary.opacity(0.03))
            }
        }
    }

    // MARK: - Subviews & Helper Methods

    func showTransientBanner(_ message: String) {
        statusBanner = message
        store.labelWorkspaceSubStore.transientStatusBanner = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if statusBanner == message {
                statusBanner = ""
                store.labelWorkspaceSubStore.transientStatusBanner = ""
            }
        }
    }
}
