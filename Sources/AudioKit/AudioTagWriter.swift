import AVFoundation
import Foundation
import OpticalCore
import os

// MARK: - Tags for Ripped Tracks

/// What a ripped track is called, written into the file so music apps show it.
public struct KroutonAudioTags: Sendable, Equatable {
    public var title = ""
    public var artist = ""
    public var album = ""
    public var albumArtist = ""
    public var composer = ""
    public var genre = ""
    public var year = ""
    public var trackNumber = 0
    public var trackTotal = 0
    public var discNumber = 0
    public var discTotal = 0
    public var isCompilation = false

    public init() {}

    /// Vorbis comment fields, which FLAC uses, in a stable order.
    var vorbisFields: [(String, String)] {
        var fields: [(String, String)] = [
            ("TITLE", title), ("ARTIST", artist), ("ALBUM", album), ("ALBUMARTIST", albumArtist),
            ("COMPOSER", composer), ("GENRE", genre), ("DATE", year),
        ]
        if trackNumber > 0 { fields.append(("TRACKNUMBER", String(trackNumber))) }
        if trackTotal > 0 { fields.append(("TRACKTOTAL", String(trackTotal))) }
        if discNumber > 0 { fields.append(("DISCNUMBER", String(discNumber))) }
        if discTotal > 0 { fields.append(("DISCTOTAL", String(discTotal))) }
        if isCompilation { fields.append(("COMPILATION", "1")) }
        return fields.filter { !$0.1.isEmpty }
    }
}

public enum KroutonAudioTagError: Error, LocalizedError, Sendable, Equatable {
    case unreadable(String)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let file): return "Krouton couldn't read \(file) to add its tags."
        case .exportFailed(let file): return "Krouton couldn't write the tags into \(file)."
        }
    }
}

// MARK: - Tag Writer

/// Adds tags to a file the ripper has just written, in the way each format keeps them: a
/// Vorbis comment block in FLAC, a LIST/INFO chunk in WAV, NAME/AUTH/ANNO chunks in AIFF, and
/// iTunes metadata in M4A (ALAC/AAC).
///
/// Programmer's notes: FLAC, WAV and AIFF are rewritten in place by editing their container
/// (the audio bytes are not touched). M4A goes through a passthrough `AVAssetExportSession`
/// into a temporary file that then replaces the original, because inserting atoms by hand
/// would move the sample data the `moov` atom points to.
public enum KroutonAudioTagWriter {
    public static func write(_ tags: KroutonAudioTags, to url: URL) async throws {
        switch url.pathExtension.lowercased() {
        case "flac": try rewrite(url) { try flacWithComments($0, tags: tags) }
        case "wav": try rewrite(url) { wavWithInfo($0, tags: tags) }
        case "aif", "aiff": try rewrite(url) { aiffWithText($0, tags: tags) }
        case "m4a", "mp4": try await writeMP4(tags, to: url)
        default: return
        }
    }

    /// `write` for callers on a plain thread (the ripper's queue). Never call it on the main
    /// thread or from inside a task.
    public static func writeBlocking(_ tags: KroutonAudioTags, to url: URL) -> Bool {
        let done = DispatchSemaphore(value: 0)
        let result = KroutonTagResultBox()
        Task {
            do { try await write(tags, to: url) } catch { result.fail() }
            done.signal()
        }
        done.wait()
        return result.ok
    }

    private static func rewrite(_ url: URL, _ edit: (Data) throws -> Data) throws {
        guard let data = try? Data(contentsOf: url) else { throw KroutonAudioTagError.unreadable(url.lastPathComponent) }
        try edit(data).write(to: url, options: .atomic)
    }

    // MARK: - FLAC

    /// Replaces any Vorbis comment block with ours, right after STREAMINFO.
    static func flacWithComments(_ data: Data, tags: KroutonAudioTags) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count > 8, Array(bytes[0..<4]) == [0x66, 0x4C, 0x61, 0x43] else { throw KroutonAudioTagError.unreadable("FLAC file") }
        var blocks: [(type: UInt8, body: ArraySlice<UInt8>)] = []
        var at = 4
        var last = false
        while !last {
            guard at + 4 <= bytes.count else { throw KroutonAudioTagError.unreadable("FLAC file") }
            last = bytes[at] & 0x80 != 0
            let type = bytes[at] & 0x7F
            let length = Int(bytes[at + 1]) << 16 | Int(bytes[at + 2]) << 8 | Int(bytes[at + 3])
            guard at + 4 + length <= bytes.count else { throw KroutonAudioTagError.unreadable("FLAC file") }
            if type != 4 { blocks.append((type, bytes[(at + 4)..<(at + 4 + length)])) }
            at += 4 + length
        }
        var comment = le32Field(Array("Krouton".utf8))
        let fields = tags.vorbisFields
        comment += KroutonBytes.le32(UInt32(fields.count))
        for (key, value) in fields { comment += le32Field(Array("\(key)=\(value)".utf8)) }
        blocks.insert((4, ArraySlice(comment)), at: min(1, blocks.count))

        var out: [UInt8] = Array(bytes[0..<4])
        for (i, block) in blocks.enumerated() {
            let flag: UInt8 = i == blocks.count - 1 ? 0x80 : 0
            let n = block.body.count
            out += [flag | block.type, UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)]
            out += block.body
        }
        out += bytes[at...]
        return Data(out)
    }

    // MARK: - WAV and AIFF

    /// Appends a LIST/INFO chunk and fixes the RIFF size.
    static func wavWithInfo(_ data: Data, tags: KroutonAudioTags) -> Data {
        var info: [UInt8] = Array("INFO".utf8)
        let fields: [(String, String)] = [
            ("INAM", tags.title), ("IART", tags.artist), ("IPRD", tags.album), ("IGNR", tags.genre),
            ("ICRD", tags.year), ("ITRK", tags.trackNumber > 0 ? String(tags.trackNumber) : ""),
        ]
        for (id, value) in fields where !value.isEmpty {
            var text = Array(value.utf8) + [0]
            info += Array(id.utf8) + KroutonBytes.le32(UInt32(text.count))
            if text.count % 2 == 1 { text.append(0) }
            info += text
        }
        var out = [UInt8](data)
        if out.count % 2 == 1 { out.append(0) }
        out += Array("LIST".utf8) + KroutonBytes.le32(UInt32(info.count)) + info
        let riff = KroutonBytes.le32(UInt32(out.count - 8))
        out.replaceSubrange(4..<8, with: riff)
        return Data(out)
    }

    /// Appends NAME, AUTH and ANNO chunks and fixes the FORM size.
    static func aiffWithText(_ data: Data, tags: KroutonAudioTags) -> Data {
        var out = [UInt8](data)
        if out.count % 2 == 1 { out.append(0) }
        let note = [tags.album, tags.year].filter { !$0.isEmpty }.joined(separator: ", ")
        for (id, value) in [("NAME", tags.title), ("AUTH", tags.artist), ("ANNO", note)] where !value.isEmpty {
            var text = Array(value.utf8)
            out += Array(id.utf8) + KroutonBytes.be32(UInt32(text.count))
            if text.count % 2 == 1 { text.append(0) }
            out += text
        }
        out.replaceSubrange(4..<8, with: KroutonBytes.be32(UInt32(out.count - 8)))
        return Data(out)
    }

    // MARK: - M4A

    private static func writeMP4(_ tags: KroutonAudioTags, to url: URL) async throws {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw KroutonAudioTagError.exportFailed(url.lastPathComponent)
        }
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".krouton-tags-\(UUID().uuidString).m4a")
        session.outputURL = temporary
        session.outputFileType = .m4a
        session.metadata = mp4Items(tags)
        await session.export()
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: temporary)
            throw KroutonAudioTagError.exportFailed(url.lastPathComponent)
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }

    private static func mp4Items(_ tags: KroutonAudioTags) -> [AVMetadataItem] {
        func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem? {
            guard !value.isEmpty else { return nil }
            let m = AVMutableMetadataItem()
            m.identifier = identifier
            m.value = value as NSString
            return m
        }
        return [
            item(.iTunesMetadataSongName, tags.title),
            item(.iTunesMetadataArtist, tags.artist),
            item(.iTunesMetadataAlbum, tags.album),
            item(.iTunesMetadataAlbumArtist, tags.albumArtist),
            item(.iTunesMetadataComposer, tags.composer),
            item(.iTunesMetadataUserGenre, tags.genre),
            item(.iTunesMetadataReleaseDate, tags.year),
        ].compactMap { $0 }
    }

    // MARK: - Byte Helpers

    private static func le32Field(_ bytes: [UInt8]) -> [UInt8] { KroutonBytes.le32(UInt32(bytes.count)) + bytes }
}

/// Carries `writeBlocking`'s result out of its task.
final class KroutonTagResultBox: Sendable {
    private let failed = OSAllocatedUnfairLock(initialState: false)
    func fail() { failed.withLock { $0 = true } }
    var ok: Bool { !failed.withLock { $0 } }
}
