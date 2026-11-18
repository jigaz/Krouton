import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

// MARK: - Clean 5-Slider Background Adjustments Inspector (Blur, Brightness, Contrast, Hue & Saturation)

extension KroutonDiscLabelWorkspaceView {

    func adjustmentsToolInspector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Adjust Background", systemImage: "slider.horizontal.3")
                    .font(.subheadline.bold())
                Spacer()
                Button(KroutonL10n.tr("Reset")) {
                    store.labelBgAdjustments = KroutonBackgroundAdjustments()
                }
                .font(.caption2.bold())
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(store.labelBgAdjustments.isIdentity)
            }

            Text("Soften, brighten, or shift the colors of the disc background while keeping foreground text layers sharp.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.labelBackgroundStyle == .templateDefault {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Blank White Printable Disc is active (unprinted surface). Select a gradient or optical background in 'Bg' to preview color & blur adjustments.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            // 1. BLUR
            adjustmentSliderRow(
                title: "Blur",
                valueText: String(format: "%.1f px", store.labelBgAdjustments.blurRadius),
                value: Bindable(store).labelBgAdjustments.blurRadius,
                range: 0.0...35.0,
                defaultValue: 0.0
            )

            Divider()

            // 2. BRIGHTNESS & CONTRAST
            adjustmentSliderRow(
                title: "Brightness",
                valueText: String(format: "%+.0f%%", store.labelBgAdjustments.brightness * 200.0),
                value: Bindable(store).labelBgAdjustments.brightness,
                range: -0.45...0.45,
                defaultValue: 0.0
            )

            adjustmentSliderRow(
                title: "Contrast",
                valueText: String(format: "%.2f×", store.labelBgAdjustments.contrast),
                value: Bindable(store).labelBgAdjustments.contrast,
                range: 0.50...1.80,
                defaultValue: 1.0
            )

            Divider()

            // 3. HUE & SATURATION
            adjustmentSliderRow(
                title: "Hue Shift",
                valueText: String(format: "%+.0f°", store.labelBgAdjustments.hueDegrees),
                value: Bindable(store).labelBgAdjustments.hueDegrees,
                range: -180.0...180.0,
                defaultValue: 0.0
            )

            adjustmentSliderRow(
                title: "Saturation",
                valueText: String(format: "%.2f×", store.labelBgAdjustments.saturation),
                value: Bindable(store).labelBgAdjustments.saturation,
                range: 0.0...2.0,
                defaultValue: 1.0
            )

            Divider()

            // 4. Quick 1-Click Presets
            VStack(alignment: .leading, spacing: 5) {
                Text("Quick Presets")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Button(KroutonL10n.tr("Frosted")) {
                        store.labelBgAdjustments.blurRadius = 12.0
                        store.labelBgAdjustments.brightness = 0.08
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button(KroutonL10n.tr("Pastel Ink-Saver")) {
                        store.labelBgAdjustments.brightness = 0.22
                        store.labelBgAdjustments.contrast = 0.82
                        store.labelBgAdjustments.saturation = 0.75
                    }.buttonStyle(.bordered).controlSize(.mini)

                    Button(KroutonL10n.tr("B&W Mono")) {
                        store.labelBgAdjustments.saturation = 0.0
                    }.buttonStyle(.bordered).controlSize(.mini)
                }
            }
        }
    }

    func adjustmentSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        defaultValue: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(valueText) {
                    value.wrappedValue = defaultValue
                }
                .buttonStyle(.plain)
                .font(.caption2.monospaced())
                .help("Click value to reset this slider")
            }
            Slider(value: value, in: range)
        }
    }
}
