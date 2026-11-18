import DriveKit
import Foundation
import OpticalCore
import SwiftUI

// MARK: - Searchable Built-In Krouton User Manual, Shortcuts & Interactive Tutorial Launcher

enum KroutonManualChapter: String, CaseIterable, Identifiable, Sendable {
    case quickStart = "1. Quick Start & Workspace Layout"
    case audioCrossfades = "2. Red Book Audio & 4-Point Crossfades"
    case multiBurnerPool = "3. Multi-Burner Pool & Waiting Queue"
    case spanningAndHybrid = "4. Multi-Disc Spanning & Hybrid ISO/UDF"
    case videoAndRescue = "5. DVD-9 Shrink, Video Rip & Bad-Sector Rescue"
    case polarLabelStudio = "6. Polar 300-DPI Disc Label Studio"
    case shortcutsAndGlossary = "7. Keyboard Shortcuts & Optical Glossary"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .quickStart: return "sparkles.rectangle.stack.fill"
        case .audioCrossfades: return "waveform.path.ecg.rectangle.fill"
        case .multiBurnerPool: return "externaldrive.connected.to.line.below.fill"
        case .spanningAndHybrid: return "square.stack.3d.up.fill"
        case .videoAndRescue: return "film.stack.fill"
        case .polarLabelStudio: return "printer.dotmatrix.fill"
        case .shortcutsAndGlossary: return "command.square.fill"
        }
    }

    var associatedTutorial: KroutonGuidedTutorialID? {
        switch self {
        case .quickStart: return .redBookCrossfade
        case .audioCrossfades: return .redBookCrossfade
        case .multiBurnerPool: return .multiBurnerPool
        case .spanningAndHybrid: return .multiDiscSpanning
        case .videoAndRescue: return nil
        case .polarLabelStudio: return .polarLabelStudio
        case .shortcutsAndGlossary: return nil
        }
    }

    var sections: [(heading: String, detail: String)] {
        switch self {
        case .quickStart:
            return [
                ("Three-Column Mastering Architecture", "Krouton organizes every optical workflow into three resizable columns: the Left Format Chooser Sidebar (⌘1–⌘5), the Center Mastering Deck & Integrated Capacity Bar, and the Right Two-Zone Destination Queue & Multi-Burner Pool."),
                ("Interactive Live Coach-Mark Tours", "Click any Guided Tour card above (or choose Help -> Interactive Guided Tutorials in the macOS menu bar) to launch a live graphical spotlight overlay that highlights controls directly on the active workspace."),
                ("Crash-Safe Session Persistence (.krut)", "Every staged file list, Red Book transition, disc break, and label layer is journaled automatically. Use File -> Save Project (⌘S) to archive a portable .krut project file.")
            ]
        case .audioCrossfades:
            return [
                ("5.0-Second Precision Crossfade Viewport", "Switching any track transition to Crossfade automatically frames the Track Montage Editor to a 5.0-second timeline window so the Outgoing and Incoming gain curves fill the canvas. Toggle Zoom Out for a 15.0-second extended view."),
                ("Four Independent 1/4 & 3/4 Bezier Diamond Curve Handles", "Hover near the 1/4 (t = 0.25) or 3/4 (t = 0.75) region of either the Outgoing or Incoming curve to reveal a dashed track-colored Ghost Bezier Diamond. Click in that vicinity to spawn the handle and shape each quarter of the fade-out and fade-in curves independently. Double-click any handle to hide it, or click Reset to restore factory defaults."),
                ("Dual-Track BPM & Tempo Delta Readouts", "Krouton estimates track tempo (BPM) off the 75 Hz frame onset envelope during background analysis and displays Outgoing BPM, Incoming BPM, and ΔBPM right in the Track Montage header and track badges."),
                ("Lock-Free AVAudioSourceNode Live Auditioning", "Press Preview to audition the transition through a sample-accurate 44.1 kHz AVAudioSourceNode driven by CrossfadeParameterMailbox. Dragging any Bezier diamond handle or X-Fade/Tension slider updates the live audio stream within 2.9 ms without zipper noise."),
                ("Click Inline Mini Ghost Graph to Focus Popped-Out Window", "When the Track Montage Editor is popped out (⌥⌘M), an inline 25%-height mini waveform remains in the tracklist. Clicking the mini waveform immediately brings the popped-out Track Montage Editor window to the front.")
            ]
        case .multiBurnerPool:
            return [
                ("Two-Zone Active Burners & Waiting Burn Pool", "When multiple USB optical burners are plugged in, each physical burner appears in the top Active Burners zone. Increasing the Copies stepper (up to 99×) or staging a multi-disc spanned set populates the Waiting Burn Pool below the secondary-accent divider line."),
                ("Late-Binding BurnClaimLedger & Non-Stranding Pool", "Burners never pre-lock waiting discs while idle. A disc is committed only when blank media is physically present and validated, so an untouched second burner tray never strands a multi-disc set."),
                ("Auto-Assign vs. Manual Mode & Task Promotion (↑)", "Toggle between Auto-Assign (Next Free) and Ask / Manual in the Waiting Burn Pool header. Click the ↑ promote button on any waiting ticket to move it to the front of the queue or assign it to an idle burner."),
                ("USB Power & Bandwidth Arbiter", "BusArbitrationState spaces out concurrent burner spin-ups and OPC laser calibrations by 10 seconds and monitors hardware buffer fill and CAV speed sag so multiple USB drives never starve the bus.")
            ]
        case .spanningAndHybrid:
            return [
                ("Deterministic Multi-Disc Spanning (DiscPlanner)", "When staged files exceed a single disc, Krouton packs items across Disc 1..N using First-Fit-Decreasing bin packing (or sequential order when manual disc breaks are set)."),
                ("APFS fclonefileat() Zero-Extra-Space Staging", "BurnSetStager freezes every source file using descriptor-pinned APFS copy-on-write clones (fclonefileat) verified with fstat stamps, hashing the staged clone and removing temporary per-disc directories as soon as each .iso is sealed."),
                ("RFC 8493 BagIt & Cross-Disc Set Index", "Every spanned disc includes krouton-set-index.json and SHA-256 manifests so any individual disc can be verified standalone or reassembled with the full set."),
                ("Hybrid ISO-9660 + Joliet + UDF + HFS+ & Custom .DS_Store", "Toggle [Mac] and [PC] visibility pills per file to build platform-tailored hybrid discs, or switch to the Custom Finder Layout tab to author icon positions, color tags, and backgrounds into a real .DS_Store.")
            ]
        case .videoAndRescue:
            return [
                ("DVD-9 to DVD-5 Menu-Preserving Shrink", "Compresses dual-layer 8.5 GB DVD-9 titles onto standard 4.7 GB DVD-5 media using Apple Silicon VideoToolbox 2-pass VBR while preserving interactive menus, NV_PCK highlight overlays, and relinking .IFO sector pointers."),
                ("Optical Bad-Sector Rescue & C2 Quality Grading", "Recovers scratched CDs, DVDs, and Blu-rays using adaptive multi-pass sector bisection and generates an Archival Quality Certificate graded by C2 error telemetry.")
            ]
        case .polarLabelStudio:
            return [
                ("1-Click Auto Label & Apple Vision Hole Avoidance", "Harvests embedded, folder, or MusicBrainz artwork, extracts a Display-P3 harmony palette, and uses Apple Vision saliency detection to keep subjects clear of the 18mm center hole."),
                ("Curved Polar Arc Typography & Vector Shape Recognition", "Add curved arc text layers (⌘T), duplicate 180°-mirrored bottom-upright text (⌘D), or draw freehand shapes that vectorize automatically."),
                ("1:1 Millimeter-Calibrated Print Sheets", "Export 1:1 Vector PDF print sheets or 300-DPI PNGs calibrated with X/Y millimeter tray offsets for Epson EcoTank ET-8550, Canon PIXMA, and standard 120mm/80mm trays.")
            ]
        case .shortcutsAndGlossary:
            return [
                ("Workspace & Window Shortcuts", "⌘1 Burn Station • ⌘2 Disc Image Depot • ⌘3 Copy, Rip & Rescue • ⌘4 Polar Disc Label Studio • ⌘5 Audio CD Ripper • ⌘0 Main Window • ⌥⌘M Track Montage Editor Window • ⌥⌘P Floating Phase Scope • ⌘, Settings • ⌘? User Manual."),
                ("Mastering, Format & Inspector Shortcuts", "^⌘1 Hybrid ISO/UDF • ^⌘2 Red Book Audio CD • ^⌘3 DVD-Video • ^⌘4 Blu-ray 25GB • ^⌘5 M-DISC Vault • ^⌘6 Burn Disc Image • ^⌘L Inspect Hybrid LBA • ^⌘U Inspect Red Book CUE • ^⌘B Inspect Video Bitrate."),
                ("Disc & Transport Shortcuts", "⌘B Execute Active Queue / Burn Now • ⌘. Abort Active Operation • ⌘R Rescan Optical Drives • ⌘E Eject Optical Media • ⇧⌘P Phase Scope Sweep • ⇧⌘M Stamp DVD-ROM Book Type • ⌥⌘R Scan Audio CD TOC • ⇧⌘R Rip Selected Tracks • ⌘I CD Info."),
                ("Optical Engineering Glossary", "LBA (Logical Block Address): 2048-byte sector index on data media. Red Book Frame: 1/75th of a second (2352 bytes of 44.1 kHz 16-bit stereo PCM). INDEX 00 / 01: Red Book pre-gap silence / track start marker. OPC (Optimum Power Calibration): Laser power test at inner calibration area before lead-in write. Book Type Bitsetting: MMC command stamping DVD+R/DL lead-in as DVD-ROM (0x00).")
            ]
        }
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let hay = (rawValue + " " + sections.map { $0.heading + " " + $0.detail }.joined(separator: " ")).lowercased()
        return q.split(separator: " ").allSatisfy { hay.contains($0) }
    }
}

struct KroutonUserManualWindowView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var tutorialController = KroutonGuidedTutorialController.shared

    @State private var selectedChapter: KroutonManualChapter = .quickStart
    @State private var searchQuery: String = ""

    private var filteredChapters: [KroutonManualChapter] {
        let list = KroutonManualChapter.allCases.filter { $0.matches(query: searchQuery) }
        return list.isEmpty ? KroutonManualChapter.allCases : list
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search manual, shortcuts & glossary", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.kroutonControlSurface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CHAPTERS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)

                        ForEach(filteredChapters) { chapter in
                            let isSelected = (selectedChapter == chapter)
                            Button {
                                selectedChapter = chapter
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: chapter.sfSymbol)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isSelected ? store.activeOnAccentText : store.activeAccent)
                                        .frame(width: 18)
                                    Text(chapter.rawValue)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(isSelected ? store.activeAccent : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 6)

                        Text("LIVE GRAPHICAL TUTORIALS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(KroutonGuidedTutorialID.allCases) { tour in
                            Button {
                                KroutonWindowManager.shared.startGuidedTutorialOnMainWorkspace(tour)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: tour.sfSymbol)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(store.uiSecondaryAccent)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tour.title)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("Launch Live Coach-Mark Tour")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(store.uiSecondaryAccent)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.kroutonControlSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 270, max: 310)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: selectedChapter.sfSymbol)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedChapter.rawValue)
                                .font(.title2.bold())
                            Text("Krouton Optical Media Mastering Manual & Live Reference")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let tour = selectedChapter.associatedTutorial {
                            Button {
                                KroutonWindowManager.shared.startGuidedTutorialOnMainWorkspace(tour)
                            } label: {
                                Label("Launch Live Graphical Tutorial", systemImage: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(store.activeAccent)
                        }
                    }

                    Divider()

                    ForEach(Array(selectedChapter.sections.enumerated()), id: \.offset) { _, sec in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sec.heading)
                                .font(.headline)
                                .foregroundStyle(store.activeAccent)
                            Text(sec.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.kroutonControlSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.kroutonWindowSurface)
        }
        .frame(minWidth: 880, idealWidth: 980, minHeight: 540, idealHeight: 660)
        .preferredColorScheme(store.resolvedColorScheme)
        .tint(store.activeAccent)
    }
}
