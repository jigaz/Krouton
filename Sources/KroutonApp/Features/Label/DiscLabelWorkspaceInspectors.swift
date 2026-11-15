import SwiftUI
import UniformTypeIdentifiers
import OpticalCore
import LabelKit
import RescueKit

// MARK: - Stage 1 Disc Label Contextual Tool Inspectors (Background, Curved Text, Disc Size Override)

extension KroutonDiscLabelWorkspaceView {
    // MARK: - 3. Contextual Right Inspector (Shows Only Active Tool's Controls)

    @ViewBuilder
    func contextualInspectorPanel() -> some View {
        switch activeTool {
        case .background:
            backgroundToolInspector()
        case .adjust:
            adjustmentsToolInspector()
        case .text:
            textToolInspector()
        case .shapes:
            shapesAndBadgesToolInspector()
        case .discSize:
            discSizeOverrideInspector()
        case .select:
            selectOverviewInspector()
        }
    }

    // MARK: - Tool Inspector A: Background Fill (Blank White, Solid Color, Circular Gradient)

    private func backgroundToolInspector() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Background Fill", systemImage: "circle.lefthalf.filled")
                .font(.subheadline.bold())

            Text("Choose a blank printable disc, a solid color, or a smooth circular gradient radiating from the center hub to the outer rim.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 6 Clean Background & GPU Procedural Modes
            VStack(spacing: 6) {
                backgroundModeButton(title: "Blank White Printable Disc", subtitle: "Clean white ink-saving surface", style: .templateDefault, icon: "circle")
                backgroundModeButton(title: "Circular (Radial) Gradient", subtitle: "Hub-to-rim concentric color blend", style: .radialGradient, icon: "circle.circle.fill")
                backgroundModeButton(title: "Linear Gradient", subtitle: "Directional angled color blend", style: .linearGradient, icon: "lessthan.circle.fill")
                backgroundModeButton(title: "Solid Disc Color", subtitle: "Uniform edge-to-edge fill", style: .solidColor, icon: "circle.fill")
                backgroundModeButton(title: "GPU Silk Kaleidoscope", subtitle: "Radial symmetric prism reflections", style: .gpuKaleidoscope, icon: "sparkles")
                backgroundModeButton(title: "360° Tiny Planet Globe", subtitle: "Polar stereographic horizon world", style: .tinyPlanetGlobe, icon: "globe.americas.fill")
            }

            if store.labelBackgroundStyle != .templateDefault {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    ColorPicker(
                        store.labelBackgroundStyle == .radialGradient ? "Inner Hub Color:" : "Primary Color:",
                        selection: $store.labelBgPrimaryColor
                    )
                    .font(.caption.bold())

                    if store.labelBackgroundStyle != .solidColor {
                        ColorPicker(
                            store.labelBackgroundStyle == .radialGradient ? "Outer Rim Color:" : "Secondary Color:",
                            selection: $store.labelBgSecondaryColor
                        )
                        .font(.caption.bold())

                        Button {
                            let tmp = store.labelBgPrimaryColor
                            store.labelBgPrimaryColor = store.labelBgSecondaryColor
                            store.labelBgSecondaryColor = tmp
                        } label: {
                            Label("Swap Inner / Outer Colors", systemImage: "arrow.up.arrow.down")
                                .font(.caption2.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Workspace Palettes")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            HStack(spacing: 5) {
                                workspaceSwatchButton("Paper", c1: .white, c2: Color(red: 0.88, green: 0.93, blue: 0.98))
                                workspaceSwatchButton("Ocean", c1: Color(red: 0.78, green: 0.96, blue: 0.99), c2: Color(red: 0.16, green: 0.56, blue: 0.92))
                                workspaceSwatchButton("Sunset", c1: Color(red: 0.99, green: 0.92, blue: 0.76), c2: Color(red: 0.94, green: 0.38, blue: 0.52))
                                workspaceSwatchButton("Mint", c1: Color(red: 0.86, green: 0.98, blue: 0.91), c2: Color(red: 0.18, green: 0.78, blue: 0.58))
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(store.labelBackgroundStyle == .gpuKaleidoscope || store.labelBackgroundStyle == .tinyPlanetGlobe
                                     ? "Backdrop Brightness (Ink Saver)"
                                     : "Gradient Midpoint")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(store.labelGradientMidpoint * 100))%")
                                    .font(.caption2.monospaced())
                            }
                            Slider(value: $store.labelGradientMidpoint, in: 0.0...1.0)
                        }
                    }

                    if store.labelBackgroundStyle == .linearGradient || store.labelBackgroundStyle == .gpuKaleidoscope || store.labelBackgroundStyle == .tinyPlanetGlobe {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(store.labelBackgroundStyle == .linearGradient ? "Gradient Angle" : "Rotation / Spin Angle")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(store.labelGradientAngle))°")
                                    .font(.caption2.monospaced())
                            }
                            Slider(value: $store.labelGradientAngle, in: 0...360, step: 5)
                        }
                    }

                    if store.labelBackgroundStyle == .gpuKaleidoscope || store.labelBackgroundStyle == .tinyPlanetGlobe {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Optical Object Chamber")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    store.labelChamberTumble = Double.random(in: 0.02...0.98)
                                    store.labelGradientAngle = Double(Int.random(in: 0...71) * 5)
                                } label: {
                                    Label("Tumble Gems", systemImage: "dice.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(store.activeAccent)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .help("Randomize the physical glass shards and mirror angle inside the optical chamber")
                            }

                            Picker("Object Chamber", selection: $store.labelGPUSeedPattern) {
                                Text("Stained Glass & Gem Shards").tag(KroutonGPUSeedPattern.neonLaserPrism)
                                Text("Dichroic Neon Filaments").tag(KroutonGPUSeedPattern.cyberSunburst)
                                Text("Liquid Oil Interference").tag(KroutonGPUSeedPattern.holographicFoil)
                                Text("Botanical Golden Spirals").tag(KroutonGPUSeedPattern.cmykHalftone)
                            }
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Chamber Tumble (Slide Shards)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(store.labelChamberTumble * 100))%")
                                        .font(.caption2.monospaced())
                                }
                                Slider(value: $store.labelChamberTumble, in: 0.0...1.0)
                            }

                            if store.labelBackgroundStyle == .gpuKaleidoscope {
                                Text("Optical Mirror Assembly")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)

                                Picker("Mirror Rig", selection: $store.labelKaleidoscopeRig) {
                                    ForEach(KroutonKaleidoscopeMirrorRig.allCases) { rig in
                                        Text(rig.rawValue).tag(rig)
                                    }
                                }
                                .labelsHidden()

                                Stepper("Mirror Facets / Scale: \(store.labelKaleidoscopeFacets)×", value: $store.labelKaleidoscopeFacets, in: 3...16)
                                    .font(.caption.bold())
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Planet Horizon Radius")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(store.labelTinyPlanetRadius * 100))%")
                                            .font(.caption2.monospaced())
                                    }
                                    Slider(value: $store.labelTinyPlanetRadius, in: 0.35...0.95)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func backgroundModeButton(title: String, subtitle: String, style: KroutonVectorBackgroundStyle, icon: String) -> some View {
        let isSel = (store.labelBackgroundStyle == style)
        return Button {
            store.labelBackgroundStyle = style
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.caption.bold())
                    Text(subtitle).font(.system(size: 10)).opacity(0.8)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSel ? store.activeAccent : Color.primary.opacity(0.06))
            .foregroundStyle(isSel ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tool Inspector B: Curved & Straight Text Tool

    private func textToolInspector() -> some View {
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
    private func selectedTextElementControls(index: Int) -> some View {
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

                    Toggle("Bold", isOn: safeTextElementBinding(index, \.isBold, default: fallbackElem.isBold))
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                        .fixedSize()

                    Toggle("Shadow", isOn: safeTextElementBinding(index, \.hasDropShadow, default: fallbackElem.hasDropShadow))
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                        .fixedSize()

                    Spacer(minLength: 2)

                    Picker("Font", selection: safeTextElementBinding(index, \.fontDesignRaw, default: fallbackElem.fontDesignRaw)) {
                        Text("Sans").tag("Default")
                        Text("Rounded").tag("Rounded")
                        Text("Serif").tag("Serif")
                        Text("Mono").tag("Monospaced")
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }

                Toggle("Follow Circular Disc Arc", isOn: safeTextElementBinding(index, \.isCurvedArc, default: fallbackElem.isCurvedArc))
                    .toggleStyle(.checkbox)
                    .font(.caption.bold())

                if currentElem.isCurvedArc {
                    Toggle("Keep Bottom Arc Text Upright (Readable)", isOn: safeTextElementBinding(index, \.isBottomUpright, default: fallbackElem.isBottomUpright))
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    HStack(spacing: 6) {
                        Button("Top (0°)") {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 0
                            store.labelTextElements[index].isBottomUpright = false
                        }.buttonStyle(.bordered).controlSize(.mini)

                        Button("Bottom (180°)") {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 180
                            store.labelTextElements[index].isBottomUpright = true
                        }.buttonStyle(.bordered).controlSize(.mini)

                        Button("Left (270°)") {
                            guard store.labelTextElements.indices.contains(index) else { return }
                            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
                            store.labelTextElements[index].angleDegrees = 270
                        }.buttonStyle(.bordered).controlSize(.mini)

                        Button("Right (90°)") {
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

    private func workspaceSwatchButton(_ label: String, c1: Color, c2: Color) -> some View {
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
