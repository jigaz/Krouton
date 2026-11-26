import Foundation
import ImageKit
import Observation
import VideoKit
import os

// MARK: - AVCHD Controller

/// Makes a high-definition disc image from video files: ffmpeg converts each file to Blu-ray
/// H.264 + AC-3, Krouton writes the BDMV navigation files from the converted streams, then
/// puts the folder on a UDF 2.50 image, ready for Burn Disc Image.
@Observable
@MainActor
final class KroutonAVCHDController {
    var isRunning = false
    var fraction = 0.0
    var status = "Add video files, then make the disc image. Blu-ray players and PlayStation 3, 4 and 5 play it from a DVD."
    var dualLayer = false
    var lastImage: URL?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let cancelled = OSAllocatedUnfairLock(initialState: false)

    var capacityBytes: Int64 { dualLayer ? 8_500_000_000 : 4_700_000_000 }

    var ffmpegInstalled: Bool { OpticalDiscVolumeScanner.locateFFmpeg() != nil }

    /// Where finished images go: ~/Movies/Krouton.
    static var outputFolder: URL {
        (FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Krouton")
    }

    func start(sources: [URL], label: String, onImage: @escaping @MainActor (URL) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        fraction = 0
        cancelled.withLock { $0 = false }
        let capacity = capacityBytes
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "HD Video" : label
        let flag = cancelled
        task = Task { @MainActor in
            defer {
                self.isRunning = false
                self.task = nil
            }
            let outcome = await Task.detached(priority: .userInitiated) {
                Self.make(sources: sources, name: name, capacity: capacity, isCancelled: { flag.withLock { $0 } }) { f, text in
                    Task { @MainActor in
                        self.fraction = f
                        self.status = text
                    }
                }
            }.value
            switch outcome {
            case .success(let image):
                self.fraction = 1
                self.lastImage = image
                self.status = "\(image.lastPathComponent) is ready in Movies › Krouton. It's open in Burn Disc Image: put in a blank DVD and burn."
                onImage(image)
            case .failure(let error as KroutonAVCHDError) where error == .cancelled:
                self.status = "Stopped. Nothing was kept."
            case .failure(let error):
                self.status = error.localizedDescription
            }
        }
    }

    func stop() {
        cancelled.withLock { $0 = true }
        status = "Stopping…"
    }

    /// Authors into a temporary folder, images it, and removes the folder.
    nonisolated private static func make(
        sources: [URL], name: String, capacity: Int64,
        isCancelled: @escaping @Sendable () -> Bool,
        progress: @escaping AVCHDOnDVDAuthoringEngine.Progress
    ) -> Result<URL, any Error> {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("Krouton-AVCHD-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: work) }
        do {
            let disc: KroutonAVCHDDisc = try AVCHDOnDVDAuthoringEngine.author(
                sources: sources, into: work, capacityBytes: capacity,
                progress: { f, text in progress(f * 0.9, text) }, isCancelled: isCancelled)
            try fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)
            let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let image = outputFolder.appendingPathComponent(safe).appendingPathExtension("iso")
            progress(0.9, "Writing the UDF 2.50 disc image (\(disc.clips.count) clip\(disc.clips.count == 1 ? "" : "s") at \(disc.videoKbps / 1000) Mbit/s)")
            let built = try KroutonUDFImageWriter.build(
                folder: disc.root, output: image, label: name,
                progress: { progress(0.9 + 0.1 * $0, "Writing the disc image") }, isCancelled: isCancelled)
            guard Int64(built.sectors) * 2048 <= capacity else {
                try? fm.removeItem(at: image)
                throw KroutonAVCHDError.tooLong(minutes: Int((disc.clips.map(\.analysis.duration).reduce(0, +) / 60).rounded(.up)))
            }
            return .success(image)
        } catch is CancellationError {
            return .failure(KroutonAVCHDError.cancelled)
        } catch {
            return .failure(error)
        }
    }
}
