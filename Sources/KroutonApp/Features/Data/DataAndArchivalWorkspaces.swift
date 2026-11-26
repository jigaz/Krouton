import AudioKit
import Combine
import Foundation
import ImageKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import VideoKit

//
//  KroutonMasteringWorkspaces.swift
//  Krouton — Optical Media Mastering Package (Optical Media Mastering Workspace)
//
//  Format-Specific Mastering Workspaces (Data/Archival, Red Book Audio, Video Authoring, Car-Safe Audio, Retro Console ROMs, and Disc Image Inspector).
//

// MARK: - DataAndArchivalWorkspaces

struct KroutonDataAndArchivalWorkspaceView: View {
    var store: KroutonStateStore
    let activeSpec: KroutonOpticalWorkflowSpec
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State var showHybridLBAMapPopover: Bool = false
    @State var activeDataWorkspaceTab: Int = 0
    // The M-DISC parity slider is `store.mdiscParityPercent`, applied by `burnInputFiles()`
    // (par2 files written beside the data). The DOS 8.3 format always burns ISO 9660 Level 1.
    // The other labels say what DiscRecording writes; see `KroutonFormatID.burnSupport`.

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
    var dataStagingAndLayoutSection: some View {
        let isUniversalHybrid = (activeSpec.id == "data-hybrid" || activeSpec.id == "mdisc-vault")
        let isRetro83 = (activeSpec.id == "data-retro-iso")
        Group {
            if activeDataWorkspaceTab == 1 && store.enableCustomFinderLayoutTab {
                KroutonFinderDiscStageView(
                    store: store,
                    blueprint: Bindable(store).finderLayoutBlueprint,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop,
                    onInspectLBA: { showHybridLBAMapPopover = true }
                )
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
                                ? "One set of files appears in HFS+ (Mac), Joliet and UDF (Windows, Linux) at once. Toggle [Mac] / [PC] to hide platform-specific installers."
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

                            let plan = store.dataDiscPlan(forFormatID: activeSpec.id)
                            let activeMedium = store.resolvedDataDiscMedium(forFormatID: activeSpec.id)
                            let oversizeIDs: Set<UUID> = Set(plan.issues.compactMap { issue in
                                if case .itemExceedsDisc(let id, _, _) = issue { return id }
                                return nil
                            })
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(plan.discs) { disc in
                                        if plan.discs.count > 1 || !oversizeIDs.isEmpty {
                                            DataDiscHeaderBannerView(
                                                store: store,
                                                disc: disc,
                                                totalDiscs: plan.discs.count,
                                                medium: activeMedium,
                                                hasOversizeItem: disc.items.contains { oversizeIDs.contains($0.id) }
                                            )
                                        }
                                        ForEach(disc.items) { entry in
                                            stagedFileTableRow(entry: entry, isUniversalHybrid: isUniversalHybrid, isRetro83: isRetro83)
                                        }
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
    func stagedFileTableRow(entry: KroutonStagedFileEntry, isUniversalHybrid: Bool, isRetro83: Bool) -> some View {
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
                                            .accessibilityLabel(KroutonL10n.tr("Remove Item"))
                                            .help(KroutonL10n.tr("Remove Item"))
                                            .frame(width: 18, alignment: .center)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .contextMenu {
                                            if (store.stagedFiles.firstIndex(where: { $0.id == entry.id }) ?? 0) > 0 {
                                                Button(entry.startsNewDisc ? KroutonL10n.tr("Merge Back With Previous Disc") : KroutonL10n.tr("Start New Disc Here (Disc Break)")) {
                                                    store.toggleDataManualDiscBreak(before: entry.id)
                                                }
                                                Divider()
                                            }
                                            Button(KroutonL10n.tr("Reveal in Finder")) { KroutonOSDesktopBridge.revealURLsInFinder([entry.url]) }.keyboardShortcut("f", modifiers: [.command, .shift])
                                            Button(KroutonL10n.tr("Inspect Hybrid ISO/UDF LBA Layout")) { showHybridLBAMapPopover = true }.keyboardShortcut("l", modifiers: [.command, .control])
                                            if isUniversalHybrid {
                                                Button(KroutonL10n.tr(entry.showOnMac ? "Hide from macOS (HFS+)" : "Show on macOS (HFS+)")) { store.toggleMacVisibility(id: entry.id) }
                                                Button(KroutonL10n.tr(entry.showOnPC ? "Hide from Windows (Joliet/UDF)" : "Show on Windows (Joliet/UDF)")) { store.togglePCVisibility(id: entry.id) }
                                            }
                                            Button(KroutonL10n.tr("Copy File Path & Sector Count")) {
                                                KroutonOSDesktopBridge.copyTextToClipboard("\(entry.url.path) • \(entry.sectorsLBA) LBA (\(entry.byteSize) B)")
                                            }
                                            Divider()
                                            Button(role: .destructive) { store.removeStagedFile(id: entry.id) } label: { Text(KroutonL10n.tr("Remove from Stage")) }.keyboardShortcut(.delete, modifiers: .command)
                                        }
                                        Divider()
    }
}
