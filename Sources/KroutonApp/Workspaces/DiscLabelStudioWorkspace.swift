import SwiftUI
import UniformTypeIdentifiers
import OpticalDough
import Crustini

// MARK: - Stage 1 Disc Label Designer: Photoshop-Style Left Tool Rail + Blank Disc + Circular Gradient + Curved Text Tool

public enum KroutonStage1Tool: String, CaseIterable, Identifiable {
    case select     = "Select"
    case text       = "Text Tool"
    case background = "Background"
    case discSize   = "Disc Size"
    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .select:     return "cursorarrow"
        case .text:       return "textformat"
        case .background: return "circle.lefthalf.filled"
        case .discSize:   return "ruler"
        }
    }
}

public struct KroutonDiscLabelStudioWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @State var activeTool: KroutonStage1Tool = .background
    @State var newPresetName: String = ""
    @State var statusBanner: String = ""

    public init(store: KroutonStateStore) {
        self.store = store
    }

    var safePresetIndex: Int {
        min(max(0, store.selectedLabelPresetIndex), max(0, store.labelPresets.count - 1))
    }

    var activePreset: KroutonSliceLabelGeometry {
        store.labelPresets[safePresetIndex]
    }

    var selectedTextIndex: Int? {
        guard let id = store.labelSelectedTextID else {
            return store.labelTextElements.isEmpty ? nil : 0
        }
        return store.labelTextElements.firstIndex(where: { $0.id == id })
    }

    public var body: some View {
        VStack(spacing: 0) {
            topHeaderBar(preset: activePreset)
            Divider()

            HStack(spacing: 0) {
                // 1. Photoshop-Style Left-Hand Vertical Icon Rail
                photoshopLeftToolRail()

                Divider()

                // 2. Center Dark Studio Pasteboard + Blank Disc Canvas + Bottom Zoom/Grid Bar
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
                                textElements: store.labelTextElements,
                                selectedTextID: store.labelSelectedTextID,
                                showAlignmentGrid: store.labelShowAlignmentGrid,
                                onSelectOrDragText: { targetID, newRadiusMM, newAngleDeg in
                                    if let idx = store.labelTextElements.firstIndex(where: { $0.id == targetID }) {
                                        store.labelSelectedTextID = targetID
                                        store.labelTextElements[idx].radiusMM = newRadiusMM
                                        store.labelTextElements[idx].angleDegrees = newAngleDeg
                                        activeTool = .text
                                    }
                                }
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
                        Text(tool == .background ? "Bg" : (tool == .discSize ? "Size" : (tool == .text ? "Text" : "Move")))
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
            Button {
                store.labelBackgroundStyle = .templateDefault
                store.labelTextElements.removeAll()
                store.labelSelectedTextID = nil
                statusBanner = "Reset to Blank White Printable Disc"
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
}
