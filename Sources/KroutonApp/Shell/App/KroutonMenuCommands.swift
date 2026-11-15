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
    private var appSettingsCommands: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(KroutonL10n.tr("Hardware, Theme & Language Settings...")) {
                KroutonWindowManager.shared.openSettingsWindow(store: wm.store, driveManager: wm.driveManager)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    @CommandsBuilder
    private var fileMenuCommands: some Commands {
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

            Button(KroutonL10n.tr("Reveal Krouton Rips Folder in Finder")) {
                let path = ("~/Music/Krouton Rips" as NSString).expandingTildeInPath
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                KroutonOSDesktopBridge.revealFolderInFinder(path: path)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
    }

    @CommandsBuilder
    private var editMenuCommands: some Commands {
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
    private var viewMenuCommands: some Commands {
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

            Button(KroutonL10n.tr("Open Floating Phase Scope Telemetry")) {
                let firstID = wm.driveManager.availableDrives.first?.id ?? "network-spool-drive"
                KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: firstID)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Divider()
        }
    }

    @CommandsBuilder
    private var formatMenuCommands: some Commands {
        CommandMenu(KroutonL10n.tr("Format")) {
            Menu(KroutonL10n.tr("Data & Archival Media")) {
                Button("Hybrid ISO-9660 + Joliet + UDF") { selectBurnFormat("data-hybrid") }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("UDF 2.60 Optical Volume") { selectBurnFormat("udf-260") }
                Button("M-DISC 1,000-Year Archival Vault") { selectBurnFormat("m-disc") }
                    .keyboardShortcut("5", modifiers: [.command, .control])
                Button("Burn Disc Image (.iso / .cue / .dmg)") { selectBurnFormat("image-burn") }
                    .keyboardShortcut("6", modifiers: [.command, .control])
            }
            Menu(KroutonL10n.tr("Audio & Music Discs")) {
                Button("Red Book Audio CD (CD-DA)") { selectBurnFormat("cd-da") }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("MP3 / FLAC Car Audio CD") { selectBurnFormat("mp3-cd") }
                Button("Blue Book CD-Extra (Audio + Data)") { selectBurnFormat("cd-extra") }
            }
            Menu(KroutonL10n.tr("Video & Cinema Discs")) {
                Button("DVD-Video (VIDEO_TS)") { selectBurnFormat("dvd-video") }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Button("AVCHD High-Definition") { selectBurnFormat("avchd") }
                Button("Blu-ray Disc Single-Layer (BD-R 25 GB)") { selectBurnFormat("bd-r-sl") }
                    .keyboardShortcut("4", modifiers: [.command, .control])
                Button("Blu-ray Disc Dual-Layer (BD-R 50 GB)") { selectBurnFormat("bd-r-dl") }
                Button("BDXL Triple/Quad-Layer UHD (100 GB)") { selectBurnFormat("bdxl-uhd") }
            }
            Menu(KroutonL10n.tr("Retro Console Optical Media")) {
                Button("Nintendo Wii Optical Disc") { selectBurnFormat("console-wii") }
                Button("Nintendo GameCube (MiniDVD)") { selectBurnFormat("console-gc") }
                Button("Sony PlayStation 2 (DVD-ROM)") { selectBurnFormat("console-ps2") }
                Button("Sony PlayStation 1 (CD-XA Mode 2)") { selectBurnFormat("console-ps1") }
                Button("Original Xbox (XDVDFS)") { selectBurnFormat("console-xbox") }
            }

            Divider()

            Button(KroutonL10n.tr("Copy Hybrid ISO/UDF LBA Layout Summary")) {
                let plan = wm.store.planLiveHybridDataLayout()
                let summary = "Volume: \(plan.volumeIdentifier) | PVD LBA: \(plan.pvdSectorLBA) | UDF Anchor LBA: \(plan.udfAnchorAVDPLBA) | Total Sectors: \(plan.totalSectorsLBA)"
                KroutonOSDesktopBridge.copyTextToClipboard(summary)
                NotificationCenter.default.post(name: .kroutonMenuInspectHybridLBA, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .control])
            .disabled(wm.store.stagedFiles.isEmpty)

            Button(KroutonL10n.tr("Copy Compiled Red Book CUE Sheet")) {
                let cue = wm.store.compileLiveAudioCueSheet()
                KroutonOSDesktopBridge.copyTextToClipboard(cue)
                NotificationCenter.default.post(name: .kroutonMenuInspectAudioCue, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .control])

            Button(KroutonL10n.tr("Inspect Video Bitrate Budget")) {
                NotificationCenter.default.post(name: .kroutonMenuInspectVideoBitrate, object: nil)
            }
            .keyboardShortcut("b", modifiers: [.command, .control])
        }
    }

    @CommandsBuilder
    private var copyAndRipMenuCommands: some Commands {
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
    private var discMenuCommands: some Commands {
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
                    sectorsWrittenLBA: lba,
                    c1Rate: 0.0, c2Count: 0, jitterPercent: 3.5
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
        }
    }

    @CommandsBuilder
    private var windowAndHelpMenuCommands: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button(KroutonL10n.tr("Show Main Krouton Workspace Window")) {
                KroutonWindowManager.shared.openMainWindow()
            }
            .keyboardShortcut("0", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button(KroutonL10n.tr("Krouton Optical Mastering & Glossary Reference")) {
                KroutonWindowManager.shared.openSettingsWindow(store: wm.store, driveManager: wm.driveManager)
            }
            .keyboardShortcut("?", modifiers: .command)

            Divider()

            Link(KroutonL10n.tr("Krouton Online Documentation (krouton.app)"), destination: KroutonDomainIdentity.documentationURL)
            Link(KroutonL10n.tr("Verify Archival Disc Certificate Online"), destination: KroutonDomainIdentity.archivalVerifyURL)
        }
    }

    private func selectBurnFormat(_ id: String) {
        wm.store.selectedCategory = .burn
        wm.store.selectedTaskID = id
        wm.store.syncDefaultDestinationForCategory(.burn, taskID: id, driveManager: wm.driveManager)
    }
}
