import Foundation
import OpticalCore

/// Feature model owning Disc Image Depot subscriptions, curated items, and Internet Archive search state.
struct DepotCatalogue: Equatable, Sendable {
    var channels: [KroutonDepotFeedSubscription] = KroutonDepotStaticCatalog.defaultChannels
    var items: [KroutonDepotCatalogItem] = KroutonDepotStaticCatalog.defaultItems
    var customFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    var autoVerifySHA256: Bool = true
    var enableVMTestBoot: Bool = true
    var stagedItemID: String? = nil
    var selectedHeroItemID: String? = nil
    var downloadProgress: [String: Double] = [:]
    var isSearchingInternetArchive: Bool = false
    var archiveOrgLiveCount: Int = 0

    init() {}
}
