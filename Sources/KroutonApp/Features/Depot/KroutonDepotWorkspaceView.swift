import Foundation
import OpticalCore
import SwiftUI

// MARK: - Disc Image Depot Workspace

struct KroutonDepotWorkspaceView: View {
    var store: KroutonStateStore
    @Environment(\.kroutonLayout) var windowLayout
    var isCenterWorkspaceNarrow: Bool { windowLayout.workspace == .narrow }

    @State private var depotSearchQuery: String = ""

    var filteredDepotItems: [KroutonDepotCatalogItem] {
        let channelFilter: String? = {
            switch store.selectedTaskID {
            case "depot-shelf": return "shelf"
            case "depot-odd": return "odd"
            case "depot-rescue": return "rescue"
            case "depot-homebrew": return "console"
            case "depot-ia-live": return "Internet Archive Live"
            default: return nil // "depot-all" shows everything
            }
        }()

        let disabled = Set(store.depotChannels.filter { !$0.isEnabled }.map(\.id))
        return store.depotItems.filter { item in
            guard !disabled.contains(item.channel) else { return false }
            let matchesChannel = (channelFilter == nil) || (item.channel == channelFilter)
            let q = depotSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesQuery = q.isEmpty
                || item.title.lowercased().contains(q)
                || item.subtitle.lowercased().contains(q)
                || item.architecture.lowercased().contains(q)
                || item.bootStandard.lowercased().contains(q)
                || item.channel.lowercased().contains(q)
            return matchesChannel && matchesQuery
        }
    }

    var depotHeroSelectedItem: KroutonDepotCatalogItem {
        let items = filteredDepotItems
        if let selID = store.selectedDepotHeroItemID,
           let match = items.first(where: { $0.id == selID }) {
            return match
        }
        return items.first ?? store.depotItems.first ?? KroutonDepotCatalogItem.placeholder(status: store.depotFeedStatus)
    }

    var depotChannelHeadline: (badge: String, title: String, subtitle: String) {
        let channelID: String? = switch store.selectedTaskID {
        case "depot-shelf": "shelf"
        case "depot-odd": "odd"
        case "depot-rescue": "rescue"
        case "depot-homebrew": "console"
        default: nil
        }
        if let channelID, let channel = store.depotChannels.first(where: { $0.id == channelID }) {
            return (channel.name.uppercased(), channel.name, channel.description)
        }
        if store.selectedTaskID == "depot-ia-live" {
            return (
                "INTERNET ARCHIVE SEARCH",
                "Internet Archive search",
                "Results from archive.org. These have no depot checksum, so check them yourself before burning."
            )
        }
        let checked = store.depotFeedGenerated.map { "Checked \($0)" } ?? "Not loaded yet"
        return (
            "DEPOT.KROUTON.APP",
            "Disc images worth burning",
            store.depotFeedStatus ?? "Every image is downloaded from its own project and checked against the depot's SHA-256. \(checked)."
        )
    }

    var body: some View {
        let heroMeta = depotChannelHeadline
        let heroItem = depotHeroSelectedItem

        return GeometryReader { _ in
            let isNarrowWorkspace = isCenterWorkspaceNarrow

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Responsive Sub-Library Header + Search Bar
                if isNarrowWorkspace {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            KroutonStyledIconBadge(
                                sfSymbol: heroItem.sfSymbol,
                                tintColor: store.activeAccent,
                                style: store.iconWidgetStyle,
                                size: 28,
                                symbolSize: 14
                            )
                            Text(KroutonL10n.tr(heroMeta.title))
                                .font(.title3.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                            Spacer(minLength: 4)
                            Text("\(filteredDepotItems.count) Titles")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent)
                                .lineLimit(1)
                        }
                        depotSearchBarPill
                    }
                } else {
                    HStack(spacing: 10) {
                        KroutonStyledIconBadge(
                            sfSymbol: heroItem.sfSymbol,
                            tintColor: store.activeAccent,
                            style: store.iconWidgetStyle,
                            size: 28,
                            symbolSize: 14
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(KroutonL10n.tr(heroMeta.title))
                                .font(.title3.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                            Text(KroutonL10n.tr(heroMeta.subtitle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        depotSearchBarPill
                    }
                }

                if let notice = store.rejectedDropNotice, !notice.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(notice).font(.caption).lineLimit(2)
                        Spacer()
                        Button(KroutonL10n.tr("Dismiss")) { store.rejectedDropNotice = nil }
                            .buttonStyle(.bordered).controlSize(.mini)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Row 2: Interactive Hero Inspector Zone
                KroutonDepotHeroBannerView(store: store, item: heroItem, isNarrow: isNarrowWorkspace)

                // Row 3: Active Staged Image Ready-to-Burn Dock
                if let stagedEntry = store.stagedFiles.first {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(isNarrowWorkspace ? "STAGED:" : "STAGED IN BURN QUEUE:")
                                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                                Text(stagedEntry.name)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                            }
                            if !isNarrowWorkspace {
                                Text("\(ByteCountFormatter.string(fromByteCount: stagedEntry.byteSize, countStyle: .file)) (\(stagedEntry.sectorsLBA) LBA Sectors) — Ready for physical burn or hex sector inspection.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        Button {
                            store.selectedCategory = .burn
                            store.selectedTaskID = "image-burn"
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                Text(isNarrowWorkspace ? "Hex Map" : "Inspect Sector & Hex Map")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.clearStagedFiles()
                            store.stagedDepotItemID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Unstage image")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(store.uiSecondaryAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.uiSecondaryAccent.opacity(0.42), lineWidth: 1))
                }

                // Row 4: Sub-Library Grid Header
                HStack(spacing: 6) {
                    Text(isNarrowWorkspace ? "CLICK ANY TITLE TO INSPECT" : "\(heroMeta.badge) • CLICK ANY CARD TO INSPECT")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(isNarrowWorkspace ? "SHA-256 Verified" : "\(filteredDepotItems.count) Titles in Sub-Library  •  SHA-256 Verified")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                // Row 5: Scrollable Responsive 1-or-2 Column Sub-Library Card Grid
                ScrollView {
                    LazyVGrid(
                        columns: isNarrowWorkspace
                            ? [GridItem(.flexible(), spacing: 10)]
                            : [GridItem(.adaptive(minimum: 295, maximum: 520), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(filteredDepotItems) { item in
                            KroutonDepotAppStoreCardView(store: store, item: item, isSelectedInHero: item.id == heroItem.id)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var depotSearchBarPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(KroutonL10n.tr(isCenterWorkspaceNarrow ? "Filter or search Archive.org..." : "Filter or search archive.org..."), text: $depotSearchQuery)
                .textFieldStyle(.plain)
                .frame(minWidth: isCenterWorkspaceNarrow ? 90 : 140, maxWidth: isCenterWorkspaceNarrow ? .infinity : 210)
                .accessibilityLabel(KroutonL10n.tr("Filter Depot or Search Internet Archive"))
                .onSubmit {
                    store.selectedTaskID = "depot-ia-live"
                    store.queryInternetArchiveLive(query: depotSearchQuery)
                }
            if !depotSearchQuery.isEmpty {
                Button {
                    depotSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search query")
            }
            Button {
                store.selectedTaskID = "depot-ia-live"
                store.queryInternetArchiveLive(query: depotSearchQuery)
            } label: {
                HStack(spacing: 4) {
                    if store.isSearchingInternetArchive {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 9))
                    }
                    Text(isCenterWorkspaceNarrow ? "Archive.org" : "Archive.org API")
                        .font(.system(size: 9.5, weight: .bold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(store.activeAccent)
                .foregroundStyle(store.activeOnAccentText)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .help("Query live Internet Archive REST API (archive.org/advancedsearch.php) for optical ISO / CD-ROM images")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .background(Color.kroutonControlSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
    }
}
