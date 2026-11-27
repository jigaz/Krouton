import Foundation
import Observation

/// Settings for ripping and burning that several workspaces share.
@Observable
@MainActor
final class RipSettings {
    /// Check each ripped track against the AccurateRip database.
    var verifyAccurateRip: Bool = true
    /// The ripped files' naming pattern (Settings › Ripping); see `ripFileStem`.
    var namingTokens: [String] = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
    /// Burn without closing the disc, so more sessions can be added later (Puppy Linux saves
    /// itself back onto the disc it booted from this way). Set by the Depot for such images.
    var leaveDiscOpenForMoreSessions: Bool = false

    init() {}

    var namingPreviewString: String {
        let stem = Self.ripFileStem(tokens: namingTokens, number: 1, artist: "Artist", album: "Album", title: "Title", year: "1977")
        return stem.isEmpty ? "01 - Title.flac" : "\(stem).flac"
    }

    /// Fills the pattern in. Tokens are [Track 01], [Artist], [Album], [Title], [Year]; anything
    /// else is used as typed, and "/" makes a folder. "/" inside a value becomes "-".
    nonisolated static func ripFileStem(tokens: [String], number: Int, artist: String, album: String, title: String, year: String) -> String {
        func clean(_ value: String) -> String { value.replacingOccurrences(of: "/", with: "-") }
        return tokens.map { token -> String in
            switch token {
            case "[Track 01]": return String(format: "%02d", number)
            case "[Artist]": return clean(artist)
            case "[Album]": return clean(album)
            case "[Title]": return clean(title)
            case "[Year]": return clean(year)
            default: return token
            }
        }.joined()
    }
}
