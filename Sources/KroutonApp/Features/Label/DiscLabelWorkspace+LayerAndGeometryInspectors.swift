import CoreImage
import LabelKit
import OpticalCore
import SwiftUI

// MARK: - Disc Label Geometry Override, Layer Overview & Vision Trace Inspectors

extension KroutonDiscLabelWorkspaceView {
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
                    Button(KroutonL10n.tr("Full Hub (18/120)")) {
                        activeGeometryBinding.wrappedValue.innerDiameterMM = 18
                        activeGeometryBinding.wrappedValue.outerDiameterMM = 120
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button(KroutonL10n.tr("Standard (41/118)")) {
                        activeGeometryBinding.wrappedValue.innerDiameterMM = 41
                        activeGeometryBinding.wrappedValue.outerDiameterMM = 118
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button(KroutonL10n.tr("Mini 80mm")) {
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
                    let saved = KroutonDiscLabelGeometry(
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
    func addDefaultCurvedTextLayer() {
        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
        let item = KroutonLabelTextElement(text: store.discVolumeTitle.isEmpty ? "DISC TITLE" : store.discVolumeTitle, isCurvedArc: true, radiusMM: 44.0, angleDegrees: 0.0, fontSizePoints: 16.0)
        store.labelTextElements.append(item); store.labelSelectedTextID = item.id
    }
    func deleteSelectedLabelTextLayer() {
        guard let id = store.labelSelectedTextID, let idx = store.labelTextElements.firstIndex(where: { $0.id == id }) else { return }
        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
        store.labelTextElements.remove(at: idx); store.labelSelectedTextID = store.labelTextElements.last?.id
    }

    // MARK: - Tool Inspector D: Select / Layer Overview

    func selectOverviewInspector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Canvas Layers Overview", systemImage: "cursorarrow")
                .font(.subheadline.bold())

            HStack {
                Text("Background:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(store.labelBackgroundStyle.rawValue) {
                    activeTool = .background
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack {
                Text("Vector Shapes (\(store.labelVectorShapes.count))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(KroutonL10n.tr("+ Shapes & Badges")) {
                    activeTool = .shapes
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Divider()

            HStack {
                Text("Text Layers (\(store.labelTextElements.count))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(KroutonL10n.tr("+ Add Text")) {
                    addNewTextElement()
                    activeTool = .text
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
                .controlSize(.mini)
            }

            if store.labelTextElements.isEmpty && store.labelVectorShapes.isEmpty {
                Text("Canvas is currently blank. Use the left tool rail to set a Circular Gradient, stamp Vector Shapes, or add Curved Arc Text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.labelTextElements) { item in
                    Button {
                        store.labelSelectedTextID = item.id
                        activeTool = .text
                    } label: {
                        HStack {
                            Image(systemName: item.isCurvedArc ? "dial.medium.fill" : "text.aligncenter")
                            Text(item.text).font(.caption.bold()).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(KroutonL10n.tr("Select Text Layer")) { store.labelSelectedTextID = item.id }
                        Button(KroutonL10n.tr("Duplicate Text Layer (180° Mirror)")) {
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            var copy = item; copy.id = UUID(); copy.angleDegrees = fmod(item.angleDegrees + 180.0, 360.0)
                            copy.isBottomUpright = (copy.angleDegrees >= 110.0 && copy.angleDegrees <= 250.0)
                            store.labelTextElements.append(copy); store.labelSelectedTextID = copy.id
                        }.keyboardShortcut("d", modifiers: .command)
                        Divider()
                        Button(KroutonL10n.tr("Delete Text Layer"), role: .destructive) {
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements.removeAll { $0.id == item.id }; store.labelSelectedTextID = store.labelTextElements.last?.id
                        }.keyboardShortcut(.delete, modifiers: .command)
                    }
                }
            }
        }
    }

    func traceActiveGPUPatternContoursWithVision() {
        let (r1, g1, b1, a1) = KroutonPureColorMath.extractSRGB(store.labelBgPrimaryColor)
        let (r2, g2, b2, a2) = KroutonPureColorMath.extractSRGB(store.labelBgSecondaryColor)
        let seedCI = KroutonLabelGeometryEngine.makeGPUSeedCIImage(
            pattern: store.labelGPUSeedPattern,
            primaryColor: KroutonRGBAColor(r: Double(r1), g: Double(g1), b: Double(b1), a: Double(a1)),
            secondaryColor: KroutonRGBAColor(r: Double(r2), g: Double(g2), b: Double(b2), a: Double(a2)),
            dimension: 256.0
        )
        let ciCtx = CIContext()
        guard let cgImg = ciCtx.createCGImage(seedCI, from: CGRect(x: 0, y: 0, width: 256, height: 256)) else { return }
        let (cr, cg, cb, _) = KroutonPureColorMath.extractSRGB(store.activeAccent)
        let stroke = KroutonRGBAColor(r: Double(cr), g: Double(cg), b: Double(cb), a: 0.88)
        let traced = KroutonLabelGeometryEngine.traceImageContoursWithVision(cgImage: cgImg, strokeColor: stroke)
        guard !traced.isEmpty else {
            showTransientBanner("No High-Contrast Contours Found in Current Pattern")
            return
        }
        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
        store.labelVectorShapes.append(contentsOf: traced.prefix(6))
        showTransientBanner("Traced \(min(6, traced.count)) Vision Vector Contours onto Disc")
    }

    // MARK: - 1-Click Project Tracklist & Staged File Manifest Stamp

    func stampProjectTracklistOrManifestOnDisc() {
        Task { @MainActor in
            let summary = await AutoLabelEngine.generateAndApply(to: store)
            showTransientBanner(summary)
        }
    }

    func safeTextElementBinding<T: Equatable>(
        _ index: Int,
        _ keyPath: WritableKeyPath<KroutonLabelTextElement, T>,
        default defaultValue: T
    ) -> Binding<T> {
        Binding(
            get: {
                guard store.labelTextElements.indices.contains(index) else { return defaultValue }
                return store.labelTextElements[index][keyPath: keyPath]
            },
            set: { newValue in
                guard store.labelTextElements.indices.contains(index) else { return }
                if store.labelTextElements[index][keyPath: keyPath] != newValue {
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
                    store.labelTextElements[index][keyPath: keyPath] = newValue
                }
            }
        )
    }
}
