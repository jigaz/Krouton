import SwiftUI
import Foundation
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

struct KroutonTestHarness {
    var passed = 0
    var failed = 0

    mutating func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passed += 1
        } else {
            failed += 1
            print("  ❌ FAIL: \(message)")
        }
    }

    mutating func runSuite(_ title: String, _ block: (inout KroutonTestHarness) throws -> Void) {
        let beforeFail = failed
        do {
            try block(&self)
            if failed == beforeFail {
                print("  ✅ PASS: \(title)")
            }
        } catch {
            failed += 1
            print("  ❌ ERROR in \(title): \(error)")
        }
    }
}

print("=== KROUTON ARCHITECTURE & CORE INVARIANT SUITE (krouton-verify) ===")
var harness = KroutonTestHarness()

harness.runSuite("1. 21/21 (100%) AppKit-Free Clean Architecture & Zero Banned Symbols Gate") { h in
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourcesURL = repoRoot.appendingPathComponent("Sources")

    let fm = FileManager.default
    let enumerator = fm.enumerator(at: sourcesURL, includingPropertiesForKeys: nil)!
    var swiftFiles: [URL] = []
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
        if !fileURL.path.contains("/KroutonVerify/") {
            swiftFiles.append(fileURL)
        }
    }
    h.check(swiftFiles.count == 21, "Expected 21 production Swift files, found \(swiftFiles.count)")

    let bannedEverywhere = [
        "import AppKit", "NSWindow", "NSApp", "NSPasteboard", "NSWorkspace", "NSColor",
        "NSOpenPanel",
        "NSSavePanel",
        "NSSound",
        "NSBitmapImageRep",
        "NSAccessibility",
        ".nsImage"
    ]

    var filesImportingAppKit: [String] = []
    for fileURL in swiftFiles {
        let relPath = fileURL.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let activeLines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("/*") }

        for line in activeLines {
            if line.hasPrefix("import AppKit") {
                filesImportingAppKit.append(relPath)
            }
            for banned in bannedEverywhere {
                h.check(!line.contains(banned), "Banned symbol \(banned) in \(relPath): \(line)")
            }
        }
    }
    h.check(
        filesImportingAppKit.isEmpty,
        "AppKit must only be imported in KroutonApp.swift, found: \(filesImportingAppKit)"
    )
}

harness.runSuite("2. Specialized Bakery Sub-Modules (Marmalade, VideoOven, Tartine, Galette, Crustini)") { h in
    h.check(KroutonMarmaladeModule.version == "0.1.0-alpha.1", "Marmalade version")
    h.check(KroutonVideoOvenModule.version == "0.1.0-alpha.1", "VideoOven version")
    h.check(KroutonTartineModule.version == "0.1.0-alpha.1", "Tartine version")
    h.check(KroutonGaletteModule.version == "0.1.0-alpha.1", "Galette version")
    h.check(KroutonKrustiniModule.version == "0.1.0-alpha.1", "Crustini version")
}

harness.runSuite("3. Red Book CD-Text, ISRC (ISO 3901) & MCN Sanitizer Constraints") { h in
    let sanitizedText = KroutonSeasoningSanitizer.sanitize("Café   Krouton — Live!\n\t")
    h.check(!sanitizedText.isEmpty && sanitizedText.allSatisfy { $0.isASCII }, "CD-Text ASCII sanitization")

    let isrc = KroutonSeasoningSanitizer.sanitizeISRC("us-kro-26-00001-extra")
    h.check(isrc == "USKRO2600001" && isrc.count == 12, "ISRC 12-char normalization")

    let mcn = KroutonSeasoningSanitizer.sanitizeMCN("0123-4567-89012-abc")
    h.check(mcn == "0123456789012" && mcn.count == 13, "MCN 13-digit EAN-13 normalization")
}

harness.runSuite("4. Red Book Audio Cube Frame (75 fps) & PCM Byte (2352 B/frame) Math") { h in
    let cube = KroutonAudioCube(
        url: URL(fileURLWithPath: "/tmp/test.wav"),
        title: "Track 01",
        performer: "Krouton Trio",
        songWriter: "Greybeard",
        isrcCode: "USKRO2600001",
        durationSeconds: 10.0,
        preGapSeconds: 2.0,
        crossfadeSeconds: 0.0,
        transitionStyle: .standard2s
    )
    h.check(cube.totalRedBookFrames == 900, "Expected 900 Red Book frames for 10s + 2s pregap")
    h.check(cube.redBookByteSize == 900 * 2352, "Expected 2,116,800 Red Book bytes")
    h.check(cube.formattedDurationMMSSFF == "00:10:00", "Expected 00:10:00 MM:SS:FF formatting")
}

harness.runSuite("5. ISO-9660 / Joliet / UDF File Entry Limits & 2048-Byte LBA Math") { h in
    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let longName = String(repeating: "K", count: 70) + ".iso"
    let entry = KroutonLoafFileEntry(
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

harness.runSuite("6. SHA-256 Digest & 2048-Byte Sector Hex Dump Inspector") { h in
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("krouton_test_\(UUID().uuidString).iso")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var payload = Data("KROUTON_OPTICAL_MASTER".utf8)
    payload.append(Data(repeating: 0xAA, count: 2048 - payload.count))
    try payload.write(to: tempURL)

    let sha = KroutonLoafBootInspector.computeSHA256Hex(url: tempURL)
    h.check(sha.count == 64, "SHA-256 digest must be 64 hex characters")

    let rows = KroutonLoafBootInspector.readSectorHexDump(url: tempURL, lba: 0, sectorSize: 2048)
    h.check(rows.count == 16, "256-byte sector header window at 16 B/row must yield 16 rows")
    h.check(rows.first?.asciiText.hasPrefix("KROUTON_OPTICAL_") == true, "ASCII column must decode header")
}

harness.runSuite("7. Hardware Acceleration Codec Matrix & Container Stream Probing") { h in
    let matrix = KroutonPantryPrepEngine.liveHardwareCodecMatrix
    h.check(matrix.count >= 6, "Expected at least 6 codec rows in hardware matrix")

    let mkvProbe = KroutonPantryPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/concert.mkv"))
    h.check(mkvProbe.fileExtension == "MKV" && mkvProbe.isHardwareAccelerated, "MKV hardware probe")

    let flacProbe = KroutonPantryPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/master.flac"))
    h.check(flacProbe.accelerationTier == .accelerateSIMD, "FLAC Accelerate SIMD tier")
}

harness.runSuite("8. Krumb Wire Protocol Codable Round-Trip & mDNS Host Sanitization") { h in
    h.check(KrumbNetworkConstants.defaultPort == 7420, "Krumb default TCP port 7420")
    h.check(KrumbNetworkConstants.minimumPantryFreeBytes == 1_073_741_824, "1 GiB Pantry minimum rule")

    let host = KrumbKitchenClient.sanitizeMdnsHostname("Mac Studio (2)")
    h.check(host == "mac-studio-2" && !host.contains(" "), "mDNS RFC-1123 hostname label sanitizer")

    let req = KrumbBakeRequest(
        batchId: UUID(),
        pantryLoafId: UUID(),
        toasterIds: ["pioneer-bdr-xs07s"],
        heatX: 16,
        mode: .toast,
        doggyBag: .notesOnlyOnFailure,
        seasoning: KrumbSeasoning(albumTitle: "Krouton Sessions", performer: "VentureCorp"),
        cubes: [
            KrumbCubePayload(trackNumber: 1, filename: "01.wav", title: "Overture", performer: "VentureCorp", isrc: "USKRO2600001", pregapMs: 2000)
        ]
    )

    let data = try JSONEncoder().encode(req)
    let jsonString = String(data: data, encoding: .utf8)!
    h.check(jsonString.contains("pantry_loaf_id") && jsonString.contains("doggy_bag"), "Snake-case wire keys")

    let decoded = try JSONDecoder().decode(KrumbBakeRequest.self, from: data)
    h.check(decoded.batchId == req.batchId && decoded.heatX == 16 && decoded.mode == .toast, "Round-trip decode")
}


// 9. Pure IEEE-754 RGB <-> HSB Bijective Math & 10-Swatch Display-P3 Harmony Engine
harness.runSuite("9. IEEE-754 RGB <-> HSB Round-Trip & 10-Swatch Display-P3 Harmony Polarity") { h in
    // 9a. Test all 6 HSV Hue Sectors (0..5) + Neutral Grayscale (s = 0)
    let testRGBSamples: [(CGFloat, CGFloat, CGFloat)] = [
        (0.95, 0.18, 0.22), // Sector 0: Laser Crimson
        (0.92, 0.68, 0.12), // Sector 1: Solar Gold
        (0.18, 0.88, 0.34), // Sector 2: Oscilloscope Green
        (0.14, 0.82, 0.86), // Sector 3: Analog Seafoam Teal
        (0.22, 0.38, 0.96), // Sector 4: Laser Cobalt Blue
        (0.88, 0.20, 0.78), // Sector 5: Synth Magenta
        (0.45, 0.45, 0.45), // Achromatic Titanium Neutral
        (0.00, 0.00, 0.00), // Pure Black
        (1.00, 1.00, 1.00)  // Pure White
    ]

    for (r, g, b) in testRGBSamples {
        let (hue, sat, val) = KroutonPureColorMath.rgbToHSB(r: r, g: g, b: b)
        h.check(hue >= 0.0 && hue <= 1.0, "Hue must be normalized in [0, 1]")
        h.check(sat >= 0.0 && sat <= 1.0, "Saturation must be normalized in [0, 1]")
        h.check(val >= 0.0 && val <= 1.0, "Brightness/Value must be normalized in [0, 1]")

        let (r2, g2, b2) = KroutonPureColorMath.hsbToRGB(h: hue, s: sat, v: val)
        h.check(abs(r - r2) < 1e-4 && abs(g - g2) < 1e-4 && abs(b - b2) < 1e-4,
                "RGB -> HSB -> RGB round-trip drift exceeded 1e-4 for (\(r), \(g), \(b)) -> (\(r2), \(g2), \(b2))")
    }

    // 9b. Verify all 10 Swatch Presets (0..9) in Dark & Light mode produce distinct, valid Display-P3 colors
    //     and obey the WCAG Luminance Polarity Invariant (Dark mode harmony brighter than Light mode studio ink)
    for presetID in 0...9 {
        let darkColor  = KroutonPureColorMath.secondaryHarmonyForPresetID(presetID, scheme: .dark)
        let lightColor = KroutonPureColorMath.secondaryHarmonyForPresetID(presetID, scheme: .light)

        let (dr, dg, db, da) = KroutonPureColorMath.extractSRGB(darkColor)
        let (lr, lg, lb, la) = KroutonPureColorMath.extractSRGB(lightColor)

        h.check(da == 1.0 && la == 1.0, "Swatch #\(presetID) opacity must be 1.0")

        // Rec. 709 relative luminance approximation
        let darkLuma  = 0.2126 * dr + 0.7152 * dg + 0.0722 * db
        let lightLuma = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb

        h.check(
            darkLuma > lightLuma,
            "Swatch #\(presetID) Dark Mode phosphor luma (\(darkLuma)) must exceed Light Mode ink luma (\(lightLuma))"
        )
    }
}

print("\n🎯 SUMMARY: \(harness.passed) assertions passed, \(harness.failed) failed.")
if harness.failed > 0 {
    exit(1)
}
