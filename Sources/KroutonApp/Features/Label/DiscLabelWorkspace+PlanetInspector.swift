import LabelKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Panorama Planet Inspector

/// The Planet tool: wraps a panorama into the disc with polar coordinates. The photo's bottom
/// meets in the middle and its top runs round the rim (or the other way round for a tunnel).
extension KroutonDiscLabelWorkspaceView {
    func planetToolInspector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Panorama Planet", systemImage: "globe.americas.fill")
                    .font(.subheadline.bold())
                Spacer()
                Button(KroutonL10n.tr("Reset")) { store.labelPlanet = KroutonPlanetSettings() }
                    .font(.caption2.bold())
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(store.labelPlanet == KroutonPlanetSettings())
            }
            Text("Wraps a panorama into the disc: the ground curls into a small world and the sky runs round the rim. A 360° panorama twice as wide as it is tall wraps without a seam.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.labelPlanetPreviewSource != nil, store.labelBackgroundStyle != .tinyPlanetGlobe {
                Button(KroutonL10n.tr("Use the Planet as the Background")) { store.labelBackgroundStyle = .tinyPlanetGlobe }
                    .controlSize(.small)
            }
            planetPhotoSection
            if store.labelPlanetPreviewSource != nil {
                Divider()
                planetPresetsRow
                Divider()
                planetProjectionSection
                Divider()
                planetFramingSection
                Divider()
                planetEdgesSection
            }
        }
        .onChange(of: store.labelPlanet) { _, _ in
            store.labelWorkspaceSubStore.recordUndoSnapshot(from: store, coalesceWindow: 0.45)
        }
        .fileImporter(isPresented: Bindable(store.labelWorkspaceSubStore).isChoosingPlanetPhoto,
                      allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            if let problem = store.loadPlanetPhoto(url) {
                showTransientBanner(problem)
            } else {
                store.labelBackgroundStyle = .tinyPlanetGlobe
            }
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var planetPhotoSection: some View {
        let planet = store.labelPlanet
        if let thumbnail = store.labelPlanetThumbnail, let source = store.labelPlanetPreviewSource {
            VStack(alignment: .leading, spacing: 4) {
                Image(decorative: thumbnail, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay { planetFramingOverlay(planet) }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contextMenu {
                        Button(KroutonL10n.tr("Choose Another Panorama…")) { store.labelWorkspaceSubStore.isChoosingPlanetPhoto = true }
                        Button(KroutonL10n.tr("Level Horizon (Middle of the Photo)")) { store.labelPlanet.horizonInPhoto = 0.5 }
                        Button(KroutonL10n.tr("Clear Crops")) {
                            store.labelPlanet.cropTop = 0
                            store.labelPlanet.cropBottom = 0
                        }
                    }
                    .help("Drag up or down on the photo to set where its horizon is")
                HStack {
                    Text(store.labelPlanetPhotoURL?.lastPathComponent ?? "")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(KroutonL10n.tr("Change…")) { store.labelWorkspaceSubStore.isChoosingPlanetPhoto = true }
                        .controlSize(.mini)
                }
                .font(.caption2)
                Text(aspectAdvice(width: source.width, height: source.height))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Button {
                store.labelWorkspaceSubStore.isChoosingPlanetPhoto = true
            } label: {
                Label("Choose a Panorama…", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.activeAccent)
        }
    }

    /// Shaded crops and a dashed horizon line over the photo; dragging moves the horizon.
    private func planetFramingOverlay(_ planet: KroutonPlanetSettings) -> some View {
        GeometryReader { geo in
            let h = geo.size.height
            let usable = max(0.1, 1 - planet.cropTop - planet.cropBottom)
            let horizonY = (planet.cropTop + planet.horizonInPhoto * usable) * h
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.5).frame(height: h * planet.cropTop)
                Color.black.opacity(0.5).frame(height: h * planet.cropBottom).offset(y: h * (1 - planet.cropBottom))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: horizonY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: horizonY))
                }
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let fraction = (value.location.y / max(1, h) - planet.cropTop) / usable
                store.labelPlanet.horizonInPhoto = min(0.98, max(0.02, fraction))
            })
        }
    }

    private func aspectAdvice(width: Int, height: Int) -> String {
        let ratio = Double(width) / Double(max(1, height))
        let shape = String(format: "%.2f:1", ratio)
        if abs(ratio - 2) < 0.08 { return "\(shape), a full 360° panorama: Wrap joins its ends." }
        if ratio > 2 { return "\(shape), wider than 360°: crop the sky or ground to fill more of the disc, or Blend the ends." }
        return "\(shape), less than 360° round: Blend or Mirror the ends so the join doesn't show."
    }

    // MARK: - Presets

    private var planetPresetsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Starting Points")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                planetPresetButton("Little Planet") {
                    $0.projection = .stereographic; $0.orientation = .planet; $0.horizonRadius = 0.42; $0.twistDegrees = 0
                }
                planetPresetButton("Rabbit Hole") {
                    $0.projection = .stereographic; $0.orientation = .tunnel; $0.horizonRadius = 0.5; $0.twistDegrees = 0
                }
                planetPresetButton("Polar") {
                    $0.projection = .polar; $0.orientation = .planet; $0.horizonRadius = 0.5; $0.groundCurve = 1; $0.twistDegrees = 0
                }
                planetPresetButton("Swirl") {
                    $0.projection = .stereographic; $0.orientation = .planet; $0.horizonRadius = 0.45; $0.twistDegrees = 120
                }
            }
        }
    }

    private func planetPresetButton(_ title: String, _ apply: @escaping (inout KroutonPlanetSettings) -> Void) -> some View {
        Button(title) { apply(&store.labelPlanet) }
            .font(.system(size: 10, weight: .semibold))
            .buttonStyle(.bordered)
            .controlSize(.mini)
    }

    // MARK: - Projection

    private var planetProjectionSection: some View {
        let planet = Bindable(store).labelPlanet
        return VStack(alignment: .leading, spacing: 8) {
            Picker(KroutonL10n.tr("Projection"), selection: planet.projection) {
                ForEach(KroutonPlanetSettings.Projection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Picker(KroutonL10n.tr("Orientation"), selection: planet.orientation) {
                Text("Planet").tag(KroutonPlanetSettings.Orientation.planet)
                Text("Tunnel").tag(KroutonPlanetSettings.Orientation.tunnel)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            adjustmentSliderRow(title: store.labelPlanet.orientation == .planet ? "Planet Size (Horizon)" : "Tunnel Size (Horizon)",
                                valueText: "\(Int((store.labelPlanet.horizonRadius * 100).rounded()))%",
                                value: planet.horizonRadius, range: 0.05...0.95, defaultValue: 0.42)
            adjustmentSliderRow(title: "Rotation", valueText: "\(Int(store.labelPlanet.rotationDegrees.rounded()))°",
                                value: planet.rotationDegrees, range: -180...180, defaultValue: 0)
            adjustmentSliderRow(title: "Twist", valueText: "\(Int(store.labelPlanet.twistDegrees.rounded()))°",
                                value: planet.twistDegrees, range: -360...360, defaultValue: 0)
            if store.labelPlanet.projection == .polar {
                adjustmentSliderRow(title: "Ground Curve", valueText: String(format: "%.2f", store.labelPlanet.groundCurve),
                                    value: planet.groundCurve, range: 0.25...4, defaultValue: 1)
            }
            Toggle(isOn: planet.startAtHub) {
                Text("Start at the hub's edge").font(.caption)
            }
            .help("Begins the photo at the edge of the hole, so the stretched middle of the planet isn't printed")
            Toggle(isOn: planet.flipHorizontal) {
                Text("Flip (run the photo anticlockwise)").font(.caption)
            }
            DisclosureGroup {
                adjustmentSliderRow(title: "Move Left / Right", valueText: "\(Int((store.labelPlanet.centerOffsetX * 100).rounded()))%",
                                    value: planet.centerOffsetX, range: -0.3...0.3, defaultValue: 0)
                adjustmentSliderRow(title: "Move Up / Down", valueText: "\(Int((store.labelPlanet.centerOffsetY * 100).rounded()))%",
                                    value: planet.centerOffsetY, range: -0.3...0.3, defaultValue: 0)
            } label: {
                Text("Planet Position").font(.caption2.bold()).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Framing in the photo

    private var planetFramingSection: some View {
        let planet = Bindable(store).labelPlanet
        return VStack(alignment: .leading, spacing: 8) {
            Text("Photo").font(.caption2.bold()).foregroundStyle(.secondary)
            adjustmentSliderRow(title: "Horizon in Photo", valueText: "\(Int((store.labelPlanet.horizonInPhoto * 100).rounded()))%",
                                value: planet.horizonInPhoto, range: 0.02...0.98, defaultValue: 0.5)
            adjustmentSliderRow(title: "Crop Sky (Top)", valueText: "\(Int((store.labelPlanet.cropTop * 100).rounded()))%",
                                value: planet.cropTop, range: 0...0.6, defaultValue: 0)
            adjustmentSliderRow(title: "Crop Ground (Bottom)", valueText: "\(Int((store.labelPlanet.cropBottom * 100).rounded()))%",
                                value: planet.cropBottom, range: 0...0.6, defaultValue: 0)
            Picker(KroutonL10n.tr("Seam"), selection: planet.seam) {
                ForEach(KroutonPlanetSettings.Seam.allCases) { Text($0.rawValue).tag($0) }
            }
            .font(.caption)
            if store.labelPlanet.seam == .blend {
                adjustmentSliderRow(title: "Blend Width", valueText: "\(Int((store.labelPlanet.seamBlend * 100).rounded()))%",
                                    value: planet.seamBlend, range: 0.01...0.3, defaultValue: 0.08)
            }
        }
    }

    // MARK: - Edges and quality

    private var planetEdgesSection: some View {
        let planet = Bindable(store).labelPlanet
        let fadeColor = Binding<Color>(
            get: { Color(red: store.labelPlanet.fadeColor.r, green: store.labelPlanet.fadeColor.g, blue: store.labelPlanet.fadeColor.b) },
            set: { color in
                let (r, g, b, _) = KroutonPureColorMath.extractSRGB(color)
                store.labelPlanet.fadeColor = KroutonRGBAColor(r: Double(r), g: Double(g), b: Double(b))
            })
        return VStack(alignment: .leading, spacing: 8) {
            Text("Edges").font(.caption2.bold()).foregroundStyle(.secondary)
            adjustmentSliderRow(title: "Fade at the Rim", valueText: "\(Int((store.labelPlanet.rimFade * 100).rounded()))%",
                                value: planet.rimFade, range: 0...0.4, defaultValue: 0)
            adjustmentSliderRow(title: "Fade at the Centre", valueText: "\(Int((store.labelPlanet.centerFade * 100).rounded()))%",
                                value: planet.centerFade, range: 0...0.6, defaultValue: 0)
            if store.labelPlanet.rimFade > 0 || store.labelPlanet.centerFade > 0 {
                ColorPicker(KroutonL10n.tr("Fade To"), selection: fadeColor, supportsOpacity: false)
                    .font(.caption)
            }
            Picker(KroutonL10n.tr("Smoothing"), selection: planet.antialias) {
                Text("Draft").tag(1)
                Text("Smooth").tag(2)
                Text("Finest").tag(3)
            }
            .pickerStyle(.segmented)
            .help("Samples per pixel: Smooth removes jagged edges near the centre; Finest is slower")
            Text("Colour, contrast and blur are in Adjust; they apply to the planet too.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
