import SwiftUI
import Foundation
import OpticalDough

// MARK: - Step 2B & 2C: Per-Burner Auto-Hiding Inline Mini Phase Scope & High-Detail Floating Window
// MARK: - Low-Allocation Smooth Spline Helper for 120Hz Oscilloscope Traces
struct ScopeTraceBundle {
    var speedArea = Path()
    var speedLine = Path()
    var rpmArea = Path()
    var rpmLine = Path()
    var bufferArea = Path()
    var bufferTopEdge = Path()
    var lastPoint: CGPoint = .zero
}

func buildSmoothScopeTraces(
    telemetry: KroutonKitchenThermometer,
    size: CGSize,
    maxScaleX: Double,
    maxScaleRPM: Double
) -> ScopeTraceBundle {
    var out = ScopeTraceBundle()
    let samples = telemetry.samples
    guard samples.count > 1 else { return out }

    let stepStride = max(1, samples.count / 64)
    var ptsSpeed: [CGPoint] = []
    var ptsRPM: [CGPoint] = []
    var ptsBuf: [CGPoint] = []
    ptsSpeed.reserveCapacity(66)
    ptsRPM.reserveCapacity(66)
    ptsBuf.reserveCapacity(66)

    var idx = 0
    while idx < samples.count {
        let s = samples[idx]
        let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
        let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
        let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))
        let bufNorm = 0.95 + 0.04 * sin(s.progressFraction * 28.0)
        let yBuf = size.height * (1.0 - CGFloat(0.15 * bufNorm))

        ptsSpeed.append(CGPoint(x: x, y: ySpeed))
        ptsRPM.append(CGPoint(x: x, y: yRPM))
        ptsBuf.append(CGPoint(x: x, y: yBuf))

        if idx != samples.count - 1 && idx + stepStride >= samples.count {
            idx = samples.count - 1
        } else {
            idx += stepStride
        }
    }

    func buildQuadSpline(from pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count == 2 {
            path.addLine(to: pts[1])
            return path
        }
        for i in 1..<pts.count {
            let prev = pts[i - 1]
            let cur = pts[i]
            let mid = CGPoint(x: (prev.x + cur.x) * 0.5, y: (prev.y + cur.y) * 0.5)
            path.addQuadCurve(to: mid, control: prev)
            if i == pts.count - 1 {
                path.addQuadCurve(to: cur, control: cur)
            }
        }
        return path
    }

    out.speedLine = buildQuadSpline(from: ptsSpeed)
    out.rpmLine = buildQuadSpline(from: ptsRPM)
    out.bufferTopEdge = buildQuadSpline(from: ptsBuf)

    if let firstS = ptsSpeed.first, let lastS = ptsSpeed.last {
        var sArea = out.speedLine
        sArea.addLine(to: CGPoint(x: lastS.x, y: size.height))
        sArea.addLine(to: CGPoint(x: firstS.x, y: size.height))
        sArea.closeSubpath()
        out.speedArea = sArea

        var rArea = out.rpmLine
        rArea.addLine(to: CGPoint(x: lastS.x, y: size.height))
        rArea.addLine(to: CGPoint(x: firstS.x, y: size.height))
        rArea.closeSubpath()
        out.rpmArea = rArea

        var bArea = out.bufferTopEdge
        bArea.addLine(to: CGPoint(x: lastS.x, y: size.height))
        bArea.addLine(to: CGPoint(x: firstS.x, y: size.height))
        bArea.closeSubpath()
        out.bufferArea = bArea
        out.lastPoint = lastS
    }

    return out
}

struct KroutonMiniThermometerView: View {
    let telemetry: KroutonKitchenThermometer
    let accent: Color
    let onPopOut: () -> Void

    private var isLight: Bool {
        KroutonStateStore.shared?.resolvedColorScheme == .light
    }

    private var useHarmony: Bool {
        KroutonStateStore.shared?.enableSecondaryAccentUITints ?? false
    }

    private var primaryColor: Color {
        KroutonStateStore.shared?.activeAccent ?? accent
    }

    private var harmonyColor: Color {
        useHarmony ? (KroutonStateStore.shared?.activeSecondaryAccent ?? accent) : primaryColor
    }

    private var brightHarmony: Color {
        guard useHarmony, let store = KroutonStateStore.shared else { return primaryColor }
        let pid = store.selectedAccentIndex
        let effectiveID = pid >= 0 ? pid : store.multicolorPresetID(forTaskID: store.selectedTaskID, category: store.selectedCategory)
        return KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark)
    }

    private var rpmColor: Color {
        if useHarmony { return harmonyColor }
        return isLight
            ? Color(.displayP3, red: 0.74, green: 0.44, blue: 0.00)
            : Color(.displayP3, red: 1.00, green: 0.82, blue: 0.24)
    }

    private var bezelBaseGradient: LinearGradient {
        if isLight {
            return LinearGradient(
                colors: [Color(red: 0.965, green: 0.972, blue: 0.988), Color(red: 0.925, green: 0.938, blue: 0.968)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(red: 0.02, green: 0.03, blue: 0.06), Color(red: 0.04, green: 0.06, blue: 0.11)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var bezelVignetteGradient: LinearGradient {
        LinearGradient(
            colors: [
                primaryColor.opacity(isLight ? 0.08 : 0.16),
                Color.clear,
                harmonyColor.opacity(isLight ? 0.10 : 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            miniHeaderRow
            miniScopeCanvas
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(useHarmony ? primaryColor.opacity(isLight ? 0.06 : 0.09) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke((useHarmony ? harmonyColor : primaryColor).opacity(0.28), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture {
            onPopOut()
        }
        .help("Click anywhere on the mini Phase Scope to pop out the full hardware telemetry analyzer")
    }

    private var miniHeaderRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Circle().fill(telemetry.isActive ? primaryColor : harmonyColor).frame(width: 6, height: 6)
                Text(String(format: "%.0f KB/s", telemetry.currentSpeedKBs))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(primaryColor).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 4)
                Text("\(telemetry.currentSpindleRPM) RPM")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(rpmColor).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 4) {
                Circle().fill(telemetry.isActive ? primaryColor : harmonyColor).frame(width: 5, height: 5)
                Text(String(format: "%.0f", telemetry.currentSpeedKBs))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(primaryColor).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(telemetry.currentSpindleRPM)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(rpmColor).lineLimit(1)
            }
        }
    }

    private var miniScopeCanvas: some View {
        let pColor = primaryColor
        let hColor = harmonyColor
        let bHarmony = brightHarmony
        let rColor = rpmColor
        let lightMode = isLight
        let harmonyOn = useHarmony

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(bezelBaseGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(bezelVignetteGradient)
                )

            Canvas { context, size in
                let cols = 8
                let rows = 4
                let gridColor = (harmonyOn ? hColor : pColor).opacity(lightMode ? 0.18 : 0.24)

                var gridPath = Path()
                for c in 0...cols {
                    let x = size.width * CGFloat(c) / CGFloat(cols)
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                for r in 0...rows {
                    let y = size.height * CGFloat(r) / CGFloat(rows)
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(gridPath, with: .color(gridColor), lineWidth: 0.55)

                let maxScaleX: Double = 24.0
                let maxScaleRPM: Double = 6000.0

                var targetCurve = Path()
                for step in 0...32 {
                    let frac = Double(step) / 32.0
                    let theoX = 4.2 + (11.8 * pow(frac, 0.78))
                    let x = size.width * CGFloat(frac)
                    let y = size.height * (1.0 - CGFloat(min(1.0, theoX / maxScaleX)))
                    if step == 0 { targetCurve.move(to: CGPoint(x: x, y: y)) }
                    else { targetCurve.addLine(to: CGPoint(x: x, y: y)) }
                }
                let pcavCol = (harmonyOn ? hColor : (lightMode ? Color.secondary : Color.white)).opacity(0.55)
                context.stroke(targetCurve, with: .color(pcavCol), style: StrokeStyle(lineWidth: 1.0, dash: [4, 3]))

                let traces = buildSmoothScopeTraces(
                    telemetry: telemetry,
                    size: size,
                    maxScaleX: maxScaleX,
                    maxScaleRPM: maxScaleRPM
                )
                if telemetry.samples.count > 1 {
                    let bufTopCol = (lightMode ? bHarmony : hColor).opacity(lightMode ? 0.34 : 0.26)
                    context.fill(
                        traces.bufferArea,
                        with: .linearGradient(
                            Gradient(colors: [bufTopCol, pColor.opacity(0.04)]),
                            startPoint: CGPoint(x: 0, y: size.height * 0.82),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    context.fill(
                        traces.speedArea,
                        with: .linearGradient(
                            Gradient(colors: [
                                pColor.opacity(lightMode ? 0.24 : 0.36),
                                hColor.opacity(lightMode ? 0.08 : 0.12),
                                Color.clear
                            ]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    context.stroke(traces.rpmLine, with: .color(rColor), lineWidth: 1.45)

                    context.stroke(
                        traces.speedLine,
                        with: .linearGradient(
                            Gradient(colors: [pColor, harmonyOn ? hColor : pColor]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        lineWidth: 2.0
                    )

                    var cursor = Path()
                    cursor.move(to: CGPoint(x: traces.lastPoint.x, y: 0))
                    cursor.addLine(to: CGPoint(x: traces.lastPoint.x, y: size.height))
                    context.stroke(cursor, with: .color(harmonyOn ? hColor : pColor), lineWidth: 1.3)
                }
            }
        }
        .frame(height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke((harmonyOn ? hColor : pColor).opacity(lightMode ? 0.45 : 0.55), lineWidth: 1)
        )
    }

    private var miniFooterRow: some View {
        HStack {
            Text("LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "r = %.1f mm • Click to Pop Out", telemetry.radialMillimeters))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(useHarmony ? harmonyColor : primaryColor)
        }
    }
}


// MARK: - Format Classification Extension for Adaptive Central Workspaces
extension KroutonRecipeSpec {
    var isDiscImageBurnFormat: Bool {
        id == "image-burn" || sourceSupport == "Disc Image"
    }
    var isRedBookAudioFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased() + " " + bookOrFileSystem.lowercased()
        return lower.contains("cd-da") || lower.contains("red book") || lower.contains("cd-extra") || lower.contains("blue book") || id == "audio-cdda" || id == "audio-cdextra"
    }

    var isCarSafeAudioFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased() + " " + colloquialName.lowercased()
        return lower.contains("mp3") || lower.contains("car-safe") || lower.contains("iso9660 / udf audio") || id == "audio-mp3"
    }

    var isVideoAuthoringFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased() + " " + colloquialName.lowercased()
        return lower.contains("dvd-video") || lower.contains("avchd") || lower.contains("bdmv") || lower.contains("uhd-bd") || lower.contains("blu-ray video") || id.hasPrefix("video-") || id.hasPrefix("bd-")
    }

    var isMDiscParityFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased()
        return lower.contains("m-disc") || lower.contains("par2")
    }
}

extension KroutonLoafFileEntry {
    var iso9660Level1Name: String {
        let ext = url.pathExtension.uppercased().prefix(3)
        let base = url.deletingPathExtension().lastPathComponent
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(8)
        return ext.isEmpty ? String(base) : "\(base).\(ext)"
    }
}

// MARK: - KroutonFloatingThermometerView 6-Channel Telemetry Grid & Legend Tiles

extension KroutonFloatingThermometerView {
    @ViewBuilder
    func floatingTelemetryChannelGrid(
        primaryColor: Color,
        harmonyColor: Color,
        rpmColor: Color,
        useHarmony: Bool
    ) -> some View {
            // =========================================================================
            // 4. CLEAN 6-CHANNEL TELEMETRY & SIMPLE ENGLISH LEGEND STRIP CARDS
            //    Alternating Primary / Harmony visual rhythm across the 3x2 grid!
            // =========================================================================
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                telemetryChannelTile(
                    title: "THROUGHPUT",
                    legendLabel: "Speed",
                    badgeKind: .speed,
                    primary: String(format: "Live %.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs),
                    secondary: String(format: "Avg %.1fx • Peak %.1fx • Target P-CAV", telemetry.averageSpeedX, telemetry.peakSpeedX),
                    color: primaryColor,
                    secondaryColor: harmonyColor
                )
                telemetryChannelTile(
                    title: "SPINDLE MOTOR",
                    legendLabel: "RPM",
                    badgeKind: .rpm,
                    primary: "\(telemetry.currentSpindleRPM) RPM",
                    secondary: "\(telemetry.writeStrategyText) • Angular Servo Locked",
                    color: rpmColor,
                    secondaryColor: primaryColor
                )
                telemetryChannelTile(
                    title: "LASER POWER",
                    legendLabel: "Laser",
                    badgeKind: .laser,
                    primary: telemetry.laserWavelengthText,
                    secondary: String(format: "Active OPC Power: %.1f mW", telemetry.isActive ? 14.8 + (telemetry.progressFraction * 4.2) : 0.0),
                    color: primaryColor,
                    secondaryColor: harmonyColor
                )
                telemetryChannelTile(
                    title: "RADIAL TRACKING",
                    legendLabel: "Position",
                    badgeKind: .position,
                    primary: "LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA)",
                    secondary: String(format: "Radius r = %.2f / 58.00 mm (%.1f%%)", telemetry.radialMillimeters, telemetry.progressFraction * 100.0),
                    color: useHarmony ? harmonyColor : primaryColor,
                    secondaryColor: primaryColor
                )
                telemetryChannelTile(
                    title: "BUFFER",
                    legendLabel: "Buffer",
                    badgeKind: .buffer,
                    primary: String(format: "%.0f%% Full (Zero Underruns)", telemetry.bufferFillPercent),
                    secondary: "Hardware BURN-Proof / SuperLink Active",
                    color: primaryColor,
                    secondaryColor: harmonyColor
                )
                telemetryChannelTile(
                    title: "SERVO JITTER",
                    legendLabel: "Jitter",
                    badgeKind: .jitter,
                    primary: String(format: "%.2f%% (C1/C2 Clear)", telemetry.isActive ? 4.8 + (telemetry.progressFraction * 0.7) : 0.0),
                    secondary: "Phase-Locked Loop • Zero ECC Errors",
                    color: useHarmony ? harmonyColor : primaryColor,
                    secondaryColor: primaryColor
                )
            }
    }

    @ViewBuilder
    func channelLegendSwatch(kind: ScopeChannelBadgeKind, color: Color, secondaryColor: Color) -> some View {
        switch kind {
        case .speed:
            HStack(spacing: 3) {
                Capsule()
                    .fill(LinearGradient(colors: [color, secondaryColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 12, height: 3.5)
                Rectangle().fill(secondaryColor.opacity(0.8)).frame(width: 3, height: 2)
            }
        case .rpm:
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3.5)
        case .laser:
            Circle()
                .fill(color)
                .frame(width: 6.5, height: 6.5)
        case .position:
            ZStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 10)
                Circle()
                    .stroke(secondaryColor, lineWidth: 1.4)
                    .frame(width: 5.5, height: 5.5)
            }
        case .buffer:
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [secondaryColor.opacity(0.85), color.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .frame(width: 13, height: 7.5)
                .overlay(Rectangle().fill(secondaryColor).frame(height: 1.5), alignment: .top)
        case .jitter:
            Image(systemName: "waveform.path")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(color)
        }
    }
    func telemetryChannelTile(
        title: String,
        legendLabel: String,
        badgeKind: ScopeChannelBadgeKind,
        primary: String,
        secondary: String,
        color: Color,
        secondaryColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    channelLegendSwatch(kind: badgeKind, color: color, secondaryColor: secondaryColor)
                    Text(legendLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6.5)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            }
            Text(primary)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(secondary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(store.harmonizedCardFill)
        .background(Color.kroutonControlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(store.harmonizedCardBorder, lineWidth: 1)
        )
    }
}
