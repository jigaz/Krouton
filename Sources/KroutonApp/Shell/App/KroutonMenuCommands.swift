import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalCore
import LabelKit
import RescueKit

public extension Notification.Name {
    static let kroutonMenuScanTOC = Notification.Name("krouton.menu.scanTOC")
    static let kroutonMenuRipSelected = Notification.Name("krouton.menu.ripSelected")
    static let kroutonMenuShowCDInfo = Notification.Name("krouton.menu.showCDInfo")
    static let kroutonMenuInspectHybridLBA = Notification.Name("krouton.menu.inspectHybridLBA")
    static let kroutonMenuInspectAudioCue = Notification.Name("krouton.menu.inspectAudioCue")
    static let kroutonMenuInspectVideoBitrate = Notification.Name("krouton.menu.inspectVideoBitrate")
}

/// Modular macOS Menu Bar Commands (`Krouton`, `File`, `Edit`, `View`, `Format`, `Copy & Rip`, `Disc`, `Window`, `Help`).
struct KroutonWorkspaceCommands: Commands {
    @ObservedObject var wm: KroutonWindowManager

    init(wm: KroutonWindowManager) {
        self.wm = wm
    }

    var body: some Commands {
        appSettingsCommands
        fileMenuCommands
        editMenuCommands
        viewMenuCommands
        formatMenuCommands
        copyAndRipMenuCommands
        discMenuCommands
        windowAndHelpMenuCommands
    }

    @CommandsBuilder
    var appSettingsCommands: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(KroutonL10n.tr("Hardware, Theme & Language Settings...")) {
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

            Button(KroutonL10n.tr("Open Project (.krut)...")) {
                wm.store.presentOpenKrutProjectSheet()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button(KroutonL10n.tr("Save Project (.krut)...")) {
                wm.store.presentSaveKrutProjectSheet()
            }
            .keyboardShortcut("s", modifiers: .command)

            Divider()

            Button(KroutonL10n.tr("Add Files or Disc Images...")) {
                wm.store.selectedCategory = .burn
                KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.item, .folder], allowsMultiple: true) { urls in
                    wm.store.addStagedURLs(urls)
                }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("Add Destination Output Card")) {
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
                Button(KroutonL10n.tr("Hybrid ISO-9660 + Joliet + UDF")) { selectBurnFormat("data-hybrid") }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button(KroutonL10n.tr("UDF 2.60 Optical Volume")) { selectBurnFormat("udf-260") }
                Button(KroutonL10n.tr("M-DISC 1,000-Year Archival Vault")) { selectBurnFormat("m-disc") }
                    .keyboardShortcut("5", modifiers: [.command, .control])
                Button(KroutonL10n.tr("Burn Disc Image (.iso / .cue / .dmg)")) { selectBurnFormat("image-burn") }
                    .keyboardShortcut("6", modifiers: [.command, .control])
            }
            Menu(KroutonL10n.tr("Audio & Music Discs")) {
                Button(KroutonL10n.tr("Red Book Audio CD (CD-DA)")) { selectBurnFormat("cd-da") }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button(KroutonL10n.tr("MP3 / FLAC Car Audio CD")) { selectBurnFormat("mp3-cd") }
                Button(KroutonL10n.tr("Blue Book CD-Extra (Audio + Data)")) { selectBurnFormat("cd-extra") }
            }
            Menu(KroutonL10n.tr("Video & Cinema Discs")) {
                Button(KroutonL10n.tr("DVD-Video (VIDEO_TS)")) { selectBurnFormat("dvd-video") }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Button(KroutonL10n.tr("AVCHD High-Definition")) { selectBurnFormat("avchd") }
                Button(KroutonL10n.tr("Blu-ray Disc Single-Layer (BD-R 25 GB)")) { selectBurnFormat("bd-r-sl") }
                    .keyboardShortcut("4", modifiers: [.command, .control])
                Button(KroutonL10n.tr("Blu-ray Disc Dual-Layer (BD-R 50 GB)")) { selectBurnFormat("bd-r-dl") }
                Button(KroutonL10n.tr("BDXL Triple/Quad-Layer UHD (100 GB)")) { selectBurnFormat("bdxl-uhd") }
            }
            Menu(KroutonL10n.tr("Retro Console Optical Media")) {
                Button(KroutonL10n.tr("Nintendo Wii Optical Disc")) { selectBurnFormat("console-wii") }
                Button(KroutonL10n.tr("Nintendo GameCube (MiniDVD)")) { selectBurnFormat("console-gc") }
                Button(KroutonL10n.tr("Sony PlayStation 2 (DVD-ROM)")) { selectBurnFormat("console-ps2") }
                Button(KroutonL10n.tr("Sony PlayStation 1 (CD-XA Mode 2)")) { selectBurnFormat("console-ps1") }
                Button(KroutonL10n.tr("Original Xbox (XDVDFS)")) { selectBurnFormat("console-xbox") }
            }

            Divider()

            Button(KroutonL10n.tr("Inspect Hybrid ISO/UDF LBA Layout")) {
                if wm.store.selectedCategory != .burn || (!wm.store.selectedTaskID.hasPrefix("data-") && wm.store.selectedTaskID != "udf-260" && wm.store.selectedTaskID != "m-disc") {
                    selectBurnFormat("data-hybrid")
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
                if wm.store.selectedCategory != .burn || (wm.store.selectedTaskID != "cd-da" && wm.store.selectedTaskID != "cd-extra") {
                    selectBurnFormat("cd-da")
                }
                let cue = wm.store.compileLiveAudioCueSheet()
                KroutonOSDesktopBridge.copyTextToClipboard(cue)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .kroutonMenuInspectAudioCue, object: nil)
                }
            }
            .keyboardShortcut("u", modifiers: [.command, .control])

            Button(KroutonL10n.tr("Inspect Video Bitrate Budget")) {
                if wm.store.selectedCategory != .burn || (!wm.store.selectedTaskID.hasPrefix("dvd-") && !wm.store.selectedTaskID.hasPrefix("bd") && wm.store.selectedTaskID != "avchd") {
                    selectBurnFormat("dvd-video")
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .kroutonMenuInspectVideoBitrate, object: nil)
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .control])
        }
    }

    @CommandsBuilder
    var copyAndRipMenuCommands: some Commands {
        CommandMenu(KroutonL10n.tr("Copy & Rip")) {
            Button(KroutonL10n.tr("Scan Audio CD TOC & Lookup MusicBrainz")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-rip-audio"
                wm.store.syncDefaultDestinationForCategory(.copy, taskID: "copy-rip-audio", driveManager: wm.driveManager)
                NotificationCenter.default.post(name: .kroutonMenuScanTOC, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button(KroutonL10n.tr("Rip Selected Audio CD Tracks")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-rip-audio"
                wm.store.syncDefaultDestinationForCategory(.copy, taskID: "copy-rip-audio", driveManager: wm.driveManager)
                NotificationCenter.default.post(name: .kroutonMenuRipSelected, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("CD Info & Metadata Tags...")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-rip-audio"
                NotificationCenter.default.post(name: .kroutonMenuShowCDInfo, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button(KroutonL10n.tr("Duplicate Disc / Fit-to-Disc DVD-9 Shrink")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-duplicate"
                wm.store.syncDefaultDestinationForCategory(.copy, taskID: "copy-duplicate", driveManager: wm.driveManager)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("Video Disc Extractor (Lossless MKV Remux)")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-rip-video"
                wm.store.syncDefaultDestinationForCategory(.copy, taskID: "copy-rip-video", driveManager: wm.driveManager)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button(KroutonL10n.tr("Optical Bad-Sector Rescue & Recovery")) {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-rescue"
                wm.store.syncDefaultDestinationForCategory(.copy, taskID: "copy-rescue", driveManager: wm.driveManager)
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
        }
    }

    @CommandsBuilder
    var discMenuCommands: some Commands {
        CommandMenu(KroutonL10n.tr("Disc")) {
            Button(KroutonL10n.tr("Execute Active Queue / Burn Now")) {
                let primaryDrive = wm.driveManager.availableDrives.first
                for item in wm.store.destinationQueue {
                    wm.store.executeSingleDestination(
                        item,
                        driveManager: wm.driveManager,
                        primarySelectedDrive: primaryDrive,
                        enableCustomFinderLayoutTab: false,
                        finderIconSize: 96.0
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

            Button(KroutonL10n.tr("Rescan Optical Drives")) {
                wm.driveManager.refreshDrives()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(KroutonL10n.tr("Run Phase Scope Diagnostic Sweep")) {
                if let firstID = wm.driveManager.availableDrives.first?.id {
                    wm.driveManager.runPhaseScopeTestSweep(for: firstID, keepPinnedAfterSweep: true)
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(wm.driveManager.availableDrives.isEmpty)

            Button(KroutonL10n.tr("Stamp DVD-ROM Book Type (Bitsetting)")) {
                if let firstID = wm.driveManager.availableDrives.first?.id {
                    wm.driveManager.stampDVDROMBookType(for: firstID)
                }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(wm.driveManager.availableDrives.isEmpty)

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

            Button(KroutonL10n.tr("Eject Optical Media")) {
                wm.driveManager.ejectDrive(id: wm.driveManager.availableDrives.first?.id)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(wm.driveManager.availableDrives.isEmpty)

            Menu(KroutonL10n.tr("Erase RW")) {
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

    func selectBurnFormat(_ id: String) {
        wm.store.selectedCategory = .burn
        wm.store.selectedTaskID = id
        wm.store.syncDefaultDestinationForCategory(.burn, taskID: id, driveManager: wm.driveManager)
    }
}
