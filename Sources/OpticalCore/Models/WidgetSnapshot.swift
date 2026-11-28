import Foundation

// MARK: - What the Widget Shows

/// Krouton's state as its desktop widget (and, from macOS 27.3, its Live Activity) shows it. The
/// app writes it to the shared app-group container; the widget extension, a separate sandboxed
/// process, only reads it.
public struct KroutonWidgetSnapshot: Codable, Hashable, Sendable {
    public struct Task: Codable, Hashable, Sendable {
        public var title: String
        public var detail: String
        /// 0…1, or nil while the length isn't known.
        public var fraction: Double?
        public var symbol: String

        public init(title: String, detail: String, fraction: Double?, symbol: String) {
            self.title = title
            self.detail = detail
            self.fraction = fraction
            self.symbol = symbol
        }
    }

    public var tasks: [Task]
    /// The last burn that finished, for the idle widget: "Holiday Photos, 2 hours ago".
    public var lastFinished: String?
    public var lastFinishedAt: Date?
    public var writtenAt: Date

    public init(tasks: [Task], lastFinished: String?, lastFinishedAt: Date?, writtenAt: Date = Date()) {
        self.tasks = tasks
        self.lastFinished = lastFinished
        self.lastFinishedAt = lastFinishedAt
        self.writtenAt = writtenAt
    }

    /// The app group both the app and the widget extension are signed with.
    public static let appGroup = "D3BJL3F92P.app.krouton.shared"
    public static let fileName = "widget-snapshot.json"
    /// The widget kind WidgetCenter reloads.
    public static let widgetKind = "app.krouton.status"

    /// Where the snapshot lives, or nil when this build isn't signed with the app group.
    public static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    public static func read() -> KroutonWidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.withISODates.decode(KroutonWidgetSnapshot.self, from: data)
    }

    public func write() throws {
        guard let url = Self.fileURL else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.withISODates.encode(self).write(to: url, options: .atomic)
    }
}

private extension JSONEncoder {
    static var withISODates: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var withISODates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
