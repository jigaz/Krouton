import AudioKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Red Book Audio CD Track Row, ISRC Fields & Crossfade Drawer

extension KroutonRedBookAudioWorkspaceView {
    @ViewBuilder
    func trackPerformerAndISRCFields(track: AudioTrack, isISRCInvalid: Bool) -> some View {
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
    }

    @ViewBuilder
    func trackRowView(track: AudioTrack, discNumber: Int, trackNum: Int, isLastOnDisc: Bool, totalDiscs: Int) -> some View {
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
            .accessibilityLabel(KroutonL10n.tr(isSelected ? "Deselect Track" : "Select Track"))
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
                    Button(KroutonL10n.tr("0 sec (Gapless)")) {
                        controller.commitTransition(tr.switched(to: .gapless), after: track.id, actionName: "Set Gapless")
                    }
                    Button(KroutonL10n.tr("1 sec Pause")) {
                        var updated = tr.switched(to: .gap); updated.preGapSeconds = 1.0
                        controller.commitTransition(updated, after: track.id, actionName: "Set 1s Pause")
                    }
                    Button(KroutonL10n.tr("2 sec Standard Pause")) {
                        var updated = tr.switched(to: .gap); updated.preGapSeconds = 2.0
                        controller.commitTransition(updated, after: track.id, actionName: "Set 2s Pause")
                    }
                    Divider()
                    Button(KroutonL10n.tr("2.5s Crossfade")) {
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
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
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
            trackPerformerAndISRCFields(track: track, isISRCInvalid: isISRCInvalid)

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
                    withAnimation(kroutonMotion(.easeInOut(duration: 0.16))) {
                        let nextID = isExpanded ? nil : track.id
                        expandedTransitionTrackID = nextID
                        if let nextID { montageState.activeTrackID = nextID }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tr.isCrossfading ? String(format: "%.1fs X-Fade", tr.overlapSeconds) : (tr.preGapSeconds <= 0.01 ? "Gapless" : String(format: "%.1fs Gap", tr.preGapSeconds)))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
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
                .accessibilityLabel(KroutonL10n.tr(isPlayingThis ? "Stop Audition" : "Audition Track Transition"))
                .help(KroutonL10n.tr(isPlayingThis ? "Stop Audition" : "Audition Track Transition"))

                Button {
                    selectedTrackIDs.remove(track.id)
                    controller.remove(track.id)
                    store.removeStagedFile(id: track.id)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KroutonL10n.tr("Remove Track"))
                .help(KroutonL10n.tr("Remove Track"))
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
            Button(KroutonL10n.tr("Inspect Compiled Red Book CUE Sheet")) { NotificationCenter.default.post(name: .kroutonMenuInspectAudioCue, object: nil) }.keyboardShortcut("u", modifiers: [.command, .control])
            Button(role: .destructive) {
                selectedTrackIDs.remove(track.id)
                controller.remove(track.id)
                store.removeStagedFile(id: track.id)
            } label: { Text("Remove Track") }.keyboardShortcut(.delete, modifiers: .command)
        }
    }

    @ViewBuilder
    func inlineCrossfadeDrawer(for track: AudioTrack, trackNum: Int) -> some View {
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
}
