import Foundation
import ImageKit
import VideoKit

// MARK: - VerifyHarness — Suite 36: AVCHD / Blu-ray on DVD

extension KroutonTestHarness {
    mutating func runVerifyAVCHDSuite() {
        self.runSuite("36. AVCHD on DVD: Stream Analysis, BDMV Files and the UDF 2.50 Image") { h in
            Self.verifyStreamAnalysis(&h)
            Self.verifyNavigationFiles(&h)
            Self.verifyUDFImageVector(&h)
            h.check(AVCHDOnDVDAuthoringEngine.encodeArguments(
                source: URL(fileURLWithPath: "/in.mov"), output: URL(fileURLWithPath: "/out.m2ts"),
                format: .pal, videoKbps: 15_000).contains { $0.contains("fake-interlaced=1") },
                "25 fps material must be encoded as fake-interlaced 1080i, the only 25 fps 1080 format Blu-ray allows")
            h.check(KroutonBDMVVideoFormat.nearest(framesPerSecond: 30) == .ntsc
                    && KroutonBDMVVideoFormat.nearest(framesPerSecond: 23.976) == .film
                    && KroutonBDMVVideoFormat.nearest(framesPerSecond: 60) == .hd60,
                    "Source frame rates must map to the nearest Blu-ray format")
            h.check((try? AVCHDOnDVDAuthoringEngine.fittingBitrate(seconds: 3600, capacityBytes: 4_700_000_000)) ?? 0 > 4_000
                    && (try? AVCHDOnDVDAuthoringEngine.fittingBitrate(seconds: 600, capacityBytes: 4_700_000_000)) == 18_000,
                    "An hour fits a DVD below 18 Mbit/s; ten minutes gets the full 18 Mbit/s")
            h.check((try? AVCHDOnDVDAuthoringEngine.fittingBitrate(seconds: 4 * 3600, capacityBytes: 4_700_000_000)) == nil,
                    "Four hours must be refused rather than encoded unwatchably")
            Self.authorRealSample(&h)
        }
    }

    /// With `KROUTON_AVCHD_INPUTS` (comma-separated video files) and `KROUTON_AVCHD_OUT` set, as
    /// in CI, runs the real pipeline: ffmpeg, the BDMV files and the UDF image, into
    /// `$KROUTON_AVCHD_OUT/disc` and `disc.iso`, for `Scripts/check-avchd-disc.py` to read back
    /// with libbluray and hdiutil.
    private static func authorRealSample(_ h: inout KroutonTestHarness) {
        let env = ProcessInfo.processInfo.environment
        guard let inputs = env["KROUTON_AVCHD_INPUTS"], let out = env["KROUTON_AVCHD_OUT"] else { return }
        let sources = inputs.split(separator: ",").map { URL(fileURLWithPath: String($0)) }
        let folder = URL(fileURLWithPath: out).appendingPathComponent("disc")
        try? FileManager.default.removeItem(at: folder)
        do {
            let disc = try AVCHDOnDVDAuthoringEngine.author(sources: sources, into: folder, capacityBytes: 4_700_000_000)
            h.check(disc.clips.count == sources.count && disc.clips.allSatisfy { $0.analysis.entryPoints.count > 1 },
                    "Every sample must become a clip with key frames")
            for clip in disc.clips {
                print("    clip \(clip.name): \(String(format: "%.2f", clip.analysis.duration)) s, \(clip.analysis.entryPoints.count) key frames, "
                      + "format \(clip.format.formatCode)/\(clip.format.rateCode), audio type \(clip.analysis.audioPresentation)")
            }
            let image = URL(fileURLWithPath: out).appendingPathComponent("disc.iso")
            let built = try KroutonUDFImageWriter.build(folder: folder, output: image, label: "AVCHD sample")
            h.check(built.sectors > 300, "The sample disc image must be written")
        } catch {
            h.check(false, "The AVCHD sample must author and image: \(error.localizedDescription)")
        }
    }

    // MARK: - A synthetic stream

    /// One 192-byte source packet: a zero arrival-time header, then a 188-byte TS packet.
    private static func sourcePacket(pid: UInt16, start: Bool, randomAccess: Bool? = nil, payload: [UInt8]) -> [UInt8] {
        var ts: [UInt8] = [0x47, (start ? 0x40 : 0) | UInt8(pid >> 8), UInt8(pid & 0xFF)]
        if let randomAccess {
            ts.append(0x30)
            ts += [1, randomAccess ? 0x40 : 0x00]
        } else {
            ts.append(0x10)
        }
        ts += payload
        ts += [UInt8](repeating: 0xFF, count: max(0, 188 - ts.count))
        return [0, 0, 0, 0] + ts.prefix(188)
    }

    private static func pts(_ value: UInt64) -> [UInt8] {
        [0x21 | UInt8((value >> 29) & 0x0E), UInt8((value >> 22) & 0xFF), UInt8((value >> 14) & 0xFE) | 1,
         UInt8((value >> 7) & 0xFF), UInt8((value << 1) & 0xFE) | 1]
    }

    static func syntheticM2TS(frames: Int, start: UInt64, keyEvery: Int) -> [UInt8] {
        let pat: [UInt8] = [0, 0x00, 0xB0, 0x0D, 0x00, 0x01, 0xC1, 0x00, 0x00, 0x00, 0x01, 0xE1, 0x00, 0, 0, 0, 0]
        let pmt: [UInt8] = [0, 0x02, 0xB0, 23, 0x00, 0x01, 0xC1, 0x00, 0x00, 0xF0, 0x11, 0xF0, 0x00,
                            0x1B, 0xF0, 0x11, 0xF0, 0x00, 0x81, 0xF1, 0x00, 0xF0, 0x00, 0, 0, 0, 0]
        var out = sourcePacket(pid: 0, start: true, payload: pat) + sourcePacket(pid: 0x100, start: true, payload: pmt)
        for frame in 0..<frames {
            let key = frame % keyEvery == 0
            let time = start + UInt64(frame) * 3_754
            let nal: [UInt8] = key ? [0, 0, 0, 1, 0x09, 0xF0, 0, 0, 1, 0x67, 0x64] : [0, 0, 0, 1, 0x09, 0xF0, 0, 0, 1, 0x41, 0x9A]
            out += sourcePacket(pid: 0x1011, start: true, randomAccess: key,
                                payload: [0, 0, 1, 0xE0, 0, 0, 0x80, 0x80, 5] + pts(time) + nal)
            if frame % 8 == 0 {
                out += sourcePacket(pid: 0x1100, start: true,
                                    payload: [0, 0, 1, 0xBD, 0, 0, 0x80, 0x80, 5] + pts(time) + [0x0B, 0x77, 0, 0, 0x14, 0x40, 0xE0])
            }
        }
        return out
    }

    // MARK: - Checks

    private static func verifyStreamAnalysis(_ h: inout KroutonTestHarness) {
        let bytes = syntheticM2TS(frames: 48, start: 900_000, keyEvery: 24)
        var analyzer = KroutonM2TSAnalyzer()
        let analysis = (try? analyzer.feed(bytes)).flatMap { try? analyzer.finish() }
        h.check(analysis?.videoPID == 0x1011 && analysis?.audioPID == 0x1100 && analysis?.pcrPID == 0x1011,
                "The analyzer must find the video, audio and PCR PIDs in the PMT")
        h.check(analysis?.entryPoints.count == 2 && analysis?.entryPoints.first?.pts == 900_000,
                "Only key frames become entry points")
        h.check(analysis?.sourcePackets == UInt32(bytes.count / 192), "Every 192-byte source packet is counted")
        h.check(analysis?.firstPTS == 900_000 && analysis?.endPTS == 900_000 + 48 * 3_754,
                "Presentation runs from the first frame to the end of the last one")
        h.check(analysis?.audioPresentation == 6, "An AC-3 stream in 3/2 mode is multi-channel")
        var broken = KroutonM2TSAnalyzer()
        h.check((try? broken.feed([UInt8](repeating: 0, count: 384))) == nil, "A file without TS sync bytes is refused")
    }

    private static func be32(_ b: [UInt8], _ at: Int) -> UInt32 {
        UInt32(b[at]) << 24 | UInt32(b[at + 1]) << 16 | UInt32(b[at + 2]) << 8 | UInt32(b[at + 3])
    }

    private static func verifyNavigationFiles(_ h: inout KroutonTestHarness) {
        var analysis = KroutonM2TSAnalysis()
        analysis.videoPID = 0x1011
        analysis.videoCoding = 0x1B
        analysis.pcrPID = 0x1011
        analysis.audioPID = 0x1100
        analysis.audioCoding = 0x81
        analysis.firstPTS = 54_000
        analysis.sourcePackets = 9_000_000
        // A key frame every second for 25 minutes, ~2 MB apart: PTS bit 19 and SPN bit 17 roll
        // over many times, so the EP map needs many coarse entries.
        analysis.entryPoints = (0..<1500).map { .init(pts: 54_000 + UInt64($0) * 90_000, sourcePacket: UInt32($0) * 6_000) }
        analysis.endPTS = 54_000 + 1500 * 90_000
        let clip = KroutonBDMVClip(name: "00000", analysis: analysis, format: .film, recordingRate: 2_500_000)

        let index = [UInt8](KroutonBDMVWriter.index(format: .film))
        h.check(String(decoding: index[0..<8], as: UTF8.self) == "INDX0200" && be32(index, 8) == 78 && index[45] == 0x61,
                "index.bdmv: INDX0200, indexes at 78, 1080p at 23.976")
        let mobj = [UInt8](KroutonBDMVWriter.movieObject())
        h.check(String(decoding: mobj[0..<8], as: UTF8.self) == "MOBJ0200" && be32(mobj, 54) == 0x2280_0000,
                "MovieObject.bdmv: PlayPL with an immediate playlist number")

        let mpls = [UInt8](KroutonBDMVWriter.playlist(clips: [clip, clip]))
        let list = Int(be32(mpls, 8)), marks = Int(be32(mpls, 12))
        let item = list + 10
        h.check(list == 58 && mpls[list + 7] == 2 && String(decoding: mpls[item + 2..<item + 11], as: UTF8.self) == "00000M2TS"
                && be32(mpls, item + 14) == 27_000 && be32(mpls, item + 18) == UInt32(analysis.endPTS / 2),
                "00000.mpls: two play items with the clip's real in and out times (45 kHz)")
        let markCount = Int(mpls[marks + 4]) << 8 | Int(mpls[marks + 5])
        h.check(markCount == 2 * 5 && mpls.count == marks + 6 + 14 * markCount,
                "00000.mpls: a chapter at each clip and every five minutes within it")

        let clpi = [UInt8](KroutonBDMVWriter.clipInfo(clip))
        h.check(String(decoding: clpi[0..<8], as: UTF8.self) == "HDMV0200" && be32(clpi, 8) == 40 + 4 + 176
                && be32(clpi, 40 + 4 + 12) == 9_000_000,
                "00000.clpi: ClipInfo with the source-packet count, then the sequence info")
        h.check(entryPointsRoundTrip(clpi, analysis.entryPoints), "00000.clpi: every EP map entry must decode to its key frame (libbluray's arithmetic)")
    }

    /// Decodes the EP map the way libbluray's `clpi_parse.c` does and compares with `points`.
    private static func entryPointsRoundTrip(_ c: [UInt8], _ points: [KroutonM2TSAnalysis.EntryPoint]) -> Bool {
        let cpi = Int(be32(c, 16))
        let map = cpi + 6
        guard c[map + 1] == 1 else { return false }
        let packed = c[map + 4..<map + 10].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let coarseCount = Int(packed >> 18 & 0xFFFF), fineCount = Int(packed & 0x3_FFFF)
        let stream = map + Int(be32(c, map + 10))
        let fineStart = stream + Int(be32(c, stream))
        guard fineCount == points.count else { return false }
        var coarse: [(ref: Int, pts: UInt64, spn: UInt32)] = []
        for i in 0..<coarseCount {
            let word = be32(c, stream + 4 + 8 * i)
            coarse.append((Int(word >> 14), UInt64(word & 0x3FFF), be32(c, stream + 8 + 8 * i)))
        }
        for (j, point) in points.enumerated() {
            guard let k = coarse.lastIndex(where: { $0.ref <= j }) else { return false }
            let fine = be32(c, fineStart + 4 * j)
            let pts = (coarse[k].pts & ~1) << 19 + UInt64(fine >> 17 & 0x7FF) << 9
            let spn = (coarse[k].spn & ~0x1_FFFF) + (fine & 0x1_FFFF)
            if pts != point.pts & ~0x1FF || spn != point.sourcePacket { return false }
        }
        return true
    }

    /// The Swift UDF 2.50 writer must make exactly the image Krouton Server's Rust writer makes
    /// from the same folder (`Vectors/udf-bd-v1.sha256`), which CI mounts on three systems.
    private static func verifyUDFImageVector(_ h: inout KroutonTestHarness) {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("krouton-udf-vector-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: base) }
        let tree = base.appendingPathComponent("tree")
        let pattern = { (count: Int, seed: UInt8) in Data((0..<count).map { UInt8(truncatingIfNeeded: $0) &* 31 &+ seed }) }
        do {
            for dir in ["BDMV/PLAYLIST", "BDMV/CLIPINF", "BDMV/STREAM", "BDMV/BACKUP", "CERTIFICATE"] {
                try fm.createDirectory(at: tree.appendingPathComponent(dir), withIntermediateDirectories: true)
            }
            let files: [(String, Int, UInt8)] = [
                ("BDMV/index.bdmv", 120, 1), ("BDMV/MovieObject.bdmv", 200, 2), ("BDMV/PLAYLIST/00000.mpls", 300, 3),
                ("BDMV/CLIPINF/00000.clpi", 400, 4), ("BDMV/STREAM/00000.m2ts", 6144 * 50, 5),
            ]
            for (path, count, seed) in files {
                try pattern(count, seed).write(to: tree.appendingPathComponent(path))
            }
            let stamp: [FileAttributeKey: Any] = [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)]
            let paths = files.map(\.0) + ["BDMV/PLAYLIST", "BDMV/CLIPINF", "BDMV/STREAM", "BDMV/BACKUP", "CERTIFICATE", "BDMV", ""]
            for path in paths {
                try fm.setAttributes(stamp, ofItemAtPath: tree.appendingPathComponent(path).path)
            }
            let image = base.appendingPathComponent("disc.iso")
            let built = try KroutonUDFImageWriter.build(folder: tree, output: image, label: "Krouton vector", now: 1_795_000_000)
            let (hex, bytes) = try KroutonHybridImageBuilder.sha256(ofFileAt: image)
            let vector = (try? String(contentsOf: Self.repositoryRoot.appendingPathComponent("Vectors/udf-bd-v1.sha256"), encoding: .utf8)) ?? ""
            h.check(vector == "\(hex)  udf-bd-v1: \(bytes) bytes\n",
                    "The Swift UDF 2.50 writer must match Vectors/udf-bd-v1.sha256 (got \(hex), \(bytes) bytes)")
            h.check(built.files == 5 && built.folders == 6, "The image must hold 5 files in 6 folders")
        } catch {
            h.check(false, "The UDF vector image must build: \(error)")
        }
        verifyDVDVideoVector(&h)
    }

    /// The DVD-Video profile against `Vectors/udf-dvd-v1.sha256`, from the same folder as the
    /// server's `dvd_tree`: ISO 9660 level 1 + UDF 1.02, VIDEO_TS in player order.
    private static func verifyDVDVideoVector(_ h: inout KroutonTestHarness) {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("krouton-dvd-vector-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: base) }
        let tree = base.appendingPathComponent("tree")
        let pattern = { (count: Int, seed: UInt8) in Data((0..<count).map { UInt8(truncatingIfNeeded: $0) &* 31 &+ seed }) }
        do {
            for dir in ["VIDEO_TS", "AUDIO_TS"] {
                try fm.createDirectory(at: tree.appendingPathComponent(dir), withIntermediateDirectories: true)
            }
            let files: [(String, Int)] = [
                ("VIDEO_TS.IFO", 12_288), ("VIDEO_TS.VOB", 6144), ("VIDEO_TS.BUP", 12_288), ("VTS_01_0.IFO", 20_480),
                ("VTS_01_0.VOB", 2048), ("VTS_01_1.VOB", 300_000), ("VTS_01_2.VOB", 50_000), ("VTS_01_0.BUP", 20_480),
            ]
            for (name, count) in files {
                try pattern(count, UInt8(name.count)).write(to: tree.appendingPathComponent("VIDEO_TS/\(name)"))
            }
            let stamp: [FileAttributeKey: Any] = [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)]
            for path in files.map({ "VIDEO_TS/\($0.0)" }) + ["VIDEO_TS", "AUDIO_TS", ""] {
                try fm.setAttributes(stamp, ofItemAtPath: tree.appendingPathComponent(path).path)
            }
            let image = base.appendingPathComponent("disc.iso")
            _ = try KroutonUDFImageWriter.build(folder: tree, output: image, label: "Krouton vector", profile: .dvdVideo, now: 1_795_000_000)
            let (hex, bytes) = try KroutonHybridImageBuilder.sha256(ofFileAt: image)
            let vector = (try? String(contentsOf: Self.repositoryRoot.appendingPathComponent("Vectors/udf-dvd-v1.sha256"), encoding: .utf8)) ?? ""
            h.check(vector == "\(hex)  udf-dvd-v1: \(bytes) bytes\n",
                    "The Swift DVD-Video writer must match Vectors/udf-dvd-v1.sha256 (got \(hex), \(bytes) bytes)")
            if let out = ProcessInfo.processInfo.environment["KROUTON_AVCHD_OUT"] {
                try? fm.createDirectory(at: URL(fileURLWithPath: out), withIntermediateDirectories: true)
                try? fm.removeItem(at: URL(fileURLWithPath: out).appendingPathComponent("dvd-vector.iso"))
                try? fm.copyItem(at: image, to: URL(fileURLWithPath: out).appendingPathComponent("dvd-vector.iso"))
            }
        } catch {
            h.check(false, "The DVD-Video vector image must build: \(error)")
        }
    }
}
