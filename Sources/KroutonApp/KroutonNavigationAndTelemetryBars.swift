//
//  KroutonNavigationAndTelemetryBars.swift
//  Krouton — Optical Media Mastering Studio
//
//  Left Format Chooser Sidebar, Top Hardware Telemetry Header Bar, Center Router, and Bottom Capacity Bar.
//

import AppKit
import Combine
import Foundation
import OpticalDough
import SwiftUI
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
                    Image(systemName: "slider.horizontal.3")
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
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(store.discFormats.filter { $0.showInTaskChooser }) { fmt in
                            taskRowButton(
                                id: fmt.id,
                                category: .burn,
                                title: fmt.technicalName,
                                shortTitle: fmt.shortDisplayName,
                                colloquial: fmt.colloquialName,
                                badge: fmt.sourceSupport,
                                sfSymbol: fmt.sfSymbol
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("DISC IMAGE DEPOT"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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
        .background(Color(NSColor.controlBackgroundColor))
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
                        .foregroundStyle(isOverburn ? .red : store.activeAccent)
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
                        .foregroundStyle(isOverburn ? .red : store.activeAccent)
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    .background(Color(NSColor.controlBackgroundColor))
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
                    .background(Color.green.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.green.opacity(0.40), lineWidth: 1))
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
            // Format Header Bar with Context-Sensitive Add Action
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        KroutonStyledIconBadge(
                            sfSymbol: activeSpec.sfSymbol,
                            tintColor: store.activeAccent,
                            style: store.iconWidgetStyle,
                            size: 28,
                            symbolSize: 15
                        )
                        Text(activeSpec.technicalName)
                            .font(.title3.bold())
                        Text(activeSpec.colloquialName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Spec: \(activeSpec.bookOrFileSystem) • Laser: \(activeSpec.laserType) • Launched: \(activeSpec.launchYear) • Source: \(activeSpec.sourceSupport)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if !store.stagedFiles.isEmpty {
                    Button {
                        auditioningTrackID = nil
                        store.clearStagedFiles()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            Text(KroutonL10n.tr("Clear All"))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    promptToAddFiles()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: addButtonSymbol(for: activeSpec))
                        Text(KroutonL10n.tr(addButtonTitle(for: activeSpec)))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
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

    var labelWorkspaceView: some View {
        let preset = store.labelPresets[min(store.selectedLabelPresetIndex, store.labelPresets.count - 1)]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: store.selectedTaskID == "label-auto" ? "wand.and.stars" : "printer.dotmatrix.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedTaskID == "label-auto" ? "Automatic Disc Label (Artwork Lookup)" : "Manual 120mm Disc Label Canvas")
                        .font(.title3.bold())
                    Text(String(format: "Active Geometry Preset: %@ (Outer: %.1fmm / Hole: %.1fmm)", preset.name, preset.outerDiameterMM, preset.innerDiameterMM))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset:", selection: $store.selectedLabelPresetIndex) {
                    ForEach(Array(store.labelPresets.enumerated()), id: \.offset) { idx, item in
                        Text(item.name).tag(idx)
                    }
                }
                .frame(width: 260)
            }
            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    if store.selectedTaskID == "label-auto" {
                        Text(KroutonL10n.tr("Automatic Album / Movie / Game Cover Lookup"))
                            .font(.headline)
                        HStack {
                            TextField("Search Album, Movie, TV Show, or Game...", text: $autoLabelSearchQuery)
                                .textFieldStyle(.roundedBorder)
                            Button("Fetch Art") {}
                        }
                        Text("Queries MusicBrainz, iTunes, TVMaze & GameTDB. Uses Apple Vision to prevent the \(Int(preset.innerDiameterMM))mm hole from cropping faces.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                    }
                    Text(KroutonL10n.tr("Disc Face Typography"))
                        .font(.headline)
                    TextField("Primary Arc Title", text: $labelDiscTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bottom Subtitle / Track Summary", text: $labelSubtitle)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                }
                .frame(width: 300)

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [store.activeAccent.opacity(0.85), Color.black.opacity(0.92)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 150
                            )
                        )
                        .frame(width: 260, height: 260)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))

                    VStack {
                        Text(labelDiscTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 26)
                        Spacer()
                        Text(labelSubtitle)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 26)
                    }
                    .frame(width: 260, height: 260)

                    Circle()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(
                            width: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 260.0,
                            height: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 260.0
                        )
                        .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                }
                Spacer()
            }
            Spacer()
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
                    .background(store.activeAccent.opacity(0.2))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Iterating directly over store.destinationQueue by UUID (Zero raw array indices = Zero crashes!)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.destinationQueue) { item in
                        destinationCard(item: item)
                    }
                }
                .padding(12)
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
                .padding(.horizontal, 14)
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
        .background(Color(NSColor.controlBackgroundColor))
    }
}
