import OpticalCore
import SwiftUI
import AudioKit

@MainActor
@Observable
public final class AudioProjectController {

    public struct LiveTransition: Equatable {
        public let trackID: UUID
        public var spec: KroutonTrackTransitionSpec
    }

    public enum AnalysisState {
        case pending
        case ready(TrackAnalysis)
        case failed(String)
    }

    public private(set) var project: AudioProject
    public private(set) var liveTransition: LiveTransition?
    public private(set) var analysis: [UUID: AnalysisState] = [:]

    @ObservationIgnored public var undoManager: UndoManager?
    @ObservationIgnored private let service: AudioAnalysisService
    @ObservationIgnored private let persist: @MainActor (AudioProject) -> Void
    @ObservationIgnored private var analysisTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        project: AudioProject = AudioProject(),
        service: AudioAnalysisService = .shared,
        persist: @escaping @MainActor (AudioProject) -> Void
    ) {
        self.project = project
        self.service = service
        self.persist = persist
        for track in project.tracks { startAnalysis(of: track) }
    }

    // MARK: Reading

    public func transition(after trackID: UUID) -> KroutonTrackTransitionSpec {
        if let live = liveTransition, live.trackID == trackID { return live.spec }
        return project.track(trackID)?.transitionToNext ?? project.defaultTransition
    }

    public func readyAnalysis(_ trackID: UUID) -> TrackAnalysis? {
        if case .ready(let value)? = analysis[trackID] { return value }
        return nil
    }

    // MARK: Preview (per frame, cheap)

    public func preview(_ spec: KroutonTrackTransitionSpec, after trackID: UUID) {
        liveTransition = LiveTransition(trackID: trackID, spec: spec)
    }

    public func cancelPreview() { liveTransition = nil }

    // MARK: Commit (once per gesture or discrete edit)

    public func commitTransition(_ spec: KroutonTrackTransitionSpec, after trackID: UUID, actionName: String = "Edit Transition") {
        edit(actionName) { $0.update(trackID) { $0.transitionToNext = spec } }
    }

    public func edit(_ actionName: String, _ change: (inout AudioProject) -> Void) {
        liveTransition = nil
        let before = project
        change(&project)
        guard project != before else { return }
        registerUndo(restoring: before, actionName: actionName)
        persist(project)
    }

    public func setTitle(_ text: String, for trackID: UUID) {
        let sanitized = AudioProject.sanitizeCDTextField(text)
        edit("Edit CD-TEXT Title") {
            $0.update(trackID) {
                $0.title = sanitized
                $0.userEdited.insert(.title)
            }
        }
    }

    public func setPerformer(_ text: String, for trackID: UUID) {
        let sanitized = AudioProject.sanitizeCDTextField(text)
        edit("Edit CD-TEXT Artist") {
            $0.update(trackID) {
                $0.performer = sanitized
                $0.userEdited.insert(.performer)
            }
        }
    }

    @discardableResult
    public func setISRC(_ text: String, for trackID: UUID) -> Bool {
        var accepted = false
        edit("Edit ISRC") {
            $0.update(trackID) {
                accepted = $0.setISRC(text)
                if accepted { $0.userEdited.insert(.isrc) }
            }
        }
        return accepted
    }

    public func move(_ trackID: UUID, by delta: Int) {
        edit("Reorder Tracks") { $0.move(trackID, by: delta) }
    }

    public func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        edit("Reorder Tracks") { $0.moveTrack(from: sourceIndex, to: destinationIndex) }
    }

    public func remove(_ trackID: UUID) {
        analysisTasks.removeValue(forKey: trackID)?.cancel()
        analysis.removeValue(forKey: trackID)
        edit("Remove Track") { $0.remove(trackID) }
    }

    public func removeTracks(_ ids: Set<UUID>) {
        for id in ids {
            analysisTasks.removeValue(forKey: id)?.cancel()
            analysis.removeValue(forKey: id)
        }
        edit("Remove Selected Tracks") { $0.removeTracks(ids) }
    }

    public func applyBatchTransition(to ids: Set<UUID>, actionName: String, transform: @escaping (KroutonTrackTransitionSpec) -> KroutonTrackTransitionSpec) {
        edit(actionName) { $0.applyBatchTransition(ids, transform: transform) }
    }

    public func applyBatchPerformer(_ performer: String, to ids: Set<UUID>) {
        edit("Set Selected Track Artist") { $0.applyBatchPerformer(performer, to: ids) }
    }

    @discardableResult
    public func assignSequentialISRCs(baseISRC: String, to ids: Set<UUID>) -> Int {
        var count = 0
        edit("Assign Sequential ISRCs") { count = $0.assignSequentialISRCs(baseISRC: baseISRC, to: ids) }
        return count
    }

    public func add(_ urls: [URL]) {
        var added: [AudioTrack] = []
        edit("Add Tracks") { added = $0.append(urls) }
        guard !added.isEmpty else { return }
        let sources = added.map { (id: $0.id, url: $0.source) }
        Task { @MainActor [weak self] in
            let probed = await AudioLengthProbe.lengths(of: sources)
            guard let self else { return }
            self.applyProbe(probed)
            for track in added {
                if let latest = self.project.track(track.id), self.analysis[track.id] == nil {
                    self.startAnalysis(of: latest)
                }
            }
        }
    }

    private func applyProbe(_ results: [UUID: Result<ItemCost, any Error>]) {
        for (id, result) in results {
            switch result {
            case .success(let cost):
                project.update(id) {
                    $0.probedFrameCount = cost.units
                    if cost.isExact && $0.frameCount == nil {
                        $0.frameCount = cost.units
                    }
                }
            case .failure(let error):
                analysis[id] = .failed(error.localizedDescription)
            }
        }
        persist(project)
    }

    // MARK: CD-TEXT Enforced Bindings

    public func titleBinding(_ trackID: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.project.track(trackID)?.title ?? "" },
            set: { [weak self] in self?.setTitle($0, for: trackID) }
        )
    }

    public func performerBinding(_ trackID: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.project.track(trackID)?.performer ?? "" },
            set: { [weak self] in self?.setPerformer($0, for: trackID) }
        )
    }

    public var albumTitleBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.project.albumTitle ?? "" },
            set: { [weak self] val in
                let clean = AudioProject.sanitizeCDTextField(val)
                self?.edit("Edit Album Title") { $0.albumTitle = clean }
            }
        )
    }

    public var albumPerformerBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.project.albumPerformer ?? "" },
            set: { [weak self] val in
                let clean = AudioProject.sanitizeCDTextField(val)
                self?.edit("Edit Album Artist") { $0.albumPerformer = clean }
            }
        )
    }

    public var upcBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.project.upc ?? "" },
            set: { [weak self] val in
                let clean = AudioProject.sanitizeUPCField(val)
                self?.edit("Edit UPC") { $0.upc = clean }
            }
        )
    }


    // MARK: Multi-Disc Spanning & Per-Disc Persistent Metadata Bindings

    public var targetDiscMediumBinding: Binding<KroutonSpanningDiscMedium> {
        Binding(
            get: { [weak self] in self?.project.targetDiscMedium ?? .cd80Min700MB },
            set: { [weak self] medium in
                self?.edit("Change Disc Capacity") { $0.targetDiscMedium = medium }
            }
        )
    }

    public func discTitleBinding(forDisc discNumber: Int) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.project.metadata(forDisc: discNumber).title ?? "" },
            set: { [weak self] newTitle in
                guard let self else { return }
                var meta = self.project.metadata(forDisc: discNumber)
                meta.title = newTitle
                self.edit("Edit Disc \(discNumber) Title") { $0.setMetadata(meta, forDisc: discNumber) }
            }
        )
    }

    public func discPerformerBinding(forDisc discNumber: Int) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.project.metadata(forDisc: discNumber).performer ?? "" },
            set: { [weak self] newPerf in
                guard let self else { return }
                var meta = self.project.metadata(forDisc: discNumber)
                meta.performer = newPerf
                self.edit("Edit Disc \(discNumber) Artist") { $0.setMetadata(meta, forDisc: discNumber) }
            }
        )
    }

    public func discUPCBinding(forDisc discNumber: Int) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.project.metadata(forDisc: discNumber).upc ?? "" },
            set: { [weak self] newUPC in
                guard let self else { return }
                var meta = self.project.metadata(forDisc: discNumber)
                meta.upc = newUPC
                self.edit("Edit Disc \(discNumber) UPC") { $0.setMetadata(meta, forDisc: discNumber) }
            }
        )
    }

    public func toggleManualDiscBreak(before trackID: UUID) {
        edit("Toggle Disc Break") {
            $0.update(trackID) { $0.startsNewDisc.toggle() }
        }
    }

    public var writeCDTextBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.project.writeCDText ?? true },
            set: { [weak self] val in self?.edit("Toggle CD-TEXT") { $0.writeCDText = val } }
        )
    }

    public func restore(_ restored: AudioProject) {
        analysisTasks.values.forEach { $0.cancel() }
        analysisTasks.removeAll()
        analysis.removeAll()
        project = restored
        for track in project.tracks { startAnalysis(of: track) }
    }

    public func clearAll() {
        analysisTasks.values.forEach { $0.cancel() }
        analysisTasks.removeAll()
        analysis.removeAll()
        project = AudioProject()
    }

    // MARK: Undo

    private func registerUndo(restoring snapshot: AudioProject, actionName: String) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            let current = controller.project
            controller.project = snapshot
            controller.liveTransition = nil
            controller.registerUndo(restoring: current, actionName: actionName)
            controller.persist(snapshot)
        }
        undoManager.setActionName(actionName)
    }

    // MARK: Analysis (off the main actor)

    public func startAnalysis(of track: AudioTrack) {
        analysis[track.id] = .pending
        analysisTasks[track.id] = Task { [weak self, service, id = track.id, url = track.source] in
            do {
                let result = try await service.analysis(for: url)
                guard !Task.isCancelled, let self else { return }
                self.analysis[id] = .ready(result)
                self.project.update(id) {
                    $0.frameCount = result.redBookFrames
                    $0.applyScanned(
                        title: result.title.map { AudioProject.sanitizeCDTextField($0) },
                        performer: result.performer.map { AudioProject.sanitizeCDTextField($0) },
                        isrc: result.isrc
                    )
                }
                self.fillAlbumFieldsIfEmpty(
                    album: result.album.map { AudioProject.sanitizeCDTextField($0) },
                    performer: result.performer.map { AudioProject.sanitizeCDTextField($0) }
                )
                self.persist(self.project)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.analysis[id] = .failed(error.localizedDescription)
            }
        }
    }

    private func fillAlbumFieldsIfEmpty(album: String?, performer: String?) {
        if project.albumTitle.isEmpty, let album, !album.isEmpty { project.albumTitle = album }
        if project.albumPerformer.isEmpty, let performer, !performer.isEmpty { project.albumPerformer = performer }
    }
}
