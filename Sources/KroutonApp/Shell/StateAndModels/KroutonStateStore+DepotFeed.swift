import DriveKit
import Foundation
import OpticalCore
import SwiftUI

// MARK: - KroutonStateStore — Depot Feed

@MainActor
extension KroutonStateStore {
    /// The last feed Krouton fetched, so the Depot opens with a list even when offline.
    nonisolated static var depotFeedCacheURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("app.krouton/depot-feed.json")
    }

    /// Shows the cached (or bundled) feed at once, then fetches the current one in the background.
    func loadDepotFeed() {
        let bundled = Bundle.main.url(forResource: "depot-snapshot", withExtension: "json")
            ?? Bundle.module.url(forResource: "depot-snapshot", withExtension: "json")
        for candidate in [Self.depotFeedCacheURL, bundled].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: candidate), let feed = try? KroutonDepotFeed.decode(data) {
                applyDepotFeed(feed)
                break
            }
        }
        Task { await refreshDepotFeed() }
    }

    func refreshDepotFeed() async {
        guard let url = URL(string: self.customDepotFeedURL), url.scheme == "https" else {
            self.depotFeedStatus = "The feed address must start with https://."
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                self.depotFeedStatus = "The depot didn't answer. Showing the list from \(self.depotFeedGenerated ?? "an earlier visit")."
                return
            }
            let feed = try KroutonDepotFeed.decode(data)
            applyDepotFeed(feed)
            try? FileManager.default.createDirectory(at: Self.depotFeedCacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: Self.depotFeedCacheURL, options: .atomic)
            self.depotFeedStatus = nil
        } catch {
            self.depotFeedStatus = "Couldn't update the depot list: \(error.localizedDescription)"
        }
    }

    func applyDepotFeed(_ feed: KroutonDepotFeed) {
        let enabled = Dictionary(self.depotChannels.map { ($0.id, $0.isEnabled) }, uniquingKeysWith: { first, _ in first })
        self.depotChannels = feed.channels.map { channel in
            KroutonDepotFeedSubscription(
                id: channel.id, name: channel.title, description: channel.about,
                itemCount: feed.items.filter { $0.channel == channel.id }.count,
                isEnabled: enabled[channel.id] ?? true, sfSymbol: (channel.symbol ?? "opticaldisc") + ".fill"
            )
        }
        let symbols = Dictionary(self.depotChannels.map { ($0.id, $0.sfSymbol) }, uniquingKeysWith: { first, _ in first })
        let searchResults = self.depotItems.filter { $0.feed == nil }
        self.depotItems = feed.items.map { item in
            let cached = KroutonDepotDownloader.imageURL(for: item).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            return item.catalogItem(channelSymbols: symbols, isDownloaded: cached)
        } + searchResults
        self.depotFeedGenerated = feed.generated.map { String($0.prefix(10)) }
    }

    // MARK: - Getting an Item

    func downloadAndStageDepotItem(id: String, jumpToInspector: Bool = false) {
        guard let item = self.depotItems.first(where: { $0.id == id }) else { return }
        guard let feedItem = item.feed else {
            downloadInternetArchiveResult(item, jumpToInspector: jumpToInspector)
            return
        }
        switch feedItem.kind {
        case "link":
            EnvironmentValues().openURL(feedItem.homepage)
            return
        case "files":
            if let url = feedItem.download?.url { EnvironmentValues().openURL(url) }
            return
        default:
            break
        }
        if self.depotDownloadProgress[id] != nil { return }
        self.depotDownloadProgress[id] = 0.01
        rejectedDropNotice = nil
        Task { @MainActor in
            do {
                let imageURL = try await Task.detached(priority: .userInitiated) {
                    try await KroutonDepotDownloader.fetchImage(for: feedItem) { fraction in
                        Task { @MainActor in
                            if self.depotDownloadProgress[id] != nil { self.depotDownloadProgress[id] = max(0.01, min(0.98, fraction)) }
                        }
                    }
                }.value
                self.depotDownloadProgress.removeValue(forKey: id)
                if let index = self.depotItems.firstIndex(where: { $0.id == id }) { self.depotItems[index].isDownloaded = true }
                stageDepotImage(imageURL, for: item, jumpToInspector: jumpToInspector)
                KroutonNotificationAndCompanionService.shared.dispatchEvent(
                    id: "depot", title: "Depot Download Checked",
                    subtitle: "\(item.title) matched its SHA-256 and is on the deck.", store: self)
            } catch {
                self.depotDownloadProgress.removeValue(forKey: id)
                rejectedDropNotice = "Couldn't get \(item.title): \(error.localizedDescription)"
            }
        }
    }

    /// Puts a finished disc image on the deck and opens Burn Disc Image.
    func stageImageForBurning(_ url: URL) {
        stagedFiles = [KroutonOpticalDriveBank.inspectFileOrFolder(url: url)]
        self.leaveDiscOpenForMoreSessions = false
        selectedCategory = .burn
        selectedTaskID = "image-burn"
    }

    private func stageDepotImage(_ url: URL, for item: KroutonDepotCatalogItem, jumpToInspector: Bool) {
        stagedFiles = [KroutonOpticalDriveBank.inspectFileOrFolder(url: url)]
        self.stagedDepotItemID = item.id
        self.leaveDiscOpenForMoreSessions = item.feed?.burn?.leaveOpen ?? false
        discVolumeTitle = String(item.id.uppercased().replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_").prefix(32))
        if jumpToInspector {
            selectedCategory = .burn
            selectedTaskID = "image-burn"
        }
    }

    private func downloadInternetArchiveResult(_ item: KroutonDepotCatalogItem, jumpToInspector: Bool) {
        let folder = KroutonDepotDownloader.cacheDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(item.id + ".iso")
        if FileManager.default.fileExists(atPath: target.path) {
            stageDepotImage(target, for: item, jumpToInspector: jumpToInspector)
            return
        }
        if self.depotDownloadProgress[item.id] != nil { return }
        self.depotDownloadProgress[item.id] = 0.05
        Task { @MainActor in
            do {
                try await Self.materializeDepotImageToCache(item: item, destinationURL: target)
                self.depotDownloadProgress.removeValue(forKey: item.id)
                stageDepotImage(target, for: item, jumpToInspector: jumpToInspector)
                rejectedDropNotice = "\(item.title) came from an Internet Archive search, so it has no checksum to confirm it against."
            } catch {
                self.depotDownloadProgress.removeValue(forKey: item.id)
                rejectedDropNotice = "Couldn't get \(item.title): \(error.localizedDescription)"
            }
        }
    }
}
