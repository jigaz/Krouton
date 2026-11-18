import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Edit, View, Window & Help Menu Commands (Apple HIG Separation of View vs. Window)

extension KroutonWorkspaceCommands {
    @CommandsBuilder
    var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(KroutonL10n.tr("Undo")) {
                wm.store.labelWorkspaceSubStore.undo(into: wm.store)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!wm.store.labelWorkspaceSubStore.canUndo)

            Button(KroutonL10n.tr("Redo")) {
                wm.store.labelWorkspaceSubStore.redo(into: wm.store)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!wm.store.labelWorkspaceSubStore.canRedo)
        }

        CommandGroup(after: .pasteboard) {
            Button(KroutonL10n.tr("Copy Selected Disc or Image Metadata")) {
                let summary = "Volume: \(wm.store.discVolumeTitle) • Task: \(wm.store.selectedTaskID) • Staged: \(wm.store.stagedFiles.count) items (\(wm.store.totalStagedBytes) bytes)"
                KroutonOSDesktopBridge.copyTextToClipboard(summary)
            }
            .keyboardShortcut("c", modifiers: [.command, .option, .shift])

            Divider()

            Button(KroutonL10n.tr("Add Curved Text Layer")) {
                wm.store.selectedCategory = .label
                wm.store.labelWorkspaceSubStore.recordUndoSnapshot(from: wm.store)
                let newItem = KroutonLabelTextElement(
                    text: wm.store.discVolumeTitle.isEmpty ? "DISC TITLE" : wm.store.discVolumeTitle,
                    isCurvedArc: true,
                    radiusMM: 44.0,
                    angleDegrees: 0.0,
                    fontSizePoints: 16.0
                )
                wm.store.labelTextElements.append(newItem)
                wm.store.labelSelectedTextID = newItem.id
            }
            .keyboardShortcut("t", modifiers: .command)

            Button(KroutonL10n.tr("Duplicate Selected Text Layer")) {
                guard let selID = wm.store.labelSelectedTextID,
                      let orig = wm.store.labelTextElements.first(where: { $0.id == selID }) else { return }
                wm.store.labelWorkspaceSubStore.recordUndoSnapshot(from: wm.store)
                var copy = orig
                copy.id = UUID()
                copy.angleDegrees = fmod(orig.angleDegrees + 180.0, 360.0)
                copy.isBottomUpright = (copy.angleDegrees >= 110.0 && copy.angleDegrees <= 250.0)
                wm.store.labelTextElements.append(copy)
                wm.store.labelSelectedTextID = copy.id
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(wm.store.labelSelectedTextID == nil)

            Button(KroutonL10n.tr("Delete Selected Text Layer")) {
                guard let selID = wm.store.labelSelectedTextID,
                      let idx = wm.store.labelTextElements.firstIndex(where: { $0.id == selID }) else { return }
                wm.store.labelWorkspaceSubStore.recordUndoSnapshot(from: wm.store)
                wm.store.labelTextElements.remove(at: idx)
                wm.store.labelSelectedTextID = wm.store.labelTextElements.last?.id
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(wm.store.labelSelectedTextID == nil)
        }
    }

    @CommandsBuilder
    var viewMenuCommands: some Commands {
        CommandGroup(before: .toolbar) {
            Button(KroutonL10n.tr("Burn Station Workspace")) {
                wm.store.selectedCategory = .burn
                if wm.store.selectedTaskID.hasPrefix("depot-") || wm.store.selectedTaskID.hasPrefix("copy-") || wm.store.selectedTaskID.hasPrefix("label-") {
                    wm.store.selectedTaskID = "data-hybrid"
                }
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(KroutonL10n.tr("Disc Image Depot Library")) {
                wm.store.selectedCategory = .depot
                wm.store.selectedTaskID = "depot-all"
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(KroutonL10n.tr("Copy, Rip & Rescue Workspace")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-duplicate"
            }
            .keyboardShortcut("3", modifiers: .command)

            Button(KroutonL10n.tr("Polar Disc Label Workspace")) {
                wm.store.selectedCategory = .label
                wm.store.selectedTaskID = "label-manual"
            }
            .keyboardShortcut("4", modifiers: .command)

            Button(KroutonL10n.tr("Audio CD Ripper & AccurateRip Archiver")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-rip-audio"
                wm.store.syncDefaultDestinationForCategory(.copy, taskID: "copy-rip-audio", driveManager: wm.driveManager)
            }
            .keyboardShortcut("5", modifiers: .command)

            Divider()

            Button(KroutonL10n.tr("Inspect Hybrid ISO/UDF LBA Layout")) {
                if wm.store.selectedCategory != .burn || wm.store.activeFormatSpec().workspaceKind != .dataAndArchival {
                    selectBurnFormat(.dataHybrid)
                }
                let plan = wm.store.planLiveHybridDataLayout()
                let summary = "Volume: \(plan.volumeIdentifier) | PVD LBA: \(plan.pvdSectorLBA) | UDF Anchor LBA: \(plan.udfAnchorAVDPLBA) | Total Sectors: \(plan.totalSectorsLBA)"
                KroutonOSDesktopBridge.copyTextToClipboard(summary)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .kroutonMenuInspectHybridLBA, object: nil)
                }
            }
            .keyboardShortcut("l", modifiers: [.command, .control])

            Button(KroutonL10n.tr("Inspect Compiled Red Book CUE Sheet")) {
                if wm.store.selectedCategory != .burn || (wm.store.selectedFormatID != .cdDA && wm.store.selectedFormatID != .cdExtra) {
                    selectBurnFormat(.cdDA)
                }
                let cue = wm.store.compileLiveAudioCueSheet()
                KroutonOSDesktopBridge.copyTextToClipboard(cue)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .kroutonMenuInspectAudioCue, object: nil)
                }
            }
            .keyboardShortcut("u", modifiers: [.command, .control])

            Button(KroutonL10n.tr("Inspect Video Bitrate Budget")) {
                if wm.store.selectedCategory != .burn || wm.store.activeFormatSpec().workspaceKind != .videoAuthoring {
                    selectBurnFormat(.dvdVideo)
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .kroutonMenuInspectVideoBitrate, object: nil)
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .control])

            Divider()

            Button(wm.store.labelShowAlignmentGrid ? KroutonL10n.tr("Hide 10mm Alignment Grid") : KroutonL10n.tr("Show 10mm Alignment Grid")) {
                wm.store.labelShowAlignmentGrid.toggle()
            }
            .keyboardShortcut("g", modifiers: .command)

            Button(KroutonL10n.tr("Zoom In Label Canvas")) {
                wm.store.labelCanvasZoom = min(2.0, wm.store.labelCanvasZoom + 0.15)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button(KroutonL10n.tr("Zoom Out Label Canvas")) {
                wm.store.labelCanvasZoom = max(0.65, wm.store.labelCanvasZoom - 0.15)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button(KroutonL10n.tr("Actual Size (100%)")) {
                wm.store.labelCanvasZoom = 1.0
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Divider()
        }
    }

    @CommandsBuilder
    var windowAndHelpMenuCommands: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button(KroutonL10n.tr("Show Main Krouton Workspace Window")) {
                KroutonWindowManager.shared.openMainWindow()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button(KroutonL10n.tr("Open Track Montage Editor Window")) {
                KroutonWindowManager.shared.openTrackMontageWindow()
            }
            .keyboardShortcut("m", modifiers: [.command, .option])

            Button(KroutonL10n.tr("Open Floating Phase Scope Telemetry")) {
                let firstID = wm.driveManager.availableDrives.first?.id ?? "network-spool-drive"
                KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: firstID)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }

        CommandGroup(replacing: .help) {
            Button(KroutonL10n.tr("Krouton User Manual & Mastering Guide...")) {
                KroutonWindowManager.shared.openUserManualWindow()
            }
            .keyboardShortcut("?", modifiers: .command)

            Menu(KroutonL10n.tr("Interactive Guided Tutorials")) {
                ForEach(KroutonGuidedTutorialID.allCases) { tour in
                    Button(KroutonL10n.tr(tour.title)) {
                        KroutonWindowManager.shared.startGuidedTutorialOnMainWorkspace(tour)
                    }
                }
                if KroutonGuidedTutorialController.shared.isRunning {
                    Divider()
                    Button(KroutonL10n.tr("Exit Active Guided Tutorial")) {
                        KroutonGuidedTutorialController.shared.stop()
                    }
                }
            }

            Divider()

            Link(KroutonL10n.tr("Krouton Online Documentation (krouton.app)"), destination: KroutonDomainIdentity.documentationURL)
            Link(KroutonL10n.tr("Verify Archival Disc Certificate Online"), destination: KroutonDomainIdentity.archivalVerifyURL)
        }
    }
}
