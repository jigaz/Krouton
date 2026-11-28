import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Disc Label Header, Tool Rail and Canvas Bar

extension KroutonDiscLabelWorkspaceView {
    // MARK: - Header Bar

    func topHeaderBar(preset: KroutonDiscLabelGeometry) -> some View {
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

            Picker(KroutonL10n.tr("Preset"), selection: Bindable(store).selectedLabelPresetIndex) {
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
            .help("Fill in the label's title and subtitle from the disc's title and artist. With Apple Intelligence, a raw volume or file name becomes a readable title first")

            Button {
                exportLabel(.pdf)
            } label: {
                Label("Export 1:1 PDF", systemImage: "printer.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Save a 1:1 millimeter-calibrated Vector PDF print sheet to ~/Downloads")

            Button {
                exportLabel(.png)
            } label: {
                Label("Export \(store.labelPrint.dotsPerInch)-DPI PNG", systemImage: "square.and.arrow.down.fill")
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

    // MARK: - Tool Rail

    func photoshopLeftToolRail() -> some View {
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
                .accessibilityLabel("Undo")
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
                .accessibilityLabel("Redo")
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

    // MARK: - Canvas Bar (Zoom, Grid, Alignment Test)

    func bottomCanvasStatusBar(preset: KroutonDiscLabelGeometry) -> some View {
        HStack(spacing: 10) {
            Button { store.labelCanvasZoom = max(0.65, store.labelCanvasZoom - 0.10) } label: {
                Image(systemName: "minus.magnifyingglass").font(.caption.bold())
            }.buttonStyle(.plain).accessibilityLabel(KroutonL10n.tr("Zoom Out Canvas")).help(KroutonL10n.tr("Zoom Out Canvas"))

            Slider(value: Bindable(store).labelCanvasZoom, in: 0.65...1.35)
                .frame(width: 90)
                .accessibilityLabel(KroutonL10n.tr("Label Canvas Zoom"))
                .accessibilityValue("\(Int((store.labelCanvasZoom * 100).rounded()))%")

            Button { store.labelCanvasZoom = min(1.35, store.labelCanvasZoom + 0.10) } label: {
                Image(systemName: "plus.magnifyingglass").font(.caption.bold())
            }.buttonStyle(.plain).accessibilityLabel(KroutonL10n.tr("Zoom In Canvas")).help(KroutonL10n.tr("Zoom In Canvas"))

            Button("100%") { store.labelCanvasZoom = 1.0 }
                .font(.caption2.monospaced())
                .buttonStyle(.bordered)
                .controlSize(.mini)

            Divider().frame(height: 14)

            Toggle(isOn: Bindable(store).labelShowAlignmentGrid) {
                Label("10mm Grid", systemImage: "squareshape.split.3x3")
                    .font(.caption2.bold())
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .onChange(of: store.selectedLabelPresetIndex) { _, _ in store.labelWorkspaceSubStore.workingGeometryOverride = nil }

            Spacer()

            if !store.labelWorkspaceSubStore.transientStatusBanner.isEmpty {
                Text(store.labelWorkspaceSubStore.transientStatusBanner)
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .lineLimit(1)
            } else {
                Text("\(store.labelTextElements.count) Text Layer(s) • Outer \(Int(preset.outerDiameterMM))mm / Hub \(Int(preset.innerDiameterMM))mm")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button(KroutonL10n.tr("Alignment Test")) {
                showTransientBanner(store.exportAlignmentTest())
            }
            .help("Save rings 1 mm apart and a crosshair at 1:1, to print on a spare disc and read the tray offset")
            .font(.caption.bold())
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.03))
    }
}
