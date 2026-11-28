import Foundation
import OpticalCore

// MARK: - Disc Images

extension KroutonOpticalDriveBank {
    /// Image types burned sector for sector: by DiscRecording (`DRBurn.layout(forImageFile:)`),
    /// and DiscJuggler .cdi by Krouton's own two-session layout (`beginDiscJugglerBurn`).
    public static let burnableImageExtensions: Set<String> = ["iso", "cdr", "dmg", "cue", "toc", "cdi"]

    /// Image formats Krouton recognises but can't write as a disc. Staged alone, they would
    /// otherwise end up as a file on a data disc, which is never what anyone wants.
    public static let unburnableImageExtensions: [String: String] = [
        "gdi": "A .gdi is a GD-ROM image, a format no burner can write.",
        "wbfs": "Convert the .wbfs to .iso first (for example with Wiimms ISO Tools).",
        "rvz": "Convert the .rvz to .iso first (Dolphin: right-click the game, Convert File).",
        "chd": "Convert the .chd to .cue/.bin first (chdman extractcd).",
    ]

    /// The disc image to burn as an image, when the staged items are exactly one such file.
    public static func soleDiscImage(in stagedFiles: [KroutonStagedFileEntry]) -> URL? {
        guard stagedFiles.count == 1, let only = stagedFiles.first, !only.isDirectory,
              burnableImageExtensions.contains(only.url.pathExtension.lowercased()) else { return nil }
        return only.url
    }
}
