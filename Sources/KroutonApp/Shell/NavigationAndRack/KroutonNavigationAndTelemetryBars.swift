import AudioKit
import DriveKit
import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

// MARK: - Standalone Left Format Chooser Sidebar, Central Capacity Bar & Burn Station Views

struct KroutonLeftFormatChooserColumnView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    let isLeftSidebarUltraSkinny: Bool

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
                            colloquial: "120mm / 18mm Canvas Workspace",
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

    // MARK: - Subviews & Helper Methods

    func taskRowButton(id: String, category: KroutonMasteringStation, title: String,
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
        .contextMenu {
            Button(KroutonL10n.tr("Open \(title) Workspace")) {
                store.snapshotCurrentDestinationQueue()
                store.selectedCategory = category
                store.selectedTaskID = id
                store.syncDefaultDestinationForCategory(category, taskID: id, driveManager: driveManager)
            }
            Button(KroutonL10n.tr("Add Destination Output Card")) {
                store.appendContextAwareDestination(driveManager: driveManager)
            }.keyboardShortcut("d", modifiers: [.command, .shift])
            Button(KroutonL10n.tr("Copy Format Specification")) {
                KroutonOSDesktopBridge.copyTextToClipboard("\(title) — \(colloquial) \(badge)")
            }
            if category == .burn {
                Divider()
                Button(KroutonL10n.tr("Hide Format from Sidebar")) {
                    store.toggleFormatVisibility(id: id)
                }
            }
        }
    }
}
