import SwiftUI
import UniformTypeIdentifiers
import OpticalDough

/// Modular macOS Menu Bar Commands (`File`, `Edit`, `View`, `Disc`, `Window`, `Help`) with Keyboard Shortcuts.
struct KroutonStudioCommands: Commands {
    @ObservedObject var wm: KroutonWindowManager

    init(wm: KroutonWindowManager) {
        self.wm = wm
    }

    var body: some Commands {
        fileMenuCommands
        editMenuCommands
        viewMenuCommands
        discMenuCommands
        windowAndHelpMenuCommands
    }

    @CommandsBuilder
    private var fileMenuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Blank Project") {
                wm.store.clearStagedFiles()
                wm.store.labelStudioSubStore.recordUndoSnapshot(from: wm.store)
                wm.store.labelTextElements.removeAll()
                wm.store.labelVectorShapes.removeAll()
                wm.store.labelBackgroundStyle = .templateDefault
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Project (.krut)...") {
                wm.store.presentOpenKrutProjectSheet()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Save Project (.krut)...") {
                wm.store.presentSaveKrutProjectSheet()
            }
            .keyboardShortcut("s", modifiers: .command)

            Divider()

            Button("Add Files or Disc Images...") {
                wm.store.selectedCategory = .burn
                KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.item, .folder], allowsMultiple: true) { urls in
                    wm.store.addStagedURLs(urls)
                }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("Add Destination Output Card") {
                wm.store.appendContextAwareDestination(driveManager: wm.driveManager)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }

    @CommandsBuilder
    private var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                wm.store.labelStudioSubStore.undo(into: wm.store)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!wm.store.labelStudioSubStore.canUndo)

            Button("Redo") {
                wm.store.labelStudioSubStore.redo(into: wm.store)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!wm.store.labelStudioSubStore.canRedo)
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Add Curved Text Layer") {
                wm.store.selectedCategory = .label
                wm.store.labelStudioSubStore.recordUndoSnapshot(from: wm.store)
                let newItem = KroutonLabelTextElement(
                    text: wm.store.discVolumeTitle.isEmpty ? "NEW DISC TEXT" : wm.store.discVolumeTitle,
                    isCurvedArc: true,
                    radiusMM: 44.0,
                    angleDegrees: 0.0,
                    fontSizePoints: 16.0
                )
                wm.store.labelTextElements.append(newItem)
                wm.store.labelSelectedTextID = newItem.id
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Duplicate Selected Text Layer") {
                guard let selID = wm.store.labelSelectedTextID,
                      let orig = wm.store.labelTextElements.first(where: { $0.id == selID }) else { return }
                wm.store.labelStudioSubStore.recordUndoSnapshot(from: wm.store)
                var copy = orig
                copy.id = UUID()
                copy.angleDegrees = fmod(orig.angleDegrees + 180.0, 360.0)
                copy.isBottomUpright = (copy.angleDegrees >= 110.0 && copy.angleDegrees <= 250.0)
                wm.store.labelTextElements.append(copy)
                wm.store.labelSelectedTextID = copy.id
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(wm.store.labelSelectedTextID == nil)

            Button("Delete Selected Text Layer") {
                guard let selID = wm.store.labelSelectedTextID,
                      let idx = wm.store.labelTextElements.firstIndex(where: { $0.id == selID }) else { return }
                wm.store.labelStudioSubStore.recordUndoSnapshot(from: wm.store)
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
            Button("Burn Station Workspace") {
                wm.store.selectedCategory = .burn
                if wm.store.selectedTaskID.hasPrefix("depot-") || wm.store.selectedTaskID.hasPrefix("copy-") || wm.store.selectedTaskID.hasPrefix("label-") {
                    wm.store.selectedTaskID = "data-hybrid"
                }
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Disc Image Depot Library") {
                wm.store.selectedCategory = .depot
                wm.store.selectedTaskID = "depot-all"
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Copy, Rip & Rescue Studio") {
                wm.store.selectedCategory = .copy
                wm.store.selectedTaskID = "copy-duplicate"
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Polar Disc Label Studio") {
                wm.store.selectedCategory = .label
                wm.store.selectedTaskID = "label-manual"
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button(wm.store.labelShowAlignmentGrid ? "Hide 10mm Alignment Grid" : "Show 10mm Alignment Grid") {
                wm.store.labelShowAlignmentGrid.toggle()
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("Zoom In Label Canvas") {
                wm.store.labelCanvasZoom = min(2.0, wm.store.labelCanvasZoom + 0.15)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out Label Canvas") {
                wm.store.labelCanvasZoom = max(0.65, wm.store.labelCanvasZoom - 0.15)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Actual Size (100%)") {
                wm.store.labelCanvasZoom = 1.0
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Divider()

            Button("Open Floating Phase Scope Telemetry") {
                let firstID = wm.driveManager.availableDrives.first?.id ?? "krumb-network-toaster"
                KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: firstID)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Divider()
        }
    }

    @CommandsBuilder
    private var discMenuCommands: some Commands {
        CommandMenu("Disc") {
            Button("Execute Active Queue / Burn Now") {
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
            .disabled(wm.driveManager.isExecutingQueue)

            Button("Rescan Optical Drives") {
                wm.driveManager.refreshDrives()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Stamp DVD-ROM Book Type (Bitsetting)") {
                if let firstID = wm.driveManager.availableDrives.first?.id {
                    wm.driveManager.stampDVDROMBookType(for: firstID)
                }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button("Eject Optical Media") {
                wm.driveManager.ejectDrive(id: wm.driveManager.availableDrives.first?.id)
            }
            .keyboardShortcut("e", modifiers: .command)
        }
    }

    @CommandsBuilder
    private var windowAndHelpMenuCommands: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button("Show Main Krouton Studio Window") {
                KroutonWindowManager.shared.openMainWindow()
            }
            .keyboardShortcut("0", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Krouton Optical Mastering & Glossary Reference") {
                KroutonWindowManager.shared.openSettingsWindow(store: wm.store, driveManager: wm.driveManager)
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
