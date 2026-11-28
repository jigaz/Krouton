import AVFoundation
import Foundation
import OpticalCore

// MARK: - Video Disc Scanner

/// A mounted video disc or folder, as Extract Video Disc lists it.
public struct ScannedOpticalVideoDisc: Sendable, Equatable {
    /// The volume's name.
    public var volumeTitle: String
    /// Where it is mounted.
    public var mountPath: String
    /// "DVD-Video (VIDEO_TS)", "Blu-ray (BDMV)" or "Optical Data Volume".
    public var discKind: String
    /// The volume's size in bytes.
    public var totalBytes: Int64
    /// The volume's size in 2,048-byte sectors.
    public var totalSectorsLBA: Int64
    /// The titles found.
    public var titles: [KroutonVideoExtractTitleItem]
    /// The files that make up each title, by title ID, in play order.
    public var titleSegmentURLs: [String: [URL]]
}

/// Finds the titles of a mounted DVD-Video or Blu-ray volume (or folder), and copies a title's
/// segments into one file.
public enum OpticalDiscVolumeScanner {

    private static let ignoredSystemVolumes: Set<String> = [
        "Macintosh HD", "Macintosh HD - Data", "Preboot", "VM", "Update", "Recovery", "xarts", "iSCPreboot", "Hardware"
    ]

    /// Scans a specific folder/mount path or searches `/Volumes` for a mounted DVD-Video (`VIDEO_TS`),
    /// Blu-ray (`BDMV`), or general data optical volume.
    public static func scanMountedVideoOrDataDisc(preferredPath: String = "") -> ScannedOpticalVideoDisc? {
        let fm = FileManager.default
        var candidateRoots: [URL] = []

        let trimmed = (preferredPath as NSString).expandingTildeInPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, fm.fileExists(atPath: trimmed) {
            let u = URL(fileURLWithPath: trimmed)
            if u.lastPathComponent.uppercased() == "VIDEO_TS" || u.lastPathComponent.uppercased() == "BDMV" {
                candidateRoots.append(u.deletingLastPathComponent())
            } else {
                candidateRoots.append(u)
            }
        }

        let volumesRoot = URL(fileURLWithPath: "/Volumes")
        if let mounts = try? fm.contentsOfDirectory(at: volumesRoot, includingPropertiesForKeys: [.isDirectoryKey, .volumeIsInternalKey, .volumeIsRootFileSystemKey], options: [.skipsHiddenFiles]) {
            for m in mounts {
                let name = m.lastPathComponent
                if ignoredSystemVolumes.contains(name) { continue }
                if let vals = try? m.resourceValues(forKeys: [.volumeIsRootFileSystemKey]), vals.volumeIsRootFileSystem == true {
                    continue
                }
                if !candidateRoots.contains(m) {
                    candidateRoots.append(m)
                }
            }
        }

        // First pass: look for VIDEO_TS or BDMV structure
        for root in candidateRoots {
            let videoTS = root.appendingPathComponent("VIDEO_TS")
            if fm.fileExists(atPath: videoTS.path) {
                return scanVideoTSDirectory(videoTSDir: videoTS, volumeRoot: root)
            }
            let bdmvStream = root.appendingPathComponent("BDMV/STREAM")
            if fm.fileExists(atPath: bdmvStream.path) {
                return scanBDMVStreamDirectory(streamDir: bdmvStream, volumeRoot: root)
            }
            // Also check if root itself contains VTS_*.VOB or *.m2ts files directly
            if let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                if children.contains(where: { $0.pathExtension.uppercased() == "VOB" }) {
                    return scanVideoTSDirectory(videoTSDir: root, volumeRoot: root)
                }
                if children.contains(where: { $0.pathExtension.lowercased() == "m2ts" }) {
                    return scanBDMVStreamDirectory(streamDir: root, volumeRoot: root)
                }
            }
        }

        // Second pass: if an explicit non-system volume or override folder was provided, scan it as a Data/Video disc
        for root in candidateRoots {
            let isExplicitOverride = (!trimmed.isEmpty && root.path == URL(fileURLWithPath: trimmed).path)
            let isRemovableOrExternal: Bool = {
                guard let vals = try? root.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey]) else {
                    return false
                }
                return (vals.volumeIsRemovable == true) || (vals.volumeIsEjectable == true) || (vals.volumeIsInternal == false)
            }()
            guard isExplicitOverride || isRemovableOrExternal else { continue }
            return scanGenericOpticalVolume(volumeRoot: root)
        }

        return nil
    }

    // MARK: - DVD-Video Title Sets (VTS_xx_0.IFO, VTS_xx_1…9.VOB)

    static func scanVideoTSDirectory(videoTSDir: URL, volumeRoot: URL) -> ScannedOpticalVideoDisc {
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(at: videoTSDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []

        var totalBytes: Int64 = 0
        var vtsGroups: [Int: [URL]] = [:]
        var ifoByVTS: [Int: URL] = [:]

        let vobPattern = try? NSRegularExpression(pattern: #"^VTS_(\d{2})_([1-9])\.VOB$"#, options: [.caseInsensitive])
        let ifoPattern = try? NSRegularExpression(pattern: #"^VTS_(\d{2})_0\.IFO$"#, options: [.caseInsensitive])

        for file in children {
            let sz = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            totalBytes += sz
            let name = file.lastPathComponent
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            if let m = vobPattern?.firstMatch(in: name, options: [], range: range),
               let vtsRange = Range(m.range(at: 1), in: name),
               let vtsNum = Int(name[vtsRange]) {
                vtsGroups[vtsNum, default: []].append(file)
            } else if let m = ifoPattern?.firstMatch(in: name, options: [], range: range),
                      let vtsRange = Range(m.range(at: 1), in: name),
                      let vtsNum = Int(name[vtsRange]) {
                ifoByVTS[vtsNum] = file
            }
        }

        var titles: [KroutonVideoExtractTitleItem] = []
        var segmentMap: [String: [URL]] = [:]

        for vtsNum in vtsGroups.keys.sorted() {
            let segments = (vtsGroups[vtsNum] ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
            let vtsBytes = segments.reduce(Int64(0)) { acc, u in
                acc + Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            // Parse IFO PGC BCD duration if present, otherwise estimate from MPEG-2 ~6.0 Mbps (750,000 B/s) with floor
            let seconds: Int = {
                if let ifoURL = ifoByVTS[vtsNum], let parsed = parseIFOPGCDurationSeconds(ifoURL: ifoURL), parsed > 0 {
                    return parsed
                }
                return max(120, Int(vtsBytes / 750_000))
            }()
            let tid = String(format: "TITLE_%02d", vtsNum)
            let durString = formatSecondsToHHMMSS(seconds)
            let sizeStr = ByteCountFormatter.string(fromByteCount: vtsBytes, countStyle: .file)
            let item = KroutonVideoExtractTitleItem(
                id: tid,
                name: String(format: "Title %02d (VTS_%02d)", vtsNum, vtsNum),
                streamInfo: String(format: "MPEG-2 Program Stream • %d VOB segment%@", segments.count, segments.count == 1 ? "" : "s"),
                sizeLabel: sizeStr,
                duration: durString,
                seconds: seconds
            )
            titles.append(item)
            segmentMap[tid] = segments
        }

        let volName = volumeRoot.lastPathComponent.uppercased() == "VIDEO_TS"
            ? volumeRoot.deletingLastPathComponent().lastPathComponent
            : volumeRoot.lastPathComponent

        return ScannedOpticalVideoDisc(
            volumeTitle: volName,
            mountPath: volumeRoot.path,
            discKind: "DVD-Video (VIDEO_TS)",
            totalBytes: totalBytes,
            totalSectorsLBA: (totalBytes + 2047) / 2048,
            titles: titles,
            titleSegmentURLs: segmentMap
        )
    }

    /// Reads the BCD-encoded playback time (`HH:MM:SS:FF`) from a DVD-Video `VTS_XX_0.IFO` PGC header when present.
    static func parseIFOPGCDurationSeconds(ifoURL: URL) -> Int? {
        guard let data = try? Data(contentsOf: ifoURL), data.count >= 12,
              String(decoding: data.prefix(12), as: UTF8.self) == "DVDVIDEO-VTS" else {
            return nil
        }
        // Check if VTS_PGCI sector pointer at 0xCC points inside the file
        if data.count >= 0xD0 {
            let pgciSector = (Int(data[0xCC]) << 24) | (Int(data[0xCD]) << 16) | (Int(data[0xCE]) << 8) | Int(data[0xCF])
            let pgcTimeOffset = pgciSector * 2048 + 16 + 4 // first PGC header +4 is 4-byte BCD playback time
            if pgciSector > 0, pgcTimeOffset + 4 <= data.count {
                let hh = bcdToInt(data[pgcTimeOffset])
                let mm = bcdToInt(data[pgcTimeOffset + 1])
                let ss = bcdToInt(data[pgcTimeOffset + 2])
                if hh < 24 && mm < 60 && ss < 60 && (hh + mm + ss) > 0 {
                    return hh * 3600 + mm * 60 + ss
                }
            }
        }
        return nil
    }

    private static func bcdToInt(_ byte: UInt8) -> Int {
        Int((byte >> 4) & 0x0F) * 10 + Int(byte & 0x0F)
    }

    // MARK: - Blu-ray Streams (BDMV/STREAM/*.m2ts)

    static func scanBDMVStreamDirectory(streamDir: URL, volumeRoot: URL) -> ScannedOpticalVideoDisc {
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(at: streamDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        let m2tsFiles = children
            .filter { ["m2ts", "mts", "ts"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var totalBytes: Int64 = 0
        var titles: [KroutonVideoExtractTitleItem] = []
        var segmentMap: [String: [URL]] = [:]

        for (idx, file) in m2tsFiles.enumerated() {
            let sz = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            totalBytes += sz
            let num = idx + 1
            let tid = String(format: "TITLE_%02d", num)
            let seconds = max(120, Int(sz / 3_000_000)) // ~24 Mbps Blu-ray transport stream estimate
            let sizeStr = ByteCountFormatter.string(fromByteCount: sz, countStyle: .file)
            titles.append(KroutonVideoExtractTitleItem(
                id: tid,
                name: "Stream \(file.lastPathComponent)",
                streamInfo: "BDMV M2TS Transport Stream",
                sizeLabel: sizeStr,
                duration: formatSecondsToHHMMSS(seconds),
                seconds: seconds
            ))
            segmentMap[tid] = [file]
        }

        return ScannedOpticalVideoDisc(
            volumeTitle: volumeRoot.lastPathComponent,
            mountPath: volumeRoot.path,
            discKind: "Blu-ray (BDMV)",
            totalBytes: totalBytes,
            totalSectorsLBA: (totalBytes + 2047) / 2048,
            titles: titles,
            titleSegmentURLs: segmentMap
        )
    }

    // MARK: - Other Volumes and Folders

    static func scanGenericOpticalVolume(volumeRoot: URL) -> ScannedOpticalVideoDisc {
        let fm = FileManager.default
        let videoExts: Set<String> = ["mp4", "mov", "m4v", "mkv", "mpg", "mpeg", "vob", "m2ts", "ts", "avi"]
        var totalBytes: Int64 = 0
        var titles: [KroutonVideoExtractTitleItem] = []
        var segmentMap: [String: [URL]] = [:]

        if let enumerator = fm.enumerator(at: volumeRoot, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) {
            var videoIdx = 1
            for case let fileURL as URL in enumerator {
                guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      vals.isRegularFile == true else { continue }
                let sz = Int64(vals.fileSize ?? 0)
                totalBytes += sz
                if videoExts.contains(fileURL.pathExtension.lowercased()) {
                    let tid = String(format: "TITLE_%02d", videoIdx)
                    let secs = max(120, Int(sz / 1_000_000))
                    let sizeStr = ByteCountFormatter.string(fromByteCount: sz, countStyle: .file)
                    titles.append(KroutonVideoExtractTitleItem(
                        id: tid,
                        name: fileURL.lastPathComponent,
                        streamInfo: "\(fileURL.pathExtension.uppercased()) Video Stream",
                        sizeLabel: sizeStr,
                        duration: formatSecondsToHHMMSS(secs),
                        seconds: secs
                    ))
                    segmentMap[tid] = [fileURL]
                    videoIdx += 1
                }
            }
        }

        return ScannedOpticalVideoDisc(
            volumeTitle: volumeRoot.lastPathComponent,
            mountPath: volumeRoot.path,
            discKind: "Optical Volume",
            totalBytes: totalBytes,
            totalSectorsLBA: (totalBytes + 2047) / 2048,
            titles: titles,
            titleSegmentURLs: segmentMap
        )
    }

    static func formatSecondsToHHMMSS(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let hh = clamped / 3600
        let mm = (clamped % 3600) / 60
        let ss = clamped % 60
        return String(format: "%02d:%02d:%02d", hh, mm, ss)
    }

    // MARK: - Joining Segments and Making Images

    /// Concatenates one or more VOB/M2TS segments for a title into a single clean stream file in `outputDirectory`.
    public static func extractTitleSegments(
        titleID: String,
        segments: [URL],
        volumeTitle: String,
        outputDirectory: URL,
        shouldCancel: () -> Bool,
        onProgress: (Double) -> Void
    ) throws -> (outputURL: URL, bytesWritten: Int64) {
        let fm = FileManager.default
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let ext = segments.first?.pathExtension.lowercased() == "m2ts" ? "m2ts" : "mpg"
        let safeVol = volumeTitle.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        let outURL = outputDirectory.appendingPathComponent("\(safeVol)_\(titleID).\(ext)")
        if fm.fileExists(atPath: outURL.path) {
            try? fm.removeItem(at: outURL)
        }
        fm.createFile(atPath: outURL.path, contents: nil)
        let outHandle = try FileHandle(forWritingTo: outURL)
        defer { try? outHandle.close() }

        let totalBytes = max(1, segments.reduce(Int64(0)) { acc, u in
            acc + Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        })
        var written: Int64 = 0
        let chunkSize = 1024 * 1024 // 1 MB buffer

        for seg in segments {
            let inHandle = try FileHandle(forReadingFrom: seg)
            defer { try? inHandle.close() }
            while true {
                if shouldCancel() {
                    throw NSError(domain: "OpticalDiscVolumeScanner", code: -999, userInfo: [NSLocalizedDescriptionKey: "Cancelled by user"])
                }
                guard let chunk = try inHandle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
                try outHandle.write(contentsOf: chunk)
                written += Int64(chunk.count)
                onProgress(min(1.0, Double(written) / Double(totalBytes)))
            }
        }
        return (outURL, written)
    }

    /// ffmpeg, if installed (Homebrew puts it in /opt/homebrew/bin or /usr/local/bin).
    public static func locateFFmpeg() -> URL? {
        DVDVideoIFORelinker.locateFFmpegExecutable()
    }

    /// Joins a title's VOB (or M2TS) segments into one Matroska file without re-encoding: the
    /// main video, every audio track and every subtitle track, copied as they are. Discs with copy
    /// protection give unplayable output; Krouton doesn't remove it.
    public static func remuxTitleToMKV(segments: [URL], outputURL: URL, ffmpegURL: URL) throws -> Int64 {
        let fm = FileManager.default
        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: outputURL.path) { try fm.removeItem(at: outputURL) }
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y", "-hide_banner", "-loglevel", "error", "-nostdin",
            "-fflags", "+genpts",
            "-i", "concat:" + segments.map(\.path).joined(separator: "|"),
            "-map", "0:v:0", "-map", "0:a?", "-map", "0:s?",
            "-c", "copy",
            outputURL.path,
        ]
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let message = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, fm.fileExists(atPath: outputURL.path) else {
            let text = String(decoding: message, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "OpticalDiscVolumeScanner", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: text.isEmpty ? "ffmpeg couldn't remux the title (status \(process.terminationStatus))." : String(text.suffix(300)),
            ])
        }
        return Int64((try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }

    /// Creates a real hybrid UDF/ISO-9660 `.iso` image from a mounted optical volume or directory using `/usr/bin/hdiutil makehybrid`.
    public static func buildOpticalISOImage(
        sourceDirectory: URL,
        outputISOURL: URL,
        volumeName: String
    ) throws -> Int64 {
        let fm = FileManager.default
        try fm.createDirectory(at: outputISOURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: outputISOURL.path) {
            try? fm.removeItem(at: outputISOURL)
        }

        let cleanVol = volumeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? sourceDirectory.lastPathComponent
            : volumeName

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = [
            "makehybrid",
            "-iso",
            "-joliet",
            "-udf",
            "-default-volume-name", cleanVol,
            "-o", outputISOURL.path,
            sourceDirectory.path
        ]
        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice // never read; a pipe here can fill and stall hdiutil
        proc.standardError = errPipe
        try proc.run()
        proc.waitUntilExit()

        // hdiutil makehybrid sometimes appends .iso if not already recognized; reconcile if needed
        let appendedISO = URL(fileURLWithPath: outputISOURL.path + ".iso")
        if !fm.fileExists(atPath: outputISOURL.path), fm.fileExists(atPath: appendedISO.path) {
            try? fm.moveItem(at: appendedISO, to: outputISOURL)
        }

        guard proc.terminationStatus == 0, fm.fileExists(atPath: outputISOURL.path) else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "OpticalDiscVolumeScanner", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: msg.isEmpty ? "hdiutil makehybrid failed with status \(proc.terminationStatus)" : msg
            ])
        }

        let finalSize = Int64((try? outputISOURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        return finalSize
    }
}
