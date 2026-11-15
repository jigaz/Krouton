import DriveKit
import SwiftUI
import Foundation
import OpticalCore

struct KroutonFloatingPhaseScopeView: View {
    let driveID: String
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    let onDockInline: () -> Void

    var drive: KroutonOpticalDriveInfo? { driveManager.driveForID(driveID) }
    var telemetry: KroutonDrivePhaseScopeTelemetry {
        driveManager.telemetryForDrive(driveID) ?? KroutonDrivePhaseScopeTelemetry(id: driveID, driveName: drive?.displayName ?? "Optical Burner")
    }

    private func formatMMSS(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    var body: some View {
        let isLight = (store.resolvedColorScheme == .light)
        let useHarmony = store.enableSecondaryAccentUITints
        let primaryColor = store.activeAccent
        let harmonyColor = store.uiSecondaryAccent
        let rpmColor: Color = useHarmony ? harmonyColor : (isLight ? Color(.displayP3, red: 0.74, green: 0.44, blue: 0.00) : Color(.displayP3, red: 1.00, green: 0.82, blue: 0.24))
        let progress = min(1.0, max(0.0, telemetry.progressFraction))
        let elapsedSec = max(0, telemetry.elapsedSeconds)
        let totalKB = Double(max(1, telemetry.totalSectorsLBA)) * 2.0
        let estimatedTotalSec = (elapsedSec > 0 && progress > 0.02)
            ? max(elapsedSec, Int((Double(elapsedSec) / progress).rounded()))
            : max(4, Int((totalKB / max(1400.0, telemetry.currentSpeedKBs)).rounded()))
        let remainingSec = max(0, estimatedTotalSec - elapsedSec)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KroutonDiscArtworkView(
                    mediaType: drive?.mediaType ?? "CD-RW",
                    isMediaPresent: drive?.isMediaPresent ?? true,
                    isErasable: drive?.isMediaErasable ?? true,
                    isBlank: drive?.isMediaBlank ?? false
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(telemetry.driveName).font(.system(size: 14, weight: .bold))
                    Text("\(telemetry.phaseTitle) • LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA) • Elapsed \(formatMMSS(elapsedSec)) (Rem \(formatMMSS(remainingSec)))")
                        .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button {
                    driveManager.runPhaseScopeTestSweep(for: driveID)
                } label: {
                    Label("Test Sweep", systemImage: "waveform.path.ecg").font(.system(size: 11, weight: .semibold))
                }.buttonStyle(.bordered).controlSize(.small)
                Button {
                    onDockInline()
                } label: {
                    Label("Dock Inline", systemImage: "pip.enter").font(.system(size: 11, weight: .semibold))
                }.buttonStyle(.borderedProminent).tint(primaryColor).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(store.harmonizedCardFill).background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(store.harmonizedCardBorder, lineWidth: 1))

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isLight
                        ? LinearGradient(colors: [Color(red: 0.968, green: 0.975, blue: 0.990), Color(red: 0.928, green: 0.942, blue: 0.972)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(red: 0.016, green: 0.022, blue: 0.045), Color(red: 0.030, green: 0.042, blue: 0.082)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Canvas { context, size in
                    let gridCol = (useHarmony ? harmonyColor : primaryColor).opacity(isLight ? 0.20 : 0.30)
                    var grid = Path()
                    for c in 0...16 {
                        let x = size.width * CGFloat(c) / 16.0
                        grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for r in 0...8 {
                        let y = size.height * CGFloat(r) / 8.0
                        grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(gridCol), lineWidth: 0.6)

                    var targetCurve = Path()
                    for step in 0...48 {
                        let frac = Double(step) / 48.0
                        let theoX = 4.2 + (11.8 * pow(frac, 0.78))
                        let pt = CGPoint(x: size.width * CGFloat(frac), y: size.height * (1.0 - CGFloat(min(1.0, theoX / 24.0))))
                        if step == 0 { targetCurve.move(to: pt) } else { targetCurve.addLine(to: pt) }
                    }
                    context.stroke(targetCurve, with: .color(harmonyColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))

                    let traces = buildSmoothScopeTraces(telemetry: telemetry, size: size, maxScaleX: 24.0, maxScaleRPM: 6000.0)
                    if telemetry.samples.count > 1 {
                        context.fill(traces.bufferArea, with: .color(harmonyColor.opacity(0.18)))
                        context.fill(traces.speedArea, with: .color(primaryColor.opacity(0.22)))
                        context.stroke(traces.rpmLine, with: .color(rpmColor), lineWidth: 1.8)
                        context.stroke(traces.speedLine, with: .color(primaryColor), lineWidth: 2.4)
                    }
                }
                VStack {
                    HStack {
                        Text("24.0x MAX SPEED").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(primaryColor)
                        Spacer()
                        Text("6,000 RPM CEILING").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(rpmColor)
                    }
                    Spacer()
                    HStack {
                        Text("Inner Hub (r = 24.0 mm • LBA 0)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text("Buffer Ribbon: \(Int(telemetry.bufferFillPercent))% Armed").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(useHarmony ? harmonyColor : primaryColor)
                        Spacer()
                        Text("Outer Rim (r = 58.0 mm • Lead-Out)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }.padding(14)
            }
            .frame(minHeight: 265, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(primaryColor.opacity(0.55), lineWidth: 1.5))

            floatingTelemetryChannelGrid(primaryColor: primaryColor, harmonyColor: harmonyColor, rpmColor: rpmColor, useHarmony: useHarmony)
        }
        .padding(18)
        .frame(minWidth: 740, idealWidth: 800, minHeight: 510, idealHeight: 570)
        .background(store.mainPanelTintOverlay)
        .background(Color.kroutonWindowSurface)
        .preferredColorScheme(store.resolvedColorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
    }
}
