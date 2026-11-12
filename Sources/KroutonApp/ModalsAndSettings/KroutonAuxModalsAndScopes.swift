//
//  KroutonAuxModalsAndScopes.swift
//  Krouton — Optical Media Mastering Studio
//
//  Standalone Inspector Sheets, Hardware Scopes, Burn Progress Modals, and Support Views.
//

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
                    .fill(Color.kroutonWindowSurface)
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
        .background(Color.kroutonWindowSurface)
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
                colors: [accent.opacity(0.12), Color.kroutonControlSurface],
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
        .background(Color.kroutonControlSurface)
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
                .background(Color.kroutonControlSurface)
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
                KroutonOSDesktopBridge.revealFolderInFinder(path: vol.mountPath)
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
        .background(Color.kroutonControlSurface)
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
        .background(Color.kroutonControlSurface)
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
        .background(Color.kroutonControlSurface)
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
        .background(Color.kroutonControlSurface)
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
            .background(Color.kroutonControlSurface)
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
                    KroutonOSDesktopBridge.copyTextToClipboard("\(report.title)\n\(report.summary)\nDrive: \(report.driveModel) (FW \(report.firmwareRevision))\nMedia: \(report.mediaFormattedName)\nSectors: \(report.sectorsWrittenLBA) LBA\nAdvice: \(report.diagnosticAdvice)")
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
        .background(Color.kroutonWindowSurface)
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
