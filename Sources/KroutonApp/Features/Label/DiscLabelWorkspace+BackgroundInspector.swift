import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers

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

    func backgroundToolInspector() -> some View {
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

                            Picker(KroutonL10n.tr("Object Chamber"), selection: $store.labelGPUSeedPattern) {
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

                                Picker(KroutonL10n.tr("Mirror Rig"), selection: $store.labelKaleidoscopeRig) {
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

    func backgroundModeButton(title: String, subtitle: String, style: KroutonVectorBackgroundStyle, icon: String) -> some View {
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
}
