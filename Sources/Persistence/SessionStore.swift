import Foundation
import OpticalCore
import os

// Session persistence for Krouton. The app wires these up at launch, at quit and
// around burns in KroutonSessionPersistence.swift.
//
// Four pieces, each independent:
//
//   RunLock        Detects "the last run did not quit normally" with a file whose
//                  flock() the kernel releases on any kind of process death, plus
//                  a marker inside it that only a clean quit erases. No atexit.
//   SessionStore   Debounced, atomic, versioned snapshot of whatever Codable
//                  payload you give it, with a one-generation backup.
//   FileReference  Bookmark + path, so staged files survive renames and report
//                  "missing" instead of vanishing.
//   BurnJournal    Append-only, fsynced record of burn phases. After an unclean
//                  exit this is what tells the user which disc is suspect.
//
// Foundation only: nothing here touches AppKit or SwiftUI.

// MARK: - RunLock

/// What a running Krouton writes into `run.lock`, so the next launch can tell how this run ended.
public struct RunMarker: Codable, Sendable, Equatable {
    /// How far the run got.
    public enum Phase: String, Codable, Sendable { case restoring, running }
    /// The process ID of the run.
    public var pid: Int32
    var launchedAt: Date
    /// `.restoring` until the snapshot is applied, then `.running`.
    public var phase: Phase
    /// Unclean exits in a row before this run started (0 after a clean quit).
    var consecutiveUncleanExits: Int
}

/// How the previous run ended, as `RunLock.acquire` found it.
public enum LaunchVerdict: Sendable, Equatable {
    /// Previous run quit normally (or this is the first launch).
    case clean
    /// Previous run ended without erasing its marker: crash, force quit, kill from
    /// Xcode, power loss. These cannot be told apart, so do not call it a "crash".
    case unclean(previous: RunMarker)
    /// Another live Krouton holds the lock. Not an error and not a crash.
    case anotherInstanceRunning
}

/// Detects an unclean exit of the previous run, and a second copy of Krouton, with a `flock`ed
/// file.
public final class RunLock: Sendable {
    private let fd: Int32
    private let markerLock: OSAllocatedUnfairLock<RunMarker>

    /// Call once, as early in launch as possible.
    public static func acquire(in directory: URL) throws -> (lock: RunLock?, verdict: LaunchVerdict) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("run.lock").path
        let fd = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }

        // Non-blocking exclusive lock. The kernel drops it when the process dies
        // for any reason, so there is never a stale lock to clean up.
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return (nil, .anotherInstanceRunning)
        }

        var previous: RunMarker?
        let size = lseek(fd, 0, SEEK_END)
        if size > 0, size < 4096 {
            var buffer = [UInt8](repeating: 0, count: Int(size))
            if pread(fd, &buffer, buffer.count, 0) == buffer.count {
                previous = try? JSONDecoder().decode(RunMarker.self, from: Data(buffer))
            }
        }

        let fresh = RunMarker(
            pid: getpid(),
            launchedAt: Date(),
            phase: .restoring,
            consecutiveUncleanExits: previous.map { $0.consecutiveUncleanExits + 1 } ?? 0
        )
        let lock = RunLock(fd: fd, marker: fresh)
        lock.markerLock.withLock { marker in lock.writeLocked(marker) }
        return (lock, previous.map { .unclean(previous: $0) } ?? .clean)
    }

    private init(fd: Int32, marker: RunMarker) {
        self.fd = fd
        self.markerLock = OSAllocatedUnfairLock(initialState: marker)
    }

    /// Call after the snapshot has been applied and the UI is up. A run that dies
    /// before this point died *during restore*, which is the crash-loop signal.
    public func markRunning() {
        markerLock.withLock { marker in
            marker.phase = .running
            writeLocked(marker)
        }
    }

    /// Call once the app has been usable for a while (say 30 s) to forgive earlier
    /// unclean exits.
    public func markStable() {
        markerLock.withLock { marker in
            marker.consecutiveUncleanExits = 0
            writeLocked(marker)
        }
    }

    /// Call from your will-terminate hook. Erasing the marker is what makes the
    /// next launch `.clean`.
    public func markCleanExit() {
        markerLock.withLock { _ in
            _ = ftruncate(fd, 0)
            _ = fsync(fd)
        }
    }

    private func writeLocked(_ marker: RunMarker) {
        guard let data = try? JSONEncoder().encode(marker) else { return }
        _ = ftruncate(fd, 0)
        _ = data.withUnsafeBytes { pwrite(fd, $0.baseAddress, $0.count, 0) }
        _ = fsync(fd)
    }

    deinit { close(fd) }
}

// MARK: - What to do at launch

/// What to do with the saved session at launch.
public enum RestoreDecision: Sendable, Equatable {
    /// Don't restore: nothing is saved, the user turned restoring off, or another Krouton is
    /// running.
    case startFresh
    /// Put things back without asking. This is the normal case, including after
    /// most unclean exits: the user wants their work, not a question.
    case restoreSilently
    /// Ask before restoring. Only used to break a crash loop.
    case askFirst(reason: AskReason)

    /// Why to ask instead of restoring silently.
    public enum AskReason: Sendable, Equatable { case diedWhileRestoring, repeatedUncleanExits }
}

/// Decides whether to restore the saved session, from how the last run ended, whether a snapshot
/// exists and the user's setting.
public func restoreDecision(verdict: LaunchVerdict, hasSnapshot: Bool, rememberSession: Bool) -> RestoreDecision {
    guard hasSnapshot, rememberSession else { return .startFresh }
    switch verdict {
    case .clean:
        return .restoreSilently
    case .anotherInstanceRunning:
        return .startFresh
    case .unclean(let previous):
        if previous.phase == .restoring { return .askFirst(reason: .diedWhileRestoring) }
        if previous.consecutiveUncleanExits >= 1 { return .askFirst(reason: .repeatedUncleanExits) }
        return .restoreSilently
    }
}

// MARK: - FileReference

/// A staged file saved as a bookmark plus its last known path, so it survives renames and reports
/// "missing" instead of vanishing.
public struct FileReference: Codable, Sendable, Equatable {
    var bookmark: Data?
    var lastKnownPath: String

    /// Where a reference points now.
    public enum Resolution: Sendable, Equatable {
        /// The file is reachable at this URL.
        case found(URL)
        /// Keep this in the staged list as a visible "missing" row. Never drop it
        /// silently: the user needs to know the disc layout changed.
        case missing(lastKnownPath: String)
    }

    /// Records `url`'s path and a bookmark to it.
    public init(url: URL) {
        lastKnownPath = url.path
        // Add `.withSecurityScope` to both calls if the app is sandboxed.
        bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Touches the file system and can block on dead network volumes.
    /// Call it off the main actor (see `SessionStore.resolve`).
    public func resolve() -> Resolution {
        if let bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &stale),
               (try? url.checkResourceIsReachable()) == true {
                return .found(url)
            }
        }
        let url = URL(fileURLWithPath: lastKnownPath)
        return (try? url.checkResourceIsReachable()) == true ? .found(url) : .missing(lastKnownPath: lastKnownPath)
    }
}

// MARK: - SessionStore

/// Reads only the schema version of a saved snapshot.
private struct SessionVersionProbe: Decodable { var schemaVersion: Int }

/// Saves a snapshot of the app's state (`Payload`) to `session.json`, debounced and atomic, keeping
/// the previous one as `session.previous.json`. `Payload` must hold everything expensive to redo,
/// with staged files as `FileReference`s.
public actor SessionStore<Payload: Codable & Sendable> {

    private struct Envelope: Codable {
        var schemaVersion: Int
        var savedAt: Date
        var payload: Payload
    }

    /// What `load()` found.
    public enum LoadResult: Sendable {
        /// Nothing saved, or nothing readable.
        case none
        /// A snapshot, when it was saved, and whether it came from the backup.
        case loaded(Payload, savedAt: Date, fromBackup: Bool)
        /// Written by a newer Krouton. Leave the file alone and start fresh.
        case newerSchema(Int)
    }

    private let schemaVersion: Int
    private let currentURL: URL
    private let backupURL: URL
    private let debounce: Duration
    private var pending: Payload?
    private var saveTask: Task<Void, Never>?
    /// Upgrade hook: (rawJSON, fromVersion) -> rawJSON at `schemaVersion`.
    private let migrate: (@Sendable (Data, Int) throws -> Data)?
    /// What the last `load()` had to fill in or leave out to read a session saved by another
    /// version (see `KroutonPersistedJSON`); empty when it read as saved.
    public private(set) var lastLoadRepairs: [String] = []

    /// Saves under `directory`. `migrate` upgrades a snapshot saved with an older `schemaVersion`.
    public init(
        directory: URL,
        schemaVersion: Int,
        debounce: Duration = .seconds(1),
        migrate: (@Sendable (Data, Int) throws -> Data)? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.currentURL = directory.appendingPathComponent("session.json")
        self.backupURL = directory.appendingPathComponent("session.previous.json")
        self.debounce = debounce
        self.migrate = migrate
    }

    /// Call on every model change. Cheap: the write happens once, after changes
    /// stop for `debounce`.
    public func scheduleSave(_ payload: Payload) {
        pending = payload
        saveTask?.cancel()
        saveTask = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self.flush()
        }
    }

    /// Call from the will-terminate hook and before starting a burn.
    public func flush() {
        guard let payload = pending else { return }
        pending = nil
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Envelope(schemaVersion: schemaVersion, savedAt: Date(), payload: payload))
            let fm = FileManager.default
            // Keep the last good generation, then write temp-file-and-rename.
            if fm.fileExists(atPath: currentURL.path) {
                _ = try? fm.removeItem(at: backupURL)
                try? fm.copyItem(at: currentURL, to: backupURL)
            }
            try data.write(to: currentURL, options: .atomic)
        } catch {
            // Surface this in your log. A save that fails silently is how people lose work.
            pending = payload
        }
    }

    /// Reads the current snapshot, or the backup when the current one can't be read.
    public func load() -> LoadResult {
        lastLoadRepairs = []
        for (url, isBackup) in [(currentURL, false), (backupURL, true)] {
            guard var data = try? Data(contentsOf: url) else { continue }
            guard let probe = try? JSONDecoder().decode(SessionVersionProbe.self, from: data) else { continue }
            if probe.schemaVersion > schemaVersion { return .newerSchema(probe.schemaVersion) }
            if probe.schemaVersion < schemaVersion {
                guard let migrate, let upgraded = try? migrate(data, probe.schemaVersion) else { continue }
                data = upgraded
            }
            // A session saved by another version opens with what it lacks filled in, rather
            // than being skipped for the older backup or for nothing.
            if let read = try? KroutonPersistedJSON.decode(Envelope.self, from: data, iso8601Dates: true) {
                lastLoadRepairs = read.repairs
                return .loaded(read.value.payload, savedAt: read.value.savedAt, fromBackup: isBackup)
            }
        }
        return .none
    }

    /// Forgets the pending snapshot and deletes both files.
    public func discard() {
        saveTask?.cancel()
        pending = nil
        try? FileManager.default.removeItem(at: currentURL)
        try? FileManager.default.removeItem(at: backupURL)
    }

    /// Resolves references off the main actor, giving up on any that take too long
    /// (a sleeping NAS should not hang launch). A file-system call that is stuck
    /// cannot be cancelled, so each lookup races a timer and the loser is ignored.
    public nonisolated func resolve(_ references: [FileReference], timeoutPerFile: TimeInterval = 2) async -> [FileReference.Resolution] {
        await withTaskGroup(of: (Int, FileReference.Resolution).self) { group in
            for (index, reference) in references.enumerated() {
                group.addTask { (index, await Self.resolveOne(reference, timeout: timeoutPerFile)) }
            }
            var results = references.map { FileReference.Resolution.missing(lastKnownPath: $0.lastKnownPath) }
            for await (index, resolution) in group { results[index] = resolution }
            return results
        }
    }

    private static func resolveOne(_ reference: FileReference, timeout: TimeInterval) async -> FileReference.Resolution {
        await withCheckedContinuation { continuation in
            let gate = OnceGate()
            DispatchQueue.global(qos: .userInitiated).async {
                let resolution = reference.resolve()
                if gate.claim() { continuation.resume(returning: resolution) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if gate.claim() { continuation.resume(returning: .missing(lastKnownPath: reference.lastKnownPath)) }
            }
        }
    }
}

/// Lets exactly one of several racing callers win.
private final class OnceGate: Sendable {
    private let claimed = OSAllocatedUnfairLock(initialState: false)
    /// True for the first caller only.
    public func claim() -> Bool {
        claimed.withLock { flag in
            if flag { return false }
            flag = true
            return true
        }
    }
}

// MARK: - BurnJournal

/// One phase change of one burn, as a line of `burn-journal.jsonl`.
public struct BurnJournalRecord: Codable, Sendable, Equatable {
    /// The burn's phase. `succeeded`, `failed` and `cancelled` end a job.
    public enum Phase: String, Codable, Sendable {
        case started, writingLeadIn, writingData, closing, verifying
        case succeeded, failed, cancelled

        var isTerminal: Bool { self == .succeeded || self == .failed || self == .cancelled }
    }
    var jobID: UUID
    /// When the phase started.
    public var at: Date
    /// The phase.
    public var phase: Phase
    /// The drive, such as "ASUS SBW-06D5H-U".
    public var deviceName: String
    /// The disc, such as "CD-R, 97m15s05f".
    public var mediaDescription: String
    /// The project being burned.
    public var projectTitle: String
    /// On failure, what went wrong (for example the decoded sense code).
    public var detail: String?

    public init(jobID: UUID, at: Date = Date(), phase: Phase, deviceName: String,
                mediaDescription: String, projectTitle: String, detail: String? = nil) {
        self.jobID = jobID
        self.at = at
        self.phase = phase
        self.deviceName = deviceName
        self.mediaDescription = mediaDescription
        self.projectTitle = projectTitle
        self.detail = detail
    }
}

/// An append-only, fsynced record of burn phases. After an unclean exit it tells which disc was
/// mid-burn.
public actor BurnJournal {
    private let url: URL

    /// Keeps the journal in `directory`.
    public init(directory: URL) {
        url = directory.appendingPathComponent("burn-journal.jsonl")
    }

    /// One JSON object per line, flushed to disk before returning. Phase changes
    /// are rare (a handful per burn), so the fsync cost does not matter.
    public func append(_ record: BurnJournalRecord) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var line = try encoder.encode(record)
        line.append(0x0A)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        try handle.synchronize()
    }

    /// Jobs whose last record is not terminal: the app died mid-burn. Show these at
    /// launch ("The disc in <device> for <project> was not finished and is
    /// probably unusable"), then call `acknowledge`.
    public func interruptedJobs() -> [BurnJournalRecord] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var last: [UUID: BurnJournalRecord] = [:]
        // A torn final line (power loss mid-write) fails to decode and is skipped.
        for line in text.split(separator: "\n") {
            if let record = try? decoder.decode(BurnJournalRecord.self, from: Data(line.utf8)) {
                last[record.jobID] = record
            }
        }
        return last.values.filter { !$0.phase.isTerminal }.sorted { $0.at < $1.at }
    }

    /// Deletes the journal (Settings › Storage & Reset). Only call it while nothing is burning.
    public func clear() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// The journal's size on disk.
    public func bytesOnDisk() -> Int64 {
        // Not `url.resourceValues`: a URL caches those, so a size read before `clear()` would stay.
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Records each job as failed ("Krouton exited before this burn finished"), so it isn't
    /// reported again.
    public func acknowledge(_ jobs: [BurnJournalRecord]) throws {
        for job in jobs {
            var closed = job
            closed.at = Date()
            closed.phase = .failed
            closed.detail = "Krouton exited before this burn finished"
            try append(closed)
        }
    }
}
