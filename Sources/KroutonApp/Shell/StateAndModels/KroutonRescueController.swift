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

    /// Whether a mapfile from an earlier attempt is waiting at the chosen name.
    var canResume: Bool { FileManager.default.fileExists(atPath: mapURL.path) }

    func start(driveID: String?, driveManager: KroutonOpticalDriveBank) {
        guard !isRunning else { return }
        isRunning = true
        status = "Unmounting the disc and opening the drive…"
        let imageURL = imageURL, mapURL = mapURL, plan = KroutonRescuePlan(retryPasses: retryPasses)
        let previous = (try? String(contentsOf: mapURL, encoding: .utf8)).flatMap(KroutonRescueMap.parse(mapfile:))
        task = Task { @MainActor in
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

    /// The rescue itself, off the main actor. Saves the mapfile every few seconds and at the end.
    nonisolated private static func rescue(
        session: KroutonMMCDeviceSession, imageURL: URL, mapURL: URL, plan: KroutonRescuePlan,
        previous: KroutonRescueMap?, progress: @escaping @Sendable (KroutonRescueMap) -> Void
    ) async -> Result<KroutonRescueMap, any Error> {
        let source = MMCSectorSource(transport: session)
        do {
            let sectors = try await source.sectorCount()
            let sink: any KroutonSectorSink = try KroutonImageFileSink(url: imageURL, totalBytes: sectors * Int64(KroutonSector.size))
            defer { try? sink.close() }
            let saver = KroutonMapSaver(url: mapURL)
            let rescuer = KroutonDiscRescuer(source: source, sink: sink, plan: plan)
            let map = try await rescuer.run(resuming: previous) { map in
                saver.saveIfDue(map)
                progress(map)
            }
            saver.save(map)
            return .success(map)
        } catch {
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

/// Writes the mapfile at most every three seconds, so a crash or a pulled cable loses little.
final class KroutonMapSaver: Sendable {
    let url: URL
    private let lastSave = OSAllocatedUnfairLock(initialState: Date.distantPast)

    init(url: URL) { self.url = url }

    func saveIfDue(_ map: KroutonRescueMap) {
        let due = lastSave.withLock { last -> Bool in
            guard Date().timeIntervalSince(last) >= 3 else { return false }
            last = Date()
            return true
        }
        if due { save(map) }
    }

    func save(_ map: KroutonRescueMap) {
        try? map.mapfile(comment: "Rescue of \(url.deletingPathExtension().lastPathComponent)").write(to: url, atomically: true, encoding: .utf8)
    }
}
