import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Label Text from the On-Device Model

/// Turns what a disc is made from (a volume name like `SUMMER_2026_FINAL`, file names like
/// `01 - track one.flac`, CD-Text) into the title, subtitle and artwork search a label should
/// show, with Apple's on-device model (Foundation Models, macOS 26 and later). Nothing leaves the
/// Mac. Where the model isn't there (an older macOS, Apple Intelligence off, an Intel Mac),
/// Auto-Label works as before.
@MainActor
enum KroutonLabelSuggester {
    struct Suggestion: Equatable, Sendable {
        var title: String
        var subtitle: String
        var artworkQuery: String
    }

    /// Settings › Labels & Printers lets you turn this off.
    static var isEnabled: Bool { KroutonPreferences.bool(for: .labelSuggestions, default: true) }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Extensions that mark a title as a file name. A list, not a pattern: "Mozart K.525" and
    /// "Vol.III" are real titles.
    static let fileExtensions: Set<String> = [
        "iso", "img", "dmg", "bin", "cue", "toast", "zip", "mp4", "m4v", "mkv", "mov", "avi", "m2ts", "mts",
        "vob", "wav", "aif", "aiff", "flac", "mp3", "m4a", "jpg", "jpeg", "png", "heic", "pdf", "txt",
    ]

    /// A title that reads as a placeholder or a raw file-system name, which a person would retype.
    /// All-caps alone isn't one: "ABBA", "U2", "AC/DC" and "1989" are real titles.
    static func needsTidying(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || ["KROUTON_DISC", "KROUTON_VIDEO", "UNTITLED", "NO NAME"].contains(trimmed.uppercased()) { return true }
        let looksLikeAFileName = trimmed.contains(".") && fileExtensions.contains((trimmed as NSString).pathExtension.lowercased())
        return trimmed.contains("_") || looksLikeAFileName
    }

    /// Asks the model; nil when it isn't available, is turned off, or can't answer.
    static func suggest(volumeName: String, performer: String, itemNames: [String]) async -> Suggestion? {
        guard isEnabled, isAvailable else { return nil }
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            return try? await ask(volumeName: volumeName, performer: performer, itemNames: Array(itemNames.prefix(24)))
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private static func ask(volumeName: String, performer: String, itemNames: [String]) async throws -> Suggestion {
        let session = LanguageModelSession(instructions: """
            You name optical discs for their printed labels. You get the disc's volume name, a \
            performer if one is known, and the names of the files or tracks on it. Use only what \
            these say: never invent an artist, a year or a title that isn't suggested by them.
            """)
        let prompt = """
            Volume name: \(volumeName.isEmpty ? "(none)" : volumeName)
            Performer: \(performer.isEmpty ? "(unknown)" : performer)
            Items:
            \(itemNames.map { "- " + $0 }.joined(separator: "\n"))
            """
        let answer = try await session.respond(to: prompt, generating: LabelSuggestionAnswer.self).content
        return Suggestion(title: String(answer.title.prefix(60)), subtitle: String(answer.subtitle.prefix(60)),
                          artworkQuery: String(answer.artworkQuery.prefix(80)))
    }
    #endif
}

#if canImport(FoundationModels)
@available(macOS 26, *)
@Generable
struct LabelSuggestionAnswer {
    @Guide(description: "The disc's title as it should be printed: words, not a file or volume name; no underscores, no file extensions, no track numbers; at most 40 characters")
    var title: String
    @Guide(description: "The performer, artist, show or a short subtitle such as a season or a date, using only words present in the inputs; empty when nothing given names one")
    var subtitle: String
    @Guide(description: "Words to search for the cover art, using only words present in the inputs: album and artist, film, or show and season; empty for personal or data discs")
    var artworkQuery: String
}
#endif
