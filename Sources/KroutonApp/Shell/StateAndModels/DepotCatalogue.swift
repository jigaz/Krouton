import Foundation
import Observation
import OpticalCore

/// Feature model owning Disc Image Depot subscriptions, curated items, and Internet Archive search state.
@Observable
@MainActor
final class DepotCatalogue {
    var depotChannels: [KroutonDepotFeedSubscription] = KroutonDepotStaticCatalog.defaultChannels
    var depotItems: [KroutonDepotCatalogItem] = KroutonDepotStaticCatalog.defaultItems
    var customDepotFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    var autoVerifyDepotSHA256: Bool = true
    var enableVMTestBootInDepot: Bool = true
    var stagedDepotItemID: String? = nil
    var selectedDepotHeroItemID: String? = nil
    var depotDownloadProgress: [String: Double] = [:]
    var isSearchingInternetArchive: Bool = false
    var archiveOrgLiveCount: Int = 0

    init() {}
}
