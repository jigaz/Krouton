import SwiftUI
import UniformTypeIdentifiers
import OpticalDough
import Crustini

// MARK: - Stage 1 Disc Label Contextual Tool Inspectors (Background, Curved Text, Disc Size Override)

extension KroutonDiscLabelStudioWorkspaceView {
    // MARK: - 3. Contextual Right Inspector (Shows Only Active Tool's Controls)

    @ViewBuilder
    func contextualInspectorPanel() -> some View {
        switch activeTool {
        case .background:
            backgroundToolInspector()
        case .text:
            textToolInspector()
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

            // 4 Clean Stage-1 Background Modes
            VStack(spacing: 6) {
                backgroundModeButton(title: "Blank White Printable Disc", subtitle: "Clean white ink-saving surface", style: .templateDefault, icon: "circle")
                backgroundModeButton(title: "Circular (Radial) Gradient", subtitle: "Hub-to-rim concentric color blend", style: .radialGradient, icon: "circle.circle.fill")
                backgroundModeButton(title: "Linear Gradient", subtitle: "Directional angled color blend", style: .linearGradient, icon: "lessthan.circle.fill")
                backgroundModeButton(title: "Solid Disc Color", subtitle: "Uniform edge-to-edge fill", style: .solidColor, icon: "circle.fill")
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

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Gradient Midpoint")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(store.labelGradientMidpoint * 100))%")
                                    .font(.caption2.monospaced())
                            }
                            Slider(value: $store.labelGradientMidpoint, in: 0.10...0.90)
                        }
                    }

                    if store.labelBackgroundStyle == .linearGradient {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Gradient Angle")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(store.labelGradientAngle))°")
                                    .font(.caption2.monospaced())
                            }
                            Slider(value: $store.labelGradientAngle, in: 0...360, step: 5)
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

    private func selectedTextElementControls(index: Int) -> some View {
        let colorBinding = Binding<Color>(
            get: {
                let c = store.labelTextElements[index].color
                return Color(red: c.r, green: c.g, blue: c.b, opacity: c.a)
            },
            set: { newCol in
                let (r, g, b, a) = KroutonPureColorMath.extractSRGB(newCol)
                store.labelTextElements[index].color = KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
            }
        )

        return VStack(alignment: .leading, spacing: 10) {
            Text("Selected Text Content")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            TextField("Enter Disc Text...", text: $store.labelTextElements[index].text)
                .textFieldStyle(.roundedBorder)
                .font(.caption.bold())

            HStack(spacing: 10) {
                ColorPicker("Color:", selection: colorBinding)
                    .font(.caption.bold())

                Toggle("Bold", isOn: $store.labelTextElements[index].isBold)
                    .toggleStyle(.checkbox)
                    .font(.caption.bold())

                Picker("Font", selection: $store.labelTextElements[index].fontDesignRaw) {
                    Text("Sans").tag("Default")
                    Text("Rounded").tag("Rounded")
                    Text("Serif").tag("Serif")
                    Text("Mono").tag("Monospaced")
                }
                .labelsHidden()
                .frame(width: 85)
            }

            Divider()

            Picker("Layout Mode", selection: $store.labelTextElements[index].isCurvedArc) {
                Text("Curved on Disc Arc").tag(true)
                Text("Straight Horizontal").tag(false)
            }
            .pickerStyle(.segmented)

            // Radius Slider (Inner Hub to Outer Rim)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Distance from Center (Radius)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(store.labelTextElements[index].radiusMM)) mm")
                        .font(.caption2.monospaced())
                }
                Slider(value: $store.labelTextElements[index].radiusMM, in: 16...56, step: 1)
            }

            // Angle Slider (0° = 12 o'clock top, 90° = 3 o'clock, 180° = 6 o'clock bottom, 270° = 9 o'clock)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Position Around Disc (Angle)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(store.labelTextElements[index].angleDegrees))°")
                        .font(.caption2.monospaced())
                }
                Slider(value: $store.labelTextElements[index].angleDegrees, in: 0...360, step: 5)

                HStack(spacing: 6) {
                    Button("Top (0°)") {
                        store.labelTextElements[index].angleDegrees = 0
                        store.labelTextElements[index].isBottomUpright = false
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Bottom (180°)") {
                        store.labelTextElements[index].angleDegrees = 180
                        store.labelTextElements[index].isBottomUpright = true
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Left (270°)") {
                        store.labelTextElements[index].angleDegrees = 270
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Right (90°)") {
                        store.labelTextElements[index].angleDegrees = 90
                    }.buttonStyle(.bordered).controlSize(.mini)
                }
            }

            if store.labelTextElements[index].isCurvedArc {
                Toggle("Bottom Upright Direction (Read Left-to-Right at Bottom)", isOn: $store.labelTextElements[index].isBottomUpright)
                    .toggleStyle(.checkbox)
                    .font(.caption2.bold())
            }

            // Font Size & Letter Tracking
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Font Size")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(store.labelTextElements[index].fontSizePoints)) pt")
                        .font(.caption2.monospaced())
                }
                Slider(value: $store.labelTextElements[index].fontSizePoints, in: 8...38, step: 1)
            }

            if store.labelTextElements[index].isCurvedArc {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Letter Spacing (Tracking)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f×", store.labelTextElements[index].letterTracking))
                            .font(.caption2.monospaced())
                    }
                    Slider(value: $store.labelTextElements[index].letterTracking, in: 0.65...1.85)
                }
            }
        }
    }

    // MARK: - Tool Inspector C: Disc Size Override & Save as Preset

    private func discSizeOverrideInspector() -> some View {
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
                    Text("\(Int(store.labelPresets[pIdx].innerDiameterMM)) mm")
                        .font(.caption2.monospaced().bold())
                }
                Slider(value: $store.labelPresets[pIdx].innerDiameterMM, in: 18...50, step: 1)

                HStack {
                    Text("Outer Disc Diameter (70–120 mm)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(store.labelPresets[pIdx].outerDiameterMM)) mm")
                        .font(.caption2.monospaced().bold())
                }
                Slider(value: $store.labelPresets[pIdx].outerDiameterMM, in: 70...120, step: 1)

                HStack(spacing: 6) {
                    Button("Full Hub (18/120)") {
                        store.labelPresets[pIdx].innerDiameterMM = 18
                        store.labelPresets[pIdx].outerDiameterMM = 120
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Standard (41/118)") {
                        store.labelPresets[pIdx].innerDiameterMM = 41
                        store.labelPresets[pIdx].outerDiameterMM = 118
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button("Mini 80mm") {
                        store.labelPresets[pIdx].innerDiameterMM = 18
                        store.labelPresets[pIdx].outerDiameterMM = 80
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
                    Text(String(format: "%+.1f mm", store.labelPresets[pIdx].offsetXMM))
                        .font(.caption2.monospaced())
                }
                Slider(value: $store.labelPresets[pIdx].offsetXMM, in: -2.0...2.0, step: 0.1)

                HStack {
                    Text("Printer Y Offset (-2.0 to +2.0 mm)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%+.1f mm", store.labelPresets[pIdx].offsetYMM))
                        .font(.caption2.monospaced())
                }
                Slider(value: $store.labelPresets[pIdx].offsetYMM, in: -2.0...2.0, step: 0.1)
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
                    statusBanner = "Saved Preset '\(nameToSave)'"
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

    // MARK: - Tool Inspector D: Select / Layer Overview

    private func selectOverviewInspector() -> some View {
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

            Divider()

            HStack {
                Text("Text Layers (\(store.labelTextElements.count))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+ Add Text") {
                    addNewTextElement()
                    activeTool = .text
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
                .controlSize(.mini)
            }

            if store.labelTextElements.isEmpty {
                Text("Canvas is currently blank. Use the left tool rail to set a Circular Gradient background or add Curved Arc Text.")
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
        store.labelTextElements.append(newItem)
        store.labelSelectedTextID = newItem.id
    }

    @MainActor
    func exportHighRes300DPILabelPNG(preset: KroutonSliceLabelGeometry, isTestPrintSheet: Bool) {
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
            textElements: store.labelTextElements
        )
        let renderer = ImageRenderer(content: exportCanvas)
        renderer.scale = 1.0
        if renderer.cgImage != nil {
            statusBanner = isTestPrintSheet
                ? "Test Print Proof Ready (\(Int(preset.innerDiameterMM))/\(Int(preset.outerDiameterMM))mm)"
                : "Rendered \(Int(exportPixels))×\(Int(exportPixels))px 300-DPI Master"
        }
    }
}
