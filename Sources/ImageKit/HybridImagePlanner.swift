import CryptoKit
import Foundation
import OpticalCore

// MARK: - Hybrid Image Planner (size preview)

/// One entry's place in a planned hybrid layout.
public struct KroutonHybridExtent: Sendable, Equatable, Identifiable {
    public let id: UUID
    let originalName: String
    /// The entry's ISO 9660 name.
    public let iso9660Name: String
    let jolietName: String
    /// The first sector of its data in the plan.
    public let startLBA: Int64
    /// Its data's length in sectors.
    public let sectorCountLBA: Int64
    /// Its size in bytes.
    public let byteSize: Int64
    /// Shown in the Mac (HFS+) tree.
    public let visibleInMacTree: Bool
    /// Shown in the ISO 9660, Joliet and UDF trees.
    public let visibleInPCTree: Bool
    /// True for a file over 4 GiB, which ISO 9660 can't hold in one extent.
    public let requiresUDFMultiExtent: Bool
}

/// A planned hybrid layout, for previews (see `planHybridDataLayout`).
public struct KroutonHybridLayoutPlan: Sendable, Equatable {
    /// The cleaned ISO 9660 volume identifier.
    public let volumeIdentifier: String
    /// The primary volume descriptor's sector: always 16.
    public let pvdSectorLBA: Int64
    /// The El Torito boot record's sector (17) when bootable.
    public let elToritoBootRecordLBA: Int64?
    /// The Joliet supplementary volume descriptor's sector: 17, or 18 after a boot record.
    public let jolietSVDSectorLBA: Int64
    /// The UDF anchor volume descriptor pointer's sector: always 256 (ECMA-167).
    public let udfAnchorAVDPLBA: Int64
    /// Where file data starts in the plan: sector 288.
    public let dataPayloadStartLBA: Int64
    /// The planned image size in sectors.
    public let totalSectorsLBA: Int64
    /// The planned image size in bytes.
    public let totalBytes: Int64
    /// Every planned entry, in order.
    public let sharedHybridExtents: [KroutonHybridExtent]
    /// Names and sizes that won't fit some file system, for the user.
    public let warnings: [String]
}

/// Plans hybrid layouts for size previews and cleans names for ISO 9660.
public struct KroutonHybridImagePlanner {
    /// The module version krouton-verify checks.
    public static let version = "0.1.0-alpha.1"
    /// The data sector size.
    public static let sectorSize: Int64 = 2048
    static let iso9660FourGiBLimit: Int64 = 4_294_967_295

    /// The label as an ISO 9660 (ECMA-119) volume identifier: upper case, A–Z, 0–9 and "_",
    /// at most 32 characters.
    public static func sanitizeVolumeIdentifier(_ raw: String) -> String {
        let upper = raw.uppercased()
        let filtered = upper.map { ch -> Character in
            if (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "_" {
                return ch
            }
            return "_"
        }
        let collapsed = String(filtered).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let fallback = collapsed.isEmpty ? "KROUTON_HYBRID_DISC" : collapsed
        return String(fallback.prefix(32))
    }

    /// The name as an ISO 9660 Level 2 identifier: upper case d-characters, at most 31
    /// characters, with ";1" after a file name.
    public static func sanitizeISO9660FileIdentifier(_ filename: String, isDirectory: Bool = false) -> String {
        let upper = filename.uppercased()
        let parts = upper.split(separator: ".", omittingEmptySubsequences: false)
        let sanitizePart: (Substring) -> String = { sub in
            String(sub.map { ch in
                ((ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "_") ? ch : "_"
            })
        }

        if isDirectory {
            let cleanDir = sanitizePart(Substring(upper))
            return String((cleanDir.isEmpty ? "DIR" : cleanDir).prefix(31))
        }

        if parts.count >= 2 {
            let ext = String(sanitizePart(parts.last!).prefix(3))
            let stemRaw = parts.dropLast().map(sanitizePart).joined(separator: "_")
            let maxStem = max(1, 28 - ext.count)
            let stem = String((stemRaw.isEmpty ? "FILE" : stemRaw).prefix(maxStem))
            return "\(stem).\(ext);1"
        } else {
            let stem = String(sanitizePart(Substring(upper)).prefix(29))
            return "\(stem.isEmpty ? "FILE" : stem).;1"
        }
    }

    /// A size preview of a hybrid disc: each visible entry gets one shared extent after the
    /// descriptors, with its ISO 9660 and Joliet names and warnings for names and sizes that
    /// won't fit. Images are built by `hdiutil makehybrid`, whose layout differs; use this only
    /// to estimate size.
    public static func planHybridDataLayout(
        volumeLabel: String,
        entries: [KroutonStagedFileEntry],
        isElToritoBootable: Bool = false
    ) -> KroutonHybridLayoutPlan {
        let cleanVol = sanitizeVolumeIdentifier(volumeLabel)
        let pvdLBA: Int64 = 16
        let bootLBA: Int64? = isElToritoBootable ? 17 : nil
        let jolietLBA: Int64 = isElToritoBootable ? 18 : 17
        let udfAnchorLBA: Int64 = 256
        var cursorLBA: Int64 = 288

        var extents: [KroutonHybridExtent] = []
        var warnings: [String] = []

        for entry in entries {
            // Skip files hidden on both platforms
            guard entry.showOnMac || entry.showOnPC else { continue }

            let sectors = max(1, (entry.byteSize + (sectorSize - 1)) / sectorSize)
            let isoName = sanitizeISO9660FileIdentifier(entry.name, isDirectory: entry.isDirectory)
            let jolietName = String(entry.name.prefix(64))
            let needsUDF = entry.byteSize > iso9660FourGiBLimit

            if needsUDF && entry.showOnPC {
                warnings.append("\(entry.name) (>4 GiB) requires UDF 2.60 multi-extent allocation.")
            }
            if entry.exceedsJoliet64CharLimit && entry.showOnPC {
                warnings.append("\(entry.name) truncated to 64 UCS-2 characters in Joliet tree.")
            }

            extents.append(
                KroutonHybridExtent(
                    id: entry.id,
                    originalName: entry.name,
                    iso9660Name: isoName,
                    jolietName: jolietName,
                    startLBA: cursorLBA,
                    sectorCountLBA: sectors,
                    byteSize: entry.byteSize,
                    visibleInMacTree: entry.showOnMac,
                    visibleInPCTree: entry.showOnPC,
                    requiresUDFMultiExtent: needsUDF
                )
            )
            cursorLBA += sectors
        }

        // 16 sectors at the end for the second UDF anchor and padding.
        let totalSectors = cursorLBA + 16
        return KroutonHybridLayoutPlan(
            volumeIdentifier: cleanVol,
            pvdSectorLBA: pvdLBA,
            elToritoBootRecordLBA: bootLBA,
            jolietSVDSectorLBA: jolietLBA,
            udfAnchorAVDPLBA: udfAnchorLBA,
            dataPayloadStartLBA: 288,
            totalSectorsLBA: totalSectors,
            totalBytes: totalSectors * sectorSize,
            sharedHybridExtents: extents,
            warnings: warnings
        )
    }
}
