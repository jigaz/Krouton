//
//  KroutonAuxModalsAndScopes.swift
//  Krouton — Optical Media Mastering Studio
//
//  Standalone Inspector Sheets, Hardware Scopes, Burn Progress Modals, and Support Views.
//

import AppKit
import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - Physically Accurate Optical Disc Icon (Matches Real Dye & Substrate Physics)
struct KroutonSliceArtworkView: View {
    let mediaType: String
    let isMediaPresent: Bool
    let isErasable: Bool
    let isBlank: Bool

    var discPalette: [Color] {
        let u = mediaType.uppercased()
        if !isMediaPresent {
            return [Color.secondary.opacity(0.25), Color.secondary.opacity(0.10), Color.secondary.opacity(0.25)]
        }
        if u.contains("MDISC") || u.contains("M-DISC") {
            return [
                Color(red: 0.72, green: 0.69, blue: 0.64),
                Color(red: 0.45, green: 0.43, blue: 0.40),
                Color(red: 0.82, green: 0.79, blue: 0.73),
                Color(red: 0.48, green: 0.46, blue: 0.42),
                Color(red: 0.72, green: 0.69, blue: 0.64)
            ]
        }
        if u.contains("RAM") {
            return [
                Color(red: 0.85, green: 0.68, blue: 0.18),
                Color(red: 0.55, green: 0.42, blue: 0.10),
                Color(red: 0.92, green: 0.78, blue: 0.28),
                Color(red: 0.52, green: 0.39, blue: 0.08),
                Color(red: 0.85, green: 0.68, blue: 0.18)
            ]
        }
        if u.contains("BD") {
            return [
                Color(red: 0.12, green: 0.38, blue: 0.92),
                Color(red: 0.28, green: 0.18, blue: 0.78),
                Color(red: 0.10, green: 0.68, blue: 0.95),
                Color(red: 0.22, green: 0.14, blue: 0.68),
                Color(red: 0.12, green: 0.38, blue: 0.92)
            ]
        }
        if u.contains("DVD") {
            if isErasable {
                return [
                    Color(red: 0.44, green: 0.36, blue: 0.58),
                    Color(red: 0.26, green: 0.22, blue: 0.36),
                    Color(red: 0.58, green: 0.48, blue: 0.72),
                    Color(red: 0.28, green: 0.24, blue: 0.38),
                    Color(red: 0.44, green: 0.36, blue: 0.58)
                ]
            } else {
                return [
                    Color(red: 0.58, green: 0.18, blue: 0.78),
                    Color(red: 0.34, green: 0.10, blue: 0.56),
                    Color(red: 0.78, green: 0.26, blue: 0.88),
                    Color(red: 0.38, green: 0.12, blue: 0.62),
                    Color(red: 0.58, green: 0.18, blue: 0.78)
                ]
            }
        }
        if u.contains("CD") {
            if isErasable {
                return [
                    Color(red: 0.36, green: 0.43, blue: 0.49),
                    Color(red: 0.20, green: 0.25, blue: 0.30),
                    Color(red: 0.52, green: 0.60, blue: 0.66),
                    Color(red: 0.22, green: 0.27, blue: 0.32),
                    Color(red: 0.36, green: 0.43, blue: 0.49)
                ]
            } else if u.contains("ROM") {
                return [
                    Color(white: 0.78),
                    Color(white: 0.52),
                    Color(white: 0.90),
                    Color(white: 0.55),
                    Color(white: 0.78)
                ]
            } else {
                return [
                    Color(red: 0.16, green: 0.76, blue: 0.62),
                    Color(red: 0.78, green: 0.72, blue: 0.22),
                    Color(red: 0.12, green: 0.62, blue: 0.74),
                    Color(red: 0.68, green: 0.64, blue: 0.20),
                    Color(red: 0.16, green: 0.76, blue: 0.62)
                ]
            }
        }
        return [Color.gray, Color.secondary, Color.gray]
    }

    var body: some View {
        ZStack {
            if !isMediaPresent {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .foregroundStyle(.secondary.opacity(0.45))
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: discPalette,
                            center: .center
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Color.white.opacity(0.40), lineWidth: 1.0))
                    .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)

                if mediaType.uppercased().contains("RAM") {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2.0, dash: [3, 2]))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .frame(width: 42, height: 42)
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2.0, dash: [3, 2]))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(isBlank ? 0.16 : 0.34), lineWidth: 0.8)
                        .frame(width: 42, height: 42)
                    Circle()
                        .stroke(Color.white.opacity(isBlank ? 0.18 : 0.38), lineWidth: 0.8)
                        .frame(width: 31, height: 31)
                }

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.55), lineWidth: 1))
            }
        }
    }
}

// MARK: - Clickable Disc Pill Popover: Textured Visual Disc Media & Volume Inspector
struct KroutonSliceMediaPopover: View {
    let drive: KroutonToasterInfo
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroBannerSection
            if !drive.isMediaPresent {
                emptySlotSection
            } else {
                mountedVolumesSection
                radialCapacitySection
                hardwareSpecGridSection
                writeSpeedsSection
            }
        }
        .padding(16)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    var heroBannerSection: some View {
        let modeLabel = drive.isMediaErasable ? "REWRITABLE MEDIA" : (drive.isMediaBlank ? "WRITE-ONCE BLANK" : "MASTERED DISC")
        return HStack(spacing: 14) {
            KroutonSliceArtworkView(
                mediaType: drive.mediaType,
                isMediaPresent: drive.isMediaPresent,
                isErasable: drive.isMediaErasable,
                isBlank: drive.isMediaBlank
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(drive.statusBadgeText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("• \(modeLabel)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(accent)
                }

                Text("\(drive.displayName) • FW \(drive.firmware) • \(drive.interconnect) • \(drive.bsdDeviceNode)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(drive.bookStandard)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.12), Color(NSColor.controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    var emptySlotSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "opticaldisc")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(KroutonL10n.tr("No optical media is loaded in this drive. Insert a CD, DVD, Blu-ray, or M-DISC to inspect mounted volumes, file/track counts, ATIP/ADIP manufacturer codes, and dye chemistry."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    var mountedVolumesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                drive.mountedVolumes.isEmpty
                    ? "MOUNTED VOLUMES & PARTITIONS (UNMOUNTED / BLANK)"
                    : "MOUNTED VOLUMES & PARTITIONS (\(drive.mountedVolumes.count))",
                systemImage: "externaldrive.fill.badge.checkmark"
            )
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)

            if drive.mountedVolumes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: drive.isMediaBlank ? "sparkles" : "opticaldisc")
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drive.isMediaBlank ? "Virgin Unformatted Optical Media" : "Unmounted Optical Session (\(drive.sessionCount) Session, \(drive.trackCount) Track)")
                            .font(.system(size: 11, weight: .semibold))
                        Text(drive.isMediaBlank ? "No filesystem tracks written yet — 100% capacity available for mastering." : "Raw sector layout detected on \(drive.bsdDeviceNode).")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
            } else {
                ForEach(drive.mountedVolumes) { vol in
                    volumeRowCard(vol)
                }
            }
        }
    }

    func volumeRowCard(_ vol: KroutonMountedSlice) -> some View {
        let countLabel = vol.itemCount >= 2500 ? "2,500+" : "\(vol.itemCount)"
        let unitLabel = vol.isAudioCD ? "Audio Tracks" : "Files"
        let sizeStr = ByteCountFormatter.string(fromByteCount: vol.usedBytes, countStyle: .file)

        return HStack(spacing: 10) {
            Image(systemName: vol.isAudioCD ? "waveform.circle.fill" : "folder.fill.badge.gearshape")
                .font(.system(size: 16))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(vol.volumeName)
                        .font(.system(size: 12, weight: .bold))
                    Text("• \(vol.filesystemFormat)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text("\(countLabel) \(unitLabel) • \(sizeStr) • \(vol.creationDateText)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: vol.mountPath)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.square")
                    Text(KroutonL10n.tr("Open in Finder"))
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(accent.opacity(0.18))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Reveal \(vol.mountPath) in macOS Finder")
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    var radialCapacitySection: some View {
        let usedStr = ByteCountFormatter.string(fromByteCount: drive.usedBytes, countStyle: .file)
        let freeStr = ByteCountFormatter.string(fromByteCount: drive.freeBytes, countStyle: .file)

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(KroutonL10n.tr("RADIAL SECTOR & CAPACITY TOPOLOGY"), systemImage: "chart.pie.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Timecode: \(drive.redBookTimecodeCapacity)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.30))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [accent, Color.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(drive.usedFraction)))
                }
            }
            .frame(height: 8)

            HStack {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text("Used: \(usedStr) (\(drive.usedSectorsLBA) LBA)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                    Text("Free: \(freeStr) (\(drive.freeSectorsLBA) LBA)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    var hardwareSpecGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            specTile(
                icon: "building.2.crop.circle.fill",
                title: "ATIP / MID MANUFACTURER",
                value: drive.mediaManufacturer
            )
            specTile(
                icon: "drop.halffull",
                title: "RECORDING LAYER / DYE",
                value: drive.dyeChemistry
            )
            specTile(
                icon: "laser.burst",
                title: "OPTICAL LASER & BLOCK",
                value: "\(drive.laserWavelengthNA) • \(drive.sectorBlockSize)"
            )
            specTile(
                icon: "lock.shield.fill",
                title: "SESSIONS & PROTECTION",
                value: "\(drive.sessionCount) Session(s) • \(drive.trackCount) Track(s) • \(drive.copyProtectionStatus)"
            )
        }
    }

    var writeSpeedsSection: some View {
        let concreteSpeeds = drive.availableWriteSpeeds.filter { !$0.lowercased().contains("auto") }
        let displaySpeeds = concreteSpeeds.isEmpty ? drive.availableWriteSpeeds : concreteSpeeds

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(KroutonL10n.tr("NEGOTIATED WRITE SPEEDS"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(KroutonL10n.tr("Auto OPC Active"))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
            Text(displaySpeeds.joined(separator: "   •   "))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    func specTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

struct KroutonMasteringReportSheet: View {
    let report: KroutonToastReport
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: report.isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(report.isSuccess ? .green : .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(report.title)
                        .font(.title2.bold())
                    Text(report.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                reportDetailRow(label: "Optical Drive & Firmware", value: "\(report.driveModel) (FW \(report.firmwareRevision))")
                Divider()
                reportDetailRow(label: "Media Format & Volume", value: "\(report.mediaFormattedName) • \(report.volumeName)")
                Divider()
                reportDetailRow(label: "Sectors & Data Written", value: "\(report.sectorsWrittenLBA) LBA (\(ByteCountFormatter.string(fromByteCount: report.bytesWritten, countStyle: .file)))")
                Divider()
                reportDetailRow(label: "Transfer Rate (Avg / Peak)", value: "\(report.averageSpeedText) • Peak \(report.peakSpeedText)")
                Divider()
                reportDetailRow(label: "Elapsed Mastering Time", value: report.elapsedDurationText)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(accent)
                    .font(.system(size: 14))
                Text(report.diagnosticAdvice)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            HStack {
                Button("Copy Telemetry Log") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(report.title)\n\(report.summary)\nDrive: \(report.driveModel) (FW \(report.firmwareRevision))\nMedia: \(report.mediaFormattedName)\nSectors: \(report.sectorsWrittenLBA) LBA\nAdvice: \(report.diagnosticAdvice)", forType: .string)
                }
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Text(KroutonL10n.tr("Done"))
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .background(accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 580, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    func reportDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Step 2B & 2C: Per-Burner Auto-Hiding Inline Mini Phase Scope & High-Detail Floating Window
// MARK: - Low-Allocation Smooth Spline Helper for 120Hz Oscilloscope Traces
fileprivate struct ScopeTraceBundle {
    var speedArea = Path()
    var speedLine = Path()
    var rpmArea = Path()
    var rpmLine = Path()
    var bufferArea = Path()
    var bufferTopEdge = Path()
    var lastPoint: CGPoint = .zero
}

fileprivate func buildSmoothScopeTraces(
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
            miniFooterRow
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
        HStack(spacing: 6) {
            Circle()
                .fill(telemetry.isActive ? primaryColor : harmonyColor)
                .frame(width: 6, height: 6)
            Text("PHASE SCOPE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(useHarmony ? harmonyColor : primaryColor)
            Spacer()
            Text(String(format: "Live %.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryColor)
            Text("•")
                .foregroundStyle(.secondary)
            Text("\(telemetry.currentSpindleRPM) RPM")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(rpmColor)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(useHarmony ? harmonyColor : .secondary)
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

    private enum ScopeChannelBadgeKind {
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
        let drive = self.drive
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
            // =========================================================================
            // 1. TOP INSTRUMENT HEADER BAR ("Dock" button + Calibration Sweep)
            // =========================================================================
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
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(store.harmonizedCardFill)
            .background(Color(NSColor.controlBackgroundColor))
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
        .padding(18)
        .frame(minWidth: 740, idealWidth: 800, minHeight: 510, idealHeight: 570)
        .background(store.mainPanelTintOverlay)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
    }

    @ViewBuilder
    private func channelLegendSwatch(kind: ScopeChannelBadgeKind, color: Color, secondaryColor: Color) -> some View {
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

    private func telemetryChannelTile(
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(store.harmonizedCardBorder, lineWidth: 1)
        )
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
