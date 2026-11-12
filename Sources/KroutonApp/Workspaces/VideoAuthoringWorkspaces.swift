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

    var body: some View {
        let isDualLayer = spec.technicalName.contains("DL") || spec.technicalName.contains("DVD-9") || spec.colloquialName.contains("50 GB") || spec.colloquialName.contains("UHD")
        let isBluRay = spec.technicalName.contains("BD") || spec.technicalName.contains("AVCHD")
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "film.stack.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(isBluRay ? "BLU-RAY / BDMV & AVCHD AUTHORING STUDIO (UDF 2.50 / 2.60)" : "DVD-VIDEO AUTHORING & FIT-TO-DISC STUDIO (UDF 1.02 + ISO9660 BRIDGE)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isCenterWorkspaceNarrow {
                        Text(isBluRay ? "BDMV + CERTIFICATE Folders Auto-Built" : "VIDEO_TS + Empty AUDIO_TS Enforced")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }

                    Button {
                        showVideoOvenPopover.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                            Text("VideoOven Bitrate & Shrink")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(store.activeAccent.opacity(0.16))
                        .foregroundStyle(store.activeAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showVideoOvenPopover, arrowEdge: .bottom) {
                        KroutonVideoOvenPopoverView(store: store, spec: spec, isBluRay: isBluRay, isDualLayer: isDualLayer, fitToDiscDVD9Shrink: fitToDiscDVD9Shrink, preserveMenusAndExtras: preserveMenusAndExtras)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("KROUTON_VIDEO", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder).frame(width: 140)
                        }
                        Picker("Menu Style:", selection: $videoMenuTemplate) {
                            Text(KroutonL10n.tr("Dark Studio Chapter Grid")).tag("Dark Studio Chapter Grid")
                            Text(KroutonL10n.tr("No Menu (Auto-Play Title 1)")).tag("No Menu (Auto-Play Title 1 on Insert)")
                            Text(KroutonL10n.tr("Minimalist Studio Track List")).tag("Minimalist Studio Track List")
                        }
                        .frame(maxWidth: 230)
                        .font(.caption)

                        Picker("System:", selection: $videoSystemStandard) {
                            Text(KroutonL10n.tr("NTSC 16:9 (29.97 / 23.976p)")).tag("NTSC 16:9 (29.97 / 23.976p)")
                            Text(KroutonL10n.tr("PAL 16:9 (25 fps)")).tag("PAL 16:9 (25 fps)")
                            Text(KroutonL10n.tr("UHD 2160p HDR10 (HEVC 10-Bit)")).tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                        }
                        .frame(maxWidth: 215)
                        .font(.caption)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold())
                            TextField("KROUTON_VIDEO", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 8) {
                            Picker("Menu:", selection: $videoMenuTemplate) {
                                Text(KroutonL10n.tr("Dark Studio Chapter Grid")).tag("Dark Studio Chapter Grid")
                                Text(KroutonL10n.tr("No Menu (Auto-Play)")).tag("No Menu (Auto-Play Title 1 on Insert)")
                                Text(KroutonL10n.tr("Minimalist Track List")).tag("Minimalist Studio Track List")
                            }
                            .font(.caption)

                            Picker("System:", selection: $videoSystemStandard) {
                                Text(KroutonL10n.tr("NTSC 16:9")).tag("NTSC 16:9 (29.97 / 23.976p)")
                                Text(KroutonL10n.tr("PAL 16:9")).tag("PAL 16:9 (25 fps)")
                                Text(KroutonL10n.tr("UHD HDR10")).tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                            }
                            .font(.caption)
                        }
                    }
                }

                if spec.id == "bd-on-dvd" {
                    HStack(spacing: 12) {
                        Picker("AVCHD Bitrate Cap:", selection: $avchdBitrateCap) {
                            Text("18 Mbps (3x DVD-R Spin Safe)").tag("18 Mbps (3x DVD-R Safe)")
                            Text("24 Mbps (High-Speed BD Player)").tag("24 Mbps (High-Speed)")
                        }
                        .font(.caption)
                        .frame(maxWidth: 265)
                        Text(KroutonL10n.tr("• UDF 2.50 BDMV on 4.7 GB / 8.5 GB Red-Laser DVD"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                } else if spec.id == "bd-uhd" {
                    HStack(spacing: 12) {
                        Toggle(KroutonL10n.tr("HEVC 10-Bit HDR10 / Dolby Vision Static & Dynamic Metadata Pass-Through"), isOn: $uhdPreserveHDR10DolbyVision)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        Toggle(KroutonL10n.tr("Fit-to-Disc Smart Requantizer (DVD-9 -> DVD-5 / BD-50 -> BD-25)"), isOn: $fitToDiscDVD9Shrink)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)

                        if isDualLayer {
                            Picker("Layer Break:", selection: $videoDualLayerBreakSector) {
                                Text(KroutonL10n.tr("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC)")).tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                                Text(KroutonL10n.tr("50/50 Balanced Split (Layer 0 >= Layer 1)")).tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                                Text(KroutonL10n.tr("Seamless Layer Break (SPLB Flag Set)")).tag("Seamless Layer Break (SPLB Flag Set)")
                            }
                            .frame(maxWidth: 310)
                            .font(.caption)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(KroutonL10n.tr("Fit-to-Disc Smart Requantizer (DVD-9 -> DVD-5)"), isOn: $fitToDiscDVD9Shrink)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())

                        if isDualLayer {
                            Picker("Layer Break:", selection: $videoDualLayerBreakSector) {
                                Text(KroutonL10n.tr("Auto Cell Boundary (LBA 2,086,912)")).tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                                Text(KroutonL10n.tr("50/50 Balanced Split (L0 >= L1)")).tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                                Text(KroutonL10n.tr("Seamless Layer Break (SPLB)")).tag("Seamless Layer Break (SPLB Flag Set)")
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

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
                    VStack(spacing: 10) {
                        Image(systemName: "film.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(isCenterWorkspaceNarrow ? KroutonL10n.tr("Drop Any Video or Container") : KroutonL10n.tr("Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, AV1, HEVC 10-Bit, WebM, AVI, VOB, VIDEO_TS, BDMV)"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Text(KroutonL10n.tr("Author standalone set-top player discs with AC-3 / DTS audio, chapter markers, and 32 KB IFO/BUP ECC sector padding."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
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
