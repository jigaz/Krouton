import BurnKit
import Foundation
import NetworkSpool
import OpticalCore

// MARK: - Storage & Reset

/// What Settings › Storage & Reset measures and clears. Each action touches only what it names:
/// emptying caches never removes projects, rips, images saved to your folders or paired servers.
@MainActor
enum KroutonStorageAndReset {
    /// Bytes on disk, measured off the main actor.
    struct Usage: Sendable, Equatable {
        var caches: Int64 = 0
        var leftovers: Int64 = 0
        var session: Int64 = 0
        var burnHistory: Int64 = 0
    }

    /// Downloaded Depot images and the Depot list, the staging cache.
    nonisolated static var cacheFolders: [URL] {
        [KroutonDepotDownloader.cacheDirectory, KroutonDomainIdentity.ephemeralBurnCacheDirectory()]
    }

    nonisolated static var cacheFiles: [URL] { [KroutonStateStore.depotFeedCacheURL] }

    /// Work folders Krouton makes in the temporary folder (KroutonUDF_…, Krouton-AVCHD-…) and
    /// removes when a task ends; a crash or a forced quit can leave them behind.
    nonisolated static func leftoverWorkFolders(olderThan age: TimeInterval = 600) -> [URL] {
        let temp = FileManager.default.temporaryDirectory
        let items = (try? FileManager.default.contentsOfDirectory(at: temp, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let cutoff = Date().addingTimeInterval(-age)
        return items.filter { url in
            guard url.lastPathComponent.hasPrefix("Krouton") else { return false }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return modified < cutoff
        }
    }

    /// True while something may be writing into the caches or work folders.
    static func isBusy(_ store: KroutonStateStore) -> Bool {
        let coordinator = KroutonBurnCoordinator.shared
        return coordinator.isQueueBurning || coordinator.isSetRunning || store.rescue.isRunning || store.avchd.isRunning
            || !store.depotDownloadProgress.isEmpty
    }

    static func measure() async -> Usage {
        let recovery = KroutonCrashRecoveryController.shared
        var usage = await Task.detached(priority: .utility) {
            Usage(caches: cacheFolders.reduce(0) { $0 + bytes(at: $1) } + cacheFiles.reduce(0) { $0 + bytes(at: $1) },
                  leftovers: leftoverWorkFolders().reduce(0) { $0 + bytes(at: $1) })
        }.value
        usage.session = recovery.savedSessionBytes
        usage.burnHistory = await recovery.burnJournal.bytesOnDisk()
        return usage
    }

    // MARK: - Actions

    /// Deletes the Depot's downloaded images and list, the staging cache, and old work folders.
    static func emptyCaches() async {
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            for url in cacheFolders + cacheFiles + leftoverWorkFolders() where fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }.value
    }

    static func forgetSavedSession() async {
        await KroutonCrashRecoveryController.shared.forgetSavedSession()
    }

    /// The record of past burns that lets Krouton report a burn a crash interrupted.
    static func clearBurnHistory() async {
        let recovery = KroutonCrashRecoveryController.shared
        try? await recovery.burnJournal.clear()
        recovery.interruptedBurns = []
    }

    /// Appearance, language, units, notifications, label template, the Format Chooser's list and the
    /// copy, shrink and pool choices go back to what a first launch shows. Projects, the
    /// workspace and paired servers stay.
    static func resetSettings(_ store: KroutonStateStore) {
        KroutonPreferences.removeAll()
        store.appearance.resetToDefaults()
        store.label.selectedLabelTemplate = .synthGrid
        store.notificationMatrix = KroutonStateStore.defaultNotificationMatrix
        store.discFormats = KroutonOpticalWorkflowCatalog.defaultFormats
        store.preserveMenusAndExtras = true
        store.fitToDiscDVD9Shrink = true
        store.mdiscParityPercent = 10
        store.poolDispatchMode = .autoAssign
    }

    /// The destination queue back to one disc burner card, and the queues saved per workspace cleared.
    static func resetDestinationQueues(_ store: KroutonStateStore) {
        store.destinationQueue = KroutonStateStore.defaultDestinationQueue
        store.savedQueuesByDomain = [:]
    }

    /// Forgets every paired Krouton Server on this Mac. The servers keep their record of this
    /// Mac until it is unpaired there (`krouton-server unpair`).
    static func forgetAllServers() async {
        let client = SpoolRemoteNodeClient.shared
        for server in client.pairedServers { await client.forgetServer(server.nodeID) }
    }

    /// Forgets the servers and makes this Mac a new identity, so no server recognises it.
    static func resetServerIdentity() async {
        await forgetAllServers()
        SpoolClientIdentity.forget()
    }

    /// Everything above. The open workspace stays until you close it.
    static func resetEverything(_ store: KroutonStateStore) async {
        await emptyCaches()
        await forgetSavedSession()
        await clearBurnHistory()
        resetSettings(store)
        resetDestinationQueues(store)
        await resetServerIdentity()
    }

    // MARK: - Measuring

    nonisolated static func bytes(at url: URL, matching include: (String) -> Bool = { _ in true }) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isDirectory != true {
            return include(url.lastPathComponent) ? Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0) : 0
        }
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker where include(file.lastPathComponent) {
            let fileValues = try? file.resourceValues(forKeys: keys)
            if fileValues?.isDirectory != true { total += Int64(fileValues?.totalFileAllocatedSize ?? fileValues?.fileSize ?? 0) }
        }
        return total
    }
}

// MARK: - Defaults

extension KroutonStateStore {
    /// What Settings › Notifications starts with, and what Reset Settings goes back to.
    nonisolated static var defaultNotificationMatrix: [KroutonKitchenEventRow] {
        [
            KroutonKitchenEventRow(id: "start", eventTitle: "Burn or rip started", eventSubtitle: "When a destination card starts or a rip begins", bannerEnabled: true, soundEnabled: false),
            KroutonKitchenEventRow(id: "done", eventTitle: "Burn or rip finished", eventSubtitle: "When a destination card or a rip finishes without error", bannerEnabled: true, soundEnabled: true),
            KroutonKitchenEventRow(id: "err", eventTitle: "Burn or rip failed", eventSubtitle: "When a destination card or a rip stops with an error", bannerEnabled: true, soundEnabled: true),
            KroutonKitchenEventRow(id: "swap", eventTitle: "Insert the next blank", eventSubtitle: "Auto-Load is waiting for a blank disc", bannerEnabled: true, soundEnabled: true),
            KroutonKitchenEventRow(id: "depot", eventTitle: "Depot download checked", eventSubtitle: "An image was downloaded and matched its SHA-256", bannerEnabled: true, soundEnabled: true)
        ]
    }

    /// One disc burner card: the queue a new workspace starts with.
    nonisolated static var defaultDestinationQueue: [KroutonBakeBatchItem] {
        [
            KroutonBakeBatchItem(
                kind: .physicalBurner,
                hardwareOrPath: "",
                speedOrCodec: "Max Safe (Auto)",
                simulationMode: false,
                verifyAfterBurn: true,
                compressAfterCreation: false
            )
        ]
    }
}
