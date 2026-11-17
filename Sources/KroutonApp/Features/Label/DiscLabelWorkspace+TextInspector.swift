import SwiftUI
import UniformTypeIdentifiers
import OpticalCore
import LabelKit
import RescueKit

// MARK: - Disc Label Curved & Straight Text Inspector + 300-DPI Exporter

extension KroutonDiscLabelWorkspaceView {
    // MARK: - Tool Inspector B: Curved & Straight Text Tool

    func textToolInspector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Disc Text Tool", systemImage: "textformat")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    stampProjectTracklistOrManifestOnDisc()
                } label: {
                    Label("Stamp Tracks", systemImage: "music.note.list")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Stamp staged files or Red Book audio tracks onto the disc face")

                Button {
                    addNewTextElement()
                } label: {
                    Label("Add Text", systemImage: "plus")
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(store.activeAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if store.labelTextElements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No text layers on this disc yet.")
                        .font(.caption.bold())
                    Text("Click 'Add Text' to place a title, subtitle, or artist credit that wraps smoothly along the curve of the disc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        addNewTextElement(text: store.discVolumeTitle, radiusMM: 46.0, angleDegrees: 0.0, isBottomUpright: false)
                    } label: {
                        Label("Insert Top Curved Arc Title", systemImage: "arc.up.right")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.activeAccent)
                    .controlSize(.small)

                    Button {
                        addNewTextElement(text: "2026 ARCHIVAL MASTER", radiusMM: 46.0, angleDegrees: 180.0, isBottomUpright: true)
                    } label: {
                        Label("Insert Bottom Curved Arc Text", systemImage: "arc.down.right")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
            } else {
                // Layer list selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text Layers (\(store.labelTextElements.count))")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    ForEach(store.labelTextElements) { item in
                        let isSel = (store.labelSelectedTextID == item.id) || (store.labelSelectedTextID == nil && store.labelTextElements.first?.id == item.id)
                        HStack {
                            Button {
                                store.labelSelectedTextID = item.id
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.isCurvedArc ? "dial.medium.fill" : "text.aligncenter")
                                        .font(.caption2)
                                    Text(item.text.isEmpty ? "(Empty Text)" : item.text)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(item.radiusMM))mm • \(Int(item.angleDegrees))°")
                                        .font(.system(size: 9, design: .monospaced))
                                        .opacity(0.75)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                                store.labelTextElements.removeAll { $0.id == item.id }
                                store.labelSelectedTextID = store.labelTextElements.first?.id
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundStyle(isSel ? .white.opacity(0.85) : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(KroutonL10n.tr("Delete Text Layer"))
                            .help(KroutonL10n.tr("Delete Text Layer"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isSel ? store.activeAccent : Color.primary.opacity(0.06))
                        .foregroundStyle(isSel ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }

                if let idx = selectedTextIndex {
                    Divider()
                    selectedTextElementControls(index: idx)
                }
            }
        }
    }

    @ViewBuilder
    func selectedTextElementControls(index: Int) -> some View {
        let fallbackElem = KroutonLabelTextElement(text: "", isCurvedArc: true, radiusMM: 42.0, angleDegrees: 0.0)
        let currentElem = store.labelTextElements.indices.contains(index) ? store.labelTextElements[index] : fallbackElem
        let colorBinding = Binding<Color>(
            get: {
                let c = store.labelTextElements.indices.contains(index) ? store.labelTextElements[index].color : fallbackElem.color
                return Color(red: c.r, green: c.g, blue: c.b, opacity: c.a)
            },
            set: { newCol in
                guard store.labelTextElements.indices.contains(index) else { return }
                let (r, g, b, a) = KroutonPureColorMath.extractSRGB(newCol)
                let nextRGBA = KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
                if store.labelTextElements[index].color != nextRGBA {
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
                    store.labelTextElements[index].color = nextRGBA
                }
            }
        )

        if store.labelTextElements.indices.contains(index) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Selected Text Layer")
                        .font(.caption.bold())
                    Spacer()
                    Button(role: .destructive) {
                        guard store.labelTextElements.indices.contains(index) else { return }
                        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                        store.labelTextElements.remove(at: index)
                        store.labelSelectedTextID = store.labelTextElements.last?.id
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                TextField("Enter Disc Text...", text: safeTextElementBinding(index, \.text, default: fallbackElem.text))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 8) {
                    ColorPicker("", selection: colorBinding)
                        .labelsHidden()
                        .frame(width: 28)

                    Toggle(KroutonL10n.tr("Bold"), isOn: safeTextElementBinding(index, \.isBold, default: fallbackElem.isBold))
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                        .fixedSize()

                    Toggle(KroutonL10n.tr("Shadow"), isOn: safeTextElementBinding(index, \.hasDropShadow, default: fallbackElem.hasDropShadow))
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                        .fixedSize()

                    Spacer(minLength: 2)

                    Picker(KroutonL10n.tr("Font"), selection: safeTextElementBinding(index, \.fontDesignRaw, default: fallbackElem.fontDesignRaw)) {
                        Text("Sans").tag("Default")
                        Text("Rounded").tag("Rounded")
                        Text("Serif").tag("Serif")
                        Text("Mono").tag("Monospaced")
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }

                Toggle(KroutonL10n.tr("Follow Circular Disc Arc"), isOn: safeTextElementBinding(index, \.isCurvedArc, default: fallbackElem.isCurvedArc))
                    .toggleStyle(.checkbox)
                    .font(.caption.bold())

                if currentElem.isCurvedArc {
                    Toggle(KroutonL10n.tr("Keep Bottom Arc Text Upright (Readable)"), isOn: safeTextElementBinding(index, \.isBottomUpright, default: fallbackElem.isBottomUpright))
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    HStack(spacing: 6) {
                        Button(KroutonL10n.tr("Top (0°)")) {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 0
                            store.labelTextElements[index].isBottomUpright = false
                        }.buttonStyle(.bordered).controlSize(.mini)

                        Button(KroutonL10n.tr("Bottom (180°)")) {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 180
                            store.labelTextElements[index].isBottomUpright = true
                        }.buttonStyle(.bordered).controlSize(.mini)

                        Button(KroutonL10n.tr("Left (270°)")) {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 270
                        }.buttonStyle(.bordered).controlSize(.mini)

                        Button(KroutonL10n.tr("Right (90°)")) {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 90
                        }.buttonStyle(.bordered).controlSize(.mini)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Font Size")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(currentElem.fontSizePoints)) pt")
                            .font(.caption2.monospaced())
                    }
                    Slider(value: safeTextElementBinding(index, \.fontSizePoints, default: fallbackElem.fontSizePoints), in: 8.0...38.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Distance from Center (Radius)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f mm", currentElem.radiusMM))
                            .font(.caption2.monospaced())
                    }
                    Slider(
                        value: safeTextElementBinding(index, \.radiusMM, default: fallbackElem.radiusMM),
                        in: max(12.0, activePreset.innerDiameterMM * 0.55)...(activePreset.outerDiameterMM * 0.47)
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Clock Position Angle (0° = Top)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(currentElem.angleDegrees))°")
                            .font(.caption2.monospaced())
                    }
                    Slider(value: safeTextElementBinding(index, \.angleDegrees, default: fallbackElem.angleDegrees), in: 0.0...360.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Letter Spacing (Tracking)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f×", currentElem.letterTracking))
                            .font(.caption2.monospaced())
                    }
                    Slider(value: safeTextElementBinding(index, \.letterTracking, default: fallbackElem.letterTracking), in: 0.70...1.80)
                }
            }
        }
    }

    func addNewTextElement(
        text: String = "DISC TITLE",
        radiusMM: Double = 45.0,
        angleDegrees: Double = 0.0,
        isBottomUpright: Bool = false
    ) {
        let defaultColor = (store.labelBackgroundStyle == .templateDefault)
            ? KroutonRGBAColor(r: 0.10, g: 0.11, b: 0.14, a: 1.0)
            : KroutonRGBAColor(r: 0.98, g: 0.98, b: 0.99, a: 1.0)
        let newItem = KroutonLabelTextElement(
            text: text,
            isCurvedArc: true,
            radiusMM: radiusMM,
            angleDegrees: angleDegrees,
            fontSizePoints: 16.0,
            letterTracking: 1.0,
            isBottomUpright: isBottomUpright,
            isBold: true,
            color: defaultColor
        )
        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
        store.labelTextElements.append(newItem)
        store.labelSelectedTextID = newItem.id
    }

    @MainActor
    func exportHighRes300DPILabelPNG(preset: KroutonDiscLabelGeometry, isTestPrintSheet: Bool) {
        let exportPixels: CGFloat = preset.outerDiameterMM <= 85.0 ? 945.0 : 1417.0
        let exportCanvas = KroutonDiscLabelArtworkCanvas(
            preset: preset,
            template: store.selectedLabelTemplate,
            title: store.labelDiscTitle,
            subtitle: store.labelSubtitle,
            performer: store.discPerformer,
            mcnBarcode: store.discMCNBarcode,
            trackLines: [],
            showTracklist: false,
            primaryColor: store.activeAccent,
            harmonyColor: store.uiSecondaryAccent,
            isExportMode: true,
            diameterPoints: exportPixels,
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
            textElements: store.labelTextElements
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
                discTitle: store.discVolumeTitle,
                exportPNG: !isTestPrintSheet,
                exportPDF: isTestPrintSheet
            )
            if let pdfURL = files.pdfURL {
                showTransientBanner("Saved 1:1 Print Sheet PDF -> ~/Downloads/\(pdfURL.lastPathComponent)")
            } else if let pngURL = files.pngURL {
                showTransientBanner("Saved 300-DPI PNG -> ~/Downloads/\(pngURL.lastPathComponent)")
            }
        }
    }

    func workspaceSwatchButton(_ label: String, c1: Color, c2: Color) -> some View {
        Button {
            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
            store.labelBgPrimaryColor = c1
            store.labelBgSecondaryColor = c2
        } label: {
            HStack(spacing: 4) {
                Circle().fill(LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 10, height: 10)
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(Color.primary.opacity(0.07)).clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
