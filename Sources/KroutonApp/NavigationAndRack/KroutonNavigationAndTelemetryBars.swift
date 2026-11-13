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
            store.snapshotCurrentDestinationQueue()
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

    private var capacityTelemetry: (headerLabel: String, compactLabel: String, usedBytes: Int64, totalBytes: Int64, sectorsText: String) {
        // 1. Rip Audio CD / Extract Video Disc -> Local SSD Extraction Target
        if store.selectedCategory == .copy {
            if store.selectedTaskID == "copy-rip-audio" || store.selectedTaskID == "copy-audio-rip" {
                let estBytes: Int64 = 285_000_000 // ~285 MB Lossless Audio Rip
                let ssdFree: Int64 = 64_000_000_000
                return ("EXTRACTION TARGET (LOCAL SSD)", "SSD Target", estBytes, ssdFree, "5 PCM Tracks")
            } else if store.selectedTaskID == "copy-rip-video" {
                let estBytes: Int64 = 4_380_000_000 // ~4.38 GB MKV / HEVC Extract
                let ssdFree: Int64 = 64_000_000_000
                return ("EXTRACTION TARGET (LOCAL SSD)", "SSD Target", estBytes, ssdFree, "2 Video Titles")
            } else {
                // Duplicate Disc (DVD-9 -> DVD-5 Fit-to-Disc)
                let used: Int64 = 4_370_000_000
                let total: Int64 = 4_700_372_992
                return ("TARGET DISC SPACE (DVD-5 4.7 GB)", "DVD-5", used, total, "2,133,789 LBA")
            }
        }

        // 2. Disc Image Depot -> Selected Hero ISO Size vs Recommended Optical Medium
        if store.selectedCategory == .depot {
            let hero = store.depotItems.first(where: { $0.id == store.selectedDepotHeroItemID }) ?? store.depotItems[0]
            let imgBytes = store.parseSizeDisplayToBytes(hero.sizeDisplay)
            let isMiniDVD = hero.sizeDisplay.contains("80mm")
            let isCD = imgBytes <= 734_003_200 && !isMiniDVD
            let targetBytes: Int64 = isCD ? 700_000_000 : (isMiniDVD ? 1_459_978_240 : 4_700_372_992)
            let mediumName = isCD ? "CD-R 700 MB" : (isMiniDVD ? "Mini-DVD 1.46 GB" : "DVD-5 4.7 GB")
            let compactName = isCD ? "CD-R" : (isMiniDVD ? "80mm DVD" : "DVD-5")
            let lba = max(1, imgBytes / 2048)
            return ("DISC SPACE (\(mediumName))", compactName, imgBytes, targetBytes, "\(lba) LBA")
        }

        // 3. Burn Station -> Use physical drive mediaType ONLY when a writable blank disc (freeBytes > 0) is loaded
        let usedB = store.totalStagedBytes
        let totalB = max(1, activeDiscCapacityBytes)
        if let drive = primarySelectedDrive, drive.isMediaPresent, drive.freeBytes > 0 {
            return ("DISC SPACE (\(drive.mediaType))", drive.mediaType, usedB, totalB, "\(store.totalStagedSectorsLBA) LBA")
        }

        let spec = store.activeFormatSpec()
        let gb = spec.capacityGB
        let targetMedium: (full: String, short: String) = {
            if gb <= 0.75 { return ("CD-R (700 MB)", "CD-R") }
            if gb <= 1.50 { return ("Mini-DVD (1.46 GB)", "80mm DVD") }
            if gb <= 4.75 { return ("DVD-5 (4.7 GB)", "DVD-5") }
            if gb <= 8.60 { return ("DVD-9 DL (8.5 GB)", "DVD-9") }
            if gb <= 25.5 { return ("BD-R SL (25 GB)", "BD-25") }
            if gb <= 50.5 { return ("BD-R DL (50 GB)", "BD-50") }
            return ("BDXL UHD (100 GB)", "BDXL")
        }()
        return ("DISC SPACE (\(targetMedium.full))", targetMedium.short, usedB, totalB, "\(store.totalStagedSectorsLBA) LBA")
    }

    var body: some View {
        let info = capacityTelemetry
        let usedB = info.usedBytes
        let totalB = max(1, info.totalBytes)
        let freeB = max(0, totalB - usedB)
        let ratio = min(1.0, Double(usedB) / Double(totalB))
        let isOverburn = usedB > totalB

        return VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                // 1. Wide Workspace Layout
                HStack(spacing: 6) {
                    Label(info.headerLabel, systemImage: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Used: \(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) (\(info.sectorsText))")
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

                // 2. Compact / Narrow Workspace Fallback
                HStack(spacing: 6) {
                    Text("\(info.compactLabel):")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(info.headerLabel)
        .accessibilityValue(String(format: "%.1f percent full", ratio * 100.0))
    }
}
