import AudioKit
import Foundation

// MARK: - Destination Card Presets & Typed Settings

/// What each kind of destination card starts with, and typed access to the settings that
/// `speedOrCodec` and `hardwareOrPath` hold as text. The text fields stay as they are so
/// queues saved by earlier versions still decode.
extension KroutonBakeBatchItem {
    static let ripRootFolder = "~/Music/Krouton Rips"
    static let videoExtractFolder = "~/Movies/Krouton Extracts"
    /// The label exports' folder when a card names none.
    static let labelExportFolder = "~/Downloads"
    static let burnSpeedAuto = "Max Safe (Auto)"

    static func ripFolder(for codec: KroutonRipCodec) -> String {
        "\(ripRootFolder)/\(codec.defaultFolderName)"
    }

    // MARK: - Rip Cards

    /// The rip card's format, stored in `speedOrCodec`. Text that names no format Krouton
    /// writes reads as FLAC, which is what the card then shows.
    var ripCodec: KroutonRipCodec {
        KroutonRipCodec(savedLabel: speedOrCodec) ?? .flac
    }

    /// Changes the format, and moves the folder along with it while it is still a suggested one.
    mutating func setRipCodec(_ codec: KroutonRipCodec) {
        if Self.isSuggestedRipFolder(hardwareOrPath) {
            hardwareOrPath = Self.ripFolder(for: codec)
        }
        speedOrCodec = codec.rawValue
    }

    static func audioRip(_ codec: KroutonRipCodec) -> KroutonBakeBatchItem {
        var card = KroutonBakeBatchItem(kind: .audioRip, hardwareOrPath: "", speedOrCodec: "",
                                        simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
        card.becomeAudioRip(codec)
        return card
    }

    mutating func becomeAudioRip(_ codec: KroutonRipCodec = .flac) {
        kind = .audioRip
        targetDriveID = ""
        hardwareOrPath = Self.ripFolder(for: codec)
        speedOrCodec = codec.rawValue
    }

    /// A folder Krouton suggested (now or before 2026-11-27), as opposed to one the person chose.
    private static func isSuggestedRipFolder(_ path: String) -> Bool {
        let legacy = ["FLAC Lossless", "MP3 320kbps"].map { "\(ripRootFolder)/\($0)" }
        return path.isEmpty || path == ripRootFolder || legacy.contains(path)
            || KroutonRipCodec.allCases.contains { ripFolder(for: $0) == path }
    }

    // MARK: - Other Cards

    static func videoExtract() -> KroutonBakeBatchItem {
        KroutonBakeBatchItem(kind: .videoExtract, hardwareOrPath: videoExtractFolder, speedOrCodec: "Lossless MKV Remux",
                             simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
    }

    /// A Krouton Server card. An empty server means the first paired server, which is also
    /// what the card's picker shows.
    static func networkBurner() -> KroutonBakeBatchItem {
        KroutonBakeBatchItem(kind: .networkBurner, hardwareOrPath: "", speedOrCodec: burnSpeedAuto,
                             simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
    }

    /// The label cards hold a folder: Label Print Sheet saves a PNG and a PDF there, Vector PDF
    /// Label only the PDF, both named after the disc title.
    static func label(_ kind: KroutonBurnDestinationKind) -> KroutonBakeBatchItem {
        KroutonBakeBatchItem(kind: kind, hardwareOrPath: labelExportFolder, speedOrCodec: "",
                             simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
    }

    /// The folder a label card saves into. Cards saved before 2026-11-27 held a file path.
    var labelExportFolderURL: URL {
        var path = hardwareOrPath.isEmpty ? Self.labelExportFolder : hardwareOrPath
        if !(path as NSString).pathExtension.isEmpty { path = (path as NSString).deletingLastPathComponent }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    // MARK: - Saved Before 2026-11-27

    /// Repairs a card saved before 2026-11-27, whose preset text promised formats Krouton
    /// doesn't write (an "MP3" rip card wrote AIFF files) or named a placeholder server.
    func repairingLegacyPresets() -> KroutonBakeBatchItem {
        var card = self
        switch kind {
        case .audioRip:
            card.setRipCodec(ripCodec)
        case .networkBurner:
            if card.hardwareOrPath == "localhost:7420" { card.hardwareOrPath = "" }
        case .videoExtract:
            if card.speedOrCodec.contains("HEVC") {
                card.speedOrCodec = "Lossless MKV Remux"
                card.hardwareOrPath = Self.videoExtractFolder
            }
        case .discPrinter, .pdfVector:
            // These held a file path the export never used; keep its folder, which it now does use.
            if !(card.hardwareOrPath as NSString).pathExtension.isEmpty {
                card.hardwareOrPath = (card.hardwareOrPath as NSString).deletingLastPathComponent
            }
        case .physicalBurner, .discImage:
            break
        }
        return card
    }
}
