import LabelKit
import OpticalCore
import SwiftUI

// MARK: - Print Setup Inspector

/// Settings for printing straight onto a printable disc in an inkjet tray (or onto a sheet):
/// resolution, bleed, tray offsets and ink, plus the alignment test and the exports.
extension KroutonDiscLabelWorkspaceView {
    func printToolInspector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Print Setup", systemImage: "printer")
                .font(.subheadline.bold())

            Picker(KroutonL10n.tr("Print On"), selection: Bindable(store).labelPrint.target) {
                ForEach(KroutonLabelPrintSettings.Target.allCases) { Text($0.rawValue).tag($0) }
            }
            .font(.caption)
            Text(store.labelPrint.target == .discTray
                 ? "Export the PNG and open it in your printer's disc software (Epson Print CD, Canon IJ Label Print, HP's disc tool) at 100%. The PDF has the same artwork placed for the tray, with its offsets."
                 : "The PDF prints the label at 1:1 on US Letter, with the rim and hub marked, to cut out or to check sizes on plain paper.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            printResolutionSection()
            Divider()
            printOffsetSection
            Divider()
            printInkSection()
            Divider()
            printExportButtons
        }
    }

    // MARK: - Resolution and bleed

    private func printResolutionSection() -> some View {
        let settings = store.labelPrint
        let preset = activePreset
        let pixels = Int(((preset.outerDiameterMM + 2 * settings.bleedOuterMM) / 25.4 * Double(settings.dotsPerInch)).rounded())
        return VStack(alignment: .leading, spacing: 8) {
            Text("Resolution").font(.caption2.bold()).foregroundStyle(.secondary)
            Picker(KroutonL10n.tr("Resolution"), selection: Bindable(store).labelPrint.dotsPerInch) {
                Text("300").tag(300)
                Text("360").tag(360)
                Text("600").tag(600)
                Text("720").tag(720)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("Epson disc printing works in multiples of 360 dpi, Canon and HP in multiples of 300")
            Text("\(pixels) × \(pixels) pixels at \(settings.dotsPerInch) dpi")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            adjustmentSliderRow(title: "Bleed Past the Rim", valueText: String(format: "%.1f mm", settings.bleedOuterMM),
                                value: Bindable(store).labelPrint.bleedOuterMM, range: 0...3, defaultValue: 1)
            adjustmentSliderRow(title: "Bleed Into the Hub", valueText: String(format: "%.1f mm", settings.bleedInnerMM),
                                value: Bindable(store).labelPrint.bleedInnerMM, range: 0...2, defaultValue: 0.5)
            Text("Bleed carries the artwork a little past the printable area, so a print slightly off centre leaves no white edge. Keep text a few millimetres inside the rim.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tray offsets

    private var printOffsetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tray Alignment").font(.caption2.bold()).foregroundStyle(.secondary)
            Text("Print the alignment test on a spare disc. If the crosshair lands off the centre, enter how far: positive X moves the print right, positive Y moves it down.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            adjustmentSliderRow(title: "Offset X", valueText: String(format: "%+.1f mm", activePreset.offsetXMM),
                                value: activeGeometryBinding.offsetXMM, range: -3...3, defaultValue: 0)
            adjustmentSliderRow(title: "Offset Y", valueText: String(format: "%+.1f mm", activePreset.offsetYMM),
                                value: activeGeometryBinding.offsetYMM, range: -3...3, defaultValue: 0)
            Button {
                showTransientBanner(store.exportAlignmentTest())
            } label: {
                Label("Save Alignment Test (PDF)", systemImage: "scope")
            }
            .controlSize(.small)
        }
    }

    // MARK: - Ink

    private func printInkSection() -> some View {
        let settings = store.labelPrint
        return VStack(alignment: .leading, spacing: 8) {
            Text("Ink").font(.caption2.bold()).foregroundStyle(.secondary)
            adjustmentSliderRow(title: "Ink Density", valueText: "\(Int((settings.inkDensity * 100).rounded()))%",
                                value: Bindable(store).labelPrint.inkDensity, range: 0.5...1, defaultValue: 1)
            adjustmentSliderRow(title: "Lift Shadows", valueText: "\(Int((settings.blackLift * 100).rounded()))%",
                                value: Bindable(store).labelPrint.blackLift, range: 0...0.3, defaultValue: 0)
            Text("Glossy and water-resistant discs take less ink than matte ones: if prints smear or stay wet, lower the density or lift the shadows. Both are applied when you export.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: Bindable(store).labelPreviewInkDensity) {
                Text("Show the density on the canvas").font(.caption)
            }
            Toggle(isOn: Bindable(store).labelPrint.cropMarks) {
                Text("Rim and hub marks on the PDF").font(.caption)
            }
        }
    }

    // MARK: - Export

    private var printExportButtons: some View {
        HStack(spacing: 6) {
            Button {
                exportLabel(.png)
            } label: {
                Label("Export PNG", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .tint(store.activeAccent)
            Button {
                exportLabel(.pdf)
            } label: {
                Label("Export PDF", systemImage: "doc.richtext")
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.small)
    }
}
