import Foundation
import OpticalCore

/// Feature model owning Disc Image Depot subscriptions, curated items, and Internet Archive search state.
public struct DepotCatalogue: Equatable, Sendable {
    public var channels: [KroutonPantryFeedSubscription] = KroutonDepotStaticCatalog.defaultChannels
    public var items: [KroutonPantryCatalogItem] = KroutonDepotStaticCatalog.defaultItems
    public var customFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    public var autoVerifySHA256: Bool = true
    public var enableVMTestBoot: Bool = true
    public var stagedItemID: String? = nil
    public var selectedHeroItemID: String? = nil
    public var downloadProgress: [String: Double] = [:]
    public var isSearchingInternetArchive: Bool = false
    public var archiveOrgLiveCount: Int = 0

    public init() {}
}
