import DriveKit
import Foundation
import Observation
import OpticalCore
import SwiftUI

// MARK: - Live Graphical Guided Coach-Mark Tutorial Engine

enum KroutonTutorialTargetZone: String, Sendable, Equatable {
    case leftFormatSidebar
    case centerMasteringDeck
    case centerWorkspaceBody
    case centerCapacityBar
    case rightBurnerPool
}

enum KroutonGuidedTutorialID: String, CaseIterable, Identifiable, Sendable {
    case redBookCrossfade = "red-book-crossfade"
    case multiBurnerPool = "multi-burner-pool"
    case multiDiscSpanning = "multi-disc-spanning"
    case polarLabelStudio = "polar-label-studio"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .redBookCrossfade: return "Red Book Audio CD & 4-Point Bezier Crossfades"
        case .multiBurnerPool: return "Multi-Burner Waiting Pool & Task Promotion"
        case .multiDiscSpanning: return "Archival Multi-Disc Spanning & BagIt Sets"
        case .polarLabelStudio: return "300-DPI Polar Disc Label Studio & Auto-Artwork"
        }
    }

    var subtitle: String {
        switch self {
        case .redBookCrossfade: return "Shape 1/4 & 3/4 track-colored Bezier diamond curves in a 5s viewport with live AVAudioSourceNode auditioning."
        case .multiBurnerPool: return "Run multiple USB burners concurrently, toggle Auto-Assign vs. Manual mode, and promote tasks from the Waiting Pool."
        case .multiDiscSpanning: return "Pack large archives across multiple discs with APFS fclonefileat staging and RFC 8493 BagIt SHA-256 manifests."
        case .polarLabelStudio: return "Harvest artwork with Apple Vision 18mm center-hole avoidance, lay out curved arc text, and export 1:1 print sheets."
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

struct KroutonGuidedTutorialStep: Identifiable, Sendable, Equatable {
    let id: Int
    let zone: KroutonTutorialTargetZone
    let headline: String
    let body: String
    let shortcutHint: String
    let actionButtonTitle: String?
}

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
                    headline: "1. Select Red Book Audio CD (CD-DA)",
                    body: "Choose Red Book Audio CD in the Format Chooser sidebar (or press ^⌘2). Krouton configures 44.1 kHz / 16-bit stereo PCM mastering with 75-frame-per-second timecode precision.",
                    shortcutHint: "^⌘2 • Red Book Audio CD",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .centerMasteringDeck,
                    headline: "2. Author ISO-8859-1 CD-TEXT & Inspect the .CUE Sheet",
                    body: "Enter your Album Title, Artist, and 12/13-digit UPC/EAN barcode. Krouton compiles 18-byte Sony CD-TEXT packs with CRC-16 checksums in real time.",
                    shortcutHint: "^⌘U • Inspect Red Book CUE",
                    actionButtonTitle: "Inspect Live .CUE Sheet"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .centerWorkspaceBody,
                    headline: "3. Shape 4-Point Bezier Diamond Crossfades in a 5s View",
                    body: "Expand any track's Montage drawer (or pop out the floating Track Montage Editor). Hover near the 1/4 or 3/4 points of the Outgoing or Incoming curve and click to spawn independent track-colored Bezier diamond handles. Drag handles while listening via the lock-free AVAudioSourceNode auditioner!",
                    shortcutHint: "⌥⌘M • Pop Out Track Montage",
                    actionButtonTitle: "Open Floating Montage Editor"
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .rightBurnerPool,
                    headline: "4. Choose Write Speed & Verify on Physical Burners",
                    body: "Select a concrete optical write speed on your USB burner card, enable sector verification, or increase the copy count to duplicate across multiple burners simultaneously.",
                    shortcutHint: "⌘B • Execute Active Queue",
                    actionButtonTitle: nil
                )
            ]
        case .multiBurnerPool:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .rightBurnerPool,
                    headline: "1. Two-Zone Multi-Burner Pool Architecture",
                    body: "The Right Queue Column is divided into two zones separated by a secondary-accent divider line: Active Optical Burners sit above the line (one card per connected USB burner), and the Waiting Burn Pool sits below the line.",
                    shortcutHint: "⇧⌘D • Add Destination Card",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .rightBurnerPool,
                    headline: "2. Queue Multiple Copies or Spanned Discs",
                    body: "Increase the Copies stepper (e.g. 4× or 20×) on any burner card. Each connected burner claims one copy immediately while remaining copies queue in the Waiting Burn Pool below the divider.",
                    shortcutHint: "1×..99× • Pool Copy Stepper",
                    actionButtonTitle: "Add +2 Copies to Waiting Pool"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .rightBurnerPool,
                    headline: "3. Auto-Assign vs. Manual & One-Click Promotion (↑)",
                    body: "In Auto-Assign mode, whichever burner finishes and gets a fresh blank disc automatically claims the next waiting ticket via BurnClaimLedger. Click the ↑ arrow on any waiting ticket to promote it to the front of the queue or pin it to a specific burner.",
                    shortcutHint: "Auto-Assign / Manual Pill",
                    actionButtonTitle: "Toggle Auto-Load Mode"
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .rightBurnerPool,
                    headline: "4. USB Bus Power & Bandwidth Arbitration",
                    body: "When burning on 2–4 USB drives at once, Krouton's BusArbitrationState staggers lead-in laser calibration by 10 seconds and monitors hardware buffer fill to prevent USB bus underruns.",
                    shortcutHint: "⌥⌘P • Phase Scope Telemetry",
                    actionButtonTitle: nil
                )
            ]
        case .multiDiscSpanning:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .leftFormatSidebar,
                    headline: "1. Choose Hybrid ISO-9660 + Joliet + UDF or M-DISC Vault",
                    body: "Select Hybrid Data or M-DISC Archival Vault in the left sidebar. Krouton masters a single volume readable on macOS, Windows, and Linux simultaneously.",
                    shortcutHint: "^⌘1 • Hybrid ISO/UDF",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .centerMasteringDeck,
                    headline: "2. Inspect the 2048-Byte Sector & Hybrid LBA Map",
                    body: "Verify Primary Volume Descriptor (LBA 16), El Torito Boot Catalog (LBA 17), and UDF Anchor Volume Descriptor Pointer (LBA 256) allocations before burning.",
                    shortcutHint: "^⌘L • Inspect Hybrid LBA",
                    actionButtonTitle: "Open Hybrid LBA Inspector"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .centerCapacityBar,
                    headline: "3. Automatic Multi-Disc Spanning & Capacity Bar",
                    body: "When staged files exceed a single disc's capacity, Krouton's deterministic First-Fit-Decreasing DiscPlanner packs them across Disc 1..N and writes an RFC 8493 BagIt SHA-256 manifest onto every disc.",
                    shortcutHint: "Capacity & Spanning Bar",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .rightBurnerPool,
                    headline: "4. APFS Copy-on-Write Staging & Crash-Safe Journal",
                    body: "BurnSetStager freezes source files instantaneously on APFS using descriptor-pinned fclonefileat() and logs every disc attempt to burn-set-events.jsonl so interrupted sets resume cleanly.",
                    shortcutHint: "⌘B • Start Spanned Burn",
                    actionButtonTitle: nil
                )
            ]
        case .polarLabelStudio:
            return [
                KroutonGuidedTutorialStep(
                    id: 0,
                    zone: .leftFormatSidebar,
                    headline: "1. Open the Polar 300-DPI Disc Label Studio",
                    body: "Switch to the Label workspace (⌘4) to design edge-to-edge 120mm / 80mm optical disc artwork with true millimeter geometry.",
                    shortcutHint: "⌘4 • Polar Disc Label Studio",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 1,
                    zone: .centerMasteringDeck,
                    headline: "2. Auto Label with Apple Vision Center-Hole Avoidance",
                    body: "Click Auto Label to harvest album artwork, extract Display-P3 harmony swatches, and keep faces or logos outside the 18mm transparent center hub.",
                    shortcutHint: "⌘G • Toggle 10mm Grid",
                    actionButtonTitle: "Toggle 10mm Alignment Grid"
                ),
                KroutonGuidedTutorialStep(
                    id: 2,
                    zone: .centerWorkspaceBody,
                    headline: "3. Curved Arc Typography & Freehand Vector Shapes",
                    body: "Use the left tool rail to add curved polar arc text, Metal/CoreImage circular gradients, or draw freehand strokes that automatically snap to clean vector geometry.",
                    shortcutHint: "⌘T • Add Curved Text Layer",
                    actionButtonTitle: nil
                ),
                KroutonGuidedTutorialStep(
                    id: 3,
                    zone: .centerMasteringDeck,
                    headline: "4. Export 1:1 Vector PDF Print Sheet or 300-DPI PNG",
                    body: "Export a millimeter-calibrated 1:1 Vector PDF print sheet (with X/Y tray offset compensation for Epson EcoTank ET-8550 & Canon trays) or a 300-DPI archival PNG.",
                    shortcutHint: "1:1 Vector PDF & 300-DPI PNG",
                    actionButtonTitle: nil
                )
            ]
        }
    }
}
