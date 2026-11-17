import SwiftUI

// Shared pill controls.
//
// The packet repeats the same capsule button (font, fixedSize, padding, active or
// inactive fill, black or secondary text, Capsule clip, plain style) eight times
// across AudioCrossfadeCanvasView and AudioMasteringWorkspaces, with small drifts
// in padding and font size. These three pieces replace all of them and give every
// workspace the same on/off look.
//
// Not compiled here (no Swift toolchain in my sandbox).

// MARK: - KroutonPillControls

enum KroutonPillMetrics {
    static let activeFill = Color(white: 0.88)
    static let inactiveFill = Color.white.opacity(0.08)
    static let font = Font.system(size: 9.5, weight: .bold)
}

/// The one capsule look. `isOn` picks the filled or the quiet variant.
struct KroutonPillButtonStyle: ButtonStyle {
    var isOn: Bool
    /// Inside a segmented group the unselected segments have no fill of their own.
    var showsInactiveFill = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KroutonPillMetrics.font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(isOn ? KroutonPillMetrics.activeFill : (showsInactiveFill ? KroutonPillMetrics.inactiveFill : .clear))
            .foregroundStyle(isOn ? Color.black : Color.secondary)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// A segmented choice drawn as pills: transition mode, curve, waveform layout, A/B.
struct KroutonPillPicker<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var systemImage: String?
        var id: Value { value }
    }

    let options: [Option]
    let selection: Value
    /// Reports the tap; the owner decides what a change means (undo, mode switch).
    let onSelect: (Value) -> Void
    /// True draws one shared track behind the segments.
    var grouped = true

    var body: some View {
        HStack(spacing: grouped ? 2 : 3) {
            ForEach(options) { option in
                Button { onSelect(option.value) } label: {
                    HStack(spacing: 3) {
                        if let systemImage = option.systemImage { Image(systemName: systemImage) }
                        Text(option.title)
                    }
                }
                .buttonStyle(KroutonPillButtonStyle(isOn: option.value == selection, showsInactiveFill: !grouped))
                .accessibilityAddTraits(option.value == selection ? .isSelected : [])
            }
        }
        .padding(grouped ? 2 : 0)
        .background(grouped ? KroutonPillMetrics.inactiveFill : .clear)
        .clipShape(Capsule())
    }
}

/// An on/off pill with a state dot, so state never depends on colour alone.
struct KroutonTogglePill: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isOn ? Color.black : Color.secondary.opacity(0.5))
                    .frame(width: 5, height: 5)
                Text(title)
            }
        }
        .buttonStyle(KroutonPillButtonStyle(isOn: isOn))
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// The small monospaced readout used for timecodes, frame counts and dB values.
struct KroutonReadoutStyle: ViewModifier {
    var emphasised = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: 9.5, weight: emphasised ? .bold : .semibold, design: .monospaced))
            .foregroundStyle(emphasised ? .primary : .secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

extension View {
    func kroutonReadout(emphasised: Bool = false) -> some View {
        modifier(KroutonReadoutStyle(emphasised: emphasised))
    }
}

// Before (one of eight copies):
//
//   Button { setTransitionMode(mode) } label: {
//       Text(mode.rawValue)
//           .font(.system(size: 9.5, weight: .bold))
//           .lineLimit(1)
//           .fixedSize(horizontal: true, vertical: false)
//           .padding(.horizontal, 9).padding(.vertical, 3.5)
//           .background(isSelected ? controlActiveFill : Color.clear)
//           .foregroundStyle(isSelected ? .black : .secondary)
//           .clipShape(Capsule())
//   }
//   .buttonStyle(.plain)
//
// After:
//
//   KroutonPillPicker(
//       options: SpliceTransitionMode.allCases.map { .init(value: $0, title: $0.rawValue) },
//       selection: mode,
//       onSelect: setMode
//   )
