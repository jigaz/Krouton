//
//  KroutonNavigationAndTelemetryBars.swift
//  Krouton — Optical Media Mastering Studio
//
//  Left Format Chooser Sidebar, Top Hardware Telemetry Header Bar, Center Router, and Bottom Capacity Bar.
//

import Combine
import Foundation
import OpticalDough
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

extension KroutonMainWorkspaceView {
    var leftFormatChooserColumn: some View {
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

    var centralWorkspaceCapacityBar: some View {
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

    var depotWorkspaceView: some View {
        let heroMeta = depotChannelHeadline
        let heroItem = depotHeroSelectedItem

        return GeometryReader { geo in
            let isNarrowWorkspace = isCenterWorkspaceNarrow

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Clean Sub-Library Header + Search Bar (NO top category pills!)
                HStack(spacing: 10) {
                    KroutonStyledIconBadge(
                        sfSymbol: heroItem.sfSymbol,
                        tintColor: store.activeAccent,
                        style: store.iconWidgetStyle,
                        size: 28,
                        symbolSize: 14
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(KroutonL10n.tr(heroMeta.title))
                            .font(.title3.bold())
                            .lineLimit(1)
                        Text(KroutonL10n.tr(heroMeta.subtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField(KroutonL10n.tr("Filter or search archive.org..."), text: $depotSearchQuery)
                            .textFieldStyle(.plain)
                            .frame(minWidth: 140, maxWidth: 210)
                            .onSubmit {
                                store.selectedTaskID = "depot-ia-live"
                                store.queryInternetArchiveLive(query: depotSearchQuery)
                            }
                        if !depotSearchQuery.isEmpty {
                            Button {
                                depotSearchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            store.selectedTaskID = "depot-ia-live"
                            store.queryInternetArchiveLive(query: depotSearchQuery)
                        } label: {
                            HStack(spacing: 4) {
                                if store.isSearchingInternetArchive {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 9))
                                }
                                Text("Archive.org API")
                                .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.primary)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .help("Query live Internet Archive REST API (archive.org/advancedsearch.php) for optical ISO / CD-ROM images")
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 4)
                    .padding(.vertical, 3)
                    .background(Color.kroutonControlSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                }

                // Row 2: Interactive Hero Inspector Zone (Shows details of whichever title card is clicked!)
                depotInteractiveHeroBanner(for: heroItem, isNarrow: isNarrowWorkspace)

                // Row 3: Active Staged Image Ready-to-Burn Dock
                if let stagedEntry = store.stagedFiles.first {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text("STAGED IN BURN QUEUE:")
                                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                                Text(stagedEntry.name)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                            }
                            Text("\(ByteCountFormatter.string(fromByteCount: stagedEntry.byteSize, countStyle: .file)) (\(stagedEntry.sectorsLBA) LBA Sectors) — Ready for physical burn or hex sector inspection.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Button {
                            store.selectedCategory = .burn
                            store.selectedTaskID = "image-burn"
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                Text("Inspect Sector & Hex Map")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.clearStagedFiles()
                            store.stagedDepotItemID = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Unstage")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(store.uiSecondaryAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.uiSecondaryAccent.opacity(0.42), lineWidth: 1))
                }

                // Row 4: Sub-Library Grid Header
                HStack {
                    Text("\(heroMeta.badge)  •  CLICK ANY TITLE BELOW TO INSPECT IN HERO DECK")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(filteredDepotItems.count) Titles in Sub-Library  •  SHA-256 Verified")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent))
                        .lineLimit(1)
                }

                // Row 5: Scrollable Responsive 1-or-2 Column Sub-Library Card Grid
                ScrollView {
                    LazyVGrid(
                        columns: isNarrowWorkspace
                            ? [GridItem(.flexible(), spacing: 10)]
                            : [GridItem(.flexible(minimum: 300), spacing: 10), GridItem(.flexible(minimum: 300), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(filteredDepotItems) { item in
                            depotAppStoreCard(for: item, isSelectedInHero: item.id == heroItem.id)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    var burnWorkspaceView: some View {
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
                        Text(isCenterWorkspaceNarrow ? activeSpec.exactShortDisplayName : activeSpec.technicalName)
                            .font(.title3.bold())
                            .lineLimit(1)
                        if !isCenterWorkspaceNarrow {
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
                    promptToAddFiles()
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

            // FORMAT-ADAPTIVE WORKSPACE ROUTER
            if activeSpec.isRedBookAudioFormat {
                redBookAudioMasteringWorkspace(for: activeSpec)
            } else if activeSpec.isCarSafeAudioFormat {
                carSafeAudioMasteringWorkspace(for: activeSpec)
            } else if activeSpec.isVideoAuthoringFormat {
                videoDiscAuthoringWorkspace(for: activeSpec)
            } else if activeSpec.isDiscImageBurnFormat {
                discImageInspectorWorkspace(for: activeSpec)
            } else if activeSpec.id.hasPrefix("game-") {
                retroConsoleROMWorkspace(for: activeSpec)
            } else {
                dataAndArchivalMasteringWorkspace(for: activeSpec)
            }
        }
    }

    @MainActor
    private func exportDiscLabelAsPNG(preset: KroutonSliceLabelGeometry) {
        let exportView = KroutonDiscLabelArtworkCanvas(
            preset: preset,
            template: store.selectedLabelTemplate,
            title: labelDiscTitle,
            subtitle: labelSubtitle,
            performer: store.discPerformer,
            mcnBarcode: store.discMCNBarcode,
            trackLines: resolvedLabelTracklistLines,
            showTracklist: store.labelShowTracklistOnDisc,
            primaryColor: store.activeAccent,
            harmonyColor: store.uiSecondaryAccent,
            isExportMode: true,
            diameterPoints: 720.0
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0 // 1440x1440 px (>300 DPI for 120mm optical disc)
        guard let cgImage = renderer.cgImage else { return }
        let mutableData = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return }
        let pngData = mutableData as Data
        KroutonLabelExportBridge.shared.presentPNGExport(
            pngData: pngData,
            defaultFilename: "\(labelDiscTitle.replacingOccurrences(of: " ", with: "_"))_120mm_Label.png"
        )
    }

    private var resolvedLabelTracklistLines: [String] {
        if !store.stagedFiles.isEmpty {
            return store.stagedFiles.prefix(8).enumerated().map { idx, f in
                String(format: "%02d. %@", idx + 1, f.name)
            }
        }
        return store.redBookTracks.prefix(8).map { $0.title }
    }

    var labelWorkspaceView: some View {
        let preset = store.labelPresets[min(store.selectedLabelPresetIndex, store.labelPresets.count - 1)]
        let arcGlyphs = store.computeLiveDiscLabelArcGlyphs(title: labelDiscTitle, radiusPoints: 500.0)

        return GeometryReader { labelGeo in
            let availW = labelGeo.size.width
            let availH = labelGeo.size.height
            let useStackedLayout = availW < 650
            let dynamicDiscDiameter: CGFloat = useStackedLayout
                ? min(max(210, availW - 48), 280)
                : min(max(220, availW - 350), min(340, max(220, availH - 110)))

            VStack(alignment: .leading, spacing: 10) {
                // Responsive Header Bar: Wraps cleanly onto 2 rows when narrow (Zero Vertical Green Cucumber!)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        labelHeaderTitleBlock(preset: preset)
                        Spacer(minLength: 8)
                        labelHeaderControlsBlock(preset: preset)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        labelHeaderTitleBlock(preset: preset)
                        HStack(spacing: 10) {
                            labelHeaderControlsBlock(preset: preset)
                            Spacer(minLength: 0)
                        }
                    }
                }

                Divider()

                if useStackedLayout {
                    // NARROW / COMPACT MODE: Clean Vertical ScrollView (Disc Preview on Top, Controls Below)
                    ScrollView {
                        VStack(alignment: .center, spacing: 16) {
                            labelLiveDiscPreviewPanel(preset: preset, diameter: dynamicDiscDiameter, glyphCount: arcGlyphs.count)
                            Divider()
                            labelInspectorControlsPanel(preset: preset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, 12)
                    }
                } else {
                    // WIDE STUDIO MODE: Resizable Left Controls + Right Live Display-P3 Polar Disc Canvas
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView {
                            labelInspectorControlsPanel(preset: preset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: min(320, max(255, availW * 0.44)))

                        Divider()

                        VStack {
                            Spacer(minLength: 0)
                            labelLiveDiscPreviewPanel(preset: preset, diameter: dynamicDiscDiameter, glyphCount: arcGlyphs.count)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func labelHeaderTitleBlock(preset: KroutonSliceLabelGeometry) -> some View {
        HStack(spacing: 10) {
            KroutonStyledIconBadge(
                sfSymbol: store.selectedTaskID == "label-auto" ? "wand.and.stars" : "printer.dotmatrix.fill",
                tintColor: store.activeAccent,
                style: store.iconWidgetStyle,
                size: 28,
                symbolSize: 14
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(store.selectedTaskID == "label-auto" ? "Automatic Disc Label Studio" : "120mm / 80mm Optical Disc Label Studio")
                    .font(.title3.bold())
                    .lineLimit(1)
                Text(String(format: "%@ • Outer %.0fmm / Hub %.0fmm • Offset X:%.1f Y:%.1fmm", preset.name, preset.outerDiameterMM, preset.innerDiameterMM, preset.offsetXMM, preset.offsetYMM))
                    .font(.caption)
                    .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : .secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func labelHeaderControlsBlock(preset: KroutonSliceLabelGeometry) -> some View {
        HStack(spacing: 8) {
            Picker("Tray:", selection: $store.selectedLabelPresetIndex) {
                ForEach(Array(store.labelPresets.enumerated()), id: \.offset) { idx, item in
                    Text(item.name).tag(idx)
                }
            }
            .labelsHidden()
            .frame(minWidth: 145, maxWidth: 205)

            Button {
                exportDiscLabelAsPNG(preset: preset)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Export 300-DPI PNG...")
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(store.activeAccent)
                .foregroundStyle(store.activeOnAccentText)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .help("Render a 1,417×1,417 px (300 DPI) transparent-hub disc label PNG")
        }
    }

    @ViewBuilder
    private func labelInspectorControlsPanel(preset: KroutonSliceLabelGeometry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.selectedTaskID == "label-auto" {
                VStack(alignment: .leading, spacing: 6) {
                    Text(KroutonL10n.tr("Automatic Cover & Metadata Lookup"))
                        .font(.subheadline.bold())
                    HStack(spacing: 6) {
                        TextField("Album, Movie, or Game...", text: $autoLabelSearchQuery)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            if !autoLabelSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                                labelDiscTitle = autoLabelSearchQuery.uppercased()
                                labelSubtitle = "MASTERED IN KROUTON • SHA-256 VERIFIED"
                            }
                        } label: {
                            Text("Fetch")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(store.activeAccent)
                                .foregroundStyle(store.activeOnAccentText)
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Avoids the \(Int(preset.innerDiameterMM))mm center spindle hole automatically.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Divider()
            }

            // 2x2 Compact Template Selector Grid (Replaces the 580pt overflowing segmented Picker!)
            VStack(alignment: .leading, spacing: 6) {
                Text("Studio Harmony Template")
                    .font(.subheadline.bold())
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(KroutonCroutonLabelStyle.allCases) { tpl in
                        let isSel = (store.selectedLabelTemplate == tpl)
                        Button {
                            store.selectedLabelTemplate = tpl
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isSel ? store.activeOnAccentText : store.activeAccent)
                                    .frame(width: 6, height: 6)
                                Text(tpl.rawValue)
                                    .font(.system(size: 10.5, weight: isSel ? .bold : .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(isSel ? store.activeAccent : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(isSel ? store.activeOnAccentText : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Disc Typography & Tracklist Manifest Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(KroutonL10n.tr("Disc Face Typography"))
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        labelDiscTitle = store.discVolumeTitle
                        if !store.stagedFiles.isEmpty {
                            labelSubtitle = "\(store.stagedFiles.count) ITEMS • \(ByteCountFormatter.string(fromByteCount: store.totalStagedBytes, countStyle: .file))"
                        } else {
                            labelSubtitle = "44.1 KHZ 16-BIT RED BOOK PCM • \(store.discPerformer.uppercased())"
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync from Project")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(store.uiSecondaryAccent.opacity(0.18))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .help("Populate title, performer, MCN, and tracklist from your active Burn/Audio/Data project")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary Title (Top Polar Arc):")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("Primary Arc Title", text: $labelDiscTitle)
                        .textFieldStyle(.roundedBorder)

                    Text("Bottom Subtitle / Format Spec:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("Bottom Subtitle / Track Summary", text: $labelSubtitle)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Artist / Authored By:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("Performer", text: $store.discPerformer)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MCN / Catalog:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("0123456789012", text: $store.discMCNBarcode)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                }

                Toggle("Stamp Tracklist / File Manifest on Disc Face", isOn: $store.labelShowTracklistOnDisc)
                    .toggleStyle(.checkbox)
                    .font(.caption.bold())
            }
        }
    }

    @ViewBuilder
    private func labelLiveDiscPreviewPanel(preset: KroutonSliceLabelGeometry, diameter: CGFloat, glyphCount: Int) -> some View {
        VStack(spacing: 8) {
            KroutonDiscLabelArtworkCanvas(
                preset: preset,
                template: store.selectedLabelTemplate,
                title: labelDiscTitle,
                subtitle: labelSubtitle,
                performer: store.discPerformer,
                mcnBarcode: store.discMCNBarcode,
                trackLines: resolvedLabelTracklistLines,
                showTracklist: store.labelShowTracklistOnDisc,
                primaryColor: store.activeAccent,
                harmonyColor: store.uiSecondaryAccent,
                isExportMode: false,
                diameterPoints: diameter
            )
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed.inset.filled")
                    .foregroundStyle(store.activeAccent)
                Text("Crustini 300-DPI Polar Engine (\(glyphCount) Arc Glyphs • \(Int(preset.outerDiameterMM))mm/\(Int(preset.innerDiameterMM))mm)")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    var rightDestinationColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Label(
                    isRightQueueCompact ? "QUEUE (\(store.destinationQueue.count))" : "DESTINATIONS (\(store.destinationQueue.count))",
                    systemImage: "arrow.right.doc.on.clipboard"
                )
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.secondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    appendContextAwareDestination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        if !isRightQueueCompact {
                            Text(KroutonL10n.tr("Add Output"))
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.uiSecondaryAccent.opacity(0.2))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Iterating directly over store.destinationQueue by UUID (Zero raw array indices = Zero crashes!)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.destinationQueue) { item in
                        destinationCard(item: item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }

            Divider()

            if driveManager.isExecutingQueue || driveManager.activeJobProgress > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(driveManager.activeJobPhase)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f%%", driveManager.activeJobProgress * 100.0))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    ProgressView(value: driveManager.activeJobProgress, total: 1.0)
                        .tint(store.activeAccent)
                    if !driveManager.activeJobDetail.isEmpty {
                        Text(driveManager.activeJobDetail)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            VStack(spacing: 8) {
                Button {
                    executeDestinationQueue()
                } label: {
                    HStack {
                        Image(systemName: driveManager.isExecutingQueue ? "stop.circle.fill" : primaryActionSymbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(driveManager.isExecutingQueue ? "ABORT BURN" : primaryActionTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(driveManager.isExecutingQueue ? Color.red : store.activeAccent)
                    .foregroundStyle(driveManager.isExecutingQueue ? Color.white : store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Queue Ready • \(store.stagedFiles.count) Items (\(ByteCountFormatter.string(fromByteCount: store.totalStagedBytes, countStyle: .file)))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
        .background(Color.kroutonControlSurface)
    }
}


// MARK: - 120mm Optical Disc Label Studio Artwork Renderer (Primary + Secondary Harmony)
struct KroutonDiscLabelArtworkCanvas: View {
    let preset: KroutonSliceLabelGeometry
    let template: KroutonCroutonLabelStyle
    let title: String
    let subtitle: String
    let performer: String
    let mcnBarcode: String
    let trackLines: [String]
    let showTracklist: Bool
    let primaryColor: Color
    let harmonyColor: Color
    let isExportMode: Bool
    let diameterPoints: CGFloat

    var body: some View {
        let holeRatio = CGFloat(max(0.12, min(0.45, preset.innerDiameterMM / max(1.0, preset.outerDiameterMM))))
        let holeDiameter = diameterPoints * holeRatio

        ZStack {
            // 1. Base Disc Surface by Template
            switch template {
            case .synthGrid:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.08, green: 0.09, blue: 0.12),
                                Color(red: 0.04, green: 0.05, blue: 0.07)
                            ],
                            center: .center,
                            startRadius: holeDiameter * 0.4,
                            endRadius: diameterPoints * 0.52
                        )
                    )
                    .overlay(
                        Circle()
                            .fill(primaryColor.opacity(0.24))
                    )
            case .vinylGrooves:
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                primaryColor.opacity(0.85),
                                Color.black.opacity(0.92),
                                harmonyColor.opacity(0.75),
                                Color.black.opacity(0.92),
                                primaryColor.opacity(0.85)
                            ],
                            center: .center
                        )
                    )
            case .dualHalftone:
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, Color(red: 0.07, green: 0.08, blue: 0.10), harmonyColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            case .archivalSpec:
                Circle()
                    .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                    .overlay(
                        Circle().strokeBorder(primaryColor, lineWidth: diameterPoints * 0.035)
                    )
            }

            // 2. Precision CAD Grid / Concentric Telemetry Rings
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxR = size.width / 2

                if template == .synthGrid || template == .archivalSpec {
                    let step: CGFloat = size.width / 16.0
                    var grid = Path()
                    for x in stride(from: CGFloat(0), through: size.width, by: step) {
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat(0), through: size.height, by: step) {
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(
                        grid,
                        with: .color(template == .archivalSpec ? primaryColor.opacity(0.16) : harmonyColor.opacity(0.18)),
                        lineWidth: 0.75
                    )
                }

                // Concentric LBA / Groove rings
                for frac in [0.92, 0.78, 0.64, 0.46] {
                    let r = maxR * CGFloat(frac)
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    let ringPath = Path(ellipseIn: rect)
                    context.stroke(
                        ringPath,
                        with: .color(frac == 0.78 ? harmonyColor.opacity(0.65) : primaryColor.opacity(0.40)),
                        style: StrokeStyle(lineWidth: frac == 0.92 ? 2.0 : 1.0, dash: frac == 0.64 ? [5, 3] : [])
                    )
                }

                // Crosshair registration ticks around the hub
                var ticks = Path()
                ticks.move(to: CGPoint(x: center.x, y: size.height * 0.04))
                ticks.addLine(to: CGPoint(x: center.x, y: size.height * 0.12))
                ticks.move(to: CGPoint(x: center.x, y: size.height * 0.88))
                ticks.addLine(to: CGPoint(x: center.x, y: size.height * 0.96))
                ticks.move(to: CGPoint(x: size.width * 0.04, y: center.y))
                ticks.addLine(to: CGPoint(x: size.width * 0.12, y: center.y))
                ticks.move(to: CGPoint(x: size.width * 0.88, y: center.y))
                ticks.addLine(to: CGPoint(x: size.width * 0.96, y: center.y))
                context.stroke(ticks, with: .color(harmonyColor.opacity(0.75)), lineWidth: 1.2)
            }
            .clipShape(Circle())

            // 3. Disc Typography & Staged Tracklist Manifest (Left & Right of Spindle Hub)
            let fgText: Color = (template == .archivalSpec) ? Color.black.opacity(0.88) : .white
            let badgeBg: Color = (template == .archivalSpec) ? primaryColor : harmonyColor

            VStack(spacing: 2) {
                Text("KROUTON OPTICAL MASTER")
                    .font(.system(size: diameterPoints * 0.026, weight: .heavy, design: .monospaced))
                    .foregroundStyle(template == .archivalSpec ? primaryColor : harmonyColor)
                    .padding(.top, diameterPoints * 0.085)

                Text(title.isEmpty ? "KROUTON_DISC" : title)
                    .font(.system(size: diameterPoints * 0.046, weight: .black, design: .rounded))
                    .foregroundStyle(fgText)
                    .lineLimit(1)
                    .frame(maxWidth: diameterPoints * 0.68)

                Spacer()

                // Left & Right Wing Panels flanking the spindle hole
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DISC SPEC")
                            .font(.system(size: diameterPoints * 0.024, weight: .heavy, design: .monospaced))
                            .foregroundStyle(badgeBg)
                        Text("120mm OPTICAL")
                        Text("MCN \(mcnBarcode.prefix(8))")
                        Text("ECC VERIFIED")
                    }
                    .font(.system(size: diameterPoints * 0.023, weight: .bold, design: .monospaced))
                    .foregroundStyle(fgText.opacity(0.86))
                    .frame(width: diameterPoints * 0.27, alignment: .leading)

                    Spacer(minLength: holeDiameter + 14)

                    if showTracklist {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("MANIFEST")
                                .font(.system(size: diameterPoints * 0.024, weight: .heavy, design: .monospaced))
                                .foregroundStyle(badgeBg)
                            ForEach(Array(trackLines.prefix(5).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: diameterPoints * 0.022, weight: .semibold, design: .monospaced))
                        .foregroundStyle(fgText.opacity(0.88))
                        .frame(width: diameterPoints * 0.29, alignment: .leading)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PERFORMER")
                                .font(.system(size: diameterPoints * 0.024, weight: .heavy, design: .monospaced))
                                .foregroundStyle(badgeBg)
                            Text(performer)
                                .lineLimit(1)
                        }
                        .font(.system(size: diameterPoints * 0.024, weight: .bold, design: .monospaced))
                        .foregroundStyle(fgText.opacity(0.88))
                        .frame(width: diameterPoints * 0.27, alignment: .trailing)
                    }
                }
                .padding(.horizontal, diameterPoints * 0.06)

                Spacer()

                Text(subtitle.isEmpty ? "ISO9660 / UDF / RED BOOK MASTER" : subtitle)
                    .font(.system(size: diameterPoints * 0.030, weight: .bold, design: .monospaced))
                    .foregroundStyle(fgText.opacity(0.90))
                    .lineLimit(1)
                    .frame(maxWidth: diameterPoints * 0.64)

                Text(String(format: "OUTER %.0fMM • HUB %.0fMM", preset.outerDiameterMM, preset.innerDiameterMM))
                    .font(.system(size: diameterPoints * 0.023, weight: .heavy, design: .monospaced))
                    .foregroundStyle(template == .archivalSpec ? primaryColor : harmonyColor)
                    .padding(.bottom, diameterPoints * 0.085)
            }
            .frame(width: diameterPoints, height: diameterPoints)

            // 4. Outer Polycarbonate Rim & Clamping Ring + Center Spindle Cutout
            Circle()
                .strokeBorder(harmonyColor.opacity(0.75), lineWidth: 2.0)
                .frame(width: diameterPoints, height: diameterPoints)

            Circle()
                .stroke(primaryColor.opacity(0.55), style: StrokeStyle(lineWidth: 3.0, dash: [6, 3]))
                .frame(width: holeDiameter + 18, height: holeDiameter + 18)

            Circle()
                .fill(isExportMode ? Color.white : Color.kroutonWindowSurface)
                .frame(width: holeDiameter, height: holeDiameter)
                .overlay(
                    Circle()
                        .stroke(harmonyColor.opacity(0.85), lineWidth: 1.5)
                )
        }
        .frame(width: diameterPoints, height: diameterPoints)
        .clipShape(Circle())
    }
}


// MARK: - Native SwiftUI .fileExporter Bridge for 300-DPI 120mm Disc Label PNG
struct KroutonPNGFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var pngData: Data

    init(pngData: Data = Data()) {
        self.pngData = pngData
    }

    init(configuration: ReadConfiguration) throws {
        self.pngData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: pngData)
    }
}

@MainActor
final class KroutonLabelExportBridge: ObservableObject {
    static let shared = KroutonLabelExportBridge()
    @Published var isShowingExporter: Bool = false
    @Published var document: KroutonPNGFileDocument = KroutonPNGFileDocument()
    @Published var defaultFilename: String = "Krouton_120mm_Label.png"

    func presentPNGExport(pngData: Data, defaultFilename: String) {
        self.document = KroutonPNGFileDocument(pngData: pngData)
        self.defaultFilename = defaultFilename
        self.isShowingExporter = true
    }
}

struct KroutonLabelExportSheetModifier: ViewModifier {
    @ObservedObject private var bridge = KroutonLabelExportBridge.shared
    func body(content: Content) -> some View {
        content.fileExporter(
            isPresented: $bridge.isShowingExporter,
            document: bridge.document,
            contentType: .png,
            defaultFilename: bridge.defaultFilename
        ) { result in
            if case .success(let outURL) = result {
                KroutonOSDesktopBridge.revealURLsInFinder([outURL])
            }
        }
    }
}
