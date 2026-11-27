import AudioKit
import SwiftUI

// MARK: - SpliceHeaderBar

struct SpliceHeaderBar: View {
    let trackNumber: Int
    let totalTransitions: Int
    let snapshot: SpliceCanvasSnapshot
    let peakReadout: String
    var bpmReadout: String? = nil
    let activeSlot: ABComparison.Slot
    let primaryColor: Color
    let isFloatingWindow: Bool
    let onSelectMode: (SpliceTransitionMode) -> Void
    let onReset: () -> Void
    let onSelectSlot: (ABComparison.Slot) -> Void
    let onAddSubIndex: () -> Void
    let onStepTransition: (Int) -> Void
    let onToggleFloatingWindow: () -> Void

    @State private var montageState = TrackMontageWindowState.shared
    private var spec: KroutonTrackTransitionSpec { snapshot.spec }

    private var isModifiedFromDefault: Bool {
        if !spec.subIndexRatios.isEmpty { return true }
        switch snapshot.mode {
        case .crossfade:
            let hasQuarterHandles = spec.fadeOutMidTrim != nil
                || spec.fadeOutThreeQuarterTrim != nil
                || spec.fadeInQuarterTrim != nil
                || spec.fadeInMidTrim != nil
            return hasQuarterHandles
                || abs(spec.overlapSeconds - 2.5) > 0.015
                || spec.fadeOutCurve != .equalPower
                || spec.fadeInCurve != .equalPower
                || abs(spec.curveTension) > 0.005
                || abs(spec.spliceIndex01Ratio - 0.5) > 0.005
        case .gap:
            return abs(spec.preGapSeconds - 2.0) > 0.015
        case .gapless:
            return spec.overlapSeconds > 0.005 || spec.preGapSeconds > 0.005
        }
    }

    private var statusSummary: String {
        switch snapshot.mode {
        case .crossfade:
            let bpmSuffix = bpmReadout.map { " • \($0)" } ?? ""
            return String(format: "Overlap: %.2fs (%df) • %@%@", spec.overlapSeconds, spec.overlapRedBookFrames, peakReadout, bpmSuffix)
        case .gap:
            return String(format: "INDEX 00: %.2fs (%df)", spec.preGapSeconds, spec.preGapRedBookFrames)
        case .gapless:
            return "00:00:00 Gapless"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .foregroundStyle(primaryColor)
                Text(String(format: "TRACK MONTAGE • %02d ➔ %02d", trackNumber, trackNumber + 1))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if isFloatingWindow && totalTransitions > 1 {
                    HStack(spacing: 2) {
                        Button { onStepTransition(-1) } label: {
                            Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(KroutonPillButtonStyle(isOn: false))
                        .accessibilityLabel("Previous transition")
                        .disabled(trackNumber <= 1)
                        .help("Previous track transition")

                        Button { onStepTransition(1) } label: {
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(KroutonPillButtonStyle(isOn: false))
                        .accessibilityLabel("Next transition")
                        .disabled(trackNumber >= totalTransitions)
                        .help("Next track transition")
                    }
                }
            }

            KroutonPillPicker(
                options: SpliceTransitionMode.allCases.map { .init(value: $0, title: $0.rawValue) },
                selection: snapshot.mode,
                onSelect: onSelectMode
            )

            Button(action: onReset) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))
            .disabled(!isModifiedFromDefault)
            .opacity(isModifiedFromDefault ? 1.0 : 0.38)
            .help(isModifiedFromDefault ? "Reset transition to default settings" : "Transition is currently at default settings")

            ViewThatFits(in: .horizontal) {
                Text(statusSummary)
                    .kroutonReadout()
                EmptyView()
            }

            Spacer(minLength: 4)

            KroutonTogglePill(
                title: "Zoom Out",
                isOn: montageState.horizontalZoom < 2.0
            ) {
                withAnimation(kroutonMotion(.easeInOut(duration: 0.14))) {
                    montageState.horizontalZoom = montageState.horizontalZoom < 2.0 ? 3.0 : 1.0
                }
            }
            .help("Toggle between 5s precision crossfade view and zoomed-out 15s extended view")

            Button(action: onAddSubIndex) {
                HStack(spacing: 3) {
                    Image(systemName: "flag.badge.ellipsis.fill")
                    Text("+ Index")
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: !spec.subIndexRatios.isEmpty))
            .help("Add a draggable Red Book sub-index marker (INDEX 02..99); drag across INDEX 01 to switch track ownership & color")

            KroutonPillPicker(
                options: ABComparison.Slot.allCases.map { .init(value: $0, title: $0.rawValue) },
                selection: activeSlot,
                onSelect: onSelectSlot
            )

            Button(action: onToggleFloatingWindow) {
                HStack(spacing: 3) {
                    Image(systemName: isFloatingWindow ? "arrow.down.right.and.arrow.up.left" : "pip.exit")
                    Text(isFloatingWindow ? "Dock" : "Pop Out")
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: isFloatingWindow))
            .help(isFloatingWindow ? "Dock Track Montage Editor back into the main window" : "Pop out Track Montage Editor into an independent floating window")
        }
    }
}
