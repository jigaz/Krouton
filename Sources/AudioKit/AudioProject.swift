import Foundation
import OpticalCore

// MARK: - Audio Project
//
// The single source of truth for an audio disc: the Audio CD editor edits it, the
// session saves it, and the renderer and the cue sheet read it.
//
// One array of tracks, in disc order. Each track carries its own metadata and the
// transition that FOLLOWS it. Reordering, deleting or editing touches one value,
// so nothing can drift out of sync, and the whole project is one Codable value
// that can be snapshotted for undo and persistence.

/// One track of an audio CD: its source, metadata, length and the transition after it.
public struct AudioTrack: DiscBreakableItem, Identifiable, Equatable, Codable, Sendable {
    /// The fields the user can type.
    public enum Field: String, Codable, Sendable { case title, performer, isrc }

    /// Identifies the track across edits.
    public let id: UUID
    /// The audio file.
    public var source: URL
    /// The track's title; empty means none.
    public var title: String
    /// Empty means "use the album performer".
    public var performer: String
    /// Empty, or 12 validated characters. Never generated.
    public private(set) var isrc: String
    /// Exact length in CD frames (1/75 s), from the full decode. Nil until the file has been
    /// analysed; a nil length blocks the layout rather than being guessed.
    public var frameCount: Int64?
    /// Length from the quick header probe, used for provisional spanning while `frameCount` is nil.
    public var probedFrameCount: Int64? = nil
    /// The boundary between this track and the next one. Ignored on the last track.
    public var transitionToNext: KroutonTrackTransitionSpec
    /// Fields the user typed. A metadata rescan never overwrites these.
    public var userEdited: Set<Field>
    /// True when the user put a disc break before this track.
    public var startsNewDisc: Bool = false
    /// Disc metadata kept on the track that starts a manual disc, so adding an earlier break
    /// doesn't move this disc's title onto other music.
    var manualDiscMetadata: KroutonDiscVolumeMetadata? = nil

    public init(id: UUID = UUID(), source: URL, title: String = "", performer: String = "",
                frameCount: Int64? = nil, transitionToNext: KroutonTrackTransitionSpec) {
        self.id = id
        self.source = source
        self.title = title
        self.performer = performer
        self.isrc = ""
        self.frameCount = frameCount
        self.transitionToNext = transitionToNext
        self.userEdited = []
    }

    /// Accepts "" (clear) or a well-formed ISRC. Returns false and changes nothing otherwise.
    @discardableResult
    public mutating func setISRC(_ raw: String) -> Bool {
        let compact = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        if compact.isEmpty { isrc = ""; return true }
        guard compact.range(of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#, options: .regularExpression) != nil else { return false }
        isrc = compact
        return true
    }

    /// Applies scanned metadata without touching anything the user typed.
    public mutating func applyScanned(title: String?, performer: String?, isrc: String?) {
        if let title, !title.isEmpty, !userEdited.contains(.title) { self.title = title }
        if let performer, !performer.isEmpty, !userEdited.contains(.performer) { self.performer = performer }
        if let isrc, !userEdited.contains(.isrc) { setISRC(isrc) }
    }
}

/// Where one track sits in the master stream, in Red Book frames from the first
/// audio sample of track 1 (the mandatory 2 s lead-in pregap is not included).
public struct AudioTrackLayout: Equatable, Sendable {
    /// The track.
    public let trackID: UUID
    /// The track number on its disc.
    public let number: Int
    /// First frame of this track's own audio in the stream.
    public let audioStart: Int64
    /// INDEX 00, present only when a pause precedes the track.
    public let index00: Int64?
    /// INDEX 01: where a player lands when skipping to this track.
    public let index01: Int64
    /// Frames of this track's audio that overlap the previous track (crossfade).
    public let overlapWithPrevious: Int64
}

/// Something that was adjusted or that blocks burning.
public enum AudioProjectIssue: Equatable, Sendable {
    case noTracks
    case tooManyTracks(Int)
    case tooManyTracksOnDisc(discNumber: Int, count: Int)
    case notAnalysed(trackID: UUID)
    /// Shorter than the Red Book minimum of 4 s.
    case trackTooShort(trackID: UUID, frames: Int64)
    case trackExceedsDiscCapacity(trackID: UUID, frames: Int64, capacity: Int64)
    case overlapTrimmed(trackID: UUID, requested: Int64, used: Int64)
    case automaticBreakSplitsContinuousRun(discNumber: Int, afterTrackID: UUID)
    case exceedsCapacity(frames: Int64, capacity: Int64)
}

/// An audio CD project: album metadata, the default transition, the disc size, per-disc metadata,
/// and the tracks.
public struct AudioProject: Equatable, Codable, Sendable {
    static let minimumTrackFrames: Int64 = 300
    static let maximumTracks = 99

    /// The album title (CD-Text).
    public var albumTitle: String
    /// The album performer (CD-Text), used for tracks without their own.
    public var albumPerformer: String
    /// Empty or 12/13 digits. Empty means no CATALOG line and no 0x8E album pack.
    public var upc: String
    /// Writes CD-Text when burning.
    public var writeCDText: Bool
    /// Applied to tracks as they are added.
    public var defaultTransition: KroutonTrackTransitionSpec
    /// The disc size the project is planned for.
    public var targetDiscMedium: KroutonSpanningDiscMedium = .cd80Min700MB
    /// Per-disc metadata by disc number (from 1). Kept while a disc is briefly gone from the
    /// plan, so its names come back with it.
    public var discMetadata: [Int: KroutonDiscVolumeMetadata] = [:]
    /// Manual-break metadata anchored to the first track ID of that manual disc.
    public var anchoredDiscMetadata: [UUID: KroutonDiscVolumeMetadata] = [:]
    /// The tracks, in disc order. Change them through the methods below.
    public private(set) var tracks: [AudioTrack]

    public init(albumTitle: String = "", albumPerformer: String = "", upc: String = "",
                writeCDText: Bool = true,
                defaultTransition: KroutonTrackTransitionSpec = KroutonTrackTransitionSpec()) {
        self.albumTitle = albumTitle
        self.albumPerformer = albumPerformer
        self.upc = upc
        self.writeCDText = writeCDText
        self.defaultTransition = defaultTransition
        self.tracks = []
    }

    // MARK: - Lookup

    /// The position of the track with `id`.
    public func index(of id: UUID) -> Int? { tracks.firstIndex { $0.id == id } }
    /// The track with `id`.
    public func track(_ id: UUID) -> AudioTrack? { index(of: id).map { tracks[$0] } }
    /// The track after the one with `id`.
    public func track(after id: UUID) -> AudioTrack? {
        guard let i = index(of: id), i + 1 < tracks.count else { return nil }
        return tracks[i + 1]
    }

    // MARK: - Mutation (every edit goes through one of these)

    /// Appends files not already present. Returns the new tracks so the caller can analyse them.
    @discardableResult
    public mutating func append(_ urls: [URL]) -> [AudioTrack] {
        let existing = Set(tracks.map(\.source))
        var added: [AudioTrack] = []
        for url in urls where !existing.contains(url) && !added.contains(where: { $0.source == url }) {
            var transition = defaultTransition
            transition.id = UUID()
            added.append(AudioTrack(source: url, transitionToNext: transition))
        }
        tracks.append(contentsOf: added)
        return added
    }

    /// Removes the track with `id`.
    public mutating func remove(_ id: UUID) { tracks.removeAll { $0.id == id } }

    /// Moves a track `delta` places, within the list.
    public mutating func move(_ id: UUID, by delta: Int) {
        guard let from = index(of: id) else { return }
        let to = min(max(from + delta, 0), tracks.count - 1)
        guard to != from else { return }
        tracks.insert(tracks.remove(at: from), at: to)
    }

    /// Edits one track in place.
    public mutating func update(_ id: UUID, _ change: (inout AudioTrack) -> Void) {
        guard let i = index(of: id) else { return }
        change(&tracks[i])
    }

    /// Moves a single track from `fromIndex` to `toIndex` (for drag-and-drop reordering).
    public mutating func moveTrack(from fromIndex: Int, to toIndex: Int) {
        guard tracks.indices.contains(fromIndex) else { return }
        let clampedTo = min(max(0, toIndex), max(0, tracks.count - 1))
        guard fromIndex != clampedTo else { return }
        var item = tracks.remove(at: fromIndex)
        item.startsNewDisc = false
        tracks.insert(item, at: clampedTo)
    }

    /// Enforces Red Book CD-TEXT constraints (ISO 8859-1 printable, max 60 chars, no control chars).
    public static func sanitizeCDTextField(_ raw: String, maxLength: Int = 60) -> String {
        let strippedControls = raw.unicodeScalars.filter { scalar in
            let v = scalar.value
            return v >= 0x20 && !(0x7F...0x9F).contains(v)
        }
        let clean = KroutonCDTextSanitizer.sanitize(String(String.UnicodeScalarView(strippedControls)))
        return String(clean.prefix(maxLength))
    }

    /// Enforces 12/13-digit numeric EAN/UPC catalog code.
    public static func sanitizeUPCField(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(13))
    }

    /// Batch-updates transitions on all tracks in `ids`.
    public mutating func applyBatchTransition(_ ids: Set<UUID>, transform: (KroutonTrackTransitionSpec) -> KroutonTrackTransitionSpec) {
        for i in tracks.indices where ids.contains(tracks[i].id) {
            var updated = transform(tracks[i].transitionToNext)
            updated.id = tracks[i].transitionToNext.id
            tracks[i].transitionToNext = updated
        }
    }

    /// Batch-stamps a sanitized CD-TEXT Performer onto all tracks in `ids`.
    public mutating func applyBatchPerformer(_ performer: String, to ids: Set<UUID>) {
        let clean = Self.sanitizeCDTextField(performer)
        for i in tracks.indices where ids.contains(tracks[i].id) {
            tracks[i].performer = clean
            tracks[i].userEdited.insert(.performer)
        }
    }

    /// Batch-assigns sequential ISO 3901 ISRCs (e.g. "CCXXXYY00001", "CCXXXYY00002", ...) to `ids` in disc order.
    @discardableResult
    public mutating func assignSequentialISRCs(baseISRC: String, to ids: Set<UUID>) -> Int {
        let compact = baseISRC.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard compact.count == 12,
              compact.range(of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#, options: .regularExpression) != nil else {
            return 0
        }
        let prefix7 = String(compact.prefix(7))
        guard var serial = Int(compact.suffix(5)) else { return 0 }
        var count = 0
        for i in tracks.indices where ids.contains(tracks[i].id) {
            let code = String(format: "%@%05d", prefix7, min(99999, serial))
            if tracks[i].setISRC(code) {
                tracks[i].userEdited.insert(.isrc)
                serial += 1
                count += 1
            }
        }
        return count
    }

    /// Removes all tracks whose ID is in `ids`.
    public mutating func removeTracks(_ ids: Set<UUID>) {
        tracks.removeAll { ids.contains($0.id) }
    }

    // MARK: - Layout

    /// Integer frame layout for the cue sheet and the burn stream, plus anything
    /// that had to be adjusted or that blocks burning. `layout` is nil when a
    /// track has not been analysed yet.
    public func layout(capacityFrames: Int64? = nil) -> (layout: [AudioTrackLayout]?, issues: [AudioProjectIssue]) {
        var issues: [AudioProjectIssue] = []
        if tracks.isEmpty { return (nil, [.noTracks]) }
        if tracks.count > Self.maximumTracks { issues.append(.tooManyTracks(tracks.count)) }

        let missing = tracks.filter { $0.frameCount == nil }
        if !missing.isEmpty { return (nil, issues + missing.map { .notAnalysed(trackID: $0.id) }) }

        var result: [AudioTrackLayout] = []
        var audioStart: Int64 = 0
        for (i, track) in tracks.enumerated() {
            let frames = track.frameCount ?? 0
            if frames < Self.minimumTrackFrames { issues.append(.trackTooShort(trackID: track.id, frames: frames)) }

            var index00: Int64?
            var index01 = audioStart
            var overlap: Int64 = 0
            if i > 0 {
                let previous = tracks[i - 1]
                let previousFrames = previous.frameCount ?? 0
                let previousEnd = result[i - 1].audioStart + previousFrames
                let transition = previous.transitionToNext
                if transition.isCrossfading {
                    // Neither track may give up more than half its length to one fade.
                    let requested = transition.overlapRedBookFrames
                    overlap = max(0, min(requested, previousFrames / 2, frames / 2))
                    if overlap != requested {
                        issues.append(.overlapTrimmed(trackID: previous.id, requested: requested, used: overlap))
                    }
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

        if let last = result.last, let capacityFrames {
            let total = last.audioStart + (tracks.last?.frameCount ?? 0)
            if total > capacityFrames { issues.append(.exceedsCapacity(frames: total, capacity: capacityFrames)) }
        }
        return (result, issues)
    }

    /// Total program length in frames, or nil while any track is unanalysed.
    public var totalFrames: Int64? {
        guard let layout = layout().layout, let last = layout.last, let frames = tracks.last?.frameCount else { return nil }
        return last.audioStart + frames
    }
}

// Status: the session saves `AudioProject`, and `compileCueSheet()` writes INDEX lines
// from `AudioTrackLayout`. `KroutonRedBookTrack` is still derived for older APIs
// (`derivedRedBookCubes`); delete it once nothing reads `store.redBookTracks`.
//
// Invariants worth unit tests (none checks them yet):
//   - audioStart is non-decreasing; index00 <= index01 where index00 exists
//   - with no crossfades, total == sum(frameCount) + sum(gaps)
//   - move/remove/append never change any other track's fields
//   - applyScanned never changes a field listed in userEdited

extension AudioProject {
    /// The tracks as `KroutonRedBookTrack`s, for older APIs that still expect them. Track i's
    /// pause comes from track i-1's `transitionToNext`.
    public var derivedRedBookCubes: [KroutonRedBookTrack] {
        let computedLayout = layout().layout
        return tracks.enumerated().map { idx, track in
            let prevSpec: KroutonTrackTransitionSpec? = idx > 0 ? tracks[idx - 1].transitionToNext : nil
            let preGap: Double = {
                guard let prev = prevSpec else { return 0.0 }
                return prev.isCrossfading ? 0.0 : prev.preGapSeconds
            }()
            let xfade: Double = prevSpec?.isCrossfading == true ? (prevSpec?.overlapSeconds ?? 0.0) : 0.0
            let style: KroutonTrackPregapStyle = {
                guard let prev = prevSpec else { return .gapless0s }
                if prev.isCrossfading { return .jamCrossfade }
                return prev.preGapSeconds <= 0.01 ? .gapless0s : .standard2s
            }()
            let frames = track.frameCount ?? computedLayout.flatMap { idx < $0.count ? $0[idx].index01 : nil } ?? 0
            let secs = frames > 0 ? (Double(frames) / 75.0) : 0.0
            return KroutonRedBookTrack(
                id: track.id,
                url: track.source,
                title: track.title.isEmpty ? track.source.deletingPathExtension().lastPathComponent : track.title,
                performer: track.performer.isEmpty ? albumPerformer : track.performer,
                isrcCode: track.isrc,
                durationSeconds: secs,
                preGapSeconds: preGap,
                crossfadeSeconds: xfade,
                transitionStyle: style
            )
        }
    }
}

extension AudioProject {
    /// Compiles a frame-accurate Red Book .cue sheet directly from `AudioProject` and `[AudioTrackLayout]`.
    /// Returns nil when any track has not been analysed yet (`layout().layout == nil`).
    public func compileCueSheet(masterBinFilename: String = "KROUTON_AUDIO_MASTER.BIN") -> String? {
        guard let resolvedLayout = layout().layout else { return nil }
        return KroutonAudioEngine.compileCueSheet(
            project: self,
            layout: resolvedLayout,
            masterBinFilename: masterBinFilename
        )
    }

    /// Compiles the 18-byte Sony/Philips CD-TEXT block directly from `AudioProject` via `CDTextBlockCompiler`.
    public func compileCDTextBlock() -> CDTextBlock? {
        guard writeCDText, !tracks.isEmpty else { return nil }
        var albumFields: [CDTextField: String] = [:]
        if !albumTitle.isEmpty { albumFields[.title] = albumTitle }
        if !albumPerformer.isEmpty { albumFields[.performer] = albumPerformer }
        if !upc.isEmpty { albumFields[.upcOrISRC] = upc }
        let trackFields: [[CDTextField: String]] = tracks.map { trk in
            var dict: [CDTextField: String] = [:]
            let effTitle = trk.title.isEmpty ? trk.source.deletingPathExtension().lastPathComponent : trk.title
            if !effTitle.isEmpty { dict[.title] = effTitle }
            let effPerf = trk.performer.isEmpty ? albumPerformer : trk.performer
            if !effPerf.isEmpty { dict[.performer] = effPerf }
            if !trk.isrc.isEmpty { dict[.upcOrISRC] = trk.isrc }
            return dict
        }
        let input = CDTextInput(album: albumFields, tracks: trackFields)
        return try? CDTextBlockCompiler.compile(input)
    }
}

extension KroutonAudioEngine {
    /// Compiles a Red Book .cue sheet directly from `AudioProject` and `[AudioTrackLayout]`.
    /// Every INDEX 00 and INDEX 01 comes straight from `AudioTrackLayout`, so the transition after track N
    /// sets track (N+1)'s pregap or overlap splice point.
    public static func compileCueSheet(
        project: AudioProject,
        layout: [AudioTrackLayout],
        masterBinFilename: String = "KROUTON_AUDIO_MASTER.BIN"
    ) -> String {
        var lines: [String] = []
        let cleanMCN = KroutonCDTextSanitizer.sanitizeMCN(project.upc)
        if cleanMCN.count == 13 {
            lines.append("CATALOG \(cleanMCN)")
        }
        if project.writeCDText {
            if !project.albumTitle.isEmpty {
                lines.append("TITLE \"\(KroutonCDTextSanitizer.sanitize(project.albumTitle))\"")
            }
            if !project.albumPerformer.isEmpty {
                lines.append("PERFORMER \"\(KroutonCDTextSanitizer.sanitize(project.albumPerformer))\"")
            }
        }
        lines.append("FILE \"\(masterBinFilename)\" BINARY")

        for (idx, (track, entry)) in zip(project.tracks, layout).enumerated() {
            lines.append(String(format: "  TRACK %02d AUDIO", entry.number))
            let rawTitle = track.title.isEmpty ? track.source.deletingPathExtension().lastPathComponent : track.title
            if project.writeCDText, !rawTitle.isEmpty {
                lines.append("    TITLE \"\(KroutonCDTextSanitizer.sanitize(rawTitle))\"")
            }
            let rawPerf = track.performer.isEmpty ? project.albumPerformer : track.performer
            if project.writeCDText, !rawPerf.isEmpty {
                lines.append("    PERFORMER \"\(KroutonCDTextSanitizer.sanitize(rawPerf))\"")
            }
            if track.isrc.count == 12 {
                lines.append("    ISRC \(track.isrc)")
            }
            if let idx00 = entry.index00 {
                lines.append("    INDEX 00 \(formatFramesToMMSSFF(idx00))")
            }
            lines.append("    INDEX 01 \(formatFramesToMMSSFF(entry.index01))")

            let trackLen = max(0, track.frameCount ?? 0)
            var trackSubFrames: [Int64] = []

            // 1. Sub-indexes dragged into the incoming half (right of INDEX 01) of the PREVIOUS boundary (idx - 1 -> idx)
            if idx > 0 {
                let prevSpec = project.tracks[idx - 1].transitionToNext
                let prevPivot = prevSpec.isCrossfading ? prevSpec.spliceIndex01Ratio : 0.50
                for r in prevSpec.subIndexRatios.sorted() where r > prevPivot {
                    let normInTrack = (r - prevPivot) / max(0.05, 1.0 - prevPivot)
                    let f = entry.index01 + Int64((Double(trackLen) * max(0.02, min(0.48, normInTrack * 0.45))).rounded())
                    trackSubFrames.append(f)
                }
            }

            // 2. Sub-indexes in the outgoing half (left of INDEX 01) of THIS track's boundary (idx -> idx + 1)
            let curSpec = track.transitionToNext
            let curPivot = curSpec.isCrossfading ? curSpec.spliceIndex01Ratio : 0.50
            for r in curSpec.subIndexRatios.sorted() where r <= curPivot {
                let f = entry.index01 + Int64((Double(trackLen) * max(0.05, min(0.95, r))).rounded())
                trackSubFrames.append(f)
            }

            for (subIdx, subFrame) in trackSubFrames.sorted().prefix(97).enumerated() {
                lines.append(String(format: "    INDEX %02d %@", subIdx + 2, formatFramesToMMSSFF(subFrame)))
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
