import Foundation

// MARK: - PAR2 Recovery Files

public enum KroutonParityError: Error, LocalizedError, Sendable, Equatable {
    case par2Missing
    case failed(Int32)

    public var errorDescription: String? {
        switch self {
        case .par2Missing:
            return "Recovery files need par2 (Homebrew: brew install par2). Or set PAR2 to Off to burn without them. Nothing was written."
        case .failed(let status):
            return "par2 stopped with status \(status) while writing the recovery files. Nothing was written."
        }
    }
}

/// Writes PAR2 recovery files for a folder that is about to be burned, so a scratched M-DISC
/// can be repaired from the disc itself (`par2 repair KROUTON_RECOVERY.par2`).
///
/// Programmer's notes: par2cmdline runs with an explicit argument array (no shell). `-R` takes
/// the folder recursively and `-B` makes the stored names relative to it, so the set still
/// matches when the disc mounts elsewhere. `-n1` keeps one recovery file beside the index.
public enum KroutonParityWriter {
    public static func locatePar2() -> URL? {
        for candidate in ["/opt/homebrew/bin/par2", "/usr/local/bin/par2", "/usr/bin/par2"]
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }

    public static func arguments(folder: URL, percent: Int) -> [String] {
        ["create", "-q", "-q", "-R", "-r\(percent)", "-n1", "-B", folder.path,
         folder.appendingPathComponent("KROUTON_RECOVERY.par2").path, folder.path]
    }

    /// Adds the recovery files to `folder`. Blocking: call it off the main actor.
    public static func addRecovery(to folder: URL, percent: Int, par2: URL?) throws {
        guard percent > 0 else { return }
        guard let par2 else { throw KroutonParityError.par2Missing }
        let process = Process()
        process.executableURL = par2
        process.arguments = arguments(folder: folder, percent: percent)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw KroutonParityError.failed(process.terminationStatus) }
    }
}
