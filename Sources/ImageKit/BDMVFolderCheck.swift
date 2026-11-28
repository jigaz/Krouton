import Foundation

// MARK: - Is This a Blu-ray Video Folder a Player Will Play?

/// Checks an authored Blu-ray (BDMV) folder before a blank is spent on it, and says what to leave
/// out of the disc.
///
/// A player reads `BDMV/index.bdmv` and `MovieObject.bdmv`, then the playlists (`PLAYLIST/*.mpls`),
/// which name clip information (`CLIPINF/*.clpi`) and streams (`STREAM/*.m2ts`, or `*.ssif` for 3D).
/// A folder copied from a commercial disc without decrypting has its streams still encrypted
/// with AACS, which a BD-R can't carry: every aligned unit of 32 source packets starts with a
/// copy-permission indicator (the top two bits of its first byte) that is 0 only when clear.
public enum KroutonBDMVFolder {
    /// Why `root` (the folder holding `BDMV`) won't play as a Blu-ray disc, or nil when it will.
    public static func problem(root: URL) -> String? {
        let fm = FileManager.default
        guard let bdmv = child(of: root, named: "BDMV", directory: true) else {
            return "There's no BDMV folder in \(root.lastPathComponent). Nothing was written."
        }
        for required in ["index.bdmv", "MovieObject.bdmv"] where child(of: bdmv, named: required, directory: false) == nil {
            return "BDMV has no \(required), so players won't start the disc. Add the whole authored BDMV folder. Nothing was written."
        }
        let listing: (String, [String]) -> [URL] = { folder, extensions in
            guard let dir = child(of: bdmv, named: folder, directory: true),
                  let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
            else { return [] }
            return items.filter { extensions.contains($0.pathExtension.lowercased()) }
        }
        if listing("PLAYLIST", ["mpls"]).isEmpty {
            return "BDMV/PLAYLIST has no playlists (.mpls), so there is nothing for a player to play. Nothing was written."
        }
        if listing("CLIPINF", ["clpi"]).isEmpty {
            return "BDMV/CLIPINF has no clip information (.clpi), which players need to find the video. Nothing was written."
        }
        let streams = listing("STREAM", ["m2ts", "ssif"])
        if streams.isEmpty {
            return "BDMV/STREAM has no video (.m2ts). Nothing was written."
        }
        let largest = streams.max { size($0) < size($1) }
        if let largest, isEncrypted(largest) {
            return "\(largest.lastPathComponent) is still encrypted (AACS), as on the original disc. A burned copy of it won't play. Krouton doesn't remove copy protection. Nothing was written."
        }
        return nil
    }

    /// What doesn't go on the disc: Finder's and other systems' hidden files (.DS_Store, ._ resource
    /// forks, .Spotlight-V100…), and the AACS and ANY! folders of a decrypted copy, which would
    /// make players look for keys the BD-R doesn't have. `relativePath` is from the disc's root.
    public static func leftOut(relativePath: String, isDirectory: Bool) -> Bool {
        let components = relativePath.split(separator: "/")
        guard let name = components.last else { return false }
        if name.hasPrefix(".") || name == "Thumbs.db" || name == "desktop.ini" { return true }
        return components.count == 1 && isDirectory && ["AACS", "ANY!"].contains(name.uppercased())
    }

    // MARK: - Helpers

    /// A child whose name matches `name` ignoring case (copies from FAT or Windows can be lowercase).
    static func child(of folder: URL, named name: String, directory: Bool) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return items.first {
            $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame
                && ((try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) == directory
        }
    }

    static func size(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    /// Looks at aligned units (6144 bytes) a quarter and halfway in, past any clear lead-in.
    static func isEncrypted(_ stream: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: stream) else { return false }
        defer { try? handle.close() }
        let unit: UInt64 = 6144
        let length = UInt64(size(stream))
        guard length >= unit else { return false }
        for fraction in [4, 2] as [UInt64] {
            let offset = length / fraction / unit * unit
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let bytes = try? handle.read(upToCount: 5), bytes.count == 5 else { continue }
            // A source packet: 4-byte extra header, then a transport packet starting 0x47.
            if bytes[4] == 0x47, bytes[0] & 0xC0 != 0 { return true }
        }
        return false
    }
}
