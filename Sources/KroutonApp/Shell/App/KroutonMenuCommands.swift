import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Menu Bar Commands

extension Notification.Name {
    static let kroutonMenuScanTOC = Notification.Name("krouton.menu.scanTOC")
    static let kroutonMenuRipSelected = Notification.Name("krouton.menu.ripSelected")
    static let kroutonMenuShowCDInfo = Notification.Name("krouton.menu.showCDInfo")
    static let kroutonMenuInspectHybridLBA = Notification.Name("krouton.menu.inspectHybridLBA")
    static let kroutonMenuInspectAudioCue = Notification.Name("krouton.menu.inspectAudioCue")
    static let kroutonMenuInspectVideoBitrate = Notification.Name("krouton.menu.inspectVideoBitrate")
}

/// The menu bar: Settings in the Krouton menu, then File, Edit, View, Format, Disc, Window and
/// Help. Most items call the state store or the drive bank directly; the few that act on a
/// workspace's own view state post one of the notifications above, which that view receives.
/// Every keyboard shortcut here must be listed in `manual-09-keyboard-shortcuts.md`
/// (`Scripts/build-manual.py --check` fails otherwise).
struct KroutonWorkspaceCommands: Commands {
    var wm: KroutonWindowManager

    init(wm: KroutonWindowManager) {
        self.wm = wm
    }

    var body: some Commands {
        appSettingsCommands
        fileMenuCommands
        editMenuCommands
        viewMenuCommands
        formatMenuCommands
        discMenuCommands
        windowAndHelpMenuCommands
    }

    @CommandsBuilder
    var appSettingsCommands: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(KroutonL10n.tr("Settings…")) {
                KroutonWindowManager.shared.openSettingsWindow(store: wm.store, driveManager: wm.driveManager)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    @CommandsBuilder
    var fileMenuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(KroutonL10n.tr("New Blank Project")) {
                wm.store.clearStagedFiles()
                wm.store.labelWorkspaceSubStore.recordUndoSnapshot(from: wm.store)
                wm.store.labelTextElements.removeAll()
                wm.store.labelVectorShapes.removeAll()
                wm.store.labelBackgroundStyle = .templateDefault
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(KroutonL10n.tr("Open Project…")) {
                wm.store.presentOpenKrutProjectSheet()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button(KroutonL10n.tr("Save Project…")) {
                wm.store.presentSaveKrutProjectSheet()
            }
            .keyboardShortcut("s", modifiers: .command)

            Divider()

            Button(KroutonL10n.tr("Add Files or Disc Images…")) {
                wm.store.selectedCategory = .burn
                KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.item, .folder], allowsMultiple: true) { urls in
                    wm.store.addStagedURLs(urls)
                }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("Add Destination Card")) {
                wm.store.appendContextAwareDestination(driveManager: wm.driveManager)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("Clear Staged Files")) {
                wm.store.clearStagedFiles()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .option])
            .disabled(wm.store.stagedFiles.isEmpty)

            Divider()

            Button(KroutonL10n.tr("Reveal Staged Files in Finder")) {
                KroutonOSDesktopBridge.revealURLsInFinder(wm.store.stagedFiles.map(\.url))
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(wm.store.stagedFiles.isEmpty)

            Button(KroutonL10n.tr("Reveal Krouton Rips Folder in Finder")) {
                let path = ("~/Music/Krouton Rips" as NSString).expandingTildeInPath
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                KroutonOSDesktopBridge.revealFolderInFinder(path: path)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
    }

    @CommandsBuilder
    var formatMenuCommands: some Commands {
        CommandMenu(KroutonL10n.tr("Format")) {
            Menu(KroutonL10n.tr("Data & Archival Media")) {
                Button(KroutonL10n.tr("Hybrid ISO-9660 + Joliet + UDF")) { selectBurnFormat(.dataHybrid) }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button(KroutonL10n.tr("UDF 2.50 Large-File Volume")) { selectBurnFormat(.dataUDFModern) }
                Button(KroutonL10n.tr("M-DISC Archival Disc")) { selectBurnFormat(.mdiscVault) }
                    .keyboardShortcut("5", modifiers: [.command, .control])
                Button(KroutonL10n.tr("Burn Disc Image (.iso / .cue / .dmg)")) { selectBurnFormat(.imageBurn) }
                    .keyboardShortcut("6", modifiers: [.command, .control])
            }
            Menu(KroutonL10n.tr("Audio & Music Discs")) {
                Button(KroutonL10n.tr("Red Book Audio CD (CD-DA)")) { selectBurnFormat(.cdDA) }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button(KroutonL10n.tr("MP3 / FLAC Car Audio CD")) { selectBurnFormat(.mp3CD) }
                Button(KroutonL10n.tr("Blue Book CD-Extra (Audio + Data)")) { selectBurnFormat(.cdExtra) }
            }
            Menu(KroutonL10n.tr("Video & Cinema Discs")) {
                Button(KroutonL10n.tr("DVD-Video (VIDEO_TS)")) { selectBurnFormat(.dvdVideo) }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Button(KroutonL10n.tr("AVCHD High-Definition")) { selectBurnFormat(.bdOnDVD) }
                Button(KroutonL10n.tr("Blu-ray Disc Single-Layer (BD-R 25 GB)")) { selectBurnFormat(.bd25) }
                    .keyboardShortcut("4", modifiers: [.command, .control])
                Button(KroutonL10n.tr("Blu-ray Disc Dual-Layer (BD-R 50 GB)")) { selectBurnFormat(.bd50) }
                Button(KroutonL10n.tr("Ultra HD Blu-ray (BDXL 100 GB)")) { selectBurnFormat(.bdUHD) }
            }
            Menu(KroutonL10n.tr("Game Console Discs")) {
                Button(KroutonL10n.tr("Nintendo Wii")) { selectBurnFormat(.consoleWii) }
                Button(KroutonL10n.tr("Nintendo GameCube (MiniDVD)")) { selectBurnFormat(.consoleGC) }
                Button(KroutonL10n.tr("Sony PlayStation 2 (DVD-ROM)")) { selectBurnFormat(.consolePS2) }
                Button(KroutonL10n.tr("Sony PlayStation 1 (CD-XA Mode 2)")) { selectBurnFormat(.consolePS1) }
                Button(KroutonL10n.tr("Original Xbox (XDVDFS)")) { selectBurnFormat(.consoleXbox) }
            }

            Divider()

            Menu(KroutonL10n.tr("Copy, Rip & Rescue")) {
                Button(KroutonL10n.tr("Duplicate Disc or Shrink a DVD-9")) {
                    selectCopyTask(.duplicateDisc)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button(KroutonL10n.tr("Extract Video Disc")) {
                    selectCopyTask(.extractVideoDisc)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button(KroutonL10n.tr("Rescue a Damaged Disc")) {
                    selectCopyTask(.rescueDisc)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
            }
        }
    }

    @CommandsBuilder
    var discMenuCommands: some Commands {
        CommandMenu(KroutonL10n.tr("Disc")) {
            Button(KroutonL10n.tr("Run Destination Queue")) {
                let primaryDrive = wm.driveManager.availableDrives.first
                for item in wm.store.destinationQueue {
                    wm.store.executeSingleDestination(
                        item,
                        driveManager: wm.driveManager,
                        primarySelectedDrive: primaryDrive
                    )
                }
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(wm.driveManager.isExecutingQueue || wm.store.destinationQueue.isEmpty)

            Button(KroutonL10n.tr("Abort Active Operation")) {
                wm.driveManager.abortActiveBurn()
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!wm.driveManager.isExecutingQueue)

            Divider()

            Button(KroutonL10n.tr("Scan Audio CD & Look Up Track Names")) {
                selectCopyTask(.ripAudioCD)
                NotificationCenter.default.post(name: .kroutonMenuScanTOC, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button(KroutonL10n.tr("Rip Selected Audio CD Tracks")) {
                selectCopyTask(.ripAudioCD)
                NotificationCenter.default.post(name: .kroutonMenuRipSelected, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("CD Info & Tags…")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = KroutonCopyTaskID.ripAudioCD.rawValue
                NotificationCenter.default.post(name: .kroutonMenuShowCDInfo, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button(KroutonL10n.tr("Rescan Optical Drives")) {
                wm.driveManager.refreshDrives()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(KroutonL10n.tr("Reset Phase Scope")) {
                if let firstID = wm.driveManager.availableDrives.first?.id {
                    wm.driveManager.runPhaseScopeTestSweep(for: firstID, keepPinnedAfterSweep: true)
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(wm.driveManager.availableDrives.isEmpty)

            Toggle(KroutonL10n.tr("Leave Disc Open for More Sessions"), isOn: Bindable(wm.store).leaveDiscOpenForMoreSessions)

            Button(KroutonL10n.tr("Copy Archival Quality Certificate")) {
                let drv = wm.driveManager.availableDrives.first
                let lba = max(150, Int64((drv?.usedBytes ?? wm.store.totalStagedBytes) / 2048))
                let cert = KroutonLabelGeometryEngine.evaluateArchivalDiscGrade(
                    driveModel: drv?.displayName ?? "Optical Drive",
                    mediaType: drv?.mediaType ?? "Optical Media",
                    sectorsWrittenLBA: lba
                )
                KroutonOSDesktopBridge.copyTextToClipboard(cert.certificateText)
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Divider()

            Button(KroutonL10n.tr("Eject Disc")) {
                wm.driveManager.ejectDrive(id: wm.driveManager.availableDrives.first?.id)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(wm.driveManager.availableDrives.isEmpty)

            Menu(KroutonL10n.tr("Erase Rewritable Disc")) {
                Button(KroutonL10n.tr("Quick Erase")) {
                    wm.driveManager.eraseRewritableDisc(
                        driveID: wm.driveManager.selectedDrive?.id ?? wm.driveManager.availableDrives.first?.id,
                        fullErase: false
                    ) { _ in }
                }
                Button(KroutonL10n.tr("Full Erase")) {
                    wm.driveManager.eraseRewritableDisc(
                        driveID: wm.driveManager.selectedDrive?.id ?? wm.driveManager.availableDrives.first?.id,
                        fullErase: true
                    ) { _ in }
                }
            }
            .disabled(wm.driveManager.availableDrives.isEmpty || wm.driveManager.isExecutingQueue)
        }
    }

    func selectBurnFormat(_ format: KroutonFormatID) {
        wm.store.selectedCategory = .burn
        wm.store.selectedTaskID = format.rawValue
        wm.store.syncDefaultDestinationForCategory(.burn, taskID: format.rawValue, driveManager: wm.driveManager)
    }

    func selectCopyTask(_ task: KroutonCopyTaskID) {
        wm.store.selectedCategory = .copy
        wm.store.selectedTaskID = task.rawValue
        wm.store.syncDefaultDestinationForCategory(.copy, taskID: task.rawValue, driveManager: wm.driveManager)
    }
}
