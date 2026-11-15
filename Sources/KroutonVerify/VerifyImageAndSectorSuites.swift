import AudioKit
import BurnKit
import CoreImage
import CryptoKit
import DriveKit
import Foundation
import ImageKit
import LabelKit
import NetworkSpool
import OpticalCore
import Persistence
import RescueKit
import VideoKit

func runVerifyImageAndSectorSuites(_ harness: inout KroutonTestHarness) {
    harness.runSuite("4. ISO-9660 / Joliet / UDF File Entry Limits & 2048-Byte LBA Math") { h in
    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let longName = String(repeating: "K", count: 70) + ".iso"
    let entry = KroutonStagedFileEntry(
        url: URL(fileURLWithPath: "/tmp/\(longName)"),
        name: longName,
        isDirectory: false,
        byteSize: fiveGiB,
        itemCount: 1,
        posixPermissions: "rwxr-xr-x",
        modifiedDate: Date()
    )
    h.check(entry.exceedsISO9660FourGiBLimit, "5 GiB file must flag ISO-9660 4 GiB limit")
    h.check(entry.exceedsJoliet64CharLimit, "74-char filename must flag Joliet 64-char limit")
    h.check(entry.exceedsISO9660ThirtyOneCharLimit, "74-char filename must flag ISO-9660 31-char limit")
    h.check(entry.isConvertibleBinOrIso, ".iso extension must flag convertible sector image")
    h.check(entry.sectorsLBA == fiveGiB / 2048, "LBA sector math must equal byteSize / 2048")
    }

    harness.runSuite("5. ImageKit Hybrid Data LBA Planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256 & Deduplication)") { h in
    let vol = KroutonHybridImagePlanner.sanitizeVolumeIdentifier("Krouton Master 2026! (v1.0)")
    h.check(vol == "KROUTON_MASTER_2026___V1_0", "ECMA-119 d-character volume label sanitization")

    let isoFile = KroutonHybridImagePlanner.sanitizeISO9660FileIdentifier("my-super-archive-2026.tar.gz")
    h.check(isoFile.hasSuffix(".GZ;1") && isoFile.count <= 31, "ISO-9660 Level 2 filename + ;1 version")

    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let entries = [
        KroutonStagedFileEntry(
            url: URL(fileURLWithPath: "/tmp/SharedInstaller.pkg"),
            name: "SharedInstaller.pkg",
            isDirectory: false,
            byteSize: 4096, // 2 sectors
            itemCount: 1,
            posixPermissions: "rwxr-xr-x",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        ),
        KroutonStagedFileEntry(
            url: URL(fileURLWithPath: "/tmp/Giant4KMaster.mov"),
            name: "Giant4KMaster.mov",
            isDirectory: false,
            byteSize: fiveGiB,
            itemCount: 1,
            posixPermissions: "rw-r--r--",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        )
    ]

    let plan = KroutonHybridImagePlanner.planHybridDataLayout(
        volumeLabel: "Krouton Boot Hybrid",
        entries: entries,
        isElToritoBootable: true
    )

    h.check(plan.pvdSectorLBA == 16, "ISO-9660 PVD must sit at LBA 16")
    h.check(plan.elToritoBootRecordLBA == 17, "El Torito Boot Record must sit at LBA 17")
    h.check(plan.jolietSVDSectorLBA == 18, "Joliet SVD must shift to LBA 18 when El Torito is at LBA 17")
    h.check(plan.udfAnchorAVDPLBA == 256, "ECMA-167 UDF Anchor Volume Descriptor Pointer must sit at LBA 256")
    h.check(plan.sharedHybridExtents.count == 2, "Shared Mac+PC files must deduplicate into single physical LBA extents")
    h.check(plan.sharedHybridExtents[0].startLBA == 288 && plan.sharedHybridExtents[0].sectorCountLBA == 2, "First file starts at LBA 288 (2 sectors)")
    h.check(plan.sharedHybridExtents[1].startLBA == 290 && plan.sharedHybridExtents[1].requiresUDFMultiExtent, "Second file (>4GiB) starts monotonically at LBA 290 and flags UDF multi-extent")
    h.check(!plan.warnings.isEmpty, ">4GiB file must emit UDF multi-extent advisory")
    }

    harness.runSuite("6. ImageKit Disc Image Depot (.cue Parser, 2352B->2048B BIN Extractor & Boot Classifier)") { h in
    // 14a. Multi-track Mixed-Mode .cue sheet parsing
    let sampleCue = """
    FILE "KROUTON_MIXED_MASTER.BIN" BINARY
      TRACK 01 MODE1/2352
        TITLE "Data Track"
        INDEX 01 00:00:00
      TRACK 02 AUDIO
        TITLE "Red Book Theme"
        INDEX 00 02:00:00
        INDEX 01 02:02:00
    """
    let parsedTracks = KroutonDiscImageDepot.parseCueSheet(sampleCue)
    h.check(parsedTracks.count == 2, "Mixed-mode CUE sheet must parse 2 tracks")
    h.check(parsedTracks[0].mode == .mode1_2352 && parsedTracks[0].index01LBA == 0, "Track 1 Mode1/2352 @ LBA 0")
    h.check(parsedTracks[1].mode == .audio2352 && parsedTracks[1].index00LBA == 9000 && parsedTracks[1].index01LBA == 9150,
            "Track 2 Audio INDEX 00 @ 02:00:00 (9000 LBA) and INDEX 01 @ 02:02:00 (9150 LBA)")

    // 14b. Raw 2352-byte Mode 1 & Mode 2 Form 1 -> 2048-byte ISO payload extraction
    var mode1Raw = Data(KroutonDiscImageDepot.cdRomSyncPattern) // 12 bytes
    mode1Raw.append(contentsOf: [0x00, 0x02, 0x00, 0x01])      // 4B header (00:02:00, Mode 1 = 0x01)
    let expectedPayload = Data(repeating: 0x5A, count: 2048)
    mode1Raw.append(expectedPayload)                           // 2048B user payload
    mode1Raw.append(Data(repeating: 0xEE, count: 288))         // 288B EDC/ECC parity
    h.check(mode1Raw.count == 2352, "Synthetic Mode 1 raw sector must be 2352 bytes")

    let extractedISO = KroutonDiscImageDepot.extractISO2048SectorFromRaw2352(mode1Raw)
    h.check(extractedISO == expectedPayload && extractedISO?.count == 2048,
            "Mode 1 2352B sector extractor must strip 16B header and 288B ECC to yield exact 2048B ISO payload")

    // 14c. Depot Boot & Media Badge classification
    let depotClass = KroutonDiscImageDepot.classifyDepotImage(
        byteSize: 4_100_000_000,
        signatureSampleASCII: "CD001 EL TORITO SPECIFICATION UDF NSR03"
    )
    h.check(depotClass.isBootable && depotClass.bootStandard == "El Torito x86/EFI", "El Torito boot detection")
    h.check(depotClass.detectedFilesystems.contains("ISO-9660") && depotClass.detectedFilesystems.contains("UDF"), "ISO+UDF bridge detection")
    h.check(depotClass.recommendedMediaBadge == "DVD-5 (4.7 GB SL)", "4.1 GB image must recommend DVD-5")
    }

    harness.runSuite("7. SHA-256 Digest & 2048-Byte Sector Hex Dump Inspector") { h in
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("krouton_test_\(UUID().uuidString).iso")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var payload = Data("KROUTON_OPTICAL_MASTER".utf8)
    payload.append(Data(repeating: 0xAA, count: 2048 - payload.count))
    try payload.write(to: tempURL)

    let sha = KroutonElToritoBootInspector.computeSHA256Hex(url: tempURL)
    h.check(sha.count == 64, "SHA-256 digest must be 64 hex characters")

    let rows = KroutonElToritoBootInspector.readSectorHexDump(url: tempURL, lba: 0, sectorSize: 2048)
    h.check(rows.count == 16, "256-byte sector header window at 16 B/row must yield 16 rows")
    h.check(rows.first?.asciiText.hasPrefix("KROUTON_OPTICAL_") == true, "ASCII column must decode header")
    }
}
