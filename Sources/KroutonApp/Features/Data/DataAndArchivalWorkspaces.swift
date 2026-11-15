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

struct KroutonDataAndArchivalWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let activeSpec: KroutonRecipeSpec
    @Binding var enableCustomFinderLayoutTab: Bool
    @Binding var finderIconSize: Double
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var showTartineLBAMapPopover: Bool = false
    @State private var activeDataWorkspaceTab: Int = 0
    @State private var finderBgColor: Color = Color(red: 0.13, green: 0.17, blue: 0.24)
    @State private var mdiscPar2RedundancyPct: Double = 15.0
    @State private var preserveMacExtendedAttributes: Bool = true
    @State private var enforce8Dot3RetroCompatibility: Bool = false

    var body: some View {
        return VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        dataDeckTopControlsSection
                        dataDeckBottomOptionsSection
                    }
                }
            }
            dataStagingAndLayoutSection
        }
    }

    @ViewBuilder
    private var dataDeckTopControlsSection: some View {
        let isAppleOnly = (activeSpec.id == "data-apple-apfs")
        let isRetro83 = (activeSpec.id == "data-retro-iso")
        let isClassicHFS = (activeSpec.id == "macos9-hfs")
        let isPhotoCD = (activeSpec.id == "photo-cd")
        VStack(alignment: .leading, spacing: 8) {
                if activeSpec.isMDiscParityFormat {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(store.activeAccent)
                            Text(KroutonL10n.tr("M-DISC ROCK-LAYER VAULT + PAR2 PARITY:"))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text("PAR2: \(Int(mdiscPar2RedundancyPct))%")
                                .font(.caption.bold())
                                .foregroundStyle(store.activeAccent)
                            Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                                .frame(width: 130)
                            Text(KroutonL10n.tr("• Reed-Solomon .par2 + SHA-256"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(store.activeAccent)
                                    .accessibilityHidden(true)
                                Text(KroutonL10n.tr("M-DISC ROCK-LAYER VAULT"))
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("PAR2: \(Int(mdiscPar2RedundancyPct))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(store.activeAccent)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            HStack(spacing: 8) {
                                Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                                    .frame(maxWidth: 135)
                                    .accessibilityLabel("M-DISC PAR2 Parity Percentage")
                                    .accessibilityValue("\(Int(mdiscPar2RedundancyPct)) percent")
                                Text(KroutonL10n.tr("Reed-Solomon .par2 + SHA-256"))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Divider()
                }

                ViewThatFits(in: .horizontal) {
                    // 1. Wide Horizontal Bar
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(store.activeAccent)
                            Text(KroutonL10n.tr("Disc Title:"))
                                .font(.caption.bold())
                                .lineLimit(1)
                            TextField("Volume Title", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 145)
                        }
                        .fixedSize(horizontal: true, vertical: false)

                        if activeSpec.id == "dvd-ram" {
                            Label("Zoned CLV Defect Management (UDF 1.50 / 2.01 Hardware Verified)", systemImage: "memorychip.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if activeSpec.id == "data-udf-modern" {
                            Label("Pure UDF 2.60 (Files >4 GiB up to 128 GB)", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if isAppleOnly {
                            Toggle(KroutonL10n.tr("Preserve macOS Extended Attributes (xattr) & Resource Forks"), isOn: $preserveMacExtendedAttributes)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else if isClassicHFS {
                            Label("Apple Partition Map (APM) + Blessed Classic HFS (System 7 / Mac OS 9)", systemImage: "desktopcomputer")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isPhotoCD {
                            Label("Kodak Beige Book CD-ROM XA (Multi-Resolution .PCD Image Pac)", systemImage: "camera.aperture")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isRetro83 {
                            Toggle(KroutonL10n.tr("Enforce Strict 8.3 Uppercase Filenames (DOS / Win95 / System 7)"), isOn: $enforce8Dot3RetroCompatibility)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else {
                            Label("4-Way Universal Bridge (macOS HFS+ • Windows Joliet/UDF • Linux Rock Ridge)", systemImage: "globe")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Button {
                            showTartineLBAMapPopover.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip.fill")
                                Text(KroutonL10n.tr("LBA Sector Map"))
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showTartineLBAMapPopover, arrowEdge: .bottom) {
                            KroutonTartineLBAMapPopoverView(store: store, activeSpec: activeSpec)
                        }

                        if !isRetro83 {
                            Toggle(KroutonL10n.tr("Customize Finder Layout"), isOn: $enableCustomFinderLayoutTab)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                    activeDataWorkspaceTab = enabled ? 1 : 0
                                }
                        }
                    }

                    // 2. Narrow Stacked Fallback (Zero Vertical Word-Towers & Zero Clipping!)
                }
        }
    }
    @ViewBuilder
    private var dataDeckBottomOptionsSection: some View {
        let isAppleOnly = (activeSpec.id == "data-apple-apfs")
        let isRetro83 = (activeSpec.id == "data-retro-iso")
        let isClassicHFS = (activeSpec.id == "macos9-hfs")
        let isPhotoCD = (activeSpec.id == "photo-cd")
        VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(store.activeAccent)
                                .accessibilityHidden(true)
                            Text(KroutonL10n.tr("Disc Title:"))
                                .font(.caption.bold())
                                .lineLimit(1)
                            TextField("Volume Title", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel(KroutonL10n.tr("Disc Volume Title"))
                            Button {
                                showTartineLBAMapPopover.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "memorychip.fill")
                                    Text("LBA Map")
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(store.activeAccent.opacity(0.16))
                                .foregroundStyle(store.activeAccent)
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Inspect LBA Sector Allocation Map")
                        }

                        HStack(spacing: 8) {
                            if activeSpec.id == "dvd-ram" {
                                Label("UDF 2.01 Zoned Defect Mgmt", systemImage: "memorychip.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else if activeSpec.id == "data-udf-modern" {
                                Label("Pure UDF 2.60 (>4 GiB Files)", systemImage: "checkmark.seal.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else if isAppleOnly {
                                Toggle(KroutonL10n.tr("Preserve macOS xattr & Resource Forks"), isOn: $preserveMacExtendedAttributes)
                                    .toggleStyle(.checkbox)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                            } else if isClassicHFS {
                                Label("APM + Blessed Classic HFS", systemImage: "desktopcomputer")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else if isPhotoCD {
                                Label("Beige Book CD-ROM XA (.PCD)", systemImage: "camera.aperture")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else if isRetro83 {
                                Toggle(KroutonL10n.tr("Enforce 8.3 Uppercase Filenames"), isOn: $enforce8Dot3RetroCompatibility)
                                    .toggleStyle(.checkbox)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                            } else {
                                Label("4-Way: HFS+ • UDF • Rock Ridge", systemImage: "globe")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if !isRetro83 {
                                Toggle(KroutonL10n.tr("Finder View"), isOn: $enableCustomFinderLayoutTab)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                        activeDataWorkspaceTab = enabled ? 1 : 0
                                    }
                            }
                        }
                    }
                }

    @ViewBuilder
    private var dataStagingAndLayoutSection: some View {
        let isUniversalHybrid = (activeSpec.id == "data-hybrid" || activeSpec.id == "mdisc-vault")
        let isRetro83 = (activeSpec.id == "data-retro-iso")
        Group {
            if activeDataWorkspaceTab == 1 && enableCustomFinderLayoutTab {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        ColorPicker(KroutonL10n.tr("Finder Window Background:"), selection: $finderBgColor)
                        HStack {
                            Text("Icon Size: \(Int(finderIconSize)) px")
                                .font(.caption)
                            Slider(value: $finderIconSize, in: 64...512, step: 32)
                                .frame(width: 160)
                        }
                    }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(finderBgColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 24) {
                                    ForEach(store.stagedFiles) { item in
                                        VStack(spacing: 6) {
                                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                                .font(.system(size: min(finderIconSize * 0.25, 84)))
                                                .foregroundStyle(item.isDirectory ? store.resolvedFolderIconColor : .white)
                                            Text(item.name)
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                        }
                                        .contextMenu {
                                            Button(KroutonL10n.tr("Reveal in Finder")) { KroutonOSDesktopBridge.revealURLsInFinder([item.url]) }
                                            Button(KroutonL10n.tr("Copy Path & Byte Size")) { KroutonOSDesktopBridge.copyTextToClipboard("\(item.url.path) (\(item.byteSize) bytes)") }
                                            Divider()
                                            Button(role: .destructive) { store.removeStagedFile(id: item.id) } label: { Text(KroutonL10n.tr("Remove from Stage")) }
                                        }
                                    }
                                }
                                .padding(24)
                            }
                        )
                }
            } else {
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
                            sfSymbol: "folder.badge.plus",
                            symbolSize: 34,
                            headline: "Drag & Drop Files or Folders Here to Author a New Data Disc",
                            subtitle: isUniversalHybrid
                                ? "Shared data extents are linked into HFS+ (Mac), Joliet/UDF (Windows), and Rock Ridge (Linux) simultaneously. Toggle [Mac] / [PC] to hide platform-specific installers."
                                : "Add files and directories from Finder to build the optical volume directory tree."
                        )
                    } else {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text(KroutonL10n.tr("ITEM NAME & PATH"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 36)
                                Spacer()
                                if isUniversalHybrid {
                                    Text(KroutonL10n.tr("OS VISIBILITY"))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 112, alignment: .center)
                                }
                                Text(KroutonL10n.tr("SECTORS"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 86, alignment: .trailing)
                                Text(KroutonL10n.tr("SIZE"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                                Spacer().frame(width: 22)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                            Divider()

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(store.stagedFiles) { entry in
                                        stagedFileTableRow(entry: entry, isUniversalHybrid: isUniversalHybrid, isRetro83: isRetro83)
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


    @ViewBuilder
    private func stagedFileTableRow(entry: KroutonStagedFileEntry, isUniversalHybrid: Bool, isRetro83: Bool) -> some View {
                                        HStack(spacing: 12) {
                                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                                .foregroundStyle(entry.isDirectory ? store.resolvedFolderIconColor : store.activeAccent)
                                                .font(.system(size: 15))
                                                .frame(width: 24)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(isRetro83 ? entry.iso9660Level1Name : entry.name)
                                                    .font(.system(size: 12, weight: .semibold, design: isRetro83 ? .monospaced : .default))
                                                Text("\(entry.url.path) • Perms: \(entry.posixPermissions) • \(entry.isDirectory ? "\(entry.itemCount) items inside" : "Single file")")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            if isUniversalHybrid {
                                                HStack(spacing: 5) {
                                                    Button {
                                                        store.toggleMacVisibility(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "apple.logo")
                                                                .font(.system(size: 9))
                                                            Text(KroutonL10n.tr("Mac"))
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(entry.showOnMac ? store.activeAccent.opacity(0.22) : Color.secondary.opacity(0.10))
                                                        .foregroundStyle(entry.showOnMac ? store.activeAccent : .secondary.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(entry.showOnMac ? store.activeAccent.opacity(0.5) : Color.clear, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help(entry.showOnMac ? "Visible on macOS Finder (HFS+ Tree) — Click to hide from Mac" : "Hidden on macOS Finder — Click to show on Mac")

                                                    Button {
                                                        store.togglePCVisibility(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "pc")
                                                                .font(.system(size: 9))
                                                            Text(KroutonL10n.tr("PC"))
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(entry.showOnPC ? Color.cyan.opacity(0.20) : Color.secondary.opacity(0.10))
                                                        .foregroundStyle(entry.showOnPC ? Color.cyan : .secondary.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(entry.showOnPC ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help(entry.showOnPC ? "Visible on Windows Explorer (ISO9660 / Joliet / UDF Tree) — Click to hide from PC" : "Hidden on Windows PC — Click to show on PC")
                                                }
                                                .frame(width: 112, alignment: .center)
                                            }

                                            Text("\(entry.sectorsLBA) LBA")
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
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
                                        .contextMenu {
                                            Button(KroutonL10n.tr("Reveal in Finder")) { KroutonOSDesktopBridge.revealURLsInFinder([entry.url]) }
                                            if isUniversalHybrid {
                                                Button(KroutonL10n.tr(entry.showOnMac ? "Hide from macOS (HFS+)" : "Show on macOS (HFS+)")) { store.toggleMacVisibility(id: entry.id) }
                                                Button(KroutonL10n.tr(entry.showOnPC ? "Hide from Windows (Joliet/UDF)" : "Show on Windows (Joliet/UDF)")) { store.togglePCVisibility(id: entry.id) }
                                            }
                                            Button(KroutonL10n.tr("Copy File Path & Sector Count")) {
                                                KroutonOSDesktopBridge.copyTextToClipboard("\(entry.url.path) • \(entry.sectorsLBA) LBA (\(entry.byteSize) B)")
                                            }
                                            Divider()
                                            Button(role: .destructive) { store.removeStagedFile(id: entry.id) } label: { Text(KroutonL10n.tr("Remove from Stage")) }
                                        }
                                        Divider()
    }
}
