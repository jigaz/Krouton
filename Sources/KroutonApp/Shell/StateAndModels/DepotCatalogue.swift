import Foundation
import Observation
import OpticalCore

/// Feature model owning the Disc Image Depot: the depot.krouton.app feed, downloads and Internet Archive search state.
@Observable
@MainActor
final class DepotCatalogue {
    /// Filled from depot.krouton.app (KroutonStateStore+DepotFeed.swift); empty until the first feed loads.
    var depotChannels: [KroutonDepotFeedSubscription] = []
    var depotItems: [KroutonDepotCatalogItem] = []
    /// Why the list may be out of date, shown in the Depot; nil when the feed loaded.
    var depotFeedStatus: String? = nil
    /// The day the feed was last checked by the depot (yyyy-mm-dd).
    var depotFeedGenerated: String? = nil
    var customDepotFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    var autoVerifyDepotSHA256: Bool = true
    var stagedDepotItemID: String? = nil
    var selectedDepotHeroItemID: String? = nil
    var depotDownloadProgress: [String: Double] = [:]
    var isSearchingInternetArchive: Bool = false
    var archiveOrgLiveCount: Int = 0

    init() {}
}
