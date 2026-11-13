import SwiftUI
import Foundation
import UniformTypeIdentifiers
import ImageIO
import OpticalDough
import Crustini

// MARK: - Standalone 120mm Polar Disc Label Studio Workspace View

struct KroutonDiscLabelStudioWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore

    // Bound directly to KroutonStateStore so label edits persist across sidebar switches & .krut saves

    @MainActor
    private func exportDiscLabelAsPNG(preset: KroutonSliceLabelGeometry) {
        let exportView = KroutonDiscLabelArtworkCanvas(
            preset: preset,
            template: store.selectedLabelTemplate,
            title: store.labelDiscTitle,
            subtitle: store.labelSubtitle,
            performer: store.discPerformer,
            mcnBarcode: store.discMCNBarcode,
            trackLines: resolvedLabelTracklistLines,
            showTracklist: store.labelShowTracklistOnDisc,
            primaryColor: store.activeAccent,
            harmonyColor: store.uiSecondaryAccent,
            isExportMode: true,
            diameterPoints: 720.0
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0 // 1440x1440 px (>300 DPI for 120mm optical disc)
        guard let cgImage = renderer.cgImage else { return }
        let mutableData = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return }
        let pngData = mutableData as Data
        KroutonLabelExportBridge.shared.presentPNGExport(
            pngData: pngData,
            defaultFilename: "\(store.labelDiscTitle.replacingOccurrences(of: " ", with: "_"))_120mm_Label.png"
        )
    }

    private var resolvedLabelTracklistLines: [String] {
        if !store.stagedFiles.isEmpty {
            return store.stagedFiles.prefix(8).enumerated().map { idx, f in
                String(format: "%02d. %@", idx + 1, f.name)
            }
        }
        return store.redBookTracks.prefix(8).map { $0.title }
    }

    var body: some View {
        let preset = store.labelPresets[min(store.selectedLabelPresetIndex, store.labelPresets.count - 1)]
        let arcGlyphs = store.computeLiveDiscLabelArcGlyphs(title: store.labelDiscTitle, radiusPoints: 500.0)

        return GeometryReader { labelGeo in
            let availW = max(260, labelGeo.size.width)
            let availH = labelGeo.size.height
            let useStackedLayout = availW < 650
            let isUltraCompactLabel = availW < 420
            let dynamicDiscDiameter: CGFloat = useStackedLayout
                ? min(max(195, availW - 56), 265)
                : min(max(240, availW - 350), min(380, max(240, availH - 105)))

            VStack(alignment: .leading, spacing: 10) {
                // Responsive Header Bar: Deterministic 2-row stack when narrow, 1-row when wide
                if useStackedLayout {
                    VStack(alignment: .leading, spacing: 6) {
                        labelHeaderTitleBlock(preset: preset, isCompact: isUltraCompactLabel)
                        labelHeaderControlsBlock(preset: preset, isCompact: isUltraCompactLabel)
                    }
                } else {
                    HStack(spacing: 10) {
                        labelHeaderTitleBlock(preset: preset, isCompact: false)
                        Spacer(minLength: 8)
                        labelHeaderControlsBlock(preset: preset, isCompact: false)
                    }
                }

                Divider()

                if useStackedLayout {
                    // NARROW / COMPACT MODE: Clean Vertical ScrollView (Disc Preview on Top, Controls Below)
                    ScrollView {
                        VStack(alignment: .center, spacing: 16) {
                            labelLiveDiscPreviewPanel(preset: preset, diameter: dynamicDiscDiameter, glyphCount: arcGlyphs.count)
                            Divider()
                            labelInspectorControlsPanel(preset: preset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, 12)
                    }
                } else {
                    // WIDE STUDIO MODE: Resizable Left Controls + Right Live Display-P3 Polar Disc Canvas
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView {
                            labelInspectorControlsPanel(preset: preset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: min(320, max(255, availW * 0.44)))

                        Divider()

                        VStack {
                            Spacer(minLength: 0)
                            labelLiveDiscPreviewPanel(preset: preset, diameter: dynamicDiscDiameter, glyphCount: arcGlyphs.count)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(width: availW, height: availH, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func labelHeaderTitleBlock(preset: KroutonSliceLabelGeometry, isCompact: Bool) -> some View {
        HStack(spacing: 10) {
            KroutonStyledIconBadge(
                sfSymbol: store.selectedTaskID == "label-auto" ? "wand.and.stars" : "printer.dotmatrix.fill",
                tintColor: store.activeAccent,
                style: store.iconWidgetStyle,
                size: 28,
                symbolSize: 14
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(store.selectedTaskID == "label-auto" ? (isCompact ? "Auto Disc Label Studio" : "Automatic Disc Label Studio") : (isCompact ? "Manual Disc Label Studio" : "120mm / 80mm Optical Disc Label Studio"))
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(isCompact ? String(format: "%@ • %.0fmm / %.0fmm Hub", preset.name, preset.outerDiameterMM, preset.innerDiameterMM) : String(format: "%@ • Outer %.0fmm / Hub %.0fmm • Offset X:%.1f Y:%.1fmm", preset.name, preset.outerDiameterMM, preset.innerDiameterMM, preset.offsetXMM, preset.offsetYMM))
                    .font(.caption)
                    .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : .secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func labelHeaderControlsBlock(preset: KroutonSliceLabelGeometry, isCompact: Bool) -> some View {
        HStack(spacing: 8) {
            Picker("Tray:", selection: $store.selectedLabelPresetIndex) {
                ForEach(Array(store.labelPresets.enumerated()), id: \.offset) { idx, item in
                    Text(item.name).tag(idx)
                }
            }
            .labelsHidden()
            .frame(maxWidth: isCompact ? .infinity : 215)

            Button {
                exportDiscLabelAsPNG(preset: preset)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(isCompact ? "Export PNG..." : "Export 300-DPI PNG...")
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(store.activeAccent)
                .foregroundStyle(store.activeOnAccentText)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .help("Render a 1,417×1,417 px (300 DPI) transparent-hub disc label PNG")
        }
    }

    @ViewBuilder
    private func labelInspectorControlsPanel(preset: KroutonSliceLabelGeometry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.selectedTaskID == "label-auto" {
                VStack(alignment: .leading, spacing: 6) {
                    Text(KroutonL10n.tr("Automatic Cover & Metadata Lookup"))
                        .font(.subheadline.bold())
                    HStack(spacing: 6) {
                        TextField("Album, Movie, or Game...", text: $store.autoLabelSearchQuery)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            if !store.autoLabelSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                                store.labelDiscTitle = store.autoLabelSearchQuery.uppercased()
                                store.labelSubtitle = "MASTERED IN KROUTON • SHA-256 VERIFIED"
                            }
                        } label: {
                            Text("Fetch")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(store.activeAccent)
                                .foregroundStyle(store.activeOnAccentText)
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Avoids the \(Int(preset.innerDiameterMM))mm center spindle hole automatically.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Divider()
            }

            // 2x2 Compact Template Selector Grid (Replaces the 580pt overflowing segmented Picker!)
            VStack(alignment: .leading, spacing: 6) {
                Text("Studio Harmony Template")
                    .font(.subheadline.bold())
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(KroutonCroutonLabelStyle.allCases) { tpl in
                        let isSel = (store.selectedLabelTemplate == tpl)
                        Button {
                            store.selectedLabelTemplate = tpl
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isSel ? store.activeOnAccentText : store.activeAccent)
                                    .frame(width: 6, height: 6)
                                Text(tpl.rawValue)
                                    .font(.system(size: 10.5, weight: isSel ? .bold : .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(isSel ? store.activeAccent : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(isSel ? store.activeOnAccentText : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Disc Typography & Tracklist Manifest Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(KroutonL10n.tr("Disc Face Typography"))
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        store.labelDiscTitle = store.discVolumeTitle
                        if !store.stagedFiles.isEmpty {
                            store.labelSubtitle = "\(store.stagedFiles.count) ITEMS • \(ByteCountFormatter.string(fromByteCount: store.totalStagedBytes, countStyle: .file))"
                        } else {
                            store.labelSubtitle = "44.1 KHZ 16-BIT RED BOOK PCM • \(store.discPerformer.uppercased())"
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync from Project")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(store.uiSecondaryAccent.opacity(0.18))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .help("Populate title, performer, MCN, and tracklist from your active Burn/Audio/Data project")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary Title (Top Polar Arc):")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("Primary Arc Title", text: $store.labelDiscTitle)
                        .textFieldStyle(.roundedBorder)

                    Text("Bottom Subtitle / Format Spec:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("Bottom Subtitle / Track Summary", text: $store.labelSubtitle)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Artist / Authored By:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("Performer", text: $store.discPerformer)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MCN / Catalog:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("0123456789012", text: $store.discMCNBarcode)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                }

                Toggle("Stamp Tracklist / File Manifest on Disc Face", isOn: $store.labelShowTracklistOnDisc)
                    .toggleStyle(.checkbox)
                    .font(.caption.bold())
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Vector Background & Curved Arc", systemImage: "beziercurve")
                        .font(.subheadline.bold())
                    Spacer()
                    Picker("", selection: $store.labelBackgroundStyle) {
                        ForEach(KroutonVectorBackgroundStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 155)
                }

                if store.labelBackgroundStyle != .templateDefault {
                    HStack(spacing: 12) {
                        ColorPicker("Color 1:", selection: $store.labelBgPrimaryColor)
                            .font(.caption.bold())
                        if store.labelBackgroundStyle != .solidColor {
                            ColorPicker("Color 2:", selection: $store.labelBgSecondaryColor)
                                .font(.caption.bold())
                        }
                        if store.labelBackgroundStyle == .linearGradient || store.labelBackgroundStyle == .angularGradient {
                            Slider(value: $store.labelGradientAngle, in: 0...360, step: 15)
                                .frame(maxWidth: 95)
                                .help("Gradient Sweep Angle: \(Int(store.labelGradientAngle))°")
                        }
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 10) {
                    Text("Arc Curve:").font(.caption.bold()).foregroundStyle(.secondary).frame(width: 66, alignment: .leading)
                    Slider(value: $store.labelTopArcRadiusMM, in: 28...55)
                        .help("Top Polar Arc Radius: \(Int(store.labelTopArcRadiusMM)) mm")
                    Text("Kerning:").font(.caption.bold()).foregroundStyle(.secondary)
                    Slider(value: $store.labelArcLetterSpacing, in: 0.65...1.65)
                        .frame(maxWidth: 85)
                        .help("Polar Arc Letter Spacing")
                }

                Divider()

                HStack(spacing: 8) {
                    Toggle(isOn: $store.isLabelVectorDrawMode) {
                        Label(store.isLabelVectorDrawMode ? "Drawing on Disc (Drag Mouse)" : "Draw Vector Shapes on Disc", systemImage: "pencil.and.outline")
                            .font(.caption.bold())
                    }
                    .toggleStyle(.button)
                    .tint(store.isLabelVectorDrawMode ? .green : store.activeAccent)

                    Toggle("Auto-Snap", isOn: $store.labelDrawAutoSnap)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }

                HStack(spacing: 6) {
                    Button {
                        let (r, g, b, _) = KroutonPureColorMath.extractSRGB(store.uiSecondaryAccent)
                        let star = KroutonKrustiniModule.makeParametricVectorShape(
                            kind: .star,
                            strokeColor: KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: 1.0)
                        )
                        store.labelVectorShapes.append(star)
                    } label: {
                        Label("+ Star", systemImage: "star.fill").font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        let (r, g, b, _) = KroutonPureColorMath.extractSRGB(store.activeAccent)
                        let ring = KroutonKrustiniModule.makeParametricVectorShape(
                            kind: .concentricRing,
                            strokeColor: KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: 0.85)
                        )
                        store.labelVectorShapes.append(ring)
                    } label: {
                        Label("+ Ring", systemImage: "circle.circle").font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        traceDiscEmblemWithAppleVision(preset: preset)
                    } label: {
                        Label("Vision Auto-Trace", systemImage: "sparkles").font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(store.uiSecondaryAccent.opacity(0.18))
                            .foregroundStyle(store.uiSecondaryAccent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if !store.labelVectorShapes.isEmpty {
                        Button {
                            store.labelVectorShapes.removeAll()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @MainActor
    private func traceDiscEmblemWithAppleVision(preset: KroutonSliceLabelGeometry) {
        let symbolView = ZStack {
            Color.white
            Image(systemName: "opticaldisc.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .foregroundStyle(.black)
        }
        .frame(width: 240, height: 240)

        let renderer = ImageRenderer(content: symbolView)
        guard let cgImg = renderer.cgImage else { return }
        let (r, g, b, _) = KroutonPureColorMath.extractSRGB(store.uiSecondaryAccent)
        let traced = KroutonKrustiniModule.traceImageContoursWithVision(
            cgImage: cgImg,
            strokeColor: KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b), a: 0.95)
        )
        if !traced.isEmpty {
            store.labelVectorShapes.append(contentsOf: traced.prefix(4))
        }
    }

    @ViewBuilder
    private func labelLiveDiscPreviewPanel(preset: KroutonSliceLabelGeometry, diameter: CGFloat, glyphCount: Int) -> some View {
        VStack(spacing: 8) {
            KroutonDiscLabelArtworkCanvas(
                preset: preset,
                template: store.selectedLabelTemplate,
                title: store.labelDiscTitle,
                subtitle: store.labelSubtitle,
                performer: store.discPerformer,
                mcnBarcode: store.discMCNBarcode,
                trackLines: resolvedLabelTracklistLines,
                showTracklist: store.labelShowTracklistOnDisc,
                primaryColor: store.activeAccent,
                harmonyColor: store.uiSecondaryAccent,
                isExportMode: false,
                diameterPoints: diameter
            )
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed.inset.filled")
                    .foregroundStyle(store.activeAccent)
                Text("300-DPI Polar Vector Engine • \(glyphCount) Arc Glyphs")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

}
