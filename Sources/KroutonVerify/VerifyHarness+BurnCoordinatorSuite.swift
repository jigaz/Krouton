import Foundation

// MARK: - VerifyHarness — Suite 40: Burn Coordinator

/// Krouton has two ways to burn on this Mac, the destination queue and multi-disc sets. Each
/// used to take the drives without asking the other. `KroutonBurnCoordinator` now starts every
/// burn, so neither can start on drives the other is using. This suite keeps every burn going
/// through it; BurnKitTests (BurnCoordinatorTests) test what it decides.
extension KroutonTestHarness {
    mutating func runVerifyBurnCoordinatorSuite() {
        self.runSuite("40. Burn Coordinator: One Way to the Drives, Queue Pool Tested Outside the App") { h in
            try Self.checkEveryBurnGoesThroughTheCoordinator(&h)
        }
    }

    private static func checkEveryBurnGoesThroughTheCoordinator(_ h: inout KroutonTestHarness) throws {
        let sources = KroutonTestHarness.repositoryRoot.appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var bankCallers: [String] = []
        var imageBurnerCallers: [String] = []
        var setController = ""
        for url in files {
            let path = url.path.components(separatedBy: "/Sources/").last ?? url.lastPathComponent
            let source = try String(contentsOf: url, encoding: .utf8)
            if path.hasPrefix("DriveKit/") || path.hasPrefix("KroutonVerify/") { continue }
            if source.contains(".startPhysicalDataBurn(") { bankCallers.append(path) }
            if source.contains("KroutonDiscImageBurner.burn(") && !path.hasPrefix("BurnKit/") { imageBurnerCallers.append(path) }
            if path.hasSuffix("KroutonBurnSetController.swift") { setController = source }
        }
        h.lint(bankCallers == ["BurnKit/BurnCoordinator.swift"],
               "Only KroutonBurnCoordinator may start a drive bank burn; also called from: \(bankCallers.filter { !$0.hasPrefix("BurnKit/") })")
        h.lint(imageBurnerCallers.isEmpty, "Only BurnKit's set scheduler may burn images directly: \(imageBurnerCallers)")
        h.lint(setController.contains("beginSet(") && setController.contains("endSet()"),
               "KroutonBurnSetController must claim the drives from KroutonBurnCoordinator before a set and give them back after")
    }
}
