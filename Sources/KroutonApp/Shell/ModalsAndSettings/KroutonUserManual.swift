import Foundation
import OpticalCore

// MARK: - Manual Chapters

/// The user manual's chapters. Each one is a Markdown file in `Resources/Manual`, the same files
/// `Scripts/build-manual.py` renders into krouton.app/manual, so the app and the site never disagree.
enum KroutonManualChapter: String, CaseIterable, Identifiable, Sendable {
    case gettingStarted = "manual-01-getting-started"
    case dataDiscs = "manual-02-data-discs"
    case audioCDs = "manual-03-audio-cds"
    case burners = "manual-04-burners"
    case kroutonServer = "manual-05-krouton-server"
    case labels = "manual-06-labels"
    case videoAndMore = "manual-07-video-and-more"
    case automation = "manual-08-automation"
    case keyboardShortcuts = "manual-09-keyboard-shortcuts"
    case troubleshooting = "manual-10-troubleshooting"
    case glossary = "manual-11-glossary"

    var id: String { rawValue }

    /// The chapter's address on krouton.app: `manual-03-audio-cds` -> `audio-cds`.
    var slug: String { String(rawValue.split(separator: "-").dropFirst(2).joined(separator: "-")) }

    var onlineURL: URL { KroutonDomainIdentity.manualURL.appendingPathComponent(slug + "/") }

    var document: KroutonManualDocument { KroutonManualLibrary.documents[self] ?? .missing(self) }

    var title: String { document.title }

    var sfSymbol: String {
        switch self {
        case .gettingStarted: return "sparkles.rectangle.stack.fill"
        case .dataDiscs: return "folder.fill"
        case .audioCDs: return "waveform.path.ecg.rectangle.fill"
        case .burners: return "externaldrive.connected.to.line.below.fill"
        case .kroutonServer: return "server.rack"
        case .labels: return "printer.dotmatrix.fill"
        case .videoAndMore: return "film.stack.fill"
        case .automation: return "terminal.fill"
        case .keyboardShortcuts: return "command.square.fill"
        case .troubleshooting: return "wrench.and.screwdriver.fill"
        case .glossary: return "character.book.closed.fill"
        }
    }

    var associatedTutorial: KroutonGuidedTutorialID? {
        switch self {
        case .audioCDs: return .redBookCrossfade
        case .burners: return .multiBurnerPool
        case .dataDiscs: return .multiDiscSpanning
        case .labels: return .polarLabelStudio
        default: return nil
        }
    }

    func matches(query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = document.searchText
        return words.allSatisfy { haystack.contains($0) }
    }
}

// MARK: - Parsed Chapter

/// A chapter parsed from the small Markdown subset the manual uses: `#` title, `##` sections,
/// paragraphs, `-` bullets and `1.` steps. Inline `**bold**`, `` `code` `` and links stay in the
/// text and are rendered by `AttributedString(markdown:)`.
struct KroutonManualDocument: Sendable, Equatable {
    enum Block: Sendable, Equatable {
        case heading(String)
        case paragraph(String)
        case bullets([String])
        case steps([String])
    }

    let title: String
    let blocks: [Block]

    var searchText: String {
        let parts = blocks.flatMap { block -> [String] in
            switch block {
            case .heading(let text), .paragraph(let text): return [text]
            case .bullets(let items), .steps(let items): return items
            }
        }
        return ([title] + parts).joined(separator: " ").lowercased()
    }

    static func missing(_ chapter: KroutonManualChapter) -> KroutonManualDocument {
        KroutonManualDocument(
            title: chapter.slug.replacingOccurrences(of: "-", with: " ").capitalized,
            blocks: [.paragraph("This chapter is missing from this copy of Krouton. Read it at \(chapter.onlineURL.absoluteString).")]
        )
    }

    static func parse(_ markdown: String) -> KroutonManualDocument {
        var title = ""
        var blocks: [Block] = []
        var paragraph: [String] = []
        var list: [String] = []
        var listIsSteps = false

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        func flushList() {
            if !list.isEmpty { blocks.append(listIsSteps ? .steps(list) : .bullets(list)) }
            list = []
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                flushList()
            } else if line.hasPrefix("## ") {
                flushParagraph()
                flushList()
                blocks.append(.heading(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flushParagraph()
                flushList()
                title = String(line.dropFirst(2))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                if listIsSteps { flushList() }
                listIsSteps = false
                list.append(String(line.dropFirst(2)))
            } else if let step = stepText(line) {
                flushParagraph()
                if !listIsSteps { flushList() }
                listIsSteps = true
                list.append(step)
            } else if !list.isEmpty {
                list[list.count - 1] += " " + line
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        flushList()
        return KroutonManualDocument(title: title, blocks: blocks)
    }

    /// `"12. Do this"` -> `"Do this"`; nil for anything that isn't a numbered step.
    private static func stepText(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return String(rest.dropFirst(2))
    }

    /// Inline Markdown for one block of text; falls back to the plain text if it doesn't parse.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Loading From the Bundle

enum KroutonManualLibrary {
    static let documents: [KroutonManualChapter: KroutonManualDocument] = {
        var loaded: [KroutonManualChapter: KroutonManualDocument] = [:]
        for chapter in KroutonManualChapter.allCases {
            if let url = resourceURL(for: chapter), let text = try? String(contentsOf: url, encoding: .utf8) {
                loaded[chapter] = KroutonManualDocument.parse(text)
            }
        }
        return loaded
    }()

    private static func resourceURL(for chapter: KroutonManualChapter) -> URL? {
        for bundle in [Bundle.main, Bundle.module] {
            if let url = bundle.url(forResource: chapter.rawValue, withExtension: "md")
                ?? bundle.url(forResource: chapter.rawValue, withExtension: "md", subdirectory: "Manual") {
                return url
            }
        }
        return nil
    }
}
