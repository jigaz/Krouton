import Foundation
import OpticalCore

// MARK: - Which Krouton Server Drive Can Burn a Job

/// The server says what each drive writes and holds (`SpoolDriveInfo.writes`, `disc`,
/// `freeBytes`), and the client checks that a job fits before it uploads anything, so a Blu-ray
/// image never travels to a CD/DVD burner. The server checks again before it burns (krouton-server
/// `DriveProbe::refusal`); the two follow the same rule.
extension SpoolNodeCapabilities {
    /// CD, DVD and Blu-ray.
    public static let writesAny: SpoolNodeCapabilities = [.writesCD, .writesDVD, .writesBD]

    /// The largest image each family holds: a 99-minute CD-R, a dual-layer DVD±R, a quad-layer
    /// BD-R XL. The same values as krsp `identity::caps`.
    public static let cdMaxBytes: Int64 = 912_384_000
    public static let dvdMaxBytes: Int64 = 8_547_991_552
    public static let bdMaxBytes: Int64 = 128_001_769_472

    /// The families whose largest disc holds an image of `bytes`.
    public static func holding(bytes: Int64) -> SpoolNodeCapabilities {
        var families: SpoolNodeCapabilities = []
        if bytes <= cdMaxBytes { families.insert(.writesCD) }
        if bytes <= dvdMaxBytes { families.insert(.writesDVD) }
        if bytes <= bdMaxBytes { families.insert(.writesBD) }
        return families
    }

    /// The families a format's discs come in, or nil when the format takes any disc.
    public static func families(of media: [KroutonSpanningDiscMedium]) -> SpoolNodeCapabilities? {
        guard !media.isEmpty else { return nil }
        return media.reduce(into: []) { families, medium in
            if medium.rawValue.hasPrefix("CD") { families.insert(.writesCD) }
            if medium.rawValue.contains("DVD") { families.insert(.writesDVD) }
            if medium.rawValue.hasPrefix("BD") { families.insert(.writesBD) }
        }
    }

    /// The family of a disc named the way the server names it ("CD-R", "DVD+R DL", "BD-RE").
    public static func family(ofDisc disc: String) -> SpoolNodeCapabilities? {
        if disc.hasPrefix("CD") { return .writesCD }
        if disc.hasPrefix("DVD") { return .writesDVD }
        if disc.hasPrefix("BD") { return .writesBD }
        return nil
    }

    /// "CD and DVD", or with `or`, "DVD or Blu-ray".
    public func discNames(joinedBy word: String = "and") -> String {
        let names = [(SpoolNodeCapabilities.writesCD, "CD"), (.writesDVD, "DVD"), (.writesBD, "Blu-ray")]
            .filter { contains($0.0) }.map(\.1)
        switch names.count {
        case 0: return "no discs"
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " \(word) " + names[names.count - 1]
        }
    }
}

extension SpoolDriveInfo {
    /// Why an image of `imageBytes` that needs a disc of `needs` (nil: any) can't burn on this
    /// drive now, or nil when nothing known stands in the way. Unknown facts never refuse.
    public func refusal(imageBytes: Int64, needs: SpoolNodeCapabilities?) -> String? {
        let size = ByteCountFormatter.string(fromByteCount: imageBytes, countStyle: .file)
        let fitting = SpoolNodeCapabilities.holding(bytes: imageBytes).intersection(needs ?? .writesAny)
        if fitting.isEmpty {
            return "A \(size) image doesn't fit on a \((needs ?? .writesAny).discNames(joinedBy: "or")) disc. Nothing was uploaded."
        }
        if let writes, !writes.isEmpty, writes.isDisjoint(with: fitting) {
            return "\(name) writes \(writes.discNames()), and this needs a \(fitting.discNames(joinedBy: "or")) disc. Nothing was uploaded."
        }
        guard media == .blank || media == .appendable else { return nil }
        if let disc, let family = SpoolNodeCapabilities.family(ofDisc: disc), !fitting.contains(family) {
            return "The \(disc) in \(name) can't hold this; insert a \(fitting.discNames(joinedBy: "or")) disc. Nothing was uploaded."
        }
        if let freeBytes, freeBytes > 0, imageBytes > freeBytes {
            let free = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
            return "The \(disc ?? "disc") in \(name) holds \(free), and the image is \(size). Insert a larger disc. Nothing was uploaded."
        }
        return nil
    }

    /// The drive a job goes to: the one asked for, or the first that can burn it, preferring a
    /// blank disc in an idle drive. Fails with the reason when none can.
    public static func choose(from drives: [SpoolDriveInfo], requested: String?, imageBytes: Int64,
                              needs: SpoolNodeCapabilities?) -> Result<SpoolDriveInfo, SpoolRemoteError> {
        guard !drives.isEmpty else {
            return .failure(SpoolRemoteError(code: .unknownDrive, message: "The server has no optical drives"))
        }
        if let requested, !requested.isEmpty, let drive = drives.first(where: { $0.id == requested }) {
            if let reason = drive.refusal(imageBytes: imageBytes, needs: needs) {
                return .failure(SpoolRemoteError(code: .tooLarge, message: reason))
            }
            return .success(drive)
        }
        let able = drives.filter { $0.refusal(imageBytes: imageBytes, needs: needs) == nil }
        if let pick = able.first(where: { $0.media == .blank && !$0.busy }) ?? able.first(where: { !$0.busy }) ?? able.first {
            return .success(pick)
        }
        let reason = drives[0].refusal(imageBytes: imageBytes, needs: needs) ?? "No drive on the server can burn this."
        return .failure(SpoolRemoteError(code: .tooLarge, message: reason))
    }

    /// "Writes CD and DVD • blank DVD+R, 4.7 GB free", from what the server reported.
    public var capabilitySummary: String? {
        var parts: [String] = []
        if let writes, !writes.isEmpty { parts.append("Writes \(writes.discNames())") }
        if let disc {
            let free = freeBytes.map { ", \(ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)) free" } ?? ""
            parts.append("\(disc)\(free)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
