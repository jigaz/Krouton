import CryptoKit
import Foundation
import ImageKit
import os

// MARK: - Depot Feed (depot.krouton.app/v1/manifest.json)

/// The Disc Image Depot's catalogue, as published at depot.krouton.app. Every downloadable item
/// was fetched and checksummed by the depot; Krouton refuses a download whose SHA-256 differs.
/// Format: https://krouton.app/schema/depot-feed/v1.json. Unknown fields are ignored.
struct KroutonDepotFeed: Codable, Hashable, Sendable {
    struct Channel: Codable, Hashable, Sendable {
        let id: String
        let title: String
        let about: String
        let symbol: String?
    }

    struct Download: Codable, Hashable, Sendable {
        let url: URL
        let file: String
        let size: Int64
        let sha256: String
        let verified: String
        let archive: String?
    }

    struct Image: Codable, Hashable, Sendable {
        let path: String?
        let size: Int64
        let sha256: String
        let companions: [String]?
        let looksLike: String?

        enum CodingKeys: String, CodingKey {
            case path, size, sha256, companions
            case looksLike = "looks_like"
        }
    }

    struct Burn: Codable, Hashable, Sendable {
        let leaveOpen: Bool?
        let media: String?
        let note: String?

        enum CodingKeys: String, CodingKey {
            case media, note
            case leaveOpen = "leave_open"
        }
    }

    struct Item: Codable, Hashable, Sendable, Identifiable {
        let id: String
        let channel: String
        let kind: String
        let title: String
        let year: Int
        let era: Int?
        let version: String?
        let platform: String
        let summary: String
        let license: String
        let homepage: URL
        let boot: String?
        let fitsOn: String?
        let burn: Burn?
        let download: Download?
        let image: Image?

        enum CodingKeys: String, CodingKey {
            case id, channel, kind, title, year, era, version, platform, summary, license, homepage, boot, burn, download, image
            case fitsOn = "fits_on"
        }
    }

    let formatVersion: Int
    let generated: String?
    let channels: [Channel]
    let items: [Item]

    enum CodingKeys: String, CodingKey {
        case channels, items, generated
        case formatVersion = "format_version"
    }

    static let maximumBytes = 4 * 1024 * 1024

    static func decode(_ data: Data) throws -> KroutonDepotFeed {
        guard data.count <= maximumBytes else { throw CocoaError(.fileReadTooLarge) }
        let feed = try JSONDecoder().decode(KroutonDepotFeed.self, from: data)
        guard feed.formatVersion == 1 else { throw CocoaError(.fileReadUnsupportedScheme) }
        return feed
    }
}

// MARK: - Feed Items in the Depot UI

extension KroutonDepotFeed.Item {
    static let fitsOnLabels: [String: String] = [
        "business-card": "50 MB business-card CD", "mini-cd": "8 cm mini CD", "cd-74": "74-minute CD",
        "cd-80": "80-minute CD", "mini-dvd": "8 cm mini DVD", "dvd-5": "DVD", "dvd-9": "dual-layer DVD",
        "bd-25": "Blu-ray",
    ]

    /// The size people download, or the image's size when that is what they burn.
    var displayBytes: Int64 { image?.size ?? download?.size ?? 0 }

    func catalogItem(channelSymbols: [String: String], isDownloaded: Bool) -> KroutonDepotCatalogItem {
        let bytes = displayBytes
        let digest = image?.sha256 ?? download?.sha256 ?? ""
        let boot: String = {
            switch image?.looksLike {
            case "gamecube": return "GameCube disc (DOL-006)"
            case "wii": return "Wii disc (RVL-006)"
            case "dreamcast": return "Dreamcast MIL-CD (Mode 2)"
            default:
                switch kind {
                case "files": return "Files for an SD card or USB drive"
                case "link": return "From the project's own site"
                default: return self.boot ?? "Disc image"
                }
            }
        }()
        return KroutonDepotCatalogItem(
            id: id,
            title: title,
            subtitle: summary,
            channel: channel,
            version: version ?? String(year),
            sizeDisplay: bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) : "—",
            architecture: platform,
            bootStandard: boot,
            sha256Short: digest.count == 64 ? "\(digest.prefix(8))…\(digest.suffix(4))" : "—",
            sfSymbol: channelSymbols[channel] ?? "opticaldisc",
            isDownloaded: isDownloaded,
            feed: self
        )
    }

    /// Lines for the Depot's "About this disc" panel.
    var detailLines: [String] {
        var lines = ["Released \(year)" + (era.map { $0 < year ? " · project since \($0)" : "" } ?? "")]
        if let fitsOn, let label = Self.fitsOnLabels[fitsOn] { lines.append("Fits on a \(label)") }
        lines.append("Licence: \(license)")
        if burn?.leaveOpen == true { lines.append("Burned with the disc left open for more sessions") }
        if let note = burn?.note { lines.append(note) }
        if let verified = download?.verified { lines.append("Checksum confirmed by depot.krouton.app on \(verified.prefix(10))") }
        return lines
    }
}

extension KroutonDepotCatalogItem {
    /// Shown while the depot list hasn't loaded (first launch, offline).
    static func placeholder(status: String?) -> KroutonDepotCatalogItem {
        KroutonDepotCatalogItem(
            id: "depot-loading", title: "Fetching the depot list",
            subtitle: status ?? "Krouton is downloading the list of disc images from depot.krouton.app.",
            channel: "", version: "—", sizeDisplay: "—", architecture: "—", bootStandard: "—",
            sha256Short: "—", sfSymbol: "arrow.down.circle", isDownloaded: false
        )
    }
}

extension KroutonDepotCatalogItem {
    /// A sketch of where things sit on this kind of disc, for the Depot's hero panel.
    var blueprintSectorSegments: [(label: String, lbaRange: String)] {
        if bootStandard.contains("APM") || bootStandard.contains("HFS") {
            return [
                ("BLK 0..1: Driver + APM", "LBA 00..63"),
                ("HFS Catalog & Extents", "LBA 64..1024"),
                ("Blessed System + Payload", "LBA 1025..END")
            ]
        } else if bootStandard.contains("DOL-006") || bootStandard.contains("RVL-006") {
            return [
                ("boot.bin + bi2.bin", "0x0000..2440"),
                ("apploader.img", "0x2440..FST"),
                ("Game FST + main.dol", "32KB ECC..END")
            ]
        } else if bootStandard.contains("MIL-CD") || bootStandard.contains("Mode 2") {
            return [
                ("S1: Audio / Pre-Gap", "LBA 0..11400"),
                ("IP.BIN Bootstrap", "LBA 45000+16"),
                ("1ST_READ.BIN + XA", "LBA 45017..END")
            ]
        } else {
            return [
                ("SYS AREA / MBR", "LBA 00..15"),
                ("PVD + EL TORITO", "LBA 16..31"),
                ("UDF / ISO9660 TREE", "LBA 32..END")
            ]
        }
    }

    /// The facts shown under "About this disc".
    var blueprintRootFiles: [String] {
        feed?.detailLines ?? ["From an Internet Archive search: no depot checksum", "Check what it is before you burn it"]
    }
}

// MARK: - Downloading and Checking

enum KroutonDepotDownloadError: Error, LocalizedError, Equatable {
    case notDownloadable
    case checksumMismatch(file: String)
    case imageMissing(String)

    var errorDescription: String? {
        switch self {
        case .notDownloadable:
            return "This item has no download in the depot."
        case .checksumMismatch(let file):
            return "\(file) doesn't match the checksum the depot recorded, so Krouton deleted it. The project may have replaced the file; try again after the depot's next monthly check."
        case .imageMissing(let path):
            return "The download doesn't contain \(path)."
        }
    }
}

/// Reports download progress (0...1) from URLSession's delegate queue, once per half percent:
/// URLSession calls back for every chunk (tens of thousands for a DVD image), and each report
/// changes `depotDownloadProgress`, which the app's scenes and the Depot views read.
final class KroutonDepotDownloadProgress: NSObject, URLSessionDownloadDelegate, Sendable {
    let report: @Sendable (Double) -> Void
    private let lastReported = OSAllocatedUnfairLock(initialState: -1.0)

    init(report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let due = lastReported.withLock { last -> Bool in
            guard fraction - last >= 0.005 || fraction >= 1 else { return false }
            last = fraction
            return true
        }
        if due { report(fraction) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

enum KroutonDepotDownloader {
    static var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("Krouton/DepotCache", isDirectory: true)
    }

    /// Where an item's checked image lives once downloaded. The checksum is part of the path, so
    /// a new release never reuses an old file.
    static func imageURL(for item: KroutonDepotFeed.Item) -> URL? {
        guard let download = item.download, let image = item.image else { return nil }
        let folder = cacheDirectory.appendingPathComponent("\(item.id)-\(image.sha256.prefix(12))", isDirectory: true)
        let name = image.path.map { ($0 as NSString).lastPathComponent } ?? download.file
        return folder.appendingPathComponent(name)
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Downloads, checks the download against the feed, unpacks the image from an archive and
    /// checks that too. Returns the image to burn. Runs off the main actor.
    static func fetchImage(for item: KroutonDepotFeed.Item, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard let download = item.download, let image = item.image, let target = imageURL(for: item) else {
            throw KroutonDepotDownloadError.notDownloadable
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: target.path), (try? sha256(of: target)) == image.sha256 {
            return target
        }
        let folder = target.deletingLastPathComponent()
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let (temporary, _) = try await URLSession.shared.download(from: download.url, delegate: KroutonDepotDownloadProgress(report: progress))
        let downloaded = folder.appendingPathComponent(download.file)
        try fm.moveItem(at: temporary, to: downloaded)
        guard try sha256(of: downloaded) == download.sha256 else {
            try? fm.removeItem(at: folder)
            throw KroutonDepotDownloadError.checksumMismatch(file: download.file)
        }
        guard download.archive != nil, let member = image.path else {
            return downloaded
        }
        // The image (and a .cue sheet's .bin tracks) come out of the archive into the same folder.
        let wanted = [member] + (image.companions ?? [])
        try DiscImageDepotOperations.extractArchiveMembers(wanted, from: downloaded, into: folder)
        try? fm.removeItem(at: downloaded)
        for path in wanted {
            let extracted = folder.appendingPathComponent(path)
            let flat = folder.appendingPathComponent((path as NSString).lastPathComponent)
            if extracted.path != flat.path, fm.fileExists(atPath: extracted.path) {
                try? fm.removeItem(at: flat)
                try fm.moveItem(at: extracted, to: flat)
            }
        }
        guard fm.fileExists(atPath: target.path) else { throw KroutonDepotDownloadError.imageMissing(member) }
        guard try sha256(of: target) == image.sha256 else {
            try? fm.removeItem(at: folder)
            throw KroutonDepotDownloadError.checksumMismatch(file: member)
        }
        return target
    }
}
