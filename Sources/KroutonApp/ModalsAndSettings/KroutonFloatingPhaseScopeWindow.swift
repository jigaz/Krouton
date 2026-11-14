import SwiftUI
import Foundation
import OpticalDough

struct KroutonFloatingThermometerView: View {
    let driveID: String
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonToasterBank
    let onDockInline: () -> Void

    var drive: KroutonToasterInfo? {
        driveManager.driveForID(driveID)
    }
    var telemetry: KroutonKitchenThermometer {
        driveManager.telemetryForDrive(driveID) ?? KroutonKitchenThermometer(
            id: driveID,
            driveName: drive?.displayName ?? "Optical Burner"
        )
    }
    enum ScopeChannelBadgeKind {
        case speed
        case rpm
        case laser
        case position
        case buffer
        case jitter
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
        // Color Theory Role Assignment across all 4 Modes:
        // - In Harmony Mode (Dark & Light): Speed = Primary, Motor RPM = Secondary Harmony!
        // - In Primary-Only Mode (Dark & Light): Speed = Primary, Motor RPM = Studio Gold/Ochre so the two curves contrast cleanly.
        let rpmColor: Color = useHarmony
            ? harmonyColor
            : (isLight ? Color(.displayP3, red: 0.74, green: 0.44, blue: 0.00) : Color(.displayP3, red: 1.00, green: 0.82, blue: 0.24))
        // Detailed Transport Clock Math (Elapsed, Remaining, Estimated Total)
        VStack(alignment: .leading, spacing: 12) {
            // =========================================================================
            // 1. TOP INSTRUMENT HEADER BAR ("Dock" button + Calibration Sweep)
            // =========================================================================
            phaseScopeHeaderAndTelemetryRow
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(store.harmonizedCardFill)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(store.harmonizedCardBorder, lineWidth: 1)
            )
            // =========================================================================
            // 3. 4-MODE DISPLAY-P3 OSCILLOSCOPE JEWEL CANVAS (Low-CPU Spline Renderer)
            // =========================================================================
            ZStack {
                // Base Screen Surface: Deep CRT Obsidian in Dark Mode, Technical Plotter Paper in Light Mode
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isLight
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.968, green: 0.975, blue: 0.990),
                                    Color(red: 0.928, green: 0.942, blue: 0.972)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color(red: 0.016, green: 0.022, blue: 0.045),
                                    Color(red: 0.030, green: 0.042, blue: 0.082)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        // Diagonal Display-P3 Dual-Corner Vignette Wash (Primary Top-Left -> Harmony Bottom-Right)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(isLight ? 0.08 : 0.18),
                                        Color.clear,
                                        (useHarmony ? harmonyColor : primaryColor).opacity(isLight ? 0.10 : 0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                phaseScopeWaveformCanvasView
                VStack {
                    HStack {
                        Text(KroutonL10n.tr("24.0x MAX SPEED"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(primaryColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background((isLight ? Color.white : Color.black).opacity(0.60))
                            .clipShape(Capsule())
                        Spacer()
                        Text(KroutonL10n.tr("6,000 RPM CEILING"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(rpmColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background((isLight ? Color.white : Color.black).opacity(0.60))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    HStack {
                        Text(KroutonL10n.tr("Inner Hub (r = 24.0 mm • LBA 0)"))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Buffer Ribbon: \(Int(telemetry.bufferFillPercent))% Armed")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(useHarmony ? harmonyColor : primaryColor)
                        Spacer()
                        Text(KroutonL10n.tr("Outer Rim (r = 58.0 mm • Lead-Out)"))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 265, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [primaryColor.opacity(0.65), harmonyColor.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            floatingTelemetryChannelGrid(
                primaryColor: primaryColor,
                harmonyColor: harmonyColor,
                rpmColor: rpmColor,
                useHarmony: useHarmony
            )
        }
        .padding(18)
        .frame(minWidth: 740, idealWidth: 800, minHeight: 510, idealHeight: 570)
        .background(store.mainPanelTintOverlay)
        .background(Color.kroutonWindowSurface)
        .preferredColorScheme(store.resolvedColorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
    }

    @ViewBuilder
    private var phaseScopeHeaderAndTelemetryRow: some View {
        let drive = self.drive
        let isLight = (store.resolvedColorScheme == .light)
        let useHarmony = store.enableSecondaryAccentUITints
        let primaryColor = store.activeAccent
        let harmonyColor = store.uiSecondaryAccent
        // Color Theory Role Assignment across all 4 Modes:
        // - In Harmony Mode (Dark & Light): Speed = Primary, Motor RPM = Secondary Harmony!
        // - In Primary-Only Mode (Dark & Light): Speed = Primary, Motor RPM = Studio Gold/Ochre so the two curves contrast cleanly.
        let rpmColor: Color = useHarmony
            ? harmonyColor
            : (isLight ? Color(.displayP3, red: 0.74, green: 0.44, blue: 0.00) : Color(.displayP3, red: 1.00, green: 0.82, blue: 0.24))
        let pcavColor: Color = useHarmony
            ? harmonyColor.opacity(0.75)
            : (isLight ? Color.secondary.opacity(0.75) : Color.white.opacity(0.70))
        // Detailed Transport Clock Math (Elapsed, Remaining, Estimated Total)
        let progress = min(1.0, max(0.0, telemetry.progressFraction))
        let elapsedSec = max(0, telemetry.elapsedSeconds)
        let estimatedTotalSec: Int = {
            if elapsedSec > 0 && progress > 0.02 {
                return max(elapsedSec, Int((Double(elapsedSec) / progress).rounded()))
            }
            // Fallback theoretical total duration from sector count & current KB/s
            let totalKB = Double(max(1, telemetry.totalSectorsLBA)) * 2.0
            let rateKBs = max(1400.0, telemetry.currentSpeedKBs)
            return max(4, Int((totalKB / rateKBs).rounded()))
        }()
        let remainingSec = max(0, estimatedTotalSec - elapsedSec)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KroutonSliceArtworkView(
                    mediaType: drive?.mediaType ?? "CD-RW",
                    isMediaPresent: drive?.isMediaPresent ?? true,
                    isErasable: drive?.isMediaErasable ?? true,
                    isBlank: drive?.isMediaBlank ?? false
                )
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(telemetry.isActive ? primaryColor : harmonyColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: primaryColor.opacity(isLight ? 0.0 : 0.75), radius: 4)
                        Text("PHASE SCOPE — \(drive?.displayName ?? telemetry.driveName)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("• \(telemetry.phaseTitle)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(useHarmony ? harmonyColor : primaryColor)
                    }
                    Text("Firmware \(drive?.firmware ?? "1.0") • \(drive?.interconnect ?? "USB") Bus • \(drive?.bsdDeviceNode ?? "/dev/rdisk") • Media: \(drive?.statusBadgeText ?? "Ready")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    driveManager.runPhaseScopeTestSweep(for: driveID)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                        Text(KroutonL10n.tr("Run Calibration Sweep"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(primaryColor)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    onDockInline()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text(KroutonL10n.tr("Dock"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(harmonyColor.opacity(0.18))
                    .foregroundStyle(harmonyColor)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(harmonyColor.opacity(0.42), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Dock the floating Phase Scope window back into the inline burner card")
            }
            // =========================================================================
            // 2. DEDICATED TRANSPORT CHRONO & RADIAL TELEMETRY BAR (Above the Graph!)
            // =========================================================================
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: telemetry.isActive ? "clock.badge.checkmark.fill" : "clock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(primaryColor)
                    Text("ELAPSED")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(formatMMSS(elapsedSec))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(primaryColor)
                }
                Text("•").foregroundStyle(.secondary.opacity(0.5))
                HStack(spacing: 6) {
                    Text("REMAINING")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("~\(formatMMSS(remainingSec))")
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(useHarmony ? harmonyColor : .primary)
                }
                Text("•").foregroundStyle(.secondary.opacity(0.5))
                HStack(spacing: 6) {
                    Text("EST. TOTAL")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(formatMMSS(estimatedTotalSec))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                Spacer()
                // Compact In-Bar Trace Key (Speed vs. RPM vs. P-CAV)
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Capsule()
                            .fill(primaryColor)
                            .frame(width: 12, height: 3)
                        Text("Speed")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(primaryColor)
                    }
                    HStack(spacing: 5) {
                        Capsule()
                            .fill(rpmColor)
                            .frame(width: 12, height: 3)
                        Text("Motor RPM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(rpmColor)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(pcavColor).frame(width: 4, height: 2)
                        Rectangle().fill(pcavColor).frame(width: 4, height: 2)
                        Text("P-CAV")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("•").foregroundStyle(.secondary.opacity(0.5))
                Text(String(format: "r = %.2f / 58.00 mm (%.0f%%)", telemetry.radialMillimeters, progress * 100.0))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(useHarmony ? harmonyColor : primaryColor)
            }
        }
    }

    @ViewBuilder
    private var phaseScopeWaveformCanvasView: some View {
        let isLight = (store.resolvedColorScheme == .light)
        let useHarmony = store.enableSecondaryAccentUITints
        let primaryColor = store.activeAccent
        let harmonyColor = store.uiSecondaryAccent
        let presetID = store.selectedAccentIndex
        let effectiveID = presetID >= 0 ? presetID : store.multicolorPresetID(forTaskID: store.selectedTaskID, category: store.selectedCategory)
        let brightHarmony = useHarmony ? KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark) : primaryColor
        // Color Theory Role Assignment across all 4 Modes:
        // - In Harmony Mode (Dark & Light): Speed = Primary, Motor RPM = Secondary Harmony!
        // - In Primary-Only Mode (Dark & Light): Speed = Primary, Motor RPM = Studio Gold/Ochre so the two curves contrast cleanly.
        let rpmColor: Color = useHarmony
            ? harmonyColor
            : (isLight ? Color(.displayP3, red: 0.74, green: 0.44, blue: 0.00) : Color(.displayP3, red: 1.00, green: 0.82, blue: 0.24))
        let pcavColor: Color = useHarmony
            ? harmonyColor.opacity(0.75)
            : (isLight ? Color.secondary.opacity(0.75) : Color.white.opacity(0.70))
        let playheadColor: Color = useHarmony ? harmonyColor : primaryColor
        // Detailed Transport Clock Math (Elapsed, Remaining, Estimated Total)
        Canvas { context, size in
                    let cols = 16
                    let rows = 8
                    let majorGrid = (useHarmony ? harmonyColor : primaryColor).opacity(isLight ? 0.22 : 0.32)
                    let minorGrid = primaryColor.opacity(isLight ? 0.09 : 0.13)
                    // Single-batch Paths for Major & Minor Graticule (Minimizes CoreGraphics draw calls!)
                    var majorPath = Path()
                    var minorPath = Path()
                    for c in 0...cols {
                        let x = size.width * CGFloat(c) / CGFloat(cols)
                        if c % 4 == 0 {
                            majorPath.move(to: CGPoint(x: x, y: 0))
                            majorPath.addLine(to: CGPoint(x: x, y: size.height))
                        } else {
                            minorPath.move(to: CGPoint(x: x, y: 0))
                            minorPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                    for r in 0...rows {
                        let y = size.height * CGFloat(r) / CGFloat(rows)
                        if r % 2 == 0 {
                            majorPath.move(to: CGPoint(x: 0, y: y))
                            majorPath.addLine(to: CGPoint(x: size.width, y: y))
                        } else {
                            minorPath.move(to: CGPoint(x: 0, y: y))
                            minorPath.addLine(to: CGPoint(x: size.width, y: y))
                        }
                    }
                    // Center Optical Crosshair Sub-Ticks along Midline
                    let midY = size.height * 0.5
                    for t in stride(from: 0, through: 64, by: 2) {
                        let tx = size.width * CGFloat(t) / 64.0
                        majorPath.move(to: CGPoint(x: tx, y: midY - 2.5))
                        majorPath.addLine(to: CGPoint(x: tx, y: midY + 2.5))
                    }
                    context.stroke(minorPath, with: .color(minorGrid), lineWidth: 0.5)
                    context.stroke(majorPath, with: .color(majorGrid), lineWidth: 0.85)
                    let maxScaleX: Double = 24.0
                    let maxScaleRPM: Double = 6000.0
                    // Target P-CAV Reference Envelope (Dashed Curve)
                    var targetCurve = Path()
                    for step in 0...48 {
                        let frac = Double(step) / 48.0
                        let theoX = 4.2 + (11.8 * pow(frac, 0.78))
                        let x = size.width * CGFloat(frac)
                        let y = size.height * (1.0 - CGFloat(min(1.0, theoX / maxScaleX)))
                        if step == 0 {
                            targetCurve.move(to: CGPoint(x: x, y: y))
                        } else {
                            targetCurve.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(
                        targetCurve,
                        with: .color(pcavColor),
                        style: StrokeStyle(lineWidth: 1.4, dash: [6, 4])
                    )
                    let traces = buildSmoothScopeTraces(
                        telemetry: telemetry,
                        size: size,
                        maxScaleX: maxScaleX,
                        maxScaleRPM: maxScaleRPM
                    )
                    if telemetry.samples.count > 1 {
                        // 1. Hardware Buffer Liquid Ribbon + Meniscus Top Edge
                        context.fill(
                            traces.bufferArea,
                            with: .linearGradient(
                                Gradient(colors: [
                                    (isLight ? brightHarmony : harmonyColor).opacity(isLight ? 0.34 : 0.28),
                                    primaryColor.opacity(isLight ? 0.08 : 0.04)
                                ]),
                                startPoint: CGPoint(x: 0, y: size.height * 0.82),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )
                        context.stroke(traces.bufferTopEdge, with: .color(harmonyColor.opacity(0.65)), lineWidth: 1.15)
                        // 2. Motor RPM Area Curtain + Smooth Spline Trace (Uses Harmony Color in Harmony Mode!)
                        context.fill(
                            traces.rpmArea,
                            with: .linearGradient(
                                Gradient(colors: [rpmColor.opacity(isLight ? 0.16 : 0.20), rpmColor.opacity(0.01)]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )
                        if !isLight {
                            context.stroke(traces.rpmLine, with: .color(rpmColor.opacity(0.30)), lineWidth: 5.0)
                        }
                        context.stroke(traces.rpmLine, with: .color(rpmColor), lineWidth: 2.1)
                        // 3. Throughput Speed Area Curtain + Phosphor Bloom + Primary->Harmony Beam
                        context.fill(
                            traces.speedArea,
                            with: .linearGradient(
                                Gradient(colors: [
                                    primaryColor.opacity(isLight ? 0.26 : 0.38),
                                    harmonyColor.opacity(isLight ? 0.08 : 0.12),
                                    Color.clear
                                ]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )
                        if !isLight {
                            context.stroke(
                                traces.speedLine,
                                with: .linearGradient(
                                    Gradient(colors: [primaryColor.opacity(0.36), harmonyColor.opacity(0.32)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: size.width, y: 0)
                                ),
                                lineWidth: 7.0
                            )
                        }
                        context.stroke(
                            traces.speedLine,
                            with: .linearGradient(
                                Gradient(colors: [primaryColor, useHarmony ? harmonyColor : primaryColor]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: size.width, y: 0)
                            ),
                            lineWidth: 2.7
                        )
                        // 4. Radial LBA Playhead Laser Bar + Active Intersection Node
                        let lastPt = traces.lastPoint
                        var cursorPath = Path()
                        cursorPath.move(to: CGPoint(x: lastPt.x, y: 0))
                        cursorPath.addLine(to: CGPoint(x: lastPt.x, y: size.height))
                        if !isLight {
                            context.stroke(cursorPath, with: .color(playheadColor.opacity(0.30)), lineWidth: 4.5)
                        }
                        context.stroke(cursorPath, with: .color(playheadColor), lineWidth: 1.5)
                        let headRect = CGRect(x: lastPt.x - 4.0, y: lastPt.y - 4.0, width: 8.0, height: 8.0)
                        context.fill(Path(ellipseIn: headRect), with: .color(isLight ? primaryColor : .white))
                        context.stroke(Path(ellipseIn: headRect), with: .color(harmonyColor), lineWidth: 2.0)
                    }
                }
                .padding(8)
                // Subtle Corner Scale Telemetry Callouts Inside the Bezel
    }
}
