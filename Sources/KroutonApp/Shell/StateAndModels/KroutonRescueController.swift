import DriveKit
import Foundation
import Observation
import OpticalCore
import RescueKit
import os

// MARK: - Rescue Controller

/// Runs a disc rescue and keeps its map on screen and on disk. The image and its mapfile sit side
/// by side (`Name.iso`, `Name.iso.map`); starting again with the same name resumes where it stopped.
@Observable
@MainActor
final class KroutonRescueController {
    var map: KroutonRescueMap?
    var isRunning = false
    var status = "Insert the damaged disc, choose where to save the image, and start."
    var outputFolder: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory
    var imageName = "Rescued Disc"
    var retryPasses = 1

    @ObservationIgnored private var task: Task<Void, Never>?

    var imageURL: URL { outputFolder.appendingPathComponent(imageName.isEmpty ? "Rescued Disc" : imageName).appendingPathExtension("iso") }
    var mapURL: URL { imageURL.appendingPathExtension("map") }

    /// Whether an earlier attempt's image and mapfile are both waiting at the chosen name. A mapfile
    /// without its image can't be resumed: the sectors it lists as copied are gone.
    var canResume: Bool {
        FileManager.default.fileExists(atPath: mapURL.path) && FileManager.default.fileExists(atPath: imageURL.path)
    }

    func start(driveID: String?, driveManager: KroutonOpticalDriveBank) {
        guard !isRunning else { return }
        isRunning = true
        status = "Unmounting the disc and opening the drive…"
        let imageURL = imageURL, mapURL = mapURL, plan = KroutonRescuePlan(retryPasses: retryPasses)
        let previous = canResume ? (try? String(contentsOf: mapURL, encoding: .utf8)).flatMap(KroutonRescueMap.parse(mapfile:)) : nil
        task = Task { @MainActor [self] in
            defer {
                self.isRunning = false
                self.task = nil
            }
            let session: KroutonMMCDeviceSession
            do throws(MMCTransportError) {
                session = try await driveManager.openDriveForRescue(driveID: driveID)
            } catch {
                self.status = Self.describe(error)
                return
            }
            let outcome = await Self.rescue(session: session, imageURL: imageURL, mapURL: mapURL, plan: plan, previous: previous) { [weak self] map in
                Task { @MainActor in self?.show(map) }
            }
            await session.close()
            switch outcome {
            case .success(let map):
                self.show(map)
                let bad = map.bytes(.badSector) / Int64(KroutonSector.size)
                self.status = bad == 0
                    ? "Every sector was copied. The image is \(imageURL.lastPathComponent); eject the disc to use it again."
                    : "Finished with \(bad) unreadable sector\(bad == 1 ? "" : "s"), saved as zeros. Clean the disc or try another drive, then start again with the same name to retry only those."
            case .failure(KroutonSectorReadError.driveFailed(let reason)):
                self.status = "The drive stopped answering: \(reason). Check its cable and power, then start again with the same name to carry on."
            case .failure(let error):
                self.status = error is CancellationError
                    ? "Stopped. Start again with the same name to carry on where it stopped."
                    : "The rescue stopped: \(error.localizedDescription) Start again with the same name to carry on."
            }
        }
    }

    func stop() {
        task?.cancel()
        status = "Stopping after the current read…"
    }

    private func show(_ map: KroutonRescueMap) {
        self.map = map
        let size = Int64(KroutonSector.size)
        let done = ByteCountFormatter.string(fromByteCount: map.bytes(.finished), countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: map.totalBytes, countStyle: .file)
        guard isRunning else { return }
        let phase: String = switch map.phase {
        case .copying: "Copying the readable areas"
        case .trimming: "Trimming the edges of damaged areas"
        case .scraping: "Reading damaged areas one sector at a time"
        case .retrying: "Retrying bad sectors"
        case .finished: "Finishing"
        }
        status = "\(phase): \(done) of \(total) copied, \(map.bytes(.badSector) / size) bad sectors so far."
    }

    /// The rescue itself, off the main actor. Saves the mapfile every few seconds, at the end, and
    /// when the rescue stops early, and passes the map on a few times a second rather than per read.
    nonisolated private static func rescue(
        session: KroutonMMCDeviceSession, imageURL: URL, mapURL: URL, plan: KroutonRescuePlan,
        previous: KroutonRescueMap?, progress: @escaping @Sendable (KroutonRescueMap) -> Void
    ) async -> Result<KroutonRescueMap, any Error> {
        let source = MMCSectorSource(transport: session)
        let saver = KroutonMapSaver(url: mapURL)
        do {
            let sectors = try await source.sectorCount()
            let totalBytes = sectors * Int64(KroutonSector.size)
            // The rescuer resumes only a map of this disc's size; anything else starts from zeros.
            let resuming = previous?.totalBytes == totalBytes
            let sink: any KroutonSectorSink = try KroutonImageFileSink(url: imageURL, totalBytes: totalBytes, keepingExistingData: resuming)
            defer { try? sink.close() }
            let rescuer = KroutonDiscRescuer(source: source, sink: sink, plan: plan)
            let map = try await rescuer.run(resuming: resuming ? previous : nil) { map in
                if saver.record(map) { progress(map) }
            }
            saver.save(map)
            return .success(map)
        } catch {
            // Cancelled or the drive failed: keep the newest map, not the one from up to 3 s ago.
            if let latest = saver.latest {
                saver.save(latest)
                progress(latest)
            }
            return .failure(error)
        }
    }

    static func describe(_ error: MMCTransportError) -> String {
        switch error {
        case .unavailable(let reason): return reason
        case .checkCondition(let sense?): return "The drive refused: \(sense.meaning)."
        case .checkCondition: return "The drive refused the request."
        }
    }
}

/// Writes the mapfile at most every three seconds, so a crash or a pulled cable loses little, and
/// keeps the newest map so a rescue that stops early can save exactly where it got to.
final class KroutonMapSaver: Sendable {
    private struct Clock {
        var lastSave = Date.distantPast
        var lastPublish = Date.distantPast
        var latest: KroutonRescueMap?
    }

    let url: URL
    private let clock = OSAllocatedUnfairLock(initialState: Clock())

    init(url: URL) { self.url = url }

    /// The newest map passed to `record`.
    var latest: KroutonRescueMap? { clock.withLock { $0.latest } }

    /// Remembers `map`, saves it if three seconds have passed since the last save, and returns
    /// whether it is time to show it again (five times a second at most).
    func record(_ map: KroutonRescueMap) -> Bool {
        let now = Date()
        let (saveDue, publishDue) = clock.withLock { state -> (Bool, Bool) in
            state.latest = map
            let saveDue = now.timeIntervalSince(state.lastSave) >= 3
            let publishDue = now.timeIntervalSince(state.lastPublish) >= 0.2
            if saveDue { state.lastSave = now }
            if publishDue { state.lastPublish = now }
            return (saveDue, publishDue)
        }
        if saveDue { save(map) }
        return publishDue
    }

    func save(_ map: KroutonRescueMap) {
        try? map.mapfile(comment: "Rescue of \(url.deletingPathExtension().lastPathComponent)").write(to: url, atomically: true, encoding: .utf8)
    }
}
