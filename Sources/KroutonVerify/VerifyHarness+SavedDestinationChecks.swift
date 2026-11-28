import Foundation

// MARK: - VerifyHarness — Saved Destination Kinds (Suite 21)

extension KroutonTestHarness {
    /// Sessions and projects saved before 2026-11-27 store destination kinds under names that
    /// overstated what Krouton does. They must keep decoding, and must not be written again.
    static func checkSavedDestinationKinds(_ h: inout KroutonTestHarness) {
        // Sessions and projects saved before 2026-11-27 store these destination kinds; they
        // must keep decoding, and must not come back as raw values.
        let modelsURL = KroutonTestHarness.repositoryRoot
            .appendingPathComponent("Sources/KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift")
        let modelsSrc = (try? String(contentsOf: modelsURL, encoding: .utf8)) ?? ""
        let savedBefore = ["Physical Burner", "Network Server Burner", "Disc Image File", "Audio Rip (ALAC / AAC / FLAC)",
                           "Video Transcode (H.265 / HEVC)", "Disc Printer (Epson ET-8550)", "Vector PDF Label"]
        h.lint(savedBefore.allSatisfy { modelsSrc.contains("\"\($0)\": .") }
               && !savedBefore.contains { modelsSrc.contains("= \"\($0)\"") }
               && modelsSrc.contains("init(from decoder: Decoder)"),
               "KroutonBurnDestinationKind must still read every destination kind saved before 2026-11-27, and not write them")
    }
}
