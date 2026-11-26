import Foundation

// MARK: - UDF Descriptors

/// Volume-wide values every descriptor shares.
struct KroutonUDFVolume {
    let label: String
    let created: KroutonUDFTime
    let setID: String
    /// UDF 2.50 (BCD); descriptor tags are version 3 (ECMA-167 3rd edition).
    let revision: UInt16 = 0x0250
    let tagVersion: UInt16 = 3
}

/// A calendar time in UTC, from Unix seconds (Howard Hinnant's civil-from-days).
struct KroutonUDFTime: Equatable {
    let year: Int64, month: UInt8, day: UInt8, hour: UInt8, minute: UInt8, second: UInt8

    init(unix secs: UInt64) {
        let days = Int64(secs / 86_400)
        let rem = secs % 86_400
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        month = UInt8(m)
        day = UInt8(d)
        hour = UInt8(rem / 3600)
        minute = UInt8(rem % 3600 / 60)
        second = UInt8(rem % 60)
    }

    /// ECMA-167 timestamp: type 1 at offset 0.
    var bytes: [UInt8] {
        let y = UInt16(bitPattern: Int16(clamping: year))
        return [0x00, 0x10, UInt8(y & 0xFF), UInt8(y >> 8), month, day, hour, minute, second, 0, 0, 0]
    }
}

/// `long_ad`: an extent anywhere in the logical volume, with the target's unique ID.
struct KroutonUDFLongAD: Equatable {
    var length: UInt32
    var block: UInt32
    var partition: UInt16
    var unique: UInt32

    func put(into d: inout [UInt8], at: Int) {
        KroutonUDF.put32(&d, at, length)
        KroutonUDF.put32(&d, at + 4, block)
        KroutonUDF.put16(&d, at + 8, partition)
        KroutonUDF.put32(&d, at + 12, unique)
    }
}

enum KroutonUDF {
    static let maxExtent: UInt64 = 0x3FFF_F800
    static let fidDirectory: UInt8 = 0x02
    static let fidParent: UInt8 = 0x08

    enum FileType: UInt8 {
        case directory = 4, file = 5, metadata = 250, metadataMirror = 251
    }

    enum Allocation {
        case short([(length: UInt32, block: UInt32)])
        case long([KroutonUDFLongAD])
    }

    struct Entry {
        var fileType: FileType
        var unique: UInt64
        var length: UInt64
        var links: UInt16
        var modified: KroutonUDFTime
        var allocation: Allocation
    }

    struct MetadataMap {
        var file: UInt32
        var mirror: UInt32
        var alignment: UInt16
    }

    // MARK: Fields

    static func put16(_ d: inout [UInt8], _ at: Int, _ v: UInt16) {
        d[at] = UInt8(v & 0xFF); d[at + 1] = UInt8(v >> 8)
    }

    static func put32(_ d: inout [UInt8], _ at: Int, _ v: UInt32) {
        for i in 0..<4 { d[at + i] = UInt8(v >> (8 * UInt32(i)) & 0xFF) }
    }

    static func put64(_ d: inout [UInt8], _ at: Int, _ v: UInt64) {
        for i in 0..<8 { d[at + i] = UInt8(v >> (8 * UInt64(i)) & 0xFF) }
    }

    static func copy(_ d: inout [UInt8], _ at: Int, _ bytes: [UInt8]) {
        d.replaceSubrange(at..<at + bytes.count, with: bytes)
    }

    static func extents(_ bytes: UInt64, block: UInt32) -> [(length: UInt32, block: UInt32)] {
        var out: [(length: UInt32, block: UInt32)] = []
        var left = bytes, at = UInt64(block)
        while left > 0 {
            let take = min(left, maxExtent)
            out.append((UInt32(take), UInt32(truncatingIfNeeded: at)))
            left -= take
            at += take / 2048
        }
        return out
    }

    // MARK: Tags and strings

    static func crc(_ data: ArraySlice<UInt8>) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 { crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1 }
        }
        return crc
    }

    static func tag(_ d: inout [UInt8], _ v: KroutonUDFVolume, id: UInt16, location: UInt32) {
        put16(&d, 0, id)
        put16(&d, 2, v.tagVersion)
        d[4] = 0
        d[5] = 0
        put16(&d, 6, 1)
        let body = d.count - 16
        put16(&d, 8, crc(d[16..<16 + body]))
        put16(&d, 10, UInt16(body))
        put32(&d, 12, location)
        var sum: UInt8 = 0
        for i in 0..<16 where i != 4 { sum = sum &+ d[i] }
        d[4] = sum
    }

    /// OSTA Compressed Unicode: 8 when every character fits Latin-1, else UTF-16 big-endian.
    static func cs0(_ text: String, max: Int = 255) -> [UInt8] {
        if text.isEmpty { return [] }
        if text.unicodeScalars.allSatisfy({ $0.value <= 0xFF }) {
            var out: [UInt8] = [8]
            for s in text.unicodeScalars {
                if out.count + 1 > max { break }
                out.append(UInt8(s.value))
            }
            return out
        }
        var out: [UInt8] = [16]
        for s in text.unicodeScalars {
            let units = Array(String(s).utf16)
            if out.count + 2 * units.count > max { break }
            for unit in units { out += [UInt8(unit >> 8), UInt8(unit & 0xFF)] }
        }
        return out
    }

    static func dstring(_ text: String, _ field: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: field)
        let bytes = cs0(text, max: field - 1)
        out.replaceSubrange(0..<bytes.count, with: bytes)
        out[field - 1] = UInt8(bytes.count)
        return out
    }

    static func charspec() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 64)
        out.replaceSubrange(1..<24, with: Array("OSTA Compressed Unicode".utf8))
        return out
    }

    static func regid(_ identifier: String, suffix: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 32)
        let text = Array(identifier.utf8.prefix(23))
        out.replaceSubrange(1..<1 + text.count, with: text)
        out.replaceSubrange(24..<32, with: suffix)
        return out
    }

    static func suffix(_ revision: UInt16) -> [UInt8] {
        [UInt8(revision & 0xFF), UInt8(revision >> 8), 0, 0, 0, 0, 0, 0]
    }

    static var implementation: [UInt8] { regid("*Krouton") }

    static func fidLength(_ nameBytes: Int) -> Int { (38 + nameBytes + 3) / 4 * 4 }

    // MARK: Volume structure

    static func recognition(_ id: String) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 2048)
        d.replaceSubrange(1..<6, with: Array(id.utf8))
        d[6] = 1
        return d
    }

    static func anchor(_ v: KroutonUDFVolume, location: UInt32, main: (UInt32, UInt32), reserve: (UInt32, UInt32)) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        put32(&d, 16, main.0); put32(&d, 20, main.1); put32(&d, 24, reserve.0); put32(&d, 28, reserve.1)
        tag(&d, v, id: 2, location: location)
        return d
    }

    static func primary(_ v: KroutonUDFVolume, vdsn: UInt32, location: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        put32(&d, 16, vdsn)
        copy(&d, 24, dstring(v.label, 32))
        put16(&d, 56, 1); put16(&d, 58, 1); put16(&d, 60, 2); put16(&d, 62, 2)
        put32(&d, 64, 1); put32(&d, 68, 1)
        copy(&d, 72, dstring(v.setID + v.label, 128))
        copy(&d, 200, charspec()); copy(&d, 264, charspec())
        copy(&d, 344, implementation)
        copy(&d, 376, v.created.bytes)
        copy(&d, 388, implementation)
        tag(&d, v, id: 1, location: location)
        return d
    }

    static func implementationUse(_ v: KroutonUDFVolume, vdsn: UInt32, location: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        put32(&d, 16, vdsn)
        copy(&d, 20, regid("*UDF LV Info", suffix: suffix(v.revision)))
        copy(&d, 52, charspec())
        copy(&d, 116, dstring(v.label, 128))
        copy(&d, 352, implementation)
        tag(&d, v, id: 4, location: location)
        return d
    }

    static func partition(_ v: KroutonUDFVolume, vdsn: UInt32, location: UInt32, start: UInt32, length: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        put32(&d, 16, vdsn)
        put16(&d, 20, 1); put16(&d, 22, 0)
        copy(&d, 24, regid("+NSR03"))
        put32(&d, 184, 1); put32(&d, 188, start); put32(&d, 192, length)
        copy(&d, 196, implementation)
        tag(&d, v, id: 5, location: location)
        return d
    }

    static func logicalVolume(_ v: KroutonUDFVolume, vdsn: UInt32, location: UInt32, fileSet: KroutonUDFLongAD,
                              integrity: (UInt32, UInt32), metadata m: MetadataMap) -> [UInt8] {
        var map = [UInt8](repeating: 0, count: 64)
        map[0] = 2; map[1] = 64
        copy(&map, 4, regid("*UDF Metadata Partition", suffix: suffix(v.revision)))
        put16(&map, 36, 1); put16(&map, 38, 0)
        put32(&map, 40, m.file); put32(&map, 44, m.mirror); put32(&map, 48, .max)
        put32(&map, 52, UInt32(m.alignment)); put16(&map, 56, m.alignment)
        map[58] = 1
        let maps: [UInt8] = [1, 6, 1, 0, 0, 0] + map
        var d = [UInt8](repeating: 0, count: 440 + maps.count)
        put32(&d, 16, vdsn)
        copy(&d, 20, charspec())
        copy(&d, 84, dstring(v.label, 128))
        put32(&d, 212, 2048)
        copy(&d, 216, regid("*OSTA UDF Compliant", suffix: suffix(v.revision)))
        fileSet.put(into: &d, at: 248)
        put32(&d, 264, UInt32(maps.count)); put32(&d, 268, 2)
        copy(&d, 272, implementation)
        put32(&d, 432, integrity.0); put32(&d, 436, integrity.1)
        copy(&d, 440, maps)
        tag(&d, v, id: 6, location: location)
        return d
    }

    static func unallocatedSpace(_ v: KroutonUDFVolume, vdsn: UInt32, location: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 24)
        put32(&d, 16, vdsn)
        tag(&d, v, id: 7, location: location)
        return d
    }

    static func terminating(_ v: KroutonUDFVolume, location: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        tag(&d, v, id: 8, location: location)
        return d
    }

    static func integrity(_ v: KroutonUDFVolume, location: UInt32, partitionSizes: [UInt32], nextUnique: UInt64,
                          files: UInt32, folders: UInt32) -> [UInt8] {
        let n = partitionSizes.count
        var d = [UInt8](repeating: 0, count: 80 + 8 * n + 46)
        copy(&d, 16, v.created.bytes)
        put32(&d, 28, 1)
        put64(&d, 40, nextUnique)
        put32(&d, 72, UInt32(n)); put32(&d, 76, 46)
        for (i, size) in partitionSizes.enumerated() { put32(&d, 80 + 4 * n + 4 * i, size) }
        let iu = 80 + 8 * n
        copy(&d, iu, implementation)
        put32(&d, iu + 32, files); put32(&d, iu + 36, folders)
        put16(&d, iu + 40, v.revision); put16(&d, iu + 42, v.revision); put16(&d, iu + 44, v.revision)
        tag(&d, v, id: 9, location: location)
        return d
    }

    // MARK: File set and files

    static func fileSet(_ v: KroutonUDFVolume, location: UInt32, root: KroutonUDFLongAD) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        copy(&d, 16, v.created.bytes)
        put16(&d, 28, 3); put16(&d, 30, 3); put32(&d, 32, 1); put32(&d, 36, 1)
        copy(&d, 48, charspec())
        copy(&d, 112, dstring(v.label, 128))
        copy(&d, 240, charspec())
        copy(&d, 304, dstring(v.label, 32))
        root.put(into: &d, at: 400)
        copy(&d, 416, regid("*OSTA UDF Compliant", suffix: suffix(v.revision)))
        tag(&d, v, id: 256, location: location)
        return d
    }

    /// An extended file entry (UDF 2.50 uses them throughout).
    static func fileEntry(_ v: KroutonUDFVolume, location: UInt32, entry e: Entry) throws -> [UInt8] {
        var ads: [UInt8] = []
        var kind: UInt16 = 0
        switch e.allocation {
        case .short(let list):
            for ad in list {
                var b = [UInt8](repeating: 0, count: 8)
                put32(&b, 0, ad.length); put32(&b, 4, ad.block)
                ads += b
            }
        case .long(let list):
            kind = 1
            for ad in list {
                var b = [UInt8](repeating: 0, count: 16)
                ad.put(into: &b, at: 0)
                ads += b
            }
        }
        guard 216 + ads.count <= 2048 else { throw KroutonUDFError.tooFragmented }
        var d = [UInt8](repeating: 0, count: 216 + ads.count)
        put16(&d, 20, 4); put16(&d, 24, 1)
        d[27] = e.fileType.rawValue
        put16(&d, 34, kind)
        put32(&d, 36, .max); put32(&d, 40, .max)
        put32(&d, 44, 0x1084 | (e.fileType == .directory ? 0x0421 : 0))
        put16(&d, 48, e.links)
        put64(&d, 56, e.length)
        put64(&d, 64, e.length)
        put64(&d, 72, (e.length + 2047) / 2048)
        for at in [80, 92, 104, 116] { copy(&d, at, e.modified.bytes) }
        put32(&d, 128, 1)
        copy(&d, 168, implementation)
        put64(&d, 200, e.unique)
        put32(&d, 212, UInt32(ads.count))
        copy(&d, 216, ads)
        tag(&d, v, id: 266, location: location)
        return d
    }

    static func fid(_ v: KroutonUDFVolume, location: UInt32, characteristics: UInt8, name: [UInt8], icb: KroutonUDFLongAD) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: fidLength(name.count))
        put16(&d, 16, 1)
        d[18] = characteristics
        d[19] = UInt8(name.count)
        icb.put(into: &d, at: 20)
        copy(&d, 38, name)
        tag(&d, v, id: 257, location: location)
        return d
    }
}
