import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - KroutonAuxModalsAndScopes

struct KroutonDiscArtworkView: View {
    let mediaType: String
    let isMediaPresent: Bool
    let isErasable: Bool
    let isBlank: Bool

    var discPalette: [Color] {
        let u = mediaType.uppercased()
        if !isMediaPresent { return [Color.secondary.opacity(0.25), Color.secondary.opacity(0.10), Color.secondary.opacity(0.25)] }
        if u.contains("MDISC") || u.contains("M-DISC") { return [Color(white: 0.72), Color(white: 0.44), Color(white: 0.80), Color(white: 0.46), Color(white: 0.72)] }
        if u.contains("RAM") { return [.yellow, .orange, .yellow, .brown, .yellow] }
        if u.contains("BD") { return [.blue, .indigo, .cyan, .indigo, .blue] }
        if u.contains("DVD") { return isErasable ? [.purple.opacity(0.7), .indigo, .purple, .indigo, .purple.opacity(0.7)] : [.purple, .indigo, .pink.opacity(0.8), .indigo, .purple] }
        if isErasable { return [.teal.opacity(0.6), .gray, .cyan.opacity(0.6), .gray, .teal.opacity(0.6)] }
        return u.contains("ROM") ? [Color(white: 0.78), Color(white: 0.52), Color(white: 0.90), Color(white: 0.55), Color(white: 0.78)] : [.mint, .yellow.opacity(0.8), .cyan, .green.opacity(0.7), .mint]
    }

    var body: some View {
        ZStack {
            Circle().fill(AngularGradient(gradient: Gradient(colors: discPalette), center: .center))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            if isMediaPresent && !isBlank {
                Circle().strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 3, dash: [6, 3])).padding(6)
            }
            Circle().fill(Color.kroutonWindowSurface).frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
        }
        .frame(width: 42, height: 42)
    }
}

struct KroutonDiscMediaPopover: View {
    let drive: KroutonOpticalDriveInfo
    let accent: Color

    var body: some View {
        let modeLabel = drive.isMediaErasable ? "REWRITABLE MEDIA" : (drive.isMediaBlank ? "WRITE-ONCE BLANK" : "MASTERED DISC")
        let usedStr = ByteCountFormatter.string(fromByteCount: drive.usedBytes, countStyle: .file)
        let freeStr = ByteCountFormatter.string(fromByteCount: drive.freeBytes, countStyle: .file)
        let concreteSpeeds = drive.availableWriteSpeeds.filter { !$0.lowercased().contains("auto") }
        let displaySpeeds = concreteSpeeds.isEmpty ? drive.availableWriteSpeeds : concreteSpeeds

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                KroutonDiscArtworkView(mediaType: drive.mediaType, isMediaPresent: drive.isMediaPresent, isErasable: drive.isMediaErasable, isBlank: drive.isMediaBlank)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(drive.statusBadgeText).font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("• \(modeLabel)").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(accent)
                    }
                    Text("\(drive.displayName) • FW \(drive.firmware) • \(drive.interconnect) • \(drive.bsdDeviceNode)")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Text(drive.bookStandard).font(.system(size: 11, weight: .medium))
                }
                Spacer()
            }
            .padding(12).background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))

            if !drive.isMediaPresent {
                Label("No optical media is loaded in this drive.", systemImage: "opticaldisc")
                    .font(.caption).foregroundStyle(.secondary).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                ForEach(drive.mountedVolumes) { vol in
                    HStack(spacing: 10) {
                        Image(systemName: vol.isAudioCD ? "waveform.circle.fill" : "folder.fill.badge.gearshape").foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vol.volumeName) • \(vol.filesystemFormat)").font(.system(size: 11, weight: .bold))
                            Text("\(vol.itemCount) Items • \(ByteCountFormatter.string(fromByteCount: vol.usedBytes, countStyle: .file))").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(KroutonL10n.tr("Open in Finder")) { KroutonOSDesktopBridge.revealFolderInFinder(path: vol.mountPath) }.buttonStyle(.bordered).controlSize(.mini)
                    }.padding(9).background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Text("Used: \(usedStr) (\(drive.usedSectorsLBA) LBA)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Spacer()
                    if drive.freeSectorsLBA > 0 {
                        Text("Free: \(freeStr) (\(drive.freeSectorsLBA) LBA) • \(drive.redBookTimecodeCapacity)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    } else {
                        Text("Free space not reported by the drive").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }.padding(9).background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 8))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    specTile(icon: "building.2.crop.circle.fill", title: "ATIP / MID", value: drive.mediaManufacturer)
                    specTile(icon: "drop.halffull", title: "RECORDING DYE", value: drive.dyeChemistry)
                    specTile(icon: "laser.burst", title: "LASER & BLOCK", value: "\(drive.laserWavelengthNA) • \(drive.sectorBlockSize)")
                    specTile(icon: "gauge.with.dots.needle.67percent", title: "WRITE SPEEDS", value: displaySpeeds.joined(separator: " • "))
                }
            }
        }
        .padding(16).frame(width: 500).background(Color.kroutonWindowSurface)
    }

    func specTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(accent)
                Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(value).font(.system(size: 10, weight: .medium, design: .monospaced)).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(9).background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

/// The report shown after a destination card runs: the drive, the disc, what was written,
/// the speed and the time taken.
struct KroutonMasteringReportSheet: View {
    let report: KroutonBurnSessionReport
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        let rows: [(String, String)] = [
            ("Optical Drive & Firmware", "\(report.driveModel) (FW \(report.firmwareRevision))"),
            ("Media Format & Volume", "\(report.mediaFormattedName) • \(report.volumeName)"),
            ("Sectors & Data Written", "\(report.sectorsWrittenLBA) LBA (\(ByteCountFormatter.string(fromByteCount: report.bytesWritten, countStyle: .file)))"),
            ("Transfer Rate (Avg / Peak)", "\(report.averageSpeedText) • Peak \(report.peakSpeedText)"),
            ("Time Taken", report.elapsedDurationText),
            ("Archival Quality Grade", KroutonLabelGeometryEngine.evaluateArchivalDiscGrade(driveModel: report.driveModel, mediaType: report.mediaFormattedName, sectorsWrittenLBA: report.sectorsWrittenLBA).summaryLine)
        ]
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: report.isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 34)).foregroundStyle(report.isSuccess ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.title).font(.title2.bold())
                    Text(report.summary).font(.body).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(spacing: 6) {
                ForEach(rows, id: \.0) { label, val in
                    HStack {
                        Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        Text(val).font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
            }.padding(14).background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))
            Label(report.diagnosticAdvice, systemImage: "info.circle.fill").font(.callout).foregroundStyle(.secondary)
            Spacer()
            HStack {
                Button(KroutonL10n.tr("Copy Archival Certificate")) {
                    let cert = KroutonLabelGeometryEngine.evaluateArchivalDiscGrade(driveModel: report.driveModel, mediaType: report.mediaFormattedName, sectorsWrittenLBA: report.sectorsWrittenLBA)
                    KroutonOSDesktopBridge.copyTextToClipboard(cert.certificateText)
                }
                Button(KroutonL10n.tr("Copy Telemetry Log")) {
                    KroutonOSDesktopBridge.copyTextToClipboard("\(report.title)\n\(report.summary)\nSectors: \(report.sectorsWrittenLBA) LBA")
                }
                Spacer()
                Button(KroutonL10n.tr("Done")) { onDismiss() }.buttonStyle(.borderedProminent).tint(accent).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 580, height: 400).background(Color.kroutonWindowSurface)
    }
}
