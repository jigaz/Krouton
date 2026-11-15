import SwiftUI
import AudioKit

struct SpliceControlsBar: View {
    let snapshot: SpliceCanvasSnapshot
    @Binding var superimposed: Bool
    @Binding var showSum: Bool
    @Binding var highlightLoudFrames: Bool
    let onPreview: (KroutonTrackTransitionSpec) -> Void
    let onCommit: (KroutonTrackTransitionSpec) -> Void
    let onAudition: () -> Void

    @ObservedObject private var auditioner = SpliceAudioAuditioner.shared
    private var spec: KroutonTrackTransitionSpec { snapshot.spec }

    var body: some View {
        HStack(spacing: 6) {
            KroutonPillPicker(
                options: [
                    .init(value: true, title: "Overlap"),
                    .init(value: false, title: "Split Lanes")
                ],
                selection: superimposed,
                onSelect: { superimposed = $0 }
            )

            if snapshot.mode == .crossfade {
                KroutonPillPicker(
                    options: KroutonCrossfadeCurve.allCases.map {
                        .init(value: $0, title: shortLabel(for: $0), systemImage: glyph(for: $0))
                    },
                    selection: spec.fadeOutCurve,
                    onSelect: { curve in
                        var updated = spec
                        updated.fadeOutCurve = curve
                        updated.fadeInCurve = curve
                        onCommit(updated)
                    },
                    grouped: false
                )

                HStack(spacing: 4) {
                    Text("X-Fade:")
                        .kroutonReadout()
                    Slider(
                        value: Binding(
                            get: { spec.overlapSeconds },
                            set: { var s = spec; s.overlapSeconds = $0; onPreview(s) }
                        ),
                        in: 0.5...30.0,
                        step: 0.25,
                        onEditingChanged: { editing in
                            if !editing { onCommit(spec) }
                        }
                    )
                    .tint(KroutonPillMetrics.activeFill)
                    .frame(width: 58)

                    Text(String(format: "%.1fs", spec.overlapSeconds))
                        .kroutonReadout(emphasised: true)
                        .frame(width: 34, alignment: .trailing)
                }

                HStack(spacing: 4) {
                    Text("Tension:")
                        .kroutonReadout()
                    Slider(
                        value: Binding(
                            get: { spec.curveTension },
                            set: { var s = spec; s.curveTension = $0; onPreview(s) }
                        ),
                        in: -1.0...1.0,
                        step: 0.05,
                        onEditingChanged: { editing in
                            if !editing { onCommit(spec) }
                        }
                    )
                    .tint(KroutonPillMetrics.activeFill)
                    .frame(width: 68)

                    Text(String(format: "%+d%%", Int(spec.curveTension * 100)))
                        .kroutonReadout(emphasised: true)
                        .frame(width: 34, alignment: .trailing)
                }

                KroutonTogglePill(title: "Sum", isOn: showSum) {
                    showSum.toggle()
                }
            } else if snapshot.mode == .gap {
                HStack(spacing: 6) {
                    Text("Pre-Gap:")
                        .kroutonReadout()
                    Slider(
                        value: Binding(
                            get: { spec.preGapSeconds },
                            set: { var s = spec; s.preGapSeconds = $0; onPreview(s) }
                        ),
                        in: 0.25...4.0,
                        step: 0.25,
                        onEditingChanged: { editing in
                            if !editing { onCommit(spec) }
                        }
                    )
                    .tint(KroutonPillMetrics.activeFill)
                    .frame(width: 110)

                    Text(String(format: "%.2fs (%df)", spec.preGapSeconds, spec.preGapRedBookFrames))
                        .kroutonReadout(emphasised: true)
                }
            }

            KroutonTogglePill(title: "Peaks", isOn: highlightLoudFrames) {
                highlightLoudFrames.toggle()
            }

            Spacer(minLength: 4)

            Button {
                onCommit(resetSpec(from: spec, mode: snapshot.mode))
            } label: {
                Text("Reset")
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))

            // Compact Pre/Post-Roll Lead/Lag Pill (±3s, ±5s, ±10s) right next to Preview
            KroutonPillPicker(
                options: [
                    .init(value: 3.0, title: "±3s"),
                    .init(value: 5.0, title: "±5s"),
                    .init(value: 10.0, title: "±10s")
                ],
                selection: auditioner.leadLagSeconds,
                onSelect: { auditioner.leadLagSeconds = $0 }
            )
            .help("Pre-roll lead and post-roll lag time around the transition when listening to Preview")

            Button(action: onAudition) {
                HStack(spacing: 4) {
                    Image(systemName: auditioner.isPlaying ? "stop.fill" : "play.fill")
                    Text(auditioner.isPlaying ? "Stop" : "Preview")
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: true))
        }
    }

    private func resetSpec(from current: KroutonTrackTransitionSpec, mode: SpliceTransitionMode) -> KroutonTrackTransitionSpec {
        var updated = KroutonTrackTransitionSpec()
        updated.id = current.id
        switch mode {
        case .crossfade:
            updated.overlapSeconds = 2.5
            updated.preGapSeconds = 0
        case .gap:
            updated.overlapSeconds = 0
            updated.preGapSeconds = 2.0
        case .gapless:
            updated.overlapSeconds = 0
            updated.preGapSeconds = 0
        }
        return updated
    }

    private func glyph(for curve: KroutonCrossfadeCurve) -> String {
        switch curve {
        case .equalPower: return "waveform.path"
        case .sCurveHermite: return "point.topleft.down.curvedto.point.bottomright.up"
        case .linear: return "line.diagonal"
        case .exponential: return "chart.line.uptrend.xyaxis"
        }
    }

    private func shortLabel(for curve: KroutonCrossfadeCurve) -> String {
        switch curve {
        case .equalPower: return "Equal-Power"
        case .sCurveHermite: return "S-Curve"
        case .linear: return "Linear"
        case .exponential: return "Exponential"
        }
    }
}
