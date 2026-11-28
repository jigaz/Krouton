import Foundation

// MARK: - Rip Codec

/// The formats Krouton writes ripped CD tracks in. All four keep every sample: Krouton has
/// no lossy encoder, so there is no MP3 or AAC here.
public enum KroutonRipCodec: String, CaseIterable, Codable, Sendable, Identifiable {
    case flac
    case alac
    case wav
    case aiff

    public var id: String { rawValue }

    /// The name the pickers show; the app's String Catalog translates it.
    public var title: String {
        switch self {
        case .flac: return "FLAC (Lossless)"
        case .alac: return "Apple Lossless (ALAC)"
        case .wav: return "WAV (Uncompressed PCM)"
        case .aiff: return "AIFF (1:1 Red Book PCM)"
        }
    }

    /// The extension the ripped file gets (ALAC goes in .m4a).
    public var fileExtension: String {
        switch self {
        case .flac: return "flac"
        case .alac: return "m4a"
        case .wav: return "wav"
        case .aiff: return "aiff"
        }
    }

    /// The folder a rip card suggests under ~/Music/Krouton Rips.
    public var defaultFolderName: String {
        switch self {
        case .flac: return "FLAC"
        case .alac: return "Apple Lossless"
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        }
    }

    // MARK: - Reading Saved Text

    /// Reads the codec from text saved by Krouton: a raw value, a title, or a free-text label
    /// from before 2026-11-27 such as "FLAC (Lossless) + AccurateRip". Returns nil when the
    /// text names none of the four, such as "MP3 (320 kbps CBR)" or a burn speed.
    public init?(savedLabel: String) {
        if let exact = KroutonRipCodec(rawValue: savedLabel) {
            self = exact
            return
        }
        let text = savedLabel.uppercased()
        if text.contains("FLAC") {
            self = .flac
        } else if text.contains("ALAC") || text.contains("APPLE LOSSLESS") {
            self = .alac
        } else if text.contains("WAV") {
            self = .wav
        } else if text.contains("AIFF") {
            self = .aiff
        } else {
            return nil
        }
    }
}
