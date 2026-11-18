import AudioKit
import SwiftUI

// MARK: - SpliceControlsBar (4 Logically Grouped Control Pods & Live Rubber-Band X-Fade Slider)

struct SpliceControlsBar: View {
    let snapshot: SpliceCanvasSnapshot
    var palette: SplicePalette = SplicePalette()
    @Binding var superimposed: Bool
    @Binding var showSum: Bool
    @Binding var highlightLoudFrames: Bool
    @Binding var rubberBandSpan: Double?
    let onPreview: (KroutonTrackTransitionSpec) -> Void
    let onCommit: (KroutonTrackTransitionSpec) -> Void
    let onAudition: () -> Void

    @State private var auditioner = SpliceAudioAuditioner.shared
    @State private var isSlidingXFade = false
    private var spec: KroutonTrackTransitionSpec { snapshot.spec }

    private var maxOverlapRange: Double {
        max(15.0, ceil(spec.overlapSeconds))
    }

    /// Musical non-linear slider mapping (0...1 <-> 0.25s...maxOverlapRange) so 1s-5s crossfades have generous center travel.
    private var xFadeSliderNormalizedBinding: Binding<Double> {
        Binding<Double>(
            get: {
                let span = max(1.0, maxOverlapRange - 0.25)
                let clamped = min(maxOverlapRange, max(0.25, spec.overlapSeconds))
                return pow((clamped - 0.25) / span, 1.0 / 1.75)
            },
            set: { norm in
                let span = max(1.0, maxOverlapRange - 0.25)
                let rawSec = 0.25 + span * pow(min(1.0, max(0.0, norm)), 1.75)
                let frameQuantized = (rawSec * 75.0).rounded() / 75.0
                var updated = spec
                updated.overlapSeconds = min(maxOverlapRange, max(0.25, frameQuantized))
                onPreview(updated)
            }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            // POD 1: Canvas Display & Metering Overlays
            controlPod {
                KroutonPillPicker(
                    options: [
                        .init(value: true, title: "Overlap"),
                        .init(value: false, title: "Split Lanes")
                    ],
                    selection: superimposed,
                    onSelect: { superimposed = $0 }
                )

                if snapshot.mode == .crossfade {
                    KroutonTogglePill(title: "Sum", isOn: showSum) {
                        showSum.toggle()
                    }
                }

                Button {
                    highlightLoudFrames.toggle()
                } label: {
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(palette.outgoingHighlight)
                                .frame(width: 5.5, height: 5.5)
                            Circle()
                                .fill(palette.incomingHighlight)
                                .frame(width: 5.5, height: 5.5)
                        }
                        .opacity(highlightLoudFrames ? 1.0 : 0.55)
                        Text("Peaks")
                    }
                }
                .buttonStyle(KroutonPillButtonStyle(isOn: highlightLoudFrames))
                .help("Highlight loudest frames with distinct colors for Outgoing (chartreuse-gold) and Incoming (amber-gold) tracks")
            }

            if snapshot.mode == .crossfade {
                Spacer(minLength: 4)

                // POD 2: Curve Shape Family & Curve Tension
                controlPod {
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
                        grouped: true
                    )

                    Divider().frame(height: 14)

                    HStack(spacing: 5) {
                        Text("Tension")
                            .kroutonReadout()
                        Slider(
                            value: Binding(
                                get: { spec.curveTension },
                                set: { var s = spec; s.curveTension = $0; onPreview(s) }
                            ),
                            in: -1.0...1.0,
                            onEditingChanged: { editing in
                                if !editing { onCommit(spec) }
                            }
                        )
                        .tint(KroutonPillMetrics.activeFill)
                        .frame(minWidth: 78, idealWidth: 96, maxWidth: 115)

                        Text(String(format: "%+d%%", Int((spec.curveTension * 100).rounded())))
                            .kroutonReadout(emphasised: true)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                Spacer(minLength: 4)

                // POD 3: Crossfade Overlap Duration (Linked to Live Canvas Rubber-Banding)
                controlPod(highlighted: isSlidingXFade) {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isSlidingXFade ? Color.orange : .secondary)
                            Text("X-Fade")
                                .kroutonReadout(emphasised: isSlidingXFade)
                        }

                        Slider(
                            value: xFadeSliderNormalizedBinding,
                            in: 0.0...1.0,
                            onEditingChanged: { editing in
                                isSlidingXFade = editing
                                if editing {
                                    if rubberBandSpan == nil {
                                        rubberBandSpan = max(1.0, spec.overlapSeconds * 1.25)
                                    }
                                } else {
                                    onCommit(spec)
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                                        rubberBandSpan = nil
                                    }
                                }
                            }
                        )
                        .tint(isSlidingXFade ? Color.orange : KroutonPillMetrics.activeFill)
                        .frame(minWidth: 105, idealWidth: 135, maxWidth: 165)

                        Text(String(format: "%.2fs (%df)", spec.overlapSeconds, spec.overlapRedBookFrames))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(isSlidingXFade ? Color.orange : .white.opacity(0.92))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSlidingXFade ? Color.orange.opacity(0.18) : Color.white.opacity(0.07))
                            )
                            .frame(minWidth: 78, alignment: .trailing)
                    }
                }
            } else if snapshot.mode == .gap {
                Spacer(minLength: 4)

                controlPod {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.rectangle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("Pre-Gap")
                            .kroutonReadout()
                        Slider(
                            value: Binding(
                                get: { spec.preGapSeconds },
                                set: { var s = spec; s.preGapSeconds = $0; onPreview(s) }
                            ),
                            in: 0.25...4.0,
                            onEditingChanged: { editing in
                                if !editing { onCommit(spec) }
                            }
                        )
                        .tint(KroutonPillMetrics.activeFill)
                        .frame(minWidth: 110, idealWidth: 130, maxWidth: 155)

                        Text(String(format: "%.2fs (%df)", spec.preGapSeconds, spec.preGapRedBookFrames))
                            .kroutonReadout(emphasised: true)
                            .frame(minWidth: 74, alignment: .trailing)
                    }
                }
            }

            Spacer(minLength: 4)

            // POD 4: Audition Pre/Post-Roll & Preview Transport
            controlPod {
                ViewThatFits(in: .horizontal) {
                    KroutonPillPicker(
                        options: [
                            .init(value: 1.0, title: "±1s"),
                            .init(value: 2.0, title: "±2s"),
                            .init(value: 3.0, title: "±3s"),
                            .init(value: 10.0, title: "±10s")
                        ],
                        selection: auditioner.leadLagSeconds,
                        onSelect: { auditioner.leadLagSeconds = $0 }
                    )
                    KroutonPillPicker(
                        options: [
                            .init(value: 1.0, title: "±1s"),
                            .init(value: 2.0, title: "±2s"),
                            .init(value: 3.0, title: "±3s")
                        ],
                        selection: auditioner.leadLagSeconds == 10.0 ? 3.0 : auditioner.leadLagSeconds,
                        onSelect: { auditioner.leadLagSeconds = $0 }
                    )
                }
                .help("Pre-roll lead and post-roll lag time around the transition when listening to Preview (±1s, ±2s, ±3s, ±10s)")

                Button(action: onAudition) {
                    HStack(spacing: 4) {
                        Image(systemName: auditioner.isPlaying ? "stop.fill" : "play.fill")
                        Text(auditioner.isPlaying ? "Stop" : "Preview")
                    }
                }
                .buttonStyle(KroutonPillButtonStyle(isOn: true))
            }
        }
    }

    @ViewBuilder
    private func controlPod<Content: View>(highlighted: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(highlighted ? 0.09 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(highlighted ? Color.orange.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
        )
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
