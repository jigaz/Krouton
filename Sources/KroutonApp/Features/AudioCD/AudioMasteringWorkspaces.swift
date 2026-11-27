import AudioKit
import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

/// The Red Book workspace: track list, gaps, crossfades (Splice editor with live audition),
/// CD-Text and the compiled CUE preview.
///
/// The burn renders this editor's `AudioProject` (`KroutonAudioDiscRenderer`) and writes it
/// session-at-once; for CD-Extra, `CDExtraDataSessionView` adds the files for a second, data
/// session in the same burn.
struct KroutonRedBookAudioWorkspaceView: View {
    var store: KroutonStateStore
    var auditioner = SpliceAudioAuditioner.shared
    var montageState = TrackMontageWindowState.shared
    @Environment(\.undoManager) var undoManager

    let spec: KroutonOpticalWorkflowSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State var showAudioCuePopover: Bool = false
    @State var expandedTransitionTrackID: UUID? = nil
    @State var selectedTrackIDs: Set<UUID> = []
    @State var draggedTrackID: UUID? = nil
    @State var isrcDrafts: [UUID: String] = [:]
    @State var invalidISRCTrackIDs: Set<UUID> = []
    @State var showISRCBatchPopover: Bool = false
    @State var batchISRCSeed: String = ""

    var controller: AudioProjectController { store.audioController }
    var project: AudioProject { controller.project }

    var deckHeaderTitle: String {
        switch spec.id {
        case "cd-extra": return "BLUE BOOK 2-SESSION AUDIO + DATA DECK"
        case "dts-cd": return "IEC 61937 5.1 DTS-CD SURROUND MASTERING DECK"
        case "dvd-audio": return "DVD-AUDIO HIGH-RESOLUTION MASTERING DECK (24-BIT / 192 kHz MLP)"
        default: return "RED BOOK AUDIO CD & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM)"
        }
    }

    var allTracksSelected: Bool {
        !project.tracks.isEmpty && selectedTrackIDs.count == project.tracks.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            audioMasteringDeckHeaderSection
            if !selectedTrackIDs.isEmpty {
                AudioBatchSelectionActionBarView(
                    store: store,
                    controller: controller,
                    selectedTrackIDs: $selectedTrackIDs,
                    isrcDrafts: $isrcDrafts,
                    invalidISRCTrackIDs: $invalidISRCTrackIDs
                )
            }
            audioTracklistSection
            if spec.id == "cd-extra" {
                CDExtraDataSessionView(store: store)
            }
        }
        .onChange(of: undoManager, initial: true) { _, manager in
            controller.undoManager = manager
        }
        .onChange(of: montageState.activeTrackID) { _, newID in
            if let newID { expandedTransitionTrackID = newID }
        }
        .onChange(of: project.tracks.map(\.id)) { _, validIDs in
            selectedTrackIDs = selectedTrackIDs.intersection(Set(validIDs))
        }
        .onChange(of: project.albumTitle) { _, newValue in
            if !newValue.isEmpty {
                store.cdTextAlbumTitle = newValue
                store.discVolumeTitle = newValue
            }
        }
        .onChange(of: project.albumPerformer) { _, newValue in
            if !newValue.isEmpty {
                store.cdTextAlbumPerformer = newValue
                store.discPerformer = newValue
            }
        }
    }

    // MARK: - Top Mastering Deck Header

    @ViewBuilder
    var audioMasteringDeckHeaderSection: some View {
        let cdBlock = project.compileCDTextBlock()
        let packs = cdBlock?.packs.count ?? 0

        KroutonMasteringDeckCard(store: store) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: spec.sfSymbol).foregroundStyle(store.activeAccent)
                    Text(deckHeaderTitle)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)

                    Text("ISO-8859-1 • ≤60 chars/field • \(packs)/255 Packs")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(packs > 240 ? .orange : .secondary)

                    Button {
                        store.stampProjectTracklistOrManifestOnDisc(albumTitle: project.albumTitle, performer: project.albumPerformer)
                    } label: {
                        Label("Sync to Label", systemImage: "opticaldisc").font(.system(size: 10, weight: .bold))
                    }.buttonStyle(.bordered).controlSize(.small)

                    Button {
                        showAudioCuePopover.toggle()
                    } label: {
                        Label(".CUE (\(packs) Packs)", systemImage: "doc.text.magnifyingglass")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .popover(isPresented: $showAudioCuePopover, arrowEdge: .bottom) {
                        KroutonAudioCuePopoverView(store: store)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .kroutonMenuInspectAudioCue)) { _ in showAudioCuePopover = true }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("Album:").font(.caption.bold()).fixedSize()
                        TextField("Album Title (≤60 Latin-1 chars)", text: controller.albumTitleBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 130)
                            .disabled(!project.writeCDText)

                        Text("Artist:").font(.caption.bold()).fixedSize()
                        TextField("Album Performer (≤60 Latin-1 chars)", text: controller.albumPerformerBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 130)
                            .disabled(!project.writeCDText)
                    }

                    HStack(spacing: 10) {
                        Text("UPC/EAN:").font(.caption.bold()).fixedSize()
                        KroutonDigitsOnlyTextField(placeholder: "12/13 digits", text: controller.upcBinding)
                            .frame(width: 125)

                        Toggle(KroutonL10n.tr("Write CD-TEXT"), isOn: controller.writeCDTextBinding)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .fixedSize()

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Tracklist Table

    @ViewBuilder
    var audioTracklistSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.kroutonControlSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isDropTargeted ? store.activeAccent : Color.primary.opacity(0.1), lineWidth: isDropTargeted ? 2 : 1)
                )

            if project.tracks.isEmpty {
                KroutonEmptyDropZoneView(
                    store: store,
                    isDropTargeted: isDropTargeted,
                    sfSymbol: spec.sfSymbol,
                    headline: "Drop Audio Tracks or Album Folders (.WAV, .FLAC, .AIFF, .M4A, .MP3)",
                    subtitle: "Folders and nested album subfolders are unpacked in alphabetical order with off-main-actor analysis."
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Button {
                            if allTracksSelected {
                                selectedTrackIDs.removeAll()
                            } else {
                                selectedTrackIDs = Set(project.tracks.map(\.id))
                            }
                        } label: {
                            Image(systemName: allTracksSelected ? "checkmark.square.fill" : (selectedTrackIDs.isEmpty ? "square" : "minus.square.fill"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selectedTrackIDs.isEmpty ? Color.secondary : store.activeAccent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(KroutonL10n.tr(allTracksSelected ? "Deselect All Tracks" : "Select All Tracks"))
                        .help(KroutonL10n.tr(allTracksSelected ? "Deselect All Tracks" : "Select All Tracks"))
                        .frame(width: 20, alignment: .center)

                        Text("#").frame(width: 42, alignment: .leading)
                        Text("Pause").frame(width: 68, alignment: .leading)
                        Text("CD-TEXT Title (≤60 Latin-1)").frame(maxWidth: .infinity, alignment: .leading)
                        if !isCenterWorkspaceNarrow {
                            Text("CD-TEXT Artist").frame(width: 145, alignment: .leading)
                            Text("ISRC (ISO 3901)").frame(width: 118, alignment: .leading)
                        }
                        Text("Length").frame(width: 68, alignment: .trailing)
                        Text("Montage").frame(width: 118, alignment: .center)
                        Spacer().frame(width: 44)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))

                    let audioPlan = project.discPlan()
                    let discs = audioPlan.discs
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(discs) { disc in
                                if disc.number > 1 {
                                    AudioAdditionalDiscHeaderView(
                                        store: store,
                                        controller: controller,
                                        disc: disc,
                                        totalDiscs: discs.count,
                                        isProvisional: audioPlan.isProvisional,
                                        splitsContinuousRun: audioPlan.warnings.contains {
                                            if case .breakSplitsContinuousRun(let prevNum, _, _) = $0 { return prevNum == disc.number - 1 }
                                            return false
                                        }
                                    )
                                }
                                ForEach(Array(disc.tracks.enumerated()), id: \.element.id) { localIdx, track in
                                    let isLastOnDisc = (localIdx == disc.tracks.count - 1)
                                    let trackNumOnDisc = localIdx + 1
                                    VStack(spacing: 0) {
                                        trackRowView(
                                            track: track,
                                            discNumber: disc.number,
                                            trackNum: trackNumOnDisc,
                                            isLastOnDisc: isLastOnDisc,
                                            totalDiscs: discs.count
                                        )
                                        .onDrag {
                                            draggedTrackID = track.id
                                            return NSItemProvider(object: track.id.uuidString as NSString)
                                        }
                                        .onDrop(
                                            of: [UTType.text],
                                            delegate: AudioTrackReorderDropDelegate(
                                                targetTrackID: track.id,
                                                controller: controller,
                                                draggedTrackID: $draggedTrackID
                                            )
                                        )

                                        if expandedTransitionTrackID == track.id, !isLastOnDisc {
                                            inlineCrossfadeDrawer(
                                                for: track,
                                                trackNum: trackNumOnDisc
                                            )
                                        }
                                        Divider().opacity(0.3)
                                    }
                                }
                            }
                        }
                    }

                    Divider().opacity(0.4)
                    bottomTransportFooter
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
    }

    @ViewBuilder
    var bottomTransportFooter: some View {
        let cdTextBlock = project.compileCDTextBlock()
        let packCount = cdTextBlock?.packs.count ?? 0
        let warningCount = cdTextBlock?.warnings.count ?? 0

        let spans = project.discPlan().discs
        HStack(spacing: 12) {
            if let totalFrames = project.totalFrames {
                Text("\(project.tracks.count) Tracks across \(spans.count) Disc\(spans.count == 1 ? "" : "s") • \(KroutonAudioEngine.formatFramesToMMSSFF(totalFrames)) Total")
                    .kroutonReadout(emphasised: spans.count > 1)
            } else {
                Text("\(project.tracks.count) Tracks • Analysing length…")
                    .kroutonReadout()
            }

            Text("• Drag ≡ to reorder")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                guard let first = project.tracks.first else { return }
                let second = project.track(after: first.id)
                auditioner.startTransitionAudition(
                    trackID: first.id,
                    outgoingURL: first.source,
                    incomingURL: second?.source,
                    spec: controller.transition(after: first.id),
                    suppressedAtDiscBoundary: controller.isTransitionSuppressedByDiscBreak(after: first.id)
                )
            } label: {
                Image(systemName: auditioner.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 26, height: 20)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            if project.writeCDText {
                HStack(spacing: 6) {
                    Circle()
                        .fill(packCount > 240 ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text("CD-TEXT: \(packCount)/255 Packs • ISO-8859-1\(warningCount > 0 ? " (\(warningCount) folded)" : "")")
                        .kroutonReadout()
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }
}
