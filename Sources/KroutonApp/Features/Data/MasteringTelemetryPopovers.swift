import VideoKit
import ImageKit
import AudioKit
//
//  KroutonMasteringWorkspaces.swift
//  Krouton — Optical Media Mastering Package (Optical Media Mastering Workspace)
//
//  Format-Specific Mastering Workspaces (Data/Archival, Red Book Audio, Video Authoring, Car-Safe Audio, Retro Console ROMs, and Disc Image Inspector).
//

import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - Standalone Mastering Telemetry Popover Views

struct KroutonTartineLBAMapPopoverView: View {
    @ObservedObject var store: KroutonStateStore
    let activeSpec: KroutonRecipeSpec

    var body: some View {
        let plan = store.planLiveTartineHybridLayout(
            volumeLabel: store.discVolumeTitle,
            entries: store.stagedFiles,
            isElToritoBootable: (activeSpec.id == "data-hybrid" || activeSpec.id.contains("boot") || activeSpec.technicalName.localizedCaseInsensitiveContains("El Torito"))
        )
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .foregroundStyle(store.activeAccent)
                Text("TARTINE HYBRID LBA SECTOR PLANNER • \(plan.volumeIdentifier)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Button {
                    let report = """
                    VOLUME: \(plan.volumeIdentifier)
                    LBA 16: ISO-9660 Primary Volume Descriptor
                    LBA \(plan.elToritoBootRecordLBA ?? -1): El Torito Boot Catalog
                    LBA \(plan.jolietSVDSectorLBA): Joliet UCS-2 SVD
                    LBA \(plan.udfAnchorAVDPLBA): ECMA-167 UDF 2.60 Anchor (AVDP)
                    TOTAL SECTORS: \(plan.totalSectorsLBA) (\(plan.totalBytes) bytes)
                    """
                    KroutonOSDesktopBridge.copyTextToClipboard(report)
                } label: {
                    Label("Copy Map", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("• LBA 000016 : ISO-9660 Primary Volume Descriptor (CD001)")
                if let bootLBA = plan.elToritoBootRecordLBA {
                    Text(String(format: "• LBA %06lld : El Torito Boot Record Volume Descriptor", bootLBA))
                        .foregroundStyle(.orange)
                }
                Text(String(format: "• LBA %06lld : Joliet Supplementary Volume Descriptor (UCS-2)", plan.jolietSVDSectorLBA))
                Text(String(format: "• LBA %06lld : ECMA-167 / UDF 2.60 Anchor Volume Descriptor (AVDP)", plan.udfAnchorAVDPLBA))
                Text(String(format: "• LBA %06lld : Shared Hybrid Data Payload Start (%d deduplicated extents)", plan.dataPayloadStartLBA, plan.sharedHybridExtents.count))
                    .foregroundStyle(store.activeAccent)
            }
            .font(.system(size: 11, design: .monospaced))

            if !plan.sharedHybridExtents.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.sharedHybridExtents) { ext in
                            HStack(spacing: 8) {
                                Text(String(format: "LBA %06lld..%06lld", ext.startLBA, ext.startLBA + ext.sectorCountLBA - 1))
                                    .foregroundStyle(store.activeAccent)
                                Text(ext.iso9660Name)
                                    .frame(width: 150, alignment: .leading)
                                Spacer()
                                Text(ext.visibleInMacTree ? "[Mac]" : "     ")
                                    .foregroundStyle(.cyan)
                                Text(ext.visibleInPCTree ? "[PC]" : "    ")
                                    .foregroundStyle(.green)
                            }
                            .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            if !plan.warnings.isEmpty {
                Divider()
                ForEach(plan.warnings, id: \.self) { warn in
                    Label(warn, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(14)
        .frame(width: 560)
    }
}

struct KroutonMarmaladeCuePopoverView: View {
    @ObservedObject var store: KroutonStateStore

    private var project: AudioProject { store.audioController.project }

    private func describeIssue(_ issue: AudioProjectIssue) -> String {
        switch issue {
        case .noTracks:
            return "No tracks in project."
        case .tooManyTracks(let count):
            return "Red Book maximum is 99 tracks (found \(count))."
        case .tooManyTracksOnDisc(let discNumber, let count):
            return "Disc \(discNumber) exceeds the 99-track Red Book limit (\(count) tracks)."
        case .notAnalysed:
            return "Analysing track durations and peaks…"
        case .trackTooShort(_, let frames):
            return "Track is shorter than the 4-second Red Book minimum (\(frames) frames)."
        case .trackExceedsDiscCapacity(_, let frames, let capacity):
            return "Single track (\(frames) frames) exceeds single disc capacity (\(capacity) frames)."
        case .overlapTrimmed(_, let requested, let used):
            return "Crossfade trimmed from \(requested)f to \(used)f (max 50% of track length)."
        case .automaticBreakSplitsContinuousRun(let discNumber, _):
            return "Automatic break before Disc \(discNumber) splits a gapless or crossfaded run."
        case .exceedsCapacity(let frames, let capacity):
            return "Total length (\(frames) frames) exceeds disc capacity (\(capacity) frames)."
        }
    }

    var body: some View {
        let (_, issues) = project.layout()
        let cueText = project.compileCueSheet()
        let packCount = project.compileCDTextBlock()?.packs.count ?? 0

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .foregroundStyle(store.activeAccent)
                Text("RED BOOK .CUE SHEET & 18-BYTE CD-TEXT INSPECTOR")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                if let cueText {
                    Button {
                        KroutonOSDesktopBridge.copyTextToClipboard(cueText)
                    } label: {
                        Label("Copy .CUE", systemImage: "doc.on.doc")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.activeAccent)
                }
            }

            HStack(spacing: 12) {
                Label(
                    project.writeCDText ? "\(packCount) × 18-Byte Subchannel Packs (CRC-16 CCITT)" : "CD-TEXT Disabled",
                    systemImage: project.writeCDText ? "checkmark.shield.fill" : "slash.circle"
                )
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(project.writeCDText ? .green : .secondary)
                Spacer()
                Text("\(project.tracks.count) Audio Tracks • 75 fps (2,352 B/sector)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        Label(describeIssue(issue), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Divider()

            ScrollView {
                Text(cueText ?? "Cue sheet unavailable until all tracks have finished audio analysis.")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 220)
            .padding(8)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .frame(width: 560)
    }
}

struct KroutonVideoOvenPopoverView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isBluRay: Bool
    let isDualLayer: Bool
    let fitToDiscDVD9Shrink: Bool
    let preserveMenusAndExtras: Bool

    var body: some View {
        let medium: KroutonVideoTargetMedium = {
            if isBluRay {
                return isDualLayer ? .bd50DualLayer : .bd25SingleLayer
            } else {
                return isDualLayer ? .dvd9DualLayer : .dvd5SingleLayer
            }
        }()
        let stagedBytes = store.stagedFiles.reduce(Int64(0)) { $0 + $1.byteSize }
        // Estimate program duration from staged files (or default to 110-min feature film = 6,600s)
        let estimatedDurationSec: Double = stagedBytes > 0
            ? max(300.0, min(14_400.0, Double(stagedBytes) / 750_000.0))
            : 6_600.0
        let budget = store.computeLiveVideoOvenBitrateBudget(
            durationSeconds: estimatedDurationSec,
            audioKbps: isBluRay ? 1_536 : 448,
            medium: medium
        )
        let mainBytes: Int64 = stagedBytes
        let extrasBytes: Int64 = 0
        let shrinkPlan = KroutonVideoAuthoringEngine.planDVD9ToDVD5Shrink(
            mainFeatureBytes: mainBytes,
            menusAndExtrasBytes: extrasBytes,
            preserveMenusAndExtras: store.fitToDiscPreserveMenus
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "film.stack.fill")
                    .foregroundStyle(store.activeAccent)
                Text("VIDEOOVEN BITRATE BUDGET & REQUIEM SHRINK INSPECTOR")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Button {
                    let summary = """
                    MEDIUM: \(medium.rawValue) (\(medium.totalSectorsLBA) LBA sectors / \(medium.capacityBytes) B)
                    TARGET VIDEO BITRATE: \(budget.targetVideoKbps) kbps (Max Ceiling: \(budget.maxHardwareCeilingKbps) kbps)
                    VBV BUFFER: \(budget.vbvBufferKilobits) kilobits • Audio: \(budget.audioBitrateKbps) kbps
                    DVD-9 -> DVD-5 REQUIEM SHRINK RATIO: \(String(format: "%.1f%%", shrinkPlan.requantizationRatio * 100.0))
                    ESTIMATED OUTPUT: \(shrinkPlan.estimatedOutputBytes) bytes (Preserve Menus: \(shrinkPlan.preserveMenusAndExtras))
                    """
                    KroutonOSDesktopBridge.copyTextToClipboard(summary)
                } label: {
                    Label("Copy Budget", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text("• Target Optical Medium : \(medium.rawValue) (\(medium.totalSectorsLBA) × 2048-B sectors)")
                Text("• Target Video Bitrate  : \(budget.targetVideoKbps) kbps (Hardware Spec Ceiling: \(budget.maxHardwareCeilingKbps) kbps)")
                    .foregroundStyle(store.activeAccent)
                Text("• VBV Decoder Buffer    : \(budget.vbvBufferKilobits) kilobits • Audio Stream: \(budget.audioBitrateKbps) kbps")
                Text(String(format: "• Usable Video Payload  : %.2f GB (Est. Disc Fill: %.1f%%)", Double(budget.usableVideoBytes) / 1_000_000_000.0, budget.estimatedDiscFillRatio * 100.0))
                    .foregroundStyle(.green)
            }
            .font(.system(size: 11, design: .monospaced))

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .foregroundStyle(.orange)
                    Text("DVD-9 (8.54 GB DL) -> DVD-5 (4.70 GB SL) FIT-TO-DISC REQUANTIZATION PLAN")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                Text(String(format: "• Main Feature DCT Retention : %.1f%% (%@)", shrinkPlan.requantizationRatio * 100.0, fitToDiscDVD9Shrink ? "ACTIVE" : "STANDBY"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(String(format: "• Menus & Bonus Features     : %@ (%.2f GB source)", shrinkPlan.preserveMenusAndExtras ? "Preserved at 90% Fidelity" : "Stripped (Main Movie Only)", Double(shrinkPlan.sourceMenusAndExtrasBytes) / 1_000_000_000.0))
                    .font(.system(size: 10, design: .monospaced))
                Text(String(format: "• Requantized VTS Output     : %.3f GB / %.3f GB DVD-5 Safe Ceiling", Double(shrinkPlan.estimatedOutputBytes) / 1_000_000_000.0, Double(shrinkPlan.targetUsableDVD5Bytes) / 1_000_000_000.0))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.black.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            let totalLBA = max(0, stagedBytes / 2048)
            let sampleCells: [KroutonDVD9CellDescriptor] = store.stagedFiles.enumerated().map { idx, entry in
                let sectors = max(1, entry.byteSize / 2048)
                return KroutonDVD9CellDescriptor(cellID: idx + 1, originalStartSectorLBA: 0, originalSectorCountLBA: sectors, hadDualLayerBreakPause: totalLBA > 2_086_912 && idx == 0)
            }
            let blueprint = KroutonVideoAuthoringEngine.buildDVD9ToDVD5MenuShrinkBlueprint(
                menuVobBytes: extrasBytes,
                preserveMenus: store.fitToDiscPreserveMenus,
                sourceCells: sampleCells
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "MenuCard" == "" ? "list.bullet.rectangle.fill" : "menubar.rectangle")
                        .foregroundStyle(.cyan)
                    Text("DVD-9 -> DVD-5 MENU BUTTONS, .IFO RELINKING & LAYER-BREAK REMOVAL")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                Text("• Menu NV_PCK & SPU Highlights : 100% Bit-Exact Passthrough (Menu Video @ \(Int(blueprint.menuVobRetentionRatio * 100))%)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Text("• VTS_01_0.IFO / .BUP Pointers : \(blueprint.relinkedCells.count) PGC Cells Relinked to Shrunk VOBU Sectors (32K ECC Guarded)")
                    .font(.system(size: 10, design: .monospaced))
                Text("• Former DVD-9 Layer-Break Cell: \(blueprint.layerBreakPauseRemoved ? "SPLB Pause Flag Cleared -> 100% Seamless DVD-5 Playback" : "Seamless")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
            .padding(8)
            .background(Color.black.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .frame(width: 575)
    }

}
