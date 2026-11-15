import SwiftUI
import AudioKit

struct SpliceHeaderBar: View {
    let trackNumber: Int
    let totalTransitions: Int
    let snapshot: SpliceCanvasSnapshot
    let peakReadout: String
    let activeSlot: ABComparison.Slot
    let primaryColor: Color
    let isFloatingWindow: Bool
    let onSelectMode: (SpliceTransitionMode) -> Void
    let onSelectSlot: (ABComparison.Slot) -> Void
    let onAddSubIndex: () -> Void
    let onStepTransition: (Int) -> Void
    let onToggleFloatingWindow: () -> Void

    @ObservedObject private var montageState = TrackMontageWindowState.shared
    private var spec: KroutonTrackTransitionSpec { snapshot.spec }

    private var statusSummary: String {
        switch snapshot.mode {
        case .crossfade:
            return String(format: "Overlap: %.2fs (%df) • %@", spec.overlapSeconds, spec.overlapRedBookFrames, peakReadout)
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
                            Image(systemName: "chevron.left").font(.system(size: 8.5, weight: .bold))
                        }
                        .buttonStyle(KroutonPillButtonStyle(isOn: false))
                        .disabled(trackNumber <= 1)
                        .help("Previous track transition")

                        Button { onStepTransition(1) } label: {
                            Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold))
                        }
                        .buttonStyle(KroutonPillButtonStyle(isOn: false))
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
                withAnimation(.easeInOut(duration: 0.14)) {
                    montageState.horizontalZoom = montageState.horizontalZoom < 2.0 ? 3.0 : 1.0
                }
            }
            .help("Toggle between standard transition view and zoomed-out 34s concert crossfade view")

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
