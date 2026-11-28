import DriveKit
import Foundation
import Observation
import OpticalCore
import SwiftUI

// MARK: - Guided Tours

/// The part of the main window a tour step highlights.
enum KroutonTutorialTargetZone: String, Sendable, Equatable {
    case leftFormatSidebar
    case centerMasteringDeck
    case centerWorkspaceBody
    case centerCapacityBar
    case rightBurnerPool
}

/// The guided tours in Help › Guided Tours. The raw values are identifiers, never shown.
enum KroutonGuidedTutorialID: String, CaseIterable, Identifiable, Sendable {
    case redBookCrossfade = "red-book-crossfade"
    case multiBurnerPool = "multi-burner-pool"
    case multiDiscSpanning = "multi-disc-spanning"
    case polarLabelStudio = "polar-label-studio"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .redBookCrossfade: return "Audio CDs and Crossfades"
        case .multiBurnerPool: return "Burning on Several Burners"
        case .multiDiscSpanning: return "Data Across Several Discs"
        case .polarLabelStudio: return "Designing a Disc Label"
        }
    }

    var subtitle: String {
        switch self {
        case .redBookCrossfade: return "Add CD-Text, shape the fade between two tracks while you listen, and burn."
        case .multiBurnerPool: return "Burn copies on several burners at once, and choose how the waiting discs are handed out."
        case .multiDiscSpanning: return "Split a large folder across discs, each with a checksum manifest, and resume a set after a quit."
        case .polarLabelStudio: return "Let Auto Label fill in the title, add curved text and shapes, and export at true size for your printer."
        }
    }

    var sfSymbol: String {
        switch self {
        case .redBookCrossfade: return "waveform.path.ecg.rectangle.fill"
        case .multiBurnerPool: return "externaldrive.connected.to.line.below.fill"
        case .multiDiscSpanning: return "square.stack.3d.up.fill"
        case .polarLabelStudio: return "printer.dotmatrix.fill"
        }
    }
}

/// One step of a tour: what to highlight, what to say, and the optional button that does the
/// step's action for you (`performLiveStepAction`).
struct KroutonGuidedTutorialStep: Identifiable, Sendable, Equatable {
    let id: Int
    let zone: KroutonTutorialTargetZone
    let headline: String
    let body: String
    let shortcutHint: String
    let actionButtonTitle: String?
}

/// Runs a guided tour: holds the tour and step on screen, switches the main window to the
/// workspace each step talks about, and performs a step's action when its button is pressed.
/// `KroutonGuidedTutorialOverlayView` draws the highlight and the step's text.
@Observable
@MainActor
final class KroutonGuidedTutorialController {
    static let shared = KroutonGuidedTutorialController()

    var activeTutorial: KroutonGuidedTutorialID? = nil
    var currentStepIndex: Int = 0

    var isRunning: Bool { activeTutorial != nil }

    var activeSteps: [KroutonGuidedTutorialStep] {
        guard let activeTutorial else { return [] }
        return Self.steps(for: activeTutorial)
    }

    var currentStep: KroutonGuidedTutorialStep? {
        let list = activeSteps
        guard list.indices.contains(currentStepIndex) else { return nil }
        return list[currentStepIndex]
    }

    func start(_ tutorial: KroutonGuidedTutorialID, store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        activeTutorial = tutorial
        currentStepIndex = 0
        applyWorkspaceContextForCurrentStep(store: store, driveManager: driveManager)
    }

    func nextStep(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        let list = activeSteps
        if currentStepIndex + 1 < list.count {
            currentStepIndex += 1
            applyWorkspaceContextForCurrentStep(store: store, driveManager: driveManager)
        } else {
            stop()
        }
    }

    func previousStep(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            applyWorkspaceContextForCurrentStep(store: store, driveManager: driveManager)
        }
    }

    func stop() {
        activeTutorial = nil
        currentStepIndex = 0
    }

    func performLiveStepAction(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        guard let tut = activeTutorial else { return }
        switch (tut, currentStepIndex) {
        case (.redBookCrossfade, 1):
            NotificationCenter.default.post(name: .kroutonMenuInspectAudioCue, object: nil)
        case (.redBookCrossfade, 2):
            KroutonWindowManager.shared.openTrackMontageWindow()
        case (.multiBurnerPool, 1):
            store.setPoolTotalCopies(max(4, store.poolTotalCopies + 2), driveManager: driveManager)
        case (.multiBurnerPool, 2):
            store.autoLoadNextDiscBatchMode.toggle()
        case (.multiDiscSpanning, 1):
            NotificationCenter.default.post(name: .kroutonMenuInspectHybridLBA, object: nil)
        case (.polarLabelStudio, 1):
            store.labelShowAlignmentGrid.toggle()
        default:
            break
        }
    }

    private func applyWorkspaceContextForCurrentStep(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        guard let tut = activeTutorial else { return }
        switch tut {
        case .redBookCrossfade:
            store.selectedCategory = .burn
            store.selectedTaskID = KroutonFormatID.cdDA.rawValue
            store.syncDefaultDestinationForCategory(.burn, taskID: KroutonFormatID.cdDA.rawValue, driveManager: driveManager)
        case .multiBurnerPool:
            store.selectedCategory = .burn
            if store.poolTotalCopies < 3 {
                store.setPoolTotalCopies(4, driveManager: driveManager)
            }
        case .multiDiscSpanning:
            store.selectedCategory = .burn
            store.selectedTaskID = KroutonFormatID.dataHybrid.rawValue
            store.syncDefaultDestinationForCategory(.burn, taskID: KroutonFormatID.dataHybrid.rawValue, driveManager: driveManager)
        case .polarLabelStudio:
            store.selectedCategory = .label
            store.selectedTaskID = "label-manual"
        }
    }

    static func steps(for tutorial: KroutonGuidedTutorialID) -> [KroutonGuidedTutorialStep] {
        switch tutorial {
        case .redBookCrossfade:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .leftFormatSidebar,
                    headline: "1. Choose Audio CD",
                    body: "Choose Red Book Audio CD in the Format Chooser, or press ⌃⌘2. Audio CDs are 44.1 kHz, 16-bit stereo, timed in frames of 1/75 of a second.",
                    shortcutHint: "⌃⌘2 • Red Book Audio CD",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .centerMasteringDeck,
                    headline: "2. Add CD-Text and Check the Cue Sheet",
                    body: "Enter the album title, the artist and, if you have one, the UPC/EAN barcode. Krouton writes them as CD-Text, which many players show. The cue sheet lists what will go on the disc.",
                    shortcutHint: "⌃⌘U • Inspect Cue Sheet",
                    actionButtonTitle: "Show the Cue Sheet"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .centerWorkspaceBody,
                    headline: "3. Shape a Crossfade",
                    body: "Choose Crossfade on a transition to open the Track Montage Editor. It shows the end of one track and the start of the next over 5 seconds. Click near a curve to add a handle, and drag it while you listen.",
                    shortcutHint: "⌥⌘M • Track Montage Editor",
                    actionButtonTitle: "Open the Track Montage Editor"
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .rightBurnerPool,
                    headline: "4. Set the Burner and Burn",
                    body: "On the burner's card, choose a write speed and turn on Verify to read the disc back after the burn. Raise the copy count to burn the same disc on several burners.",
                    shortcutHint: "⌘B • Run Destination Queue",
                    actionButtonTitle: nil
                )
            ]
        case .multiBurnerPool:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .rightBurnerPool,
                    headline: "1. Burners Above, Waiting Discs Below",
                    body: "The right-hand column has two parts. Above the line is one card for each connected burner. Below it is the waiting pool: the copies or discs that no burner has taken yet.",
                    shortcutHint: "⇧⌘D • Add Destination Card",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .rightBurnerPool,
                    headline: "2. Queue Several Copies",
                    body: "Raise the copy count on a burner card. Each burner takes one copy; the rest wait in the pool below the line.",
                    shortcutHint: "1× to 99× • Copies",
                    actionButtonTitle: "Add 2 Copies"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .rightBurnerPool,
                    headline: "3. Auto-Assign or Ask Each Time",
                    body: "With Auto-Assign, a burner that finishes takes the next waiting disc once a blank is in. With Ask / Manual, you approve each one. Click ↑ on a waiting disc to move it to a burner now.",
                    shortcutHint: "Auto-Assign / Ask / Manual",
                    actionButtonTitle: "Turn Auto-Load On or Off"
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .rightBurnerPool,
                    headline: "4. Watch Each Burner",
                    body: "Each burner card has a Phase Scope that shows write speed, buffer fill and progress while it burns. Open it in its own window to see more.",
                    shortcutHint: "⌥⌘P • Phase Scope Window",
                    actionButtonTitle: nil
                )
            ]
        case .multiDiscSpanning:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .leftFormatSidebar,
                    headline: "1. Choose a Data Disc",
                    body: "Choose Hybrid Data or M-DISC in the Format Chooser. A hybrid disc reads on macOS, Windows and Linux.",
                    shortcutHint: "⌃⌘1 • Hybrid ISO-9660 + Joliet + UDF",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .centerMasteringDeck,
                    headline: "2. See Where Things Go on the Disc",
                    body: "The sector map shows where the parts of the disc start: the ISO 9660 volume descriptor at sector 16 and the UDF anchor at sector 256.",
                    shortcutHint: "⌃⌘L • Inspect LBA Layout",
                    actionButtonTitle: "Show the Sector Map"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .centerCapacityBar,
                    headline: "3. More Than One Disc's Worth",
                    body: "The capacity bar shows when the files are too big for one disc. Burn as Multi-Disc Set splits them across discs; each disc gets a checksum manifest and an index of the whole set.",
                    shortcutHint: "Capacity Bar",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .rightBurnerPool,
                    headline: "4. A Set Survives a Quit",
                    body: "Krouton copies the files before it burns, so changing the originals doesn't change the set, and records each disc as it goes. If Krouton quits halfway, the set resumes with its finished discs still finished.",
                    shortcutHint: "Burn as Multi-Disc Set",
                    actionButtonTitle: nil
                )
            ]
        case .polarLabelStudio:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .leftFormatSidebar,
                    headline: "1. Open the Label Workspace",
                    body: "Press ⌘4 to design a disc label at true size: 120 mm for standard discs, 80 mm for mini discs.",
                    shortcutHint: "⌘4 • Disc Label",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .centerMasteringDeck,
                    headline: "2. Let Auto Label Start It",
                    body: "Auto Label fills in the label's title and subtitle from the disc's title and artist. With Apple Intelligence, a raw name such as SUMMER_2026_FINAL becomes a readable title first. The grid helps you keep things clear of the centre hole.",
                    shortcutHint: "⌘G • 10 mm Alignment Grid",
                    actionButtonTitle: "Show or Hide the Grid"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .centerWorkspaceBody,
                    headline: "3. Add Text and Shapes",
                    body: "Use the tool rail on the left to add text that follows the curve of the disc, a gradient background, or shapes. Freehand strokes can snap to clean circles and polygons.",
                    shortcutHint: "⌘T • Add Curved Text Layer",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .centerMasteringDeck,
                    headline: "4. Export for Your Printer",
                    body: "Export a PNG for your printer's disc software, or a 1:1 PDF with your tray's X and Y offsets applied.",
                    shortcutHint: "Export PNG • Export 1:1 PDF",
                    actionButtonTitle: nil
                )
            ]
        }
    }
}
