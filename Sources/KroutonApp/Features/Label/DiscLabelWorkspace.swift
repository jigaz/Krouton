import SwiftUI
import UniformTypeIdentifiers
import OpticalCore
import LabelKit
import RescueKit

// MARK: - Stage 1 Disc Label Designer: Photoshop-Style Left Tool Rail + Blank Disc + Circular Gradient + Curved Text Tool

public enum KroutonStage1Tool: String, CaseIterable, Identifiable {
    case select     = "Select"
    case text       = "Text Tool"
    case shapes     = "Vector Shapes"
    case background = "Background"
    case adjust     = "Adjust FX"
    case discSize   = "Disc Size"
    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .select:     return "cursorarrow"
        case .text:       return "textformat"
        case .shapes:     return "seal.fill"
        case .background: return "circle.lefthalf.filled"
        case .adjust:     return "slider.horizontal.3"
        case .discSize:   return "ruler"
        }
    }

    public var railLabel: String {
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

public struct KroutonDiscLabelWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @State var activeTool: KroutonStage1Tool = .background
    @State var newPresetName: String = ""
    @State var workingGeometryOverride: KroutonSliceLabelGeometry? = nil
    @State var statusBanner: String = ""

    public init(store: KroutonStateStore) {
        self.store = store
    }

    var safePresetIndex: Int {
        min(max(0, store.selectedLabelPresetIndex), max(0, store.labelPresets.count - 1))
    }

    var liveCanvasSnapshot: KroutonLabelCanvasSnapshot {
        KroutonLabelCanvasSnapshot(from: store, overrideGeometry: store.labelWorkspaceSubStore.workingGeometryOverride)
    }

    var activePreset: KroutonSliceLabelGeometry {
        if let override = store.labelWorkspaceSubStore.workingGeometryOverride { return override }
        guard !store.labelPresets.isEmpty else {
            return KroutonSliceLabelGeometry(
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


    var activeGeometryBinding: Binding<KroutonSliceLabelGeometry> {
        Binding(
            get: {
                if let override = store.labelWorkspaceSubStore.workingGeometryOverride { return override }
                guard !store.labelPresets.isEmpty else {
                    return KroutonSliceLabelGeometry(
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

    public var body: some View {
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
                                        store.labelVectorShapes[idx] = KroutonKrustiniModule.recenterVectorShape(
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
                                    let recognized = KroutonKrustiniModule.recognizeAndVectorizeDrawnStroke(
                                        rawPoints: pts,
                                        autoSnapGeometry: store.labelWorkspaceSubStore.autoSnapFreehandShapes,
                                        strokeColor: stroke
                                    )
                                    store.labelVectorShapes.append(recognized)
                                    showTransientBanner("Added \(recognized.name)")
                                } : nil
                            )
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

    // MARK: - Top Header Bar (Preset Selector + Export 300-DPI PNG)

    private func topHeaderBar(preset: KroutonSliceLabelGeometry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "opticaldisc")
                .font(.title3)
                .foregroundStyle(store.activeAccent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Optical Disc Label Designer")
                    .font(.headline.bold())
                Text("\(preset.name) • Outer \(Int(preset.outerDiameterMM))mm / Hub \(Int(preset.innerDiameterMM))mm • Offset X:\(String(format: "%+.1f", preset.offsetXMM)) Y:\(String(format: "%+.1f", preset.offsetYMM))mm")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("Preset:")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Picker("Preset", selection: $store.selectedLabelPresetIndex) {
                ForEach(store.labelPresets.indices, id: \.self) { idx in
                    Text(store.labelPresets[idx].name).tag(idx)
                }
            }
            .labelsHidden()
            .frame(width: 195)

            Button {
                Task { @MainActor in
                    let summary = await AutoLabelEngine.generateAndApply(to: store)
                    showTransientBanner(summary)
                }
            } label: {
                Label("Auto Label", systemImage: "wand.and.stars")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(store.activeAccent)
            .controlSize(.small)
            .help("Automatically harvest embedded/folder/MusicBrainz artwork, extract Display-P3 palette with Vision center-hole avoidance, and lay out curved arc typography")

            Button {
                exportHighRes300DPILabelPNG(preset: preset, isTestPrintSheet: true)
            } label: {
                Label("Export 1:1 PDF", systemImage: "printer.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Save a 1:1 millimeter-calibrated Vector PDF print sheet to ~/Downloads")

            Button {
                exportHighRes300DPILabelPNG(preset: preset, isTestPrintSheet: false)
            } label: {
                Label("Export 300-DPI PNG", systemImage: "square.and.arrow.down.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(store.activeAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - 1. Photoshop-Style Left-Hand Vertical Icon Rail

    private func photoshopLeftToolRail() -> some View {
        VStack(spacing: 10) {
            ForEach(KroutonStage1Tool.allCases) { tool in
                let isSelected = (activeTool == tool)
                Button {
                    activeTool = tool
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tool.railLabel)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .frame(width: 44, height: 44)
                    .background(isSelected ? store.activeAccent : Color.primary.opacity(0.06))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .help(tool.rawValue)
            }

            Divider().frame(width: 28)

            // Quick "+ Text" action right on the rail
            Button {
                addNewTextElement()
                activeTool = .text
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "plus.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("+Text")
                        .font(.system(size: 9, weight: .semibold))
                }
                .frame(width: 44, height: 40)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("Add a new curved or straight text layer to the disc")

            Spacer()

            // Reset to Blank White Disc at bottom of rail
            HStack(spacing: 4) {
                Button {
                    store.labelWorkspaceSubStore.undo(into: store)
                    showTransientBanner("Undid Last Canvas Edit")
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!store.labelWorkspaceSubStore.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo Label Canvas Edit (Cmd+Z)")

                Button {
                    store.labelWorkspaceSubStore.redo(into: store)
                    showTransientBanner("Redid Canvas Edit")
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!store.labelWorkspaceSubStore.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("Redo Label Canvas Edit (Cmd+Shift+Z)")
            }

            Button {
                store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                store.labelBackgroundStyle = .templateDefault
                store.labelBgAdjustments = KroutonBackgroundAdjustments()
                store.labelVectorShapes.removeAll()
                store.labelTextElements.removeAll()
                store.labelSelectedTextID = nil
                showTransientBanner("Reset to Blank White Printable Disc")
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Blank")
                        .font(.system(size: 9, weight: .medium))
                }
                .frame(width: 44, height: 40)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear disc back to a blank white printable surface")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: 58)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - 2. Bottom Canvas Bar (Zoom, 10mm Alignment Grid, Test Print)

    private func bottomCanvasStatusBar(preset: KroutonSliceLabelGeometry) -> some View {
        HStack(spacing: 10) {
            Button { store.labelCanvasZoom = max(0.65, store.labelCanvasZoom - 0.10) } label: {
                Image(systemName: "minus.magnifyingglass").font(.caption.bold())
            }.buttonStyle(.plain)

            Slider(value: $store.labelCanvasZoom, in: 0.65...1.35)
                .frame(width: 90)

            Button { store.labelCanvasZoom = min(1.35, store.labelCanvasZoom + 0.10) } label: {
                Image(systemName: "plus.magnifyingglass").font(.caption.bold())
            }.buttonStyle(.plain)

            Button("100%") { store.labelCanvasZoom = 1.0 }
                .font(.caption2.monospaced())
                .buttonStyle(.bordered)
                .controlSize(.mini)

            Divider().frame(height: 14)

            Toggle(isOn: $store.labelShowAlignmentGrid) {
                Label("10mm Grid", systemImage: "squareshape.split.3x3")
                    .font(.caption2.bold())
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .onChange(of: store.selectedLabelPresetIndex) { _, _ in store.labelWorkspaceSubStore.workingGeometryOverride = nil }

            Spacer()

            if !statusBanner.isEmpty {
                Text(statusBanner)
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .lineLimit(1)
            } else {
                Text("\(store.labelTextElements.count) Text Layer(s) • Outer \(Int(preset.outerDiameterMM))mm / Hub \(Int(preset.innerDiameterMM))mm")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button("Test Print") {
                exportHighRes300DPILabelPNG(preset: preset, isTestPrintSheet: true)
            }
            .font(.caption.bold())
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Tool Inspector C: Disc Size Override & Save as Preset

    func discSizeOverrideInspector() -> some View {
        let pIdx = safePresetIndex
        return VStack(alignment: .leading, spacing: 12) {
            Label("Disc Size & Preset Override", systemImage: "ruler")
                .font(.subheadline.bold())

            Text("Override the Inner Hub and Outer Rim diameters for the current disc, or save your custom geometry as a reusable preset in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Inner Hub Diameter (18–50 mm)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(activePreset.innerDiameterMM)) mm")
                        .font(.caption2.monospaced().bold())
                }
                Slider(value: activeGeometryBinding.innerDiameterMM, in: 18...50, step: 1)

                HStack {
                    Text("Outer Disc Diameter (70–120 mm)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(activePreset.outerDiameterMM)) mm")
                        .font(.caption2.monospaced().bold())
                }
                Slider(value: activeGeometryBinding.outerDiameterMM, in: 70...120, step: 1)

                HStack(spacing: 6) {
                    Button("Full Hub (18/120)") {
                        activeGeometryBinding.wrappedValue.innerDiameterMM = 18
                        activeGeometryBinding.wrappedValue.outerDiameterMM = 120
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Standard (41/118)") {
                        activeGeometryBinding.wrappedValue.innerDiameterMM = 41
                        activeGeometryBinding.wrappedValue.outerDiameterMM = 118
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Mini 80mm") {
                        activeGeometryBinding.wrappedValue.innerDiameterMM = 18
                        activeGeometryBinding.wrappedValue.outerDiameterMM = 80
                    }.buttonStyle(.bordered).controlSize(.mini)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Printer X Offset (-2.0 to +2.0 mm)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%+.1f mm", activePreset.offsetXMM))
                        .font(.caption2.monospaced())
                }
                Slider(value: activeGeometryBinding.offsetXMM, in: -2.0...2.0, step: 0.1)

                HStack {
                    Text("Printer Y Offset (-2.0 to +2.0 mm)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%+.1f mm", activePreset.offsetYMM))
                        .font(.caption2.monospaced())
                }
                Slider(value: activeGeometryBinding.offsetYMM, in: -2.0...2.0, step: 0.1)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Save Override as New Preset")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                TextField("New Preset Name (e.g. Verbatim Full Hub)...", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                Button {
                    let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cur = store.labelPresets[pIdx]
                    let nameToSave = trimmed.isEmpty
                        ? "Custom Disc (\(Int(cur.outerDiameterMM))mm / \(Int(cur.innerDiameterMM))mm)"
                        : trimmed
                    let saved = KroutonSliceLabelGeometry(
                        name: nameToSave,
                        outerDiameterMM: cur.outerDiameterMM,
                        innerDiameterMM: cur.innerDiameterMM,
                        offsetXMM: cur.offsetXMM,
                        offsetYMM: cur.offsetYMM
                    )
                    store.labelPresets.append(saved)
                    store.selectedLabelPresetIndex = store.labelPresets.count - 1
                    newPresetName = ""
                    showTransientBanner("Saved Preset '\(nameToSave)'")
                } label: {
                    Label("Save as Preset in Settings", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
                .controlSize(.small)
            }
        }
    }
}
