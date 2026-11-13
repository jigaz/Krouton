import VideoOven
import Tartine
import Marmalade
//
//  KroutonMasteringWorkspaces.swift
//  Krouton — Optical Media Mastering Studio
//
//  Format-Specific Mastering Workspaces (Data/Archival, Red Book Audio, Video Authoring, Car-Safe Audio, Retro Console ROMs, and Disc Image Inspector).
//

import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

struct KroutonVideoAuthoringWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var fitToDiscDVD9Shrink: Bool
    let preserveMenusAndExtras: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var showVideoOvenPopover: Bool = false
    @State private var videoMenuTemplate: String = "Dark Studio Chapter Grid"
    @State private var videoSystemStandard: String = "NTSC 16:9 (29.97 / 23.976p)"
    @State private var videoDualLayerBreakSector: String = "Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)"
    @State private var avchdBitrateCap: String = "18 Mbps (3x DVD-R Safe)"
    @State private var uhdPreserveHDR10DolbyVision: Bool = true

    private var isVCDFormat: Bool {
        spec.id == "video-svcd" || spec.id == "vcd-svcd" || spec.technicalName.contains("VCD")
    }

    private var videoDeckHeaderTitle: String {
        if isVCDFormat {
            return isCenterWorkspaceNarrow ? "WHITE BOOK VCD / SVCD" : "WHITE BOOK VCD 2.0 / SVCD STUDIO (MPEG-1/2 • MODE 2 FORM 2 XA)"
        } else if spec.id == "bd-uhd" {
            return isCenterWorkspaceNarrow ? "4K UHD BLU-RAY DECK (UDF 2.60)" : "4K UHD-BD HDR10 / DOLBY VISION AUTHORING STUDIO (UDF 2.60 • BDXL)"
        } else if spec.id == "bd-on-dvd" {
            return isCenterWorkspaceNarrow ? "AVCHD ON DVD DECK (UDF 2.50)" : "AVCHD HIGH-DEFINITION ON RED-LASER DVD STUDIO (UDF 2.50 BDMV)"
        } else if spec.technicalName.contains("BD") {
            return isCenterWorkspaceNarrow ? "BLU-RAY BDMV DECK (UDF 2.50)" : "BLU-RAY / BDMV AUTHORING STUDIO (UDF 2.50 / 2.60 • H.264 / HEVC)"
        } else {
            return isCenterWorkspaceNarrow ? "DVD-VIDEO AUTHORING DECK" : "DVD-VIDEO AUTHORING & FIT-TO-DISC STUDIO (UDF 1.02 + ISO9660 BRIDGE)"
        }
    }

    @ViewBuilder
    private func menuStylePicker(compact: Bool) -> some View {
        Picker("", selection: $videoMenuTemplate) {
            Text(KroutonL10n.tr("Dark Studio Chapter Grid")).tag("Dark Studio Chapter Grid")
            Text(KroutonL10n.tr(compact ? "No Menu (Auto-Play Title 1)" : "No Menu (Auto-Play Title 1 on Insert)")).tag("No Menu (Auto-Play Title 1 on Insert)")
            Text(KroutonL10n.tr("Minimalist Studio Track List")).tag("Minimalist Studio Track List")
        }
        .labelsHidden()
        .font(.caption)
        .accessibilityLabel(KroutonL10n.tr("Disc Menu Style"))
    }

    @ViewBuilder
    private func videoSystemPicker(compact: Bool) -> some View {
        Picker("", selection: $videoSystemStandard) {
            Text(KroutonL10n.tr("NTSC 16:9 (29.97 / 23.976p)")).tag("NTSC 16:9 (29.97 / 23.976p)")
            Text(KroutonL10n.tr("PAL 16:9 (25 fps)")).tag("PAL 16:9 (25 fps)")
            Text(KroutonL10n.tr("UHD 2160p HDR10 (HEVC 10-Bit)")).tag("UHD 2160p HDR10 (HEVC 10-Bit)")
        }
        .labelsHidden()
        .font(.caption)
        .accessibilityLabel(KroutonL10n.tr("Video Broadcast System"))
    }

    @ViewBuilder
    private func layerBreakPicker(isBluRay: Bool, compact: Bool) -> some View {
        Picker("", selection: $videoDualLayerBreakSector) {
            Text(KroutonL10n.tr(compact
                ? (isBluRay ? "Auto Cell Boundary (32-Sec ECC)" : "Auto Cell Boundary (16-Sec ECC)")
                : (isBluRay ? "Auto Cell Boundary (BD-50 Layer 0/1 • 32-Sector ECC)" : "Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC)")))
                .tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
            Text(KroutonL10n.tr(compact ? "50/50 Balanced Split (L0 >= L1)" : "50/50 Balanced Split (Layer 0 >= Layer 1)")).tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
            Text(KroutonL10n.tr("Seamless Layer Break (SPLB)")).tag("Seamless Layer Break (SPLB Flag Set)")
        }
        .labelsHidden()
        .font(.caption)
        .accessibilityLabel(KroutonL10n.tr("Dual-Layer Break Mode"))
    }

    var body: some View {
        let isDualLayer = spec.technicalName.contains("DL") || spec.technicalName.contains("DVD-9") || spec.colloquialName.contains("50 GB") || spec.colloquialName.contains("UHD") || spec.id == "dvd-video"
        let isBluRay = spec.technicalName.contains("BD") || spec.technicalName.contains("AVCHD")
        return VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "film.stack.fill")
                            .foregroundStyle(store.activeAccent)
                            .accessibilityHidden(true)
                        Text(videoDeckHeaderTitle)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if !isCenterWorkspaceNarrow {
                            Text(isBluRay ? "BDMV + CERTIFICATE Auto-Built" : "VIDEO_TS + Empty AUDIO_TS Enforced")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        }

                        Button {
                            showVideoOvenPopover.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gauge.with.dots.needle.67percent")
                                Text(isCenterWorkspaceNarrow ? "Bitrate" : "Bitrate & Fit")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Inspect VideoOven Bitrate Budget and Requantizer")
                        .popover(isPresented: $showVideoOvenPopover, arrowEdge: .bottom) {
                            KroutonVideoOvenPopoverView(store: store, spec: spec, isBluRay: isBluRay, isDualLayer: isDualLayer, fitToDiscDVD9Shrink: fitToDiscDVD9Shrink, preserveMenusAndExtras: preserveMenusAndExtras)
                        }
                    }

                    if isCenterWorkspaceNarrow {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold()).frame(width: 66, alignment: .leading)
                                TextField("KROUTON_VIDEO", text: $store.discVolumeTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel(KroutonL10n.tr("Disc Volume Title"))
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Menu:")).font(.caption.bold()).frame(width: 66, alignment: .leading)
                                menuStylePicker(compact: true).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("System:")).font(.caption.bold()).frame(width: 66, alignment: .leading)
                                videoSystemPicker(compact: true).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        HStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold()).lineLimit(1)
                                TextField("KROUTON_VIDEO", text: $store.discVolumeTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 140, maxWidth: 190)
                                    .accessibilityLabel(KroutonL10n.tr("Disc Volume Title"))
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Menu Style:")).font(.caption.bold()).lineLimit(1)
                                menuStylePicker(compact: false).fixedSize(horizontal: true, vertical: false)
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("System:")).font(.caption.bold()).lineLimit(1)
                                videoSystemPicker(compact: false).fixedSize(horizontal: true, vertical: false)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    if spec.id == "bd-on-dvd" {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr(isCenterWorkspaceNarrow ? "Bitrate:" : "AVCHD Bitrate Cap:"))
                                .font(.caption.bold())
                                .frame(width: isCenterWorkspaceNarrow ? 66 : nil, alignment: .leading)
                                .lineLimit(1)
                            Picker("", selection: $avchdBitrateCap) {
                                Text("18 Mbps (3x DVD-R Spin Safe)").tag("18 Mbps (3x DVD-R Safe)")
                                Text("24 Mbps (High-Speed BD Player)").tag("24 Mbps (High-Speed)")
                            }
                            .labelsHidden()
                            .font(.caption)
                            .fixedSize(horizontal: !isCenterWorkspaceNarrow, vertical: false)
                            .frame(maxWidth: isCenterWorkspaceNarrow ? .infinity : nil, alignment: .leading)
                            .accessibilityLabel(KroutonL10n.tr("AVCHD Bitrate Cap"))

                            if !isCenterWorkspaceNarrow {
                                Text(KroutonL10n.tr("• UDF 2.50 BDMV on 4.7 GB / 8.5 GB Red-Laser DVD"))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                    } else if spec.id == "bd-uhd" {
                        Toggle(KroutonL10n.tr(isCenterWorkspaceNarrow
                            ? "HEVC 10-Bit HDR10 & Dolby Vision Pass-Through"
                            : "HEVC 10-Bit HDR10 / Dolby Vision Static & Dynamic Metadata Pass-Through"),
                            isOn: $uhdPreserveHDR10DolbyVision)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }

                    let shrinkLabel = isVCDFormat ? (isCenterWorkspaceNarrow ? "Fit-to-CD CBR/VBR Bitrate Clamp (80m CD-R)" : "Fit-to-CD Smart MPEG-1/2 Bitrate Clamp (700 MB / 80-Min CD-R)") : isBluRay
                        ? (isCenterWorkspaceNarrow ? "Fit-to-Disc Requantizer (BD-50 → BD-25)" : "Fit-to-Disc Smart Requantizer (BD-50 → BD-25 / BDXL)")
                        : (isCenterWorkspaceNarrow ? "Fit-to-Disc Requantizer (DVD-9 → DVD-5)" : "Fit-to-Disc Smart Requantizer (DVD-9 → DVD-5)")

                    if isCenterWorkspaceNarrow {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(KroutonL10n.tr(shrinkLabel), isOn: $fitToDiscDVD9Shrink)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)

                            if isDualLayer {
                                HStack(spacing: 6) {
                                    Text(KroutonL10n.tr("Break:")).font(.caption.bold()).frame(width: 66, alignment: .leading)
                                    layerBreakPicker(isBluRay: isBluRay, compact: true).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 14) {
                            Toggle(KroutonL10n.tr(shrinkLabel), isOn: $fitToDiscDVD9Shrink)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)

                            if isDualLayer {
                                HStack(spacing: 6) {
                                    Text(KroutonL10n.tr("Layer Break:")).font(.caption.bold()).lineLimit(1)
                                    layerBreakPicker(isBluRay: isBluRay, compact: false).fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "film.circle.fill",
                        headline: isCenterWorkspaceNarrow ? "Drop Any Video or Container" : "Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, AV1, HEVC 10-Bit, WebM, AVI, VOB, VIDEO_TS, BDMV)",
                        subtitle: isVCDFormat ? "Author White Book VCD 2.0 & SVCD discs with MPEG-1 / MPEG-2 video, 2,324-byte Mode 2 Form 2 XA sectors, and PBC chapter menus." : (isBluRay ? "Author standalone Blu-ray BDMV discs with H.264 / HEVC video, AC-3 / DTS-HD audio, chapter markers, and UDF 2.50 / 2.60 descriptors." : "Author standalone set-top player discs with AC-3 / DTS audio, chapter markers, and 32 KB IFO/BUP ECC sector padding.")
                    )
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("TITLE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(KroutonL10n.tr("VIDEO STREAM & CHAPTER TOPOLOGY"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("VIDEO / AUDIO PIPELINE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 195, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let chapters = max(4, min(32, Int(entry.byteSize / 150_000_000) + 6))
                                    HStack(spacing: 10) {
                                        Text(String(format: "VTS_%02d", idx + 1))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 44, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            Text("\(chapters) Auto-Chapters (Every 5 Min) • \(videoSystemStandard)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        let vProbe = KroutonPantryPrepEngine.probeFile(entry.url)
                                        Text("\(vProbe.shortHardwareBadge) • \(isBluRay ? "BDMV" : "DVD-V")")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.cyan)
                                            .frame(width: 195, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .contentTransition(.numericText())
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                onHandleFinderDrop(providers)
            }
        }
    }

}
