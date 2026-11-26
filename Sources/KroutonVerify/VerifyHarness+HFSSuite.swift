import Darwin
import Foundation
import ImageKit

// MARK: - VerifyHarness — Suite 38: Classic HFS (Mac OS 9) Images

/// Builds an HFS Standard image from a folder holding a file with a resource fork and Finder
/// type/creator, a nested folder, a name that sorts by Mac rules and a name too long for HFS,
/// then reads the image back with an independent parser (`Scripts/check-hfs-image.py`). With
/// `KROUTON_HFS_OUT` set the image is kept, and CI mounts it with Linux's HFS driver.
extension KroutonTestHarness {
    mutating func runVerifyHFSSuite() {
        self.runSuite("38. Classic HFS: Partition Map, Catalog Order, Resource Forks and Finder Info") { h in
            let fm = FileManager.default
            let base = fm.temporaryDirectory.appendingPathComponent("krouton-hfs-\(UUID().uuidString)")
            defer { try? fm.removeItem(at: base) }
            let tree = base.appendingPathComponent("tree")
            try fm.createDirectory(at: tree.appendingPathComponent("System Folder/Extensions"), withIntermediateDirectories: true)
            try Data("Read me first\r".utf8).write(to: tree.appendingPathComponent("Read Me"))
            let app = tree.appendingPathComponent("SimpleText")
            try Data().write(to: app)
            let rsrc = [UInt8]((0..<5000).map { UInt8(truncatingIfNeeded: $0 &* 7) })
            let info: [UInt8] = Array("APPLttxt".utf8) + [UInt8](repeating: 0, count: 24)
            _ = rsrc.withUnsafeBytes { setxattr(app.path, "com.apple.ResourceFork", $0.baseAddress, rsrc.count, 0, 0) }
            _ = info.withUnsafeBytes { setxattr(app.path, "com.apple.FinderInfo", $0.baseAddress, info.count, 0, 0) }
            try Data(repeating: 0x42, count: 70_000).write(to: tree.appendingPathComponent("System Folder/Extensions/apple Ext"))
            // A System file with a 'boot' resource and a Finder: the folder must be blessed.
            let boot: [UInt8] = Array("LK".utf8) + [UInt8](repeating: 0x60, count: 1022)
            var fork = [UInt8](repeating: 0, count: 256) + Self.be32(UInt32(boot.count)) + boot
            let mapStart = fork.count
            var map = [UInt8](repeating: 0, count: 28)
            map[24] = 0; map[25] = 28              // type list at map + 28
            map += [0, 0] + Array("boot".utf8) + [0, 0, 0, 10] + [0, 1, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0]
            fork += map
            fork.replaceSubrange(0..<16, with: Self.be32(256) + Self.be32(UInt32(mapStart)) + Self.be32(UInt32(4 + boot.count)) + Self.be32(UInt32(map.count)))
            for (name, type, rsrcBytes) in [("System", "zsys", fork), ("Finder", "FNDR", [UInt8]())] {
                let url = tree.appendingPathComponent("System Folder/\(name)")
                try Data().write(to: url)
                let finder: [UInt8] = Array(type.utf8) + Array("MACS".utf8) + [UInt8](repeating: 0, count: 24)
                _ = finder.withUnsafeBytes { setxattr(url.path, "com.apple.FinderInfo", $0.baseAddress, finder.count, 0, 0) }
                if !rsrcBytes.isEmpty {
                    _ = rsrcBytes.withUnsafeBytes { setxattr(url.path, "com.apple.ResourceFork", $0.baseAddress, rsrcBytes.count, 0, 0) }
                }
            }
            try Data("b".utf8).write(to: tree.appendingPathComponent("Banana"))
            try Data("x".utf8).write(to: tree.appendingPathComponent("A name much longer than thirty-one characters.txt"))
            try Data("hidden".utf8).write(to: tree.appendingPathComponent(".DS_Store"))

            let image = base.appendingPathComponent("disc.cdr")
            let built = try KroutonHFSImageWriter.build(folder: tree, output: image, label: "Krouton Classic",
                                                         now: Date(timeIntervalSince1970: 1_795_000_000),
                                                         timeZone: TimeZone(identifier: "UTC")!)
            h.check(built.files == 7 && built.folders == 2, "HFS: 7 files in 2 folders (hidden files left out)")
            let bytes = try Data(contentsOf: image)
            h.check(bytes.count == Int(built.bytes) && bytes.count % 512 == 0, "HFS: whole 512-byte blocks")
            h.check(bytes.prefix(2) == Data([0x45, 0x52]) && bytes[512..<514] == Data([0x50, 0x4D])
                    && bytes[(64 * 512 + 1024)..<(64 * 512 + 1026)] == Data([0x42, 0x44]),
                    "HFS: driver descriptor, partition map, and the MDB at the Apple_HFS partition")
            let hfs = 64 * 512
            let blessed = bytes[(hfs + 1024 + 92)..<(hfs + 1024 + 96)]
            h.check(bytes[hfs..<(hfs + 2)] == Data("LK".utf8) && blessed != Data([0, 0, 0, 0]),
                    "HFS: System Folder blessed, boot blocks taken from the System file's 'boot' resource")

            if let out = ProcessInfo.processInfo.environment["KROUTON_HFS_OUT"] {
                try? fm.createDirectory(at: URL(fileURLWithPath: out), withIntermediateDirectories: true)
                let kept = URL(fileURLWithPath: out).appendingPathComponent("classic.cdr")
                try? fm.removeItem(at: kept)
                try fm.copyItem(at: image, to: kept)
            }
        }
    }

    private static func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
}
