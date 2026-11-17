import Combine
import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

//
//  KroutonDepotCatalogViews.swift
//  Krouton — Optical Media Mastering Package (Optical Media Mastering Workspace)
//
//  Disc Image Depot Interactive Hero Banner & App-Store Style Catalog Cards.
//

// MARK: - Standalone Depot Hero Banner & App-Store Card Views

struct KroutonDepotAppStoreCardView: View {
    @ObservedObject var store: KroutonStateStore
    let item: KroutonDepotCatalogItem
    let isSelectedInHero: Bool

    var body: some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let useHarmony = store.enableSecondaryAccentUITints
        let pillAccent: Color = useHarmony ? store.activeSecondaryAccent : store.activeAccent
        let bootStdColor: Color = (isSelectedInHero && useHarmony) ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isStaged ? Color.green : (isSelectedInHero ? pillAccent : store.activeAccent.opacity(0.80)),
                                    (isStaged ? Color.green : store.activeAccent).opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(isSelectedInHero ? 0.45 : 0.18), lineWidth: 1))

                    Image(systemName: item.sfSymbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(isSelectedInHero ? pillAccent : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if isSelectedInHero {
                            Text("HERO")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(pillAccent.opacity(0.20))
                                .foregroundStyle(pillAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    Text(item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(minHeight: 26, alignment: .topLeading)
                }
            }

            Divider()

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(item.architecture) • \(item.sizeDisplay)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.bootStandard)
                        .font(.system(size: 9, weight: isSelectedInHero ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(bootStdColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let prog = activeProgress {
                    HStack(spacing: 4) {
                        ProgressView(value: prog)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("\(Int(prog * 100))%")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                } else {
                    Button {
                        store.selectedDepotHeroItemID = item.id
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                            Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE" : "GET"))
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isStaged ? Color.green : (item.isDownloaded ? pillAccent : Color.primary.opacity(0.12)))
                        .foregroundStyle(isStaged ? Color.black : (item.isDownloaded ? store.activeOnAccentText : pillAccent))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isStaged ? Color.clear : store.activeAccent.opacity(0.5), lineWidth: 1))
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.selectedDepotHeroItemID = item.id
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(5.5)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Stage image and open directly in the Sector & Hex Inspector")
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(isSelectedInHero ? store.activeAccent.opacity(0.08) : Color.kroutonControlSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isStaged ? Color.green.opacity(0.70) : (isSelectedInHero ? pillAccent.opacity(0.90) : Color.primary.opacity(0.09)),
                    lineWidth: (isStaged || isSelectedInHero) ? 1.5 : 1.0
                )
        )
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .background(
            Color.clear
                .contentShape(RoundedRectangle(cornerRadius: 11))
                .onTapGesture {
                    store.selectedDepotHeroItemID = item.id
                }
        )
        .contextMenu {
            Button(KroutonL10n.tr("Inspect in Disc Image Depot")) {
                store.selectedDepotHeroItemID = item.id
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(KroutonL10n.tr("Stage Image & Open Sector Hex Inspector")) {
                store.selectedDepotHeroItemID = item.id
                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
            }
            .keyboardShortcut("6", modifiers: [.command, .control])

            Divider()

            Button(KroutonL10n.tr("Copy Selected Disc or Image Metadata")) {
                let meta = "\(item.title) (\(item.version)) • \(item.sizeDisplay) • \(item.bootStandard) • SHA-256: \(item.sha256Short)"
                KroutonOSDesktopBridge.copyTextToClipboard(meta)
            }
            .keyboardShortcut("c", modifiers: [.command, .option, .shift])
        }
    }
}
