import SwiftUI
import Foundation
import OpticalDough
import Crustini

// MARK: - Standalone Left Format Chooser Sidebar, Central Capacity Bar & Burn Station Views

struct KroutonLeftFormatChooserColumnView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonToasterBank
    let isLeftSidebarUltraSkinny: Bool

    func taskRowButton(id: String, category: KroutonBakeryStation, title: String,
        shortTitle: String? = nil, colloquial: String, badge: String = "", sfSymbol: String) -> some View {
        let isSelected = (store.selectedTaskID == id)
        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            store.rejectedDropNotice = nil
            store.purgeIncompatibleStagedFilesForCurrentTask()
            store.syncDefaultDestinationForCategory(category, taskID: id, driveManager: driveManager)
        } label: {
            HStack(spacing: 9) {
                let rowColor = store.effectiveColorForTask(id: id, category: category)
                KroutonStyledIconBadge(
                    sfSymbol: sfSymbol,
                    tintColor: rowColor,
                    style: store.iconWidgetStyle,
                    isSelectedRow: isSelected,
                    onAccentText: store.activeOnAccentText,
                    size: store.sidebarIconSize.iconFontSize + 11,
                    symbolSize: store.sidebarIconSize.iconFontSize - 1
                )

                VStack(alignment: .leading, spacing: 1) {
                    ViewThatFits(in: .horizontal) {
                        Text(KroutonL10n.tr(title))
                            .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                            .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Text(KroutonL10n.tr(shortTitle ?? title))
                            .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                            .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                            .lineLimit(1)
                    }
                    if !isLeftSidebarUltraSkinny {
                        Text(KroutonL10n.tr(colloquial))
                            .font(.system(size: max(9.5, store.sidebarIconSize.titleFontSize - 2.0)))
                            .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.82) : .secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, store.sidebarIconSize.rowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? store.activeAccent : Color.clear)
            )
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.a11yIncreaseContrast && isSelected ? Color.primary : Color.clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(colloquial)")
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(isLeftSidebarUltraSkinny ? KroutonL10n.tr("FORMATS") : KroutonL10n.tr("FORMAT CHOOSER"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager, pane: .formatChooser)
                } label: {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(store.uiSecondaryAccent)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Configure visible formats in Settings -> Format Chooser")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("BURN"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary)
                            .padding(.horizontal, 10)

                        ForEach(store.discFormats.filter { $0.showInTaskChooser }) { fmt in
                            taskRowButton(
                                id: fmt.id,
                                category: .burn,
                                title: fmt.technicalName,
                                shortTitle: fmt.exactShortDisplayName,
                                colloquial: fmt.colloquialName,
                                badge: fmt.sourceSupport,
                                sfSymbol: fmt.sfSymbol
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("DISC IMAGE DEPOT"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "depot-all",
                            category: .depot,
                            title: "All Depot Library (60+)",
                            shortTitle: "All Depot",
                            colloquial: "Complete Verified Optical Catalog",
                            sfSymbol: "square.grid.2x2.fill"
                        )
                        taskRowButton(
                            id: "depot-rescue",
                            category: .depot,
                            title: "System Rescue & BIOS",
                            shortTitle: "Rescue & BIOS",
                            colloquial: "SystemRescue, GParted, Memtest, UBCD",
                            sfSymbol: "cross.case.fill"
                        )
                        taskRowButton(
                            id: "depot-linux",
                            category: .depot,
                            title: "Live Linux & BSD",
                            shortTitle: "Linux & BSD",
                            colloquial: "Ubuntu, Fedora, Debian, FreeBSD, Arch",
                            sfSymbol: "terminal.fill"
                        )
                        taskRowButton(
                            id: "depot-vintage",
                            category: .depot,
                            title: "Vintage Mac & Apple",
                            shortTitle: "Vintage Mac",
                            colloquial: "Mac OS 9.2.2, System 7.5, A/UX, AHT",
                            sfSymbol: "desktopcomputer"
                        )
                        taskRowButton(
                            id: "depot-homebrew",
                            category: .depot,
                            title: "Console Homebrew & ROMs",
                            shortTitle: "Console ROMs",
                            colloquial: "Swiss GC, FreeDVDBoot PS2, 240p Suite",
                            sfSymbol: "gamecontroller.fill"
                        )
                        taskRowButton(
                            id: "depot-coverdiscs",
                            category: .depot,
                            title: "90s Cover Discs & Scene",
                            shortTitle: "Cover Discs",
                            colloquial: "MacAddict, PC Gamer, NextGen, Scene.org",
                            sfSymbol: "sparkles.tv.fill"
                        )
                        taskRowButton(
                            id: "depot-retropc",
                            category: .depot,
                            title: "Retro PC, DOS & Alt OS",
                            shortTitle: "Retro PC",
                            colloquial: "FreeDOS 1.4, Haiku, BeOS R5, OS/2, IRIX",
                            sfSymbol: "cpu.fill"
                        )
                    }

                    Divider().padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("COPY"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "copy-duplicate",
                            category: .copy,
                            title: "Duplicate Disc",
                            shortTitle: "Duplicate",
                            colloquial: "Fit-to-Disc DVD-9 / BD Shrink",
                            badge: "1:1 / Fit",
                            sfSymbol: "doc.on.doc.fill"
                        )
                        taskRowButton(
                            id: "copy-rip-audio",
                            category: .copy,
                            title: "Rip Audio CD",
                            shortTitle: "Rip Audio",
                            colloquial: "ALAC, AAC, FLAC + AccurateRip",
                            badge: "Extract",
                            sfSymbol: "waveform.badge.plus"
                        )
                        taskRowButton(
                            id: "copy-rip-video",
                            category: .copy,
                            title: "Extract Video Disc",
                            shortTitle: "Rip Video",
                            colloquial: "Hardware H.265 / HEVC Passthrough",
                            badge: "H.265",
                            sfSymbol: "film.stack"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("LABEL"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "label-auto",
                            category: .label,
                            title: "Automatic Disc Label",
                            shortTitle: "Auto Label",
                            colloquial: "Artwork Lookup + Hole Avoidance",
                            badge: "120mm",
                            sfSymbol: "wand.and.stars"
                        )
                        taskRowButton(
                            id: "label-manual",
                            category: .label,
                            title: "Manual Disc Label",
                            shortTitle: "Manual Label",
                            colloquial: "120mm / 18mm Canvas Studio",
                            badge: "Custom",
                            sfSymbol: "printer.dotmatrix.fill"
                        )
                    }
                }
                .padding(10)
            }
        }
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
        .background(Color.kroutonControlSurface)
    }

}

struct KroutonCentralWorkspaceCapacityBarView: View {
    @ObservedObject var store: KroutonStateStore
    let activeDiscCapacityBytes: Int64
    let primarySelectedDrive: KroutonToasterInfo?

    var body: some View {
        let usedB = store.totalStagedBytes
        let totalB = max(1, activeDiscCapacityBytes)
        let freeB = max(0, totalB - usedB)
        let ratio = min(1.0, Double(usedB) / Double(totalB))
        let isOverburn = usedB > totalB
        let mediaLabel = primarySelectedDrive?.isMediaPresent == true
            ? (primarySelectedDrive?.mediaType ?? "Optical Disc")
            : (store.discFormats.first(where: { $0.id == store.selectedTaskID })?.capacity ?? "4.7 GB Target")

        return VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                // 1. Wide Workspace Layout
                HStack(spacing: 6) {
                    Label("DISC SPACE (\(mediaLabel))", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Used: \(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) (\(store.totalStagedSectorsLBA) LBA)")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text("Free: \(ByteCountFormatter.string(fromByteCount: freeB, countStyle: .file))")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(KroutonDesign.Typography.telemetryMono)
                        .contentTransition(.numericText())
                        .foregroundStyle(isOverburn ? Color.red : store.uiSecondaryAccent)
                        .lineLimit(1)
                }

                // 2. Compact / Narrow Workspace Fallback (Zero Multi-Line Wrapping!)
                HStack(spacing: 6) {
                    Text("\(mediaLabel):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalB, countStyle: .file))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOverburn ? Color.red : store.uiSecondaryAccent)
                        .lineLimit(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverburn ? AnyShapeStyle(Color.red) : (store.enableSecondaryAccentUITints ? AnyShapeStyle(LinearGradient(colors: [store.activeAccent, store.activeSecondaryAccent], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(store.activeAccent)))
                        .frame(width: max(4, geo.size.width * ratio))
                    Rectangle()
                        .fill(Color.yellow.opacity(0.65))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * 0.96)
                }
            }
            .frame(height: 7)
        }
        .padding(10)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.14) : Color.clear)
        .background(Color.kroutonControlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.32) : Color.clear, lineWidth: 1))
        .accessibilityLabel(String(format: "Disc capacity %.1f percent full", ratio * 100.0))
    }

}

struct KroutonBurnStationWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let primarySelectedDrive: KroutonToasterInfo?
    let isCenterWorkspaceNarrow: Bool
    @Binding var enableCustomFinderLayoutTab: Bool
    @Binding var finderIconSize: Double
    @Binding var fitToDiscDVD9Shrink: Bool
    let preserveMenusAndExtras: Bool
    @Binding var cdTextAlbumTitle: String
    @Binding var cdTextAlbumPerformer: String
    @Binding var auditioningTrackID: UUID?
    @Binding var isDropTargeted: Bool
    let onPromptToAddFiles: () -> Void
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    func addButtonTitle(for spec: KroutonRecipeSpec) -> String {
        if spec.isRedBookAudioFormat {
            return "Add Audio Tracks (WAV / AIFF / FLAC / MP3)..."
        } else if spec.isCarSafeAudioFormat {
            return "Add Audio Files or Album Folders..."
        } else if spec.isVideoAuthoringFormat {
            return "Add Video Titles (MKV / MP4 / MOV / VIDEO_TS)..."
        } else if spec.isDiscImageBurnFormat {
            return "Select Disc Image (.ISO / .DMG / .BIN / .CUE / .CDR / .TOAST)..."
        } else if spec.id == "console-wii" {
            return "Select Wii Image (.RVZ / .WBFS / .ISO)..."
        } else if spec.id == "console-gc" {
            return "Select GameCube Image (.RVZ / .GCM / .ISO)..."
        } else if spec.id == "console-ps2" {
            return "Select PS2 Image (.ISO / .CHD / .BIN+.CUE)..."
        } else if spec.id == "console-ps1" {
            return "Select PS1 Image (.CUE+.BIN / .CHD / .CCD)..."
        } else if spec.id == "console-xbox" {
            return "Select Xbox Image (.ISO / .XISO / .DVD)..."
        } else if (spec.filterGroup == .console || spec.id.hasPrefix("console-")) {
            return "Select Console Image..."
        } else {
            return "Add Files or Folders..."
        }
    }

    func addButtonSymbol(for spec: KroutonRecipeSpec) -> String {
        if spec.isRedBookAudioFormat || spec.isCarSafeAudioFormat {
            return "waveform.badge.plus"
        } else if spec.isVideoAuthoringFormat {
            return "film.stack.fill"
        } else if spec.isDiscImageBurnFormat {
            return "opticaldisc.fill"
        } else if (spec.filterGroup == .console || spec.id.hasPrefix("console-")) {
            return "gamecontroller.fill"
        } else {
            return "plus.rectangle.on.folder.fill"
        }
    }

    // ==========================================================================
    // 1. RED BOOK AUDIO CD (CD-DA) & CD-EXTRA WAVEBURNER MASTERING STUDIO
    // ==========================================================================


    // ==========================================================================
    // 2. CAR-SAFE MP3 / FLAC AUDIO CD WORKSPACE (Head-Unit Sorting & Sanitizer)
    // ==========================================================================


    // ==========================================================================
    // 3. VIDEO DISC AUTHORING STUDIO (DVD-Video, AVCHD, BD-R SL/DL, UHD-BD)
    // ==========================================================================


    // ==========================================================================
    // 4. RETRO CONSOLE ROM & SECTOR VERIFICATION WORKSPACE (PS1/PS2/GC/Wii/Xbox)
    // ==========================================================================


    // ==========================================================================
    // 5A. DEDICATED DISC IMAGE (.ISO / .BIN / .DMG / .CDR) FULL-WORKSPACE DECK
    //     (Single-Image Radial Platter, Live LBA Hex Scope & Actionable Pills)
    // ==========================================================================


    // ==========================================================================
    // 5B. NEW DATA & ARCHIVAL DISC AUTHORING WORKSPACE
    //     (Author File/Folder Trees with Universal Bridge & Per-File OS Visibility)
    // ==========================================================================


    // MARK: - Retro Console ROM Mastering Deck & Pre-Flight Sanity Engine


    func currentPreFlightSanityWarning(for spec: KroutonRecipeSpec) -> String? {
        if (spec.filterGroup == .console || spec.id.hasPrefix("console-")), let drive = primarySelectedDrive, drive.isMediaPresent && drive.isMediaErasable {
            return "Retro Console Pickup Warning: \(drive.displayName) has rewritable \(drive.mediaType) loaded (~20% reflectivity). Vintage PS1/PS2/GameCube/Dreamcast optical pickups require high-reflectivity write-once CD-R or DVD-R media at 4x–8x."
        }
        if spec.id == "console-ps1" && !store.stagedFiles.isEmpty {
            let hasBin = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".bin") }
            let hasCue = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".cue") || $0.name.lowercased().hasSuffix(".ccd") }
            if hasBin && !hasCue {
                return "Missing .CUE Descriptor: A raw .BIN track is staged without its companion .CUE sheet. Add the .CUE file to preserve Red Book audio tracks and 2-second pre-gap offsets."
            }
        }
        if let hugeFile = store.stagedFiles.first(where: { $0.exceedsISO9660FourGiBLimit }) {
            return "4 GiB File Limit Notice: '\(hugeFile.name)' exceeds the 4 GiB ISO9660 Level 2 ceiling. Krouton will bridge this file via UDF 2.60 + HFS+."
        }
        if let longFile = store.stagedFiles.first(where: { $0.exceedsJoliet64CharLimit }) {
            return "Joliet 64-Char Notice: '\(longFile.name)' is \(longFile.name.count) characters long. Full name is preserved on Mac (HFS+) and UDF, and safely truncated in legacy Windows Joliet tables."
        }
        return nil
    }


    var body: some View {
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID }) ?? store.discFormats[0]
        return VStack(alignment: .leading, spacing: 12) {
            // Format Header Bar with Context-Sensitive Add Action (Responsive & Zero Vertical Word-Towers)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        KroutonStyledIconBadge(
                            sfSymbol: activeSpec.sfSymbol,
                            tintColor: store.activeAccent,
                            style: store.iconWidgetStyle,
                            size: 28,
                            symbolSize: 15
                        )
                        let isCDDA = (activeSpec.id == "cd-da")
                        Text(isCDDA ? KroutonL10n.tr("Audio CD") : (isCenterWorkspaceNarrow ? activeSpec.exactShortDisplayName : activeSpec.technicalName))
                            .font(.title3.bold())
                            .lineLimit(1)
                        if !isCenterWorkspaceNarrow && !isCDDA {
                            Text(activeSpec.colloquialName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    if !isCenterWorkspaceNarrow {
                        Text("Spec: \(activeSpec.bookOrFileSystem) • Laser: \(activeSpec.laserType) • Source: \(activeSpec.sourceSupport)")
                            .font(.caption)
                            .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.82) : Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)

                if !store.stagedFiles.isEmpty {
                    Button {
                        auditioningTrackID = nil
                        store.clearStagedFiles()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            if !isCenterWorkspaceNarrow {
                                Text(KroutonL10n.tr("Clear All"))
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.kroutonControlSurface)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onPromptToAddFiles()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: addButtonSymbol(for: activeSpec))
                        Text(isCenterWorkspaceNarrow ? KroutonL10n.tr("Add Files...") : KroutonL10n.tr(addButtonTitle(for: activeSpec)))
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Pre-Flight Sanity Banner (Always active across all formats)
            if let sanityWarning = currentPreFlightSanityWarning(for: activeSpec) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    Text(sanityWarning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.orange.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }

            // FORMAT-ADAPTIVE WORKSPACE ROUTER (Standalone Scoped View Structs)
            if activeSpec.isRedBookAudioFormat {
                KroutonRedBookAudioWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    cdTextAlbumTitle: $cdTextAlbumTitle,
                    cdTextAlbumPerformer: $cdTextAlbumPerformer,
                    auditioningTrackID: $auditioningTrackID,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.isCarSafeAudioFormat {
                KroutonCarSafeAudioWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.isVideoAuthoringFormat {
                KroutonVideoAuthoringWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    fitToDiscDVD9Shrink: $fitToDiscDVD9Shrink,
                    preserveMenusAndExtras: preserveMenusAndExtras,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.isDiscImageBurnFormat {
                KroutonDiscImageInspectorWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isDropTargeted: $isDropTargeted,
                    onPromptToAddFiles: onPromptToAddFiles,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.filterGroup == .console || activeSpec.id.hasPrefix("console-") {
                KroutonRetroConsoleWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else {
                KroutonDataAndArchivalWorkspaceView(
                    store: store,
                    activeSpec: activeSpec,
                    enableCustomFinderLayoutTab: $enableCustomFinderLayoutTab,
                    finderIconSize: $finderIconSize,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            }
        }
    }

}
