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
struct OpticalDiscArtworkView: View {
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
struct DiscMediaInspectorPopover: View {
    let drive: OpticalDriveDevice
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
            OpticalDiscArtworkView(
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

    func volumeRowCard(_ vol: MountedVolumePartition) -> some View {
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
    let report: BurnCompletionReport
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
struct InlineMiniPhaseScopeView: View {
    let telemetry: DrivePhaseScopeTelemetry
    let accent: Color
    let onPopOut: () -> Void

    var body: some View {
        Button {
            onPopOut()
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(KroutonL10n.tr("PHASE SCOPE"))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(String(format: "%.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Text(KroutonL10n.tr("•"))
                        .foregroundStyle(.secondary)
                    Text("\(telemetry.currentSpindleRPM) RPM")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.yellow)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.02, green: 0.03, blue: 0.07))

                    Canvas { context, size in
                        let cols = 8
                        let rows = 4
                        let gridColor = Color(red: 0.08, green: 0.18, blue: 0.72).opacity(0.75)

                        for c in 0...cols {
                            let x = size.width * CGFloat(c) / CGFloat(cols)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(p, with: .color(gridColor), lineWidth: 0.6)
                        }
                        for r in 0...rows {
                            let y = size.height * CGFloat(r) / CGFloat(rows)
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(p, with: .color(gridColor), lineWidth: 0.6)
                        }

                        let samples = telemetry.samples
                        if samples.count > 1 {
                            let maxScaleX: Double = 24.0
                            let maxScaleRPM: Double = 6000.0

                            var speedArea = Path()
                            var speedPath = Path()
                            var rpmPath = Path()

                            for (idx, s) in samples.enumerated() {
                                let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
                                let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
                                let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))

                                if idx == 0 {
                                    speedArea.move(to: CGPoint(x: x, y: size.height))
                                    speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                    speedPath.move(to: CGPoint(x: x, y: ySpeed))
                                    rpmPath.move(to: CGPoint(x: x, y: yRPM))
                                } else {
                                    speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                    speedPath.addLine(to: CGPoint(x: x, y: ySpeed))
                                    rpmPath.addLine(to: CGPoint(x: x, y: yRPM))
                                }
                            }

                            if let last = samples.last {
                                let lastX = size.width * CGFloat(min(1.0, max(0.0, last.progressFraction)))
                                speedArea.addLine(to: CGPoint(x: lastX, y: size.height))
                                speedArea.closeSubpath()

                                context.fill(
                                    speedArea,
                                    with: .linearGradient(
                                        Gradient(colors: [Color.green.opacity(0.32), Color.green.opacity(0.02)]),
                                        startPoint: CGPoint(x: 0, y: 0),
                                        endPoint: CGPoint(x: 0, y: size.height)
                                    )
                                )

                                context.stroke(rpmPath, with: .color(.yellow), lineWidth: 1.3)
                                context.stroke(speedPath, with: .color(.green), lineWidth: 1.8)

                                var cursorPath = Path()
                                cursorPath.move(to: CGPoint(x: lastX, y: 0))
                                cursorPath.addLine(to: CGPoint(x: lastX, y: size.height))
                                context.stroke(cursorPath, with: .color(.red), lineWidth: 1.2)
                            }
                        }
                    }
                    .padding(3)
                }
                .frame(height: 68)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.45), lineWidth: 1))

                HStack {
                    Text("LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "r = %.1f mm • Click to Pop Out", telemetry.radialMillimeters))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Click to pop out the high-detail Floating Phase Scope window for this burner")
    }
}

struct FloatingPhaseScopeWindowView: View {
    let driveID: String
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: DriveManager
    let onDockInline: () -> Void

    var drive: OpticalDriveDevice? {
        driveManager.driveForID(driveID)
    }

    var telemetry: DrivePhaseScopeTelemetry {
        driveManager.telemetryForDrive(driveID) ?? DrivePhaseScopeTelemetry(
            id: driveID,
            driveName: drive?.displayName ?? "Optical Burner"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                OpticalDiscArtworkView(
                    mediaType: drive?.mediaType ?? "CD-RW",
                    isMediaPresent: drive?.isMediaPresent ?? true,
                    isErasable: drive?.isMediaErasable ?? true,
                    isBlank: drive?.isMediaBlank ?? false
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(telemetry.isActive ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text("PHASE SCOPE — \(drive?.displayName ?? telemetry.driveName)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("• \(telemetry.phaseTitle)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
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
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.18))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onDockInline()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text(KroutonL10n.tr("Dock Inline"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent.opacity(0.18))
                    .foregroundStyle(store.activeAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Close floating window and return the Phase Scope to the inline burner card")
            }

            HStack(spacing: 18) {
                legendItem(color: store.enableSecondaryAccentUITints ? store.activeAccent : .green, label: "Actual Speed (X / KB/s)", isDashed: false)
                legendItem(color: store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : .cyan, label: "Target P-CAV Envelope", isDashed: true)
                legendItem(color: .yellow, label: "Spindle Velocity (RPM)", isDashed: false)
                legendItem(color: .purple, label: "Hardware Buffer Fill (%)", isDashed: false)
                legendItem(color: .red, label: "Radial LBA Playhead (mm)", isDashed: false)
                Spacer()
                Text(String(format: "Radial Position: r = %.2f mm / 58.00 mm", telemetry.radialMillimeters))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.cyan)
            }
            .padding(.horizontal, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.01, green: 0.02, blue: 0.05), Color(red: 0.03, green: 0.05, blue: 0.11)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Canvas { context, size in
                    let cols = 16
                    let rows = 8
                    let majorGrid = Color(red: 0.10, green: 0.22, blue: 0.78).opacity(0.65)
                    let minorGrid = Color(red: 0.08, green: 0.16, blue: 0.55).opacity(0.32)

                    for c in 0...cols {
                        let x = size.width * CGFloat(c) / CGFloat(cols)
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(p, with: .color(c % 4 == 0 ? majorGrid : minorGrid), lineWidth: c % 4 == 0 ? 0.9 : 0.5)
                    }
                    for r in 0...rows {
                        let y = size.height * CGFloat(r) / CGFloat(rows)
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(p, with: .color(r % 2 == 0 ? majorGrid : minorGrid), lineWidth: r % 2 == 0 ? 0.9 : 0.5)
                    }

                    let maxScaleX: Double = 24.0
                    let maxScaleRPM: Double = 6000.0

                    var targetCurve = Path()
                    for step in 0...60 {
                        let frac = Double(step) / 60.0
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
                        with: .color(Color.cyan.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 1.4, dash: [6, 4])
                    )

                    let samples = telemetry.samples
                    if samples.count > 1 {
                        var speedArea = Path()
                        var speedLine = Path()
                        var rpmArea = Path()
                        var rpmLine = Path()
                        var bufferArea = Path()

                        for (idx, s) in samples.enumerated() {
                            let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
                            let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
                            let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))
                            let bufNorm = 0.95 + 0.04 * sin(s.progressFraction * 28.0)
                            let yBuf = size.height * (1.0 - CGFloat(0.16 * bufNorm))

                            if idx == 0 {
                                speedArea.move(to: CGPoint(x: x, y: size.height))
                                speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                speedLine.move(to: CGPoint(x: x, y: ySpeed))

                                rpmArea.move(to: CGPoint(x: x, y: size.height))
                                rpmArea.addLine(to: CGPoint(x: x, y: yRPM))
                                rpmLine.move(to: CGPoint(x: x, y: yRPM))

                                bufferArea.move(to: CGPoint(x: x, y: size.height))
                                bufferArea.addLine(to: CGPoint(x: x, y: yBuf))
                            } else {
                                speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                speedLine.addLine(to: CGPoint(x: x, y: ySpeed))

                                rpmArea.addLine(to: CGPoint(x: x, y: yRPM))
                                rpmLine.addLine(to: CGPoint(x: x, y: yRPM))

                                bufferArea.addLine(to: CGPoint(x: x, y: yBuf))
                            }
                        }

                        if let last = samples.last {
                            let lastX = size.width * CGFloat(min(1.0, max(0.0, last.progressFraction)))
                            speedArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            speedArea.closeSubpath()

                            rpmArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            rpmArea.closeSubpath()

                            bufferArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            bufferArea.closeSubpath()

                            context.fill(
                                bufferArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.purple.opacity(0.30), Color.purple.opacity(0.05)]),
                                    startPoint: CGPoint(x: 0, y: size.height * 0.82),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.fill(
                                rpmArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.yellow.opacity(0.16), Color.yellow.opacity(0.01)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.fill(
                                speedArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.green.opacity(0.38), Color.green.opacity(0.02)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.stroke(rpmLine, with: .color(.yellow), lineWidth: 1.8)
                            context.stroke(speedLine, with: .color(.green), lineWidth: 2.4)

                            var cursorPath = Path()
                            cursorPath.move(to: CGPoint(x: lastX, y: 0))
                            cursorPath.addLine(to: CGPoint(x: lastX, y: size.height))
                            context.stroke(cursorPath, with: .color(.red), lineWidth: 1.6)
                        }
                    }
                }
                .padding(8)

                VStack {
                    HStack {
                        Text(KroutonL10n.tr("24.0x (Max Scale)"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.85))
                        Spacer()
                        Text(KroutonL10n.tr("6,000 RPM"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.yellow.opacity(0.85))
                    }
                    Spacer()
                    HStack {
                        Text(KroutonL10n.tr("Inner Hub (r = 24.0 mm • LBA 0)"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Hardware Buffer Ribbon: \(Int(telemetry.bufferFillPercent))% Armed")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(KroutonL10n.tr("Outer Rim (r = 58.0 mm • Lead-Out)"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 250, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.50), lineWidth: 1.2))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                telemetryTile(
                    title: "LIVE / PEAK THROUGHPUT",
                    primary: String(format: "%.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs),
                    secondary: String(format: "Avg %.1fx • Peak %.1fx", telemetry.averageSpeedX, telemetry.peakSpeedX),
                    color: .green
                )
                telemetryTile(
                    title: "SPINDLE MOTOR & STRATEGY",
                    primary: "\(telemetry.currentSpindleRPM) RPM",
                    secondary: "\(telemetry.writeStrategyText) • Angular Servo Locked",
                    color: .yellow
                )
                telemetryTile(
                    title: "LASER POWER & WAVELENGTH",
                    primary: telemetry.laserWavelengthText,
                    secondary: String(format: "Active OPC Power: %.1f mW", telemetry.isActive ? 14.8 + (telemetry.progressFraction * 4.2) : 0.0),
                    color: .orange
                )
                telemetryTile(
                    title: "RADIAL TRACKING & LBA",
                    primary: "LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA)",
                    secondary: String(format: "Radius r = %.2f mm (%.1f%%)", telemetry.radialMillimeters, telemetry.progressFraction * 100.0),
                    color: .cyan
                )
                telemetryTile(
                    title: "DRIVE FIFO RING BUFFER",
                    primary: String(format: "%.0f%% Full (Zero Underruns)", telemetry.bufferFillPercent),
                    secondary: "Hardware BURN-Proof / SuperLink Active",
                    color: .purple
                )
                telemetryTile(
                    title: "SERVO JITTER & ELAPSED",
                    primary: String(format: "Jitter: %.2f%% (C1/C2 Clear)", telemetry.isActive ? 4.8 + (telemetry.progressFraction * 0.7) : 0.0),
                    secondary: String(format: "Elapsed Time: %02d:%02d", telemetry.elapsedSeconds / 60, telemetry.elapsedSeconds % 60),
                    color: .primary
                )
            }
        }
        .padding(18)
        .frame(minWidth: 740, idealWidth: 780, minHeight: 490, idealHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
    }

    func legendItem(color: Color, label: String, isDashed: Bool) -> some View {
        HStack(spacing: 6) {
            if isDashed {
                HStack(spacing: 2) {
                    Rectangle().fill(color).frame(width: 6, height: 2.5)
                    Rectangle().fill(color).frame(width: 6, height: 2.5)
                }
            } else {
                Rectangle().fill(color).frame(width: 14, height: 2.5)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    func telemetryTile(title: String, primary: String, secondary: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Format Classification Extension for Adaptive Central Workspaces
extension DiscFormatSpec {
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

extension StagedFileEntry {
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
