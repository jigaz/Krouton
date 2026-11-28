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
            url.lastPathComponent.hasPrefix("Krouton") && newestChange(in: url) < cutoff
        }
    }

    /// The latest change anywhere inside `url`: a task writing into a subfolder (a DVD shrink's
    /// VIDEO_TS) leaves the top folder's own date alone.
    nonisolated static func newestChange(in url: URL) -> Date {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        var newest = (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
        let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys)
        while let item = walker?.nextObject() as? URL {
            if let date = try? item.resourceValues(forKeys: Set(keys)).contentModificationDate, date > newest { newest = date }
        }
        return newest
    }

    /// True while something may be writing into the caches or work folders.
    static func isBusy(_ store: KroutonStateStore) -> Bool {
        let coordinator = KroutonBurnCoordinator.shared
        return coordinator.isQueueBurning || coordinator.isSetRunning || KroutonBurnSetController.shared.isBusy
            || store.rescue.isRunning || store.avchd.isRunning || !store.depotDownloadProgress.isEmpty
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
    /// Kept: images on the deck, and the images of a multi-disc set that can still be resumed.
    static func emptyCaches(_ store: KroutonStateStore) async {
        let burnSet = KroutonBurnSetController.shared
        var keep = Set(store.stagedFiles.map { $0.url.standardizedFileURL.path })
        if burnSet.resumable != nil || burnSet.hasUnfinishedDiscs {
            keep.insert(KroutonDomainIdentity.ephemeralBurnCacheDirectory().appendingPathComponent("BurnSets", isDirectory: true).standardizedFileURL.path)
        }
        let kept = keep
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            for url in cacheFiles + leftoverWorkFolders() where fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
            for folder in cacheFolders { removeContents(of: folder, keeping: kept) }
        }.value
        // The Depot list shows which images are still downloaded.
        for index in store.depotItems.indices where store.depotItems[index].isDownloaded {
            if let feed = store.depotItems[index].feed, let url = KroutonDepotDownloader.imageURL(for: feed) {
                store.depotItems[index].isDownloaded = FileManager.default.fileExists(atPath: url.path)
            }
        }
    }

    /// Removes everything under `folder` except the paths in `keep` and the folders that hold them.
    nonisolated private static func removeContents(of folder: URL, keeping keep: Set<String>) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for child in children {
            let path = child.standardizedFileURL.path
            if keep.contains(path) { continue }
            if keep.contains(where: { $0.hasPrefix(path + "/") }) {
                removeContents(of: child, keeping: keep)
            } else {
                try? fm.removeItem(at: child)
            }
        }
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
        let syncing = KroutonCloudSettings.isOn
        KroutonPreferences.removeAll()
        // Keeping settings in iCloud is this Mac's choice, not a setting to reset; the copy in
        // iCloud is reset with this Mac's.
        if syncing {
            KroutonPreferences.setLocally(true, for: .syncSettingsWithICloud)
            KroutonCloudSettings.eraseCloudCopy()
        }
        store.appearance.resetToDefaults()
        store.label.selectedLabelTemplate = .synthGrid
        store.notificationMatrix = KroutonStateStore.defaultNotificationMatrix
        store.discFormats = KroutonOpticalWorkflowCatalog.defaultFormats
        store.preserveMenusAndExtras = true
        store.fitToDiscDVD9Shrink = true
        store.mdiscParityPercent = 10
        store.poolDispatchMode = .autoAssign
        store.distinctDriveVoices = true
        store.menuBarStatusMode = .whileWorking
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
    /// - Returns: false if the keychain refused to delete a key.
    @discardableResult
    static func resetServerIdentity() async -> Bool {
        await forgetAllServers()
        return SpoolClientIdentity.forget()
    }

    /// Everything above. The open workspace stays until you close it.
    static func resetEverything(_ store: KroutonStateStore) async {
        await emptyCaches(store)
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
            KroutonKitchenEventRow(id: "start", eventTitle: "Burn or rip started", eventSubtitle: "When a destination card starts or a rip begins", bannerEnabled: true, soundEnabled: false,
                                   sound: KroutonNotificationSound(source: "spindle")),
            KroutonKitchenEventRow(id: "done", eventTitle: "Burn or rip finished", eventSubtitle: "When a destination card or a rip finishes without error", bannerEnabled: true, soundEnabled: true,
                                   sound: KroutonNotificationSound(source: "toaster-ding")),
            KroutonKitchenEventRow(id: "err", eventTitle: "Burn or rip failed", eventSubtitle: "When a destination card or a rip stops with an error", bannerEnabled: true, soundEnabled: true,
                                   sound: KroutonNotificationSound(source: "burnt-toast")),
            KroutonKitchenEventRow(id: "swap", eventTitle: "Insert the next blank", eventSubtitle: "Auto-Load is waiting for a blank disc", bannerEnabled: true, soundEnabled: true,
                                   sound: KroutonNotificationSound(source: "tray-lock")),
            KroutonKitchenEventRow(id: "depot", eventTitle: "Depot download checked", eventSubtitle: "An image was downloaded and matched its SHA-256", bannerEnabled: true, soundEnabled: true,
                                   sound: KroutonNotificationSound(source: "calibration"))
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
