import CoreImage
import SwiftUI
import OpticalCore
import LabelKit
import RescueKit

// MARK: - Stage 1 Disc Label Vector Shapes & Optical Badges Inspector + Layer Overview

extension KroutonDiscLabelWorkspaceView {
    @ViewBuilder
    func shapesAndBadgesToolInspector() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Vector Shapes & Badges", systemImage: "seal.fill")
                    .font(.subheadline.bold())
                Spacer()
                if !store.labelVectorShapes.isEmpty {
                    Button(KroutonL10n.tr("Clear All")) {
                        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                        store.labelVectorShapes.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            Text("Stamp concentric trim rings, geometric emblems, or optical format badges onto the disc surface.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 1. Parametric Vector Shapes Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Geometric Shape")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    shapeStampButton("Trim Ring", icon: "circle.circle", kind: .concentricRing, cy: 0.0, r: 0.78)
                    shapeStampButton("5-Pt Star", icon: "star.fill", kind: .star, cy: -0.52, r: 0.14)
                    shapeStampButton("Capsule Pill", icon: "capsule", kind: .capsule, cy: 0.52, r: 0.22)
                    shapeStampButton("Diamond", icon: "suit.diamond.fill", kind: .diamond, cy: -0.52, r: 0.14)
                    shapeStampButton("Pentagon", icon: "pentagon", kind: .pentagon, cy: 0.52, r: 0.15)
                    shapeStampButton("Divider Line", icon: "line.diagonal", kind: .line, cy: 0.0, r: 0.36)
                }
            }

            Divider()

            // 2. One-Click Optical Standard Format Badges
            VStack(alignment: .leading, spacing: 6) {
                Text("Stamp Optical Format Badge")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    opticalBadgeButton("Audio CD", subtitle: "Red Book 75fps", badgeText: "COMPACT DISC • DIGITAL AUDIO", kind: .roundedRect)
                    opticalBadgeButton("DVD-ROM", subtitle: "ISO / UDF Master", badgeText: "DVD-ROM • MASTER ARCHIVE", kind: .capsule)
                    opticalBadgeButton("Blu-ray BDMV", subtitle: "High Def Optical", badgeText: "BLU-RAY DISC • 25GB / 50GB", kind: .pentagon)
                    opticalBadgeButton("M-DISC Vault", subtitle: "1000-Year Stone", badgeText: "M-DISC ARCHIVAL • SHA-256", kind: .concentricRing)
                }
            }

            Divider()

            // 2B. Freehand Auto-Snap Vector Draw & Vision AI Contour Tracer
            VStack(alignment: .leading, spacing: 6) {
                Text("Freehand Draw & Vision AI Contours")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Button {
                    store.labelWorkspaceSubStore.isFreehandDrawMode.toggle()
                    store.objectWillChange.send()
                } label: {
                    Label(
                        store.labelWorkspaceSubStore.isFreehandDrawMode ? "Drawing on Disc (Active)" : "Freehand Draw on Disc",
                        systemImage: store.labelWorkspaceSubStore.isFreehandDrawMode ? "pencil.tip.crop.circle.badge.plus" : "pencil.and.outline"
                    )
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.labelWorkspaceSubStore.isFreehandDrawMode ? store.activeAccent : Color.secondary.opacity(0.25))
                .controlSize(.small)

                Toggle(isOn: Binding(
                    get: { store.labelWorkspaceSubStore.autoSnapFreehandShapes },
                    set: { store.labelWorkspaceSubStore.autoSnapFreehandShapes = $0; store.objectWillChange.send() }
                )) {
                    Text("Auto-Snap Loops to Crisp Circles/Polygons")
                        .font(.caption2)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Button {
                    traceActiveGPUPatternContoursWithVision()
                } label: {
                    Label("Trace GPU Pattern Contours (Vision)", systemImage: "viewfinder.rectangular")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Run Apple Vision VNDetectContoursRequest on the procedural GPU pattern and add vector contour paths")
            }

            Divider()

            // 3. Active Vector Shape Layers List & Transform Controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Shape Layers (\(store.labelVectorShapes.count))")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                if store.labelVectorShapes.isEmpty {
                    Text("No vector shapes on disc yet. Click any shape or optical badge above to stamp it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(Array(store.labelVectorShapes.enumerated()), id: \.element.id) { idx, layer in
                        shapeLayerControlCard(index: idx, layer: layer)
                    }
                }
            }
        }
    }

    private func shapeStampButton(_ title: String, icon: String, kind: KroutonVectorShapeKind, cy: Double, r: Double) -> some View {
        Button {
            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
            let (cr, cg, cb, _) = KroutonPureColorMath.extractSRGB(store.activeAccent)
            let stroke = KroutonRGBAColor(r: Double(cr), g: Double(cg), b: Double(cb), a: 0.92)
            let shape = KroutonLabelGeometryEngine.makeParametricVectorShape(
                kind: kind,
                centerX: 0.0,
                centerY: cy,
                radius: r,
                strokeColor: stroke
            )
            store.labelVectorShapes.append(shape)
            showTransientBanner("Added \(title)")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(store.activeAccent)
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func opticalBadgeButton(_ title: String, subtitle: String, badgeText: String, kind: KroutonVectorShapeKind) -> some View {
        Button {
            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
            let (cr, cg, cb, _) = KroutonPureColorMath.extractSRGB(store.activeAccent)
            let stroke = KroutonRGBAColor(r: Double(cr), g: Double(cg), b: Double(cb), a: 0.90)
            let shape = KroutonLabelGeometryEngine.makeParametricVectorShape(
                kind: kind,
                centerX: 0.0,
                centerY: 0.50,
                radius: kind == .concentricRing ? 0.82 : 0.16,
                strokeColor: stroke
            )
            store.labelVectorShapes.append(shape)
            let arcItem = KroutonLabelTextElement(
                text: badgeText,
                isCurvedArc: true,
                radiusMM: max(24.0, activePreset.outerDiameterMM * 0.41),
                angleDegrees: 180.0,
                fontSizePoints: 10.0,
                letterTracking: 1.12,
                isBottomUpright: true,
                isBold: true,
                fontDesignRaw: "Monospaced",
                color: stroke
            )
            store.labelTextElements.append(arcItem)
            store.labelSelectedTextID = arcItem.id
            showTransientBanner("Stamped \(title) Badge")
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shapeLayerControlCard(index: Int, layer: KroutonVectorShapeLayer) -> some View {
        let strokeBinding = Binding<Color>(
            get: {
                let c = store.labelVectorShapes.indices.contains(index) ? store.labelVectorShapes[index].strokeColor : layer.strokeColor
                return Color(red: c.r, green: c.g, blue: c.b, opacity: c.a)
            },
            set: { newCol in
                guard store.labelVectorShapes.indices.contains(index) else { return }
                let (r, g, b, a) = KroutonPureColorMath.extractSRGB(newCol)
                let nextRGBA = KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
                store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
                store.labelVectorShapes[index].strokeColor = nextRGBA
                if store.labelVectorShapes[index].fillColor != nil {
                    store.labelVectorShapes[index].fillColor = KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: 0.22)
                }
            }
        )
        let widthBinding = Binding<Double>(
            get: { store.labelVectorShapes.indices.contains(index) ? store.labelVectorShapes[index].strokeWidthPoints : layer.strokeWidthPoints },
            set: { newW in
                guard store.labelVectorShapes.indices.contains(index) else { return }
                store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
                store.labelVectorShapes[index].strokeWidthPoints = newW
            }
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ColorPicker("", selection: strokeBinding)
                    .labelsHidden()
                    .frame(width: 24)
                Text(layer.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                Spacer()
                Button(KroutonL10n.tr("4× Ring")) {
                    guard store.labelVectorShapes.indices.contains(index) else { return }
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                    let base = store.labelVectorShapes[index]
                    let ring = KroutonLabelGeometryEngine.replicateShapeWithPolarSymmetry(baseShape: base, symmetryCount: 4)
                    store.labelVectorShapes.append(contentsOf: ring.dropFirst())
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Replicate this shape with 4-way polar rosette symmetry")

                Button(role: .destructive) {
                    guard store.labelVectorShapes.indices.contains(index) else { return }
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                    store.labelVectorShapes.remove(at: index)
                } label: {
                    Image(systemName: "trash").font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .accessibilityLabel(KroutonL10n.tr("Delete Vector Shape"))
                .help(KroutonL10n.tr("Delete Vector Shape"))
            }

            HStack(spacing: 6) {
                Text("Stroke")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: widthBinding, in: 1.0...8.0)
                Button(KroutonL10n.tr("-Scale")) {
                    guard store.labelVectorShapes.indices.contains(index) else { return }
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                    store.labelVectorShapes[index] = KroutonLabelGeometryEngine.transformVectorShape(store.labelVectorShapes[index], scaleFactor: 0.88)
                }.buttonStyle(.bordered).controlSize(.mini)
                Button(KroutonL10n.tr("+Scale")) {
                    guard store.labelVectorShapes.indices.contains(index) else { return }
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                    store.labelVectorShapes[index] = KroutonLabelGeometryEngine.transformVectorShape(store.labelVectorShapes[index], scaleFactor: 1.14)
                }.buttonStyle(.bordered).controlSize(.mini)
                Button(KroutonL10n.tr("Rot 15°")) {
                    guard store.labelVectorShapes.indices.contains(index) else { return }
                    store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                    store.labelVectorShapes[index] = KroutonLabelGeometryEngine.transformVectorShape(store.labelVectorShapes[index], rotateDegrees: 15.0)
                }.buttonStyle(.bordered).controlSize(.mini)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
