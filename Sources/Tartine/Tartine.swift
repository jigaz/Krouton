import CryptoKit
import Foundation
import OpticalDough

public struct KroutonTartineExtent: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let originalName: String
    public let iso9660Name: String
    public let jolietName: String
    public let startLBA: Int64
    public let sectorCountLBA: Int64
    public let byteSize: Int64
    public let visibleInMacTree: Bool
    public let visibleInPCTree: Bool
    public let requiresUDFMultiExtent: Bool
}

public struct KroutonTartineLayoutPlan: Sendable, Equatable {
    public let volumeIdentifier: String
    public let pvdSectorLBA: Int64              // Always LBA 16
    public let elToritoBootRecordLBA: Int64?    // LBA 17 when bootable
    public let jolietSVDSectorLBA: Int64        // LBA 17 or 18
    public let udfAnchorAVDPLBA: Int64          // Always LBA 256 per ECMA-167
    public let dataPayloadStartLBA: Int64       // Starts at LBA 288 after descriptors & path tables
    public let totalSectorsLBA: Int64
    public let totalBytes: Int64
    public let sharedHybridExtents: [KroutonTartineExtent]
    public let warnings: [String]
}

public struct KroutonTartineModule {
    public static let version = "0.1.0-alpha.1"
    public static let sectorSize: Int64 = 2048
    public static let iso9660FourGiBLimit: Int64 = 4_294_967_295

    /// Normalizes a volume label to strict 32-char ECMA-119 d-characters (A-Z, 0-9, _)
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

    /// Generates a strict ISO-9660 Level 2 (31-char + ;1 version) identifier
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

    /// Plans a deduplicated Hybrid Mac (HFS+/UDF) + PC (ISO-9660/Joliet) + El Torito LBA sector layout
    public static func planHybridDataLayout(
        volumeLabel: String,
        entries: [KroutonLoafFileEntry],
        isElToritoBootable: Bool = false
    ) -> KroutonTartineLayoutPlan {
        let cleanVol = sanitizeVolumeIdentifier(volumeLabel)
        let pvdLBA: Int64 = 16
        let bootLBA: Int64? = isElToritoBootable ? 17 : nil
        let jolietLBA: Int64 = isElToritoBootable ? 18 : 17
        let udfAnchorLBA: Int64 = 256
        var cursorLBA: Int64 = 288

        var extents: [KroutonTartineExtent] = []
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
                KroutonTartineExtent(
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

        // Reserve 16 sectors at end of session for secondary UDF AVDP + Lead-Out pad
        let totalSectors = cursorLBA + 16
        return KroutonTartineLayoutPlan(
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

    /// Computes an authentic FIPS 180-4 SHA-256 hex digest for a raw 2,048-byte ISO/UDF sector or file payload.
    public static func computeBlockSHA256Hex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    /// El Torito Boot Record Volume Descriptor sits at LBA 17 and points to the Boot Catalog sector (LBA 18).
    public static let elToritoBootRecordVolumeDescriptorLBA: Int = 17
    public static let elToritoDefaultBootCatalogLBA: Int = 18
}
