import Foundation
import OpticalCore

// Audio CD spanning on top of the shared planner.
//
// Replaces the body of `AudioProject.spannedDiscs()`. Three behaviours change:
//
//   1. A track with no length no longer counts as four seconds. Until every
//      track has at least a probed length, the list shows one provisional disc.
//   2. Disc metadata follows the content. A manual break carries its own title,
//      performer and UPC, keyed by the track it sits before. Automatic discs keep
//      the number-keyed memory you already have.
//   3. A capacity break that lands inside continuous music is reported, so the
//      user can move the break to a real pause.
//
// Requires two additions to the model:
//
//   AudioTrack    var probedFrameCount: Int64?      // header probe, may be approximate
//   AudioProject  var anchoredDiscMetadata: [UUID: KroutonDiscVolumeMetadata] = [:]

// MARK: - AudioDiscPlan

public struct AudioDisc: Identifiable, Sendable, Equatable {
    public let number: Int
    public let metadata: KroutonDiscVolumeMetadata
    public let tracks: [AudioTrack]
    /// Nil while lengths are provisional. Never guessed.
    public let layout: [AudioTrackLayout]?
    public let usedFrames: Int64
    public let capacityFrames: Int64
    public let startedBecause: DiscBreakReason

    public var id: Int { number }
}

public enum AudioDiscWarning: Sendable, Equatable {
    /// The disc ends between two tracks joined by a crossfade or a gapless
    /// transition. The transition is ignored at a disc change, so the music is cut.
    case breakSplitsContinuousRun(discNumber: Int, lastTrackID: UUID, nextTrackID: UUID)
}

public struct AudioDiscPlan: Sendable, Equatable {
    public let discs: [AudioDisc]
    public let issues: [DiscPlanIssue<UUID>]
    public let warnings: [AudioDiscWarning]
    public let isProvisional: Bool

    public var isBurnable: Bool { !discs.isEmpty && issues.isEmpty && !isProvisional }
}

extension AudioTrack {
    /// Exact once analysed; otherwise the header probe; otherwise unknown.
    var plannedLength: ItemCost? {
        if let frameCount { return .exact(frameCount) }
        if let probedFrameCount { return .estimated(probedFrameCount) }
        return nil
    }
}

extension AudioProject {

    /// The single plan the list, footer, cue compiler and burn queue all read.
    /// Compute it once per project change (in the controller), not per view.
    public func discPlan() -> AudioDiscPlan {
        let capacity = DiscCapacity(units: targetDiscMedium.maxRedBookFrames, maxItems: Self.maximumTracks)

        let planner = DiscPlanner<AudioTrack>(
            capacity: capacity,
            startsNewDisc: { $0.startsNewDisc }
        ) { track, previous in
            guard let length = track.plannedLength else { return nil }
            guard let previous else { return length }
            // The boundary belongs to the earlier track.
            let transition = previous.transitionToNext
            let previousLength = previous.plannedLength?.units ?? 0
            let adjustment: Int64 = transition.isCrossfading
                ? -Self.usableOverlap(transition, previousLength, length.units)
                : transition.preGapRedBookFrames
            return ItemCost(units: length.units + adjustment, isExact: length.isExact)
        }

        let plan = planner.plan(tracks)
        var warnings: [AudioDiscWarning] = []
        var discs: [AudioDisc] = []

        for disc in plan.discs {
            if disc.startedBecause == .capacity || disc.startedBecause == .itemLimit,
               let previousLast = discs.last?.tracks.last, let first = disc.items.first {
                let transition = previousLast.transitionToNext
                if transition.isCrossfading || transition.preGapRedBookFrames == 0 {
                    warnings.append(.breakSplitsContinuousRun(
                        discNumber: disc.number - 1, lastTrackID: previousLast.id, nextTrackID: first.id))
                }
            }
            discs.append(AudioDisc(
                number: disc.number,
                metadata: metadata(for: disc),
                tracks: disc.items,
                layout: plan.isProvisional ? nil : Self.layout(of: disc.items),
                usedFrames: disc.usedUnits,
                capacityFrames: disc.capacityUnits,
                startedBecause: disc.startedBecause
            ))
        }
        return AudioDiscPlan(discs: discs, issues: plan.issues, warnings: warnings, isProvisional: plan.isProvisional)
    }

    /// Manual discs own their metadata, anchored to their first track, so it
    /// travels with the music. Automatic discs fall back to the ordinal memory.
    private func metadata(for disc: PlannedDisc<AudioTrack>) -> KroutonDiscVolumeMetadata {
        if disc.startedBecause == .manual, let firstTrack = disc.items.first {
            if var anchored = anchoredDiscMetadata[firstTrack.id] {
                anchored.discNumber = disc.number
                return anchored
            }
            if var manual = firstTrack.manualDiscMetadata {
                manual.discNumber = disc.number
                return manual
            }
        }
        return metadata(forDisc: disc.number, firstTrack: disc.items.first)
    }

    /// Neither track may give up more than half its length to one crossfade.
    static func usableOverlap(_ transition: KroutonTrackTransitionSpec, _ previous: Int64, _ next: Int64) -> Int64 {
        max(0, min(transition.overlapRedBookFrames, previous / 2, next / 2))
    }

    /// Frame layout for one disc's tracks, numbered from 1. This is the same
    /// arithmetic as `layout()`, taking the tracks as a parameter so one function
    /// serves both the whole project and each disc. `layout()` can call it.
    static func layout(of tracks: [AudioTrack]) -> [AudioTrackLayout]? {
        var result: [AudioTrackLayout] = []
        var audioStart: Int64 = 0
        for (i, track) in tracks.enumerated() {
            guard let frames = track.frameCount else { return nil }
            var index00: Int64?
            var index01 = audioStart
            var overlap: Int64 = 0
            if i > 0, let previousFrames = tracks[i - 1].frameCount {
                let previousEnd = result[i - 1].audioStart + previousFrames
                let transition = tracks[i - 1].transitionToNext
                if transition.isCrossfading {
                    overlap = usableOverlap(transition, previousFrames, frames)
                    audioStart = previousEnd - overlap
                    index01 = audioStart + Int64((Double(overlap) * transition.spliceIndex01Ratio).rounded())
                } else {
                    let gap = transition.preGapRedBookFrames
                    audioStart = previousEnd + gap
                    index00 = gap > 0 ? previousEnd : nil
                    index01 = audioStart
                }
            }
            result.append(AudioTrackLayout(trackID: track.id, number: i + 1, audioStart: audioStart,
                                           index00: index00, index01: index01, overlapWithPrevious: overlap))
        }
        return result
    }
}

// Drag and drop over the inline headers, in terms of this model:
//
//   Dragging a TRACK      -> `move(_:by:)`; the plan recomputes. The track keeps
//                            its own `startsNewDisc` flag only if you want breaks
//                            to travel with tracks; I would clear it on move.
//   Dragging a MANUAL
//   DIVIDER row           -> clear the flag on the old first track, set it on the
//                            new one, and re-key `anchoredDiscMetadata` in the
//                            same edit, so the disc's title moves with the break.
//   Automatic headers     -> not draggable. Offer "Break here instead" on any
//                            earlier track, which sets a manual break.
//
// Invariants worth adding to krouton-verify:
//   - concatenating plan.discs' tracks gives back `tracks` in order
//   - no disc exceeds capacity unless a matching itemExceedsDisc issue exists
//   - deleting tracks never changes the metadata shown for a manual disc
//   - a provisional plan never contains a layout

extension AudioProject {
    public func metadata(forDisc discNumber: Int, firstTrack: AudioTrack? = nil, totalDiscs: Int = 2) -> KroutonDiscVolumeMetadata {
        if discNumber <= 1 {
            return KroutonDiscVolumeMetadata(
                discNumber: 1,
                title: albumTitle,
                performer: albumPerformer,
                upc: upc,
                volumeLabel: SpanManifest.volumeLabel(base: albumTitle, discIndex: 1, discCount: totalDiscs),
                writeCDText: writeCDText
            )
        }
        if let firstTrack, firstTrack.startsNewDisc {
            if var anchored = anchoredDiscMetadata[firstTrack.id] {
                anchored.discNumber = discNumber
                anchored.volumeLabel = SpanManifest.volumeLabel(
                    base: anchored.volumeLabel.isEmpty ? anchored.title : anchored.volumeLabel,
                    discIndex: discNumber,
                    discCount: totalDiscs
                )
                return anchored
            }
            if var manual = firstTrack.manualDiscMetadata {
                manual.discNumber = discNumber
                manual.volumeLabel = SpanManifest.volumeLabel(
                    base: manual.volumeLabel.isEmpty ? manual.title : manual.volumeLabel,
                    discIndex: discNumber,
                    discCount: totalDiscs
                )
                return manual
            }
        }
        if let saved = discMetadata[discNumber] {
            var copy = saved
            copy.discNumber = discNumber
            copy.volumeLabel = SpanManifest.volumeLabel(
                base: saved.volumeLabel.isEmpty ? saved.title : saved.volumeLabel,
                discIndex: discNumber,
                discCount: totalDiscs
            )
            return copy
        }
        let defaultTitle = albumTitle.isEmpty ? "" : "\(albumTitle) (Disc \(discNumber))"
        return KroutonDiscVolumeMetadata(
            discNumber: discNumber,
            title: defaultTitle,
            performer: albumPerformer,
            upc: upc,
            volumeLabel: SpanManifest.volumeLabel(base: albumTitle, discIndex: discNumber, discCount: totalDiscs),
            writeCDText: writeCDText
        )
    }

    public mutating func setMetadata(_ meta: KroutonDiscVolumeMetadata, forDisc discNumber: Int) {
        let plan = discPlan()
        let totalDiscs = max(2, plan.discs.count)
        let cleaned = KroutonDiscVolumeMetadata(
            discNumber: max(1, discNumber),
            title: Self.sanitizeCDTextField(meta.title),
            performer: Self.sanitizeCDTextField(meta.performer),
            upc: Self.sanitizeUPCField(meta.upc),
            volumeLabel: SpanManifest.volumeLabel(
                base: meta.volumeLabel.isEmpty ? meta.title : meta.volumeLabel,
                discIndex: discNumber,
                discCount: totalDiscs
            ),
            writeCDText: meta.writeCDText
        )
        if discNumber <= 1 {
            albumTitle = cleaned.title
            albumPerformer = cleaned.performer
            upc = cleaned.upc
            writeCDText = cleaned.writeCDText
            discMetadata[1] = cleaned
            return
        }
        if let disc = plan.discs.first(where: { $0.number == discNumber }),
           disc.startedBecause == .manual,
           let anchorID = disc.tracks.first?.id {
            anchoredDiscMetadata[anchorID] = cleaned
            update(anchorID) { $0.manualDiscMetadata = cleaned }
        } else {
            discMetadata[max(1, discNumber)] = cleaned
        }
    }

    public func compileCueSheet(forDisc discNumber: Int, masterBinFilename: String? = nil) -> String? {
        let plan = discPlan()
        guard plan.isBurnable,
              let targetDisc = plan.discs.first(where: { $0.number == discNumber }),
              let discLayout = targetDisc.layout,
              !targetDisc.tracks.isEmpty else { return nil }

        var subProject = AudioProject(
            albumTitle: targetDisc.metadata.title,
            albumPerformer: targetDisc.metadata.performer,
            upc: targetDisc.metadata.upc,
            writeCDText: targetDisc.metadata.writeCDText,
            defaultTransition: defaultTransition
        )
        let binName = masterBinFilename ?? (plan.discs.count > 1 ? String(format: "KROUTON_AUDIO_DISC_%02d.BIN", discNumber) : "KROUTON_AUDIO_MASTER.BIN")
        let _ = subProject.append(targetDisc.tracks.map(\.source))
        for (i, src) in targetDisc.tracks.enumerated() {
            let dstID = subProject.tracks[i].id
            subProject.update(dstID) {
                $0.title = src.title
                $0.performer = src.performer
                _ = $0.setISRC(src.isrc)
                $0.frameCount = src.frameCount
                $0.transitionToNext = src.transitionToNext
            }
        }
        return KroutonAudioEngine.compileCueSheet(
            project: subProject,
            layout: discLayout,
            masterBinFilename: binName
        )
    }
}
