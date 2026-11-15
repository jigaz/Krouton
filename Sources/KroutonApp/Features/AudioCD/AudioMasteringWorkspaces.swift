import VideoKit
import ImageKit
import AudioKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct KroutonRedBookAudioWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject private var auditioner = SpliceAudioAuditioner.shared
    @ObservedObject private var montageState = TrackMontageWindowState.shared
    @Environment(\.undoManager) private var undoManager

    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var cdTextAlbumTitle: String
    @Binding var cdTextAlbumPerformer: String
    @Binding var auditioningTrackID: UUID?
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var showMarmaladeCuePopover: Bool = false
    @State private var expandedTransitionTrackID: UUID? = nil
    @State private var selectedTrackIDs: Set<UUID> = []
    @State private var draggedTrackID: UUID? = nil
    @State private var isrcDrafts: [UUID: String] = [:]
    @State private var invalidISRCTrackIDs: Set<UUID> = []
    @State private var showISRCBatchPopover: Bool = false
    @State private var batchISRCSeed: String = "USKRO2600001"
    @State private var cdTextStatusNotice: String = ""

    private var controller: AudioProjectController { store.audioController }
    private var project: AudioProject { controller.project }

    private var deckHeaderTitle: String {
        switch spec.id {
        case "cd-extra": return "BLUE BOOK 2-SESSION AUDIO + XA DATA DECK"
        case "dts-cd": return "IEC 61937 5.1 DTS-CD SURROUND MASTERING DECK"
        case "dvd-audio": return "DVD-AUDIO HIGH-RESOLUTION MASTERING DECK (24-BIT / 192 kHz MLP)"
        case "sacd-r": return "SCARLET BOOK DSD / SACD-R MASTERING DECK (1-BIT DSD64)"
        case "cd-g": return "RED BOOK CD+G KARAOKE MASTERING DECK (R-W SUBCHANNEL)"
        default: return "RED BOOK AUDIO CD & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM)"
        }
    }

    private var allTracksSelected: Bool {
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
                cdTextAlbumTitle = newValue
                store.discVolumeTitle = newValue
            }
        }
        .onChange(of: project.albumPerformer) { _, newValue in
            if !newValue.isEmpty {
                cdTextAlbumPerformer = newValue
                store.discPerformer = newValue
            }
        }
    }

    // MARK: - Tracklist Table

    @ViewBuilder
    private var audioTracklistSection: some View {
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
                        .frame(width: 20, alignment: .center)
                        .help(allTracksSelected ? "Deselect All Tracks" : "Select All Tracks")

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
    private var bottomTransportFooter: some View {
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
                    spec: controller.transition(after: first.id)
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

    @ViewBuilder
    private func trackRowView(track: AudioTrack, discNumber: Int, trackNum: Int, isLastOnDisc: Bool, totalDiscs: Int) -> some View {
        let isLastTrack = isLastOnDisc
        let tr = controller.transition(after: track.id)
        let isExpanded = (expandedTransitionTrackID == track.id) && !isLastTrack
        let isPlayingThis = (auditioner.isPlaying && auditioner.activeTrackID == track.id)
        let isSelected = selectedTrackIDs.contains(track.id)
        let isBeingDragged = (draggedTrackID == track.id)
        let nextTrack = project.track(after: track.id)
        let state = controller.analysis[track.id]
        let isISRCInvalid = invalidISRCTrackIDs.contains(track.id)

        HStack(spacing: 8) {
            // 1. Multi-select Checkbox
            Button {
                if isSelected {
                    selectedTrackIDs.remove(track.id)
                } else {
                    selectedTrackIDs.insert(track.id)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isSelected ? store.activeAccent : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20, alignment: .center)

            // 2. Drag Grip Handle + Track Number (Replaces up/down arrows)
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
                Text(String(format: "%02d", trackNum))
                    .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isSelected ? store.activeAccent : .primary)
            }
            .frame(width: 42, alignment: .leading)
            .help("Drag row to reorder track position on disc")

            // 3. Pause / Transition Quick Menu
            if isLastTrack {
                Text(totalDiscs > 1 ? "Disc \(discNumber) End" : "Lead-Out")
                    .kroutonReadout()
                    .frame(width: 68, alignment: .leading)
                    .help(totalDiscs > 1 ? "End of Disc \(discNumber). Any crossfade on this track is suspended across the disc break and restored if tracks move back onto one disc." : "Disc Lead-Out")
            } else {
                Menu {
                    Button("0 sec (Gapless)") {
                        controller.commitTransition(tr.switched(to: .gapless), after: track.id, actionName: "Set Gapless")
                    }
                    Button("1 sec Pause") {
                        var updated = tr.switched(to: .gap); updated.preGapSeconds = 1.0
                        controller.commitTransition(updated, after: track.id, actionName: "Set 1s Pause")
                    }
                    Button("2 sec Standard Pause") {
                        var updated = tr.switched(to: .gap); updated.preGapSeconds = 2.0
                        controller.commitTransition(updated, after: track.id, actionName: "Set 2s Pause")
                    }
                    Divider()
                    Button("2.5s Crossfade") {
                        controller.commitTransition(tr.switched(to: .crossfade), after: track.id, actionName: "Set Crossfade")
                    }
                } label: {
                    Text(tr.isCrossfading ? String(format: "%.1fs X", tr.overlapSeconds) : String(format: "%.0f sec", tr.preGapSeconds))
                        .kroutonReadout()
                }
                .menuStyle(.borderlessButton)
                .frame(width: 68, alignment: .leading)
            }

            // 4. Editable CD-TEXT Track Title (Enforces ISO-8859-1 & <= 60 chars)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    TextField(track.source.deletingPathExtension().lastPathComponent, text: controller.titleBinding(track.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, weight: .semibold))
                    if track.title.count >= 52 {
                        Text("\(track.title.count)/60")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(track.title.count >= 60 ? .orange : .secondary)
                    }
                }
                if case .failed(let reason)? = state {
                    Text(reason)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 5. Editable CD-TEXT Track Performer & ISO 3901 ISRC
            if !isCenterWorkspaceNarrow {
                TextField(project.albumPerformer.isEmpty ? "Track Artist" : project.albumPerformer, text: controller.performerBinding(track.id))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 145, alignment: .leading)

                TextField(
                    "CCXXXYYNNNNN",
                    text: Binding(
                        get: { isrcDrafts[track.id] ?? track.isrc },
                        set: { raw in
                            let cleaned = String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(12))
                            isrcDrafts[track.id] = cleaned
                            if cleaned.isEmpty || cleaned.count == 12 {
                                if controller.setISRC(cleaned, for: track.id) {
                                    invalidISRCTrackIDs.remove(track.id)
                                    isrcDrafts.removeValue(forKey: track.id)
                                } else {
                                    invalidISRCTrackIDs.insert(track.id)
                                }
                            } else {
                                invalidISRCTrackIDs.insert(track.id)
                            }
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isISRCInvalid ? Color.orange : Color.clear, lineWidth: 1)
                )
                .help("ISO 3901 ISRC: 2 country letters + 3 registrant chars + 2 year digits + 5 serial digits (12 chars)")
                .frame(width: 118, alignment: .leading)
            }

            // 6. Analysed Red Book Length (MM:SS:FF)
            Group {
                if let frames = track.frameCount {
                    Text(KroutonAudioEngine.formatFramesToMMSSFF(frames))
                        .kroutonReadout(emphasised: true)
                } else if case .failed? = state {
                    Text("Unreadable").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.red)
                } else {
                    Text("…").kroutonReadout()
                }
            }
            .frame(width: 68, alignment: .trailing)

            // 7. Track Montage Editor Toggle Button
            if isLastTrack {
                Spacer().frame(width: 118)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        let nextID = isExpanded ? nil : track.id
                        expandedTransitionTrackID = nextID
                        if let nextID { montageState.activeTrackID = nextID }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tr.isCrossfading ? String(format: "%.1fs X-Fade", tr.overlapSeconds) : (tr.preGapSeconds <= 0.01 ? "Gapless" : String(format: "%.1fs Gap", tr.preGapSeconds)))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                }
                .buttonStyle(KroutonPillButtonStyle(isOn: isExpanded))
                .frame(width: 118, alignment: .center)
            }

            // 8. Row Audition & Delete
            HStack(spacing: 6) {
                Button {
                    auditioner.startTransitionAudition(
                        trackID: track.id,
                        outgoingURL: track.source,
                        incomingURL: nextTrack?.source,
                        spec: tr
                    )
                } label: {
                    Image(systemName: isPlayingThis ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isPlayingThis ? Color.green : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    selectedTrackIDs.remove(track.id)
                    controller.remove(track.id)
                    store.removeStagedFile(id: track.id)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? store.activeAccent.opacity(0.16) : (isBeingDragged ? Color.primary.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? store.activeAccent.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if project.index(of: track.id) ?? 0 > 0 {
                Button(track.startsNewDisc ? "Merge Back With Previous Disc" : "Start New Disc Here (Disc Break)") {
                    controller.toggleManualDiscBreak(before: track.id)
                }
                Divider()
            }
            Button(isSelected ? "Uncheck Track" : "Check Track") {
                if isSelected { selectedTrackIDs.remove(track.id) } else { selectedTrackIDs.insert(track.id) }
            }
            Button(role: .destructive) {
                selectedTrackIDs.remove(track.id)
                controller.remove(track.id)
                store.removeStagedFile(id: track.id)
            } label: {
                Text("Remove Track")
            }
        }
    }

    @ViewBuilder
    private func inlineCrossfadeDrawer(for track: AudioTrack, trackNum: Int) -> some View {
        let trackID = track.id
        let nextTrack = project.track(after: trackID)
        let outTitle = track.title.isEmpty ? track.source.deletingPathExtension().lastPathComponent : track.title
        let inTitle = nextTrack.map { $0.title.isEmpty ? $0.source.deletingPathExtension().lastPathComponent : $0.title } ?? "Lead-Out"

        SpliceWorkspaceView(
            trackNumber: trackNum,
            totalTransitions: max(1, project.tracks.count - 1),
            outgoingTitle: outTitle,
            incomingTitle: inTitle,
            spec: controller.transition(after: trackID),
            outgoing: controller.readyAnalysis(trackID),
            incoming: nextTrack.flatMap { controller.readyAnalysis($0.id) },
            primaryColor: store.activeAccent,
            harmonyColor: store.uiSecondaryAccent,
            isFloatingWindow: false,
            onPreview: { controller.preview($0, after: trackID) },
            onCommit: { controller.commitTransition($0, after: trackID) },
            onAudition: {
                auditioner.startTransitionAudition(
                    trackID: trackID,
                    outgoingURL: track.source,
                    incomingURL: nextTrack?.source,
                    spec: controller.transition(after: trackID)
                )
            }
        )
    }

    @ViewBuilder
    private var audioMasteringDeckHeaderSection: some View {
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
                        showMarmaladeCuePopover.toggle()
                    } label: {
                        Label(".CUE (\(packs) Packs)", systemImage: "doc.text.magnifyingglass")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .popover(isPresented: $showMarmaladeCuePopover, arrowEdge: .bottom) {
                        KroutonMarmaladeCuePopoverView(store: store)
                    }
                }

                HStack(spacing: 10) {
                    Text("Album:").font(.caption.bold())
                    TextField("Album Title (≤60 Latin-1 chars)", text: controller.albumTitleBinding)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!project.writeCDText)

                    Text("Artist:").font(.caption.bold())
                    TextField("Album Performer (≤60 Latin-1 chars)", text: controller.albumPerformerBinding)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!project.writeCDText)

                    Text("UPC/EAN:").font(.caption.bold())
                    TextField("12/13 digits", text: controller.upcBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 125)

                    Picker("", selection: controller.targetDiscMediumBinding) {
                        ForEach(KroutonSpanningDiscMedium.allowedMedia(forFormatID: "cd-da")) { med in
                            Text(med.rawValue).tag(med)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 165)
                    .help("Target CD-R capacity before spawning Disc 2, Disc 3...")

                    Toggle("Write CD-TEXT", isOn: controller.writeCDTextBinding)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                }
            }
        }
    }
}
