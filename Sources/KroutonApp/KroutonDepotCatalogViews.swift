//
//  KroutonDepotCatalogViews.swift
//  Krouton — Optical Media Mastering Studio
//
//  Disc Image Depot Interactive Hero Banner & App-Store Style Catalog Cards.
//

import AppKit
import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

extension KroutonMainWorkspaceView {
    func depotInteractiveHeroBanner(for item: KroutonPantryCatalogItem, isNarrow: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let segments = item.blueprintSectorSegments
        let treeFiles = item.blueprintRootFiles

        return ZStack(alignment: .leading) {
            // 1. Deep Blueprint Gradient Surface (Works across all 11 Krouton Accent Swatches & Dark/Light Modes)
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            store.activeAccent.opacity(0.42),
                            Color(red: 0.05, green: 0.10, blue: 0.19),
                            Color(red: 0.02, green: 0.04, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Multi-Layer Isometric & Pixel-Matrix CAD Blueprint Art Studio
            KroutonRecipeBlueprintView(item: item, accent: store.activeAccent, isNarrow: isNarrow, useHarmony: store.enableSecondaryAccentUITints).id("\(item.id)-\(store.enableSecondaryAccentUITints)")
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // 3. Foreground Layout: Left Info Column + Open Vector Showcase + Right Schematic Box
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    // Top Micro Telemetry Header
                    HStack(spacing: 6) {
                        Image(systemName: item.sfSymbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        Text("CAD BLUEPRINT INSPECTOR • \(item.channel.uppercased())")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                            .lineLimit(1)
                        Text("•").foregroundStyle(.white.opacity(0.35))
                        Text("\(item.architecture) • \(item.bootStandard)")
                            .font(KroutonDesign.Typography.badgeMono)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }

                    // Selected Title + Version
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: isNarrow ? 17 : 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("v\(item.version)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent))
                            .lineLimit(1)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                        .frame(maxWidth: 460, alignment: .leading)

                    Spacer(minLength: 2)

                    // Bottom Row: 3-Segment CAD Sector Map + Stage & Hex Action Buttons
                    HStack(spacing: 8) {
                        if !isNarrow {
                            HStack(spacing: 2) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(seg.label)
                                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(seg.lbaRange)
                                            .font(.system(size: 7, design: .monospaced))
                                            .foregroundStyle(.cyan.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        idx == 0 ? (store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent).opacity(0.28) : (idx == 1 ? Color.green.opacity(0.26) : store.activeAccent.opacity(0.36))
                                    )
                                    .overlay(Rectangle().stroke((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent).opacity(0.32), lineWidth: 0.6))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }

                        if let prog = activeProgress {
                            HStack(spacing: 5) {
                                ProgressView(value: prog)
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                Text("\(Int(prog * 100))%")
                                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(store.activeAccent.opacity(0.35))
                            .clipShape(Capsule())
                        } else {
                            Button {
                                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                                    Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE (\(item.sizeDisplay))" : "GET (\(item.sizeDisplay))"))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isStaged ? Color.green : store.activeAccent)
                                .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                    Text("Inspect Hex")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.45) : Color.white.opacity(0.14)))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: isNarrow ? 8 : 95) // Open showcase space so the Vector Blueprint Art shines through!

                if !isNarrow {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent))
                            Text("DISC CONTENT SCHEMATIC")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.sizeDisplay)
                                .font(KroutonDesign.Typography.microMono)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        Divider().overlay((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent).opacity(0.35))

                        ForEach(treeFiles, id: \.self) { pathLine in
                            HStack(spacing: 4) {
                                Text("├─")
                                    .foregroundStyle(.cyan.opacity(0.75))
                                Text(pathLine)
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                    }
                    .padding(10)
                    .frame(width: 225, alignment: .leading)
                    .background(Color.black.opacity(0.50))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent).opacity(0.38), style: StrokeStyle(lineWidth: 1.0, dash: [4, 2]))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 184)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isStaged ? Color.green.opacity(0.75) : store.activeAccent.opacity(0.55), lineWidth: 1.5))
    }

    func depotAppStoreCard(for item: KroutonPantryCatalogItem, isSelectedInHero: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let useHarmony = store.enableSecondaryAccentUITints
        let pillAccent: Color = useHarmony ? store.activeSecondaryAccent : store.activeAccent
        let bootStdColor: Color = (isSelectedInHero && useHarmony) ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary

        return VStack(alignment: .leading, spacing: 8) {
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
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
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
                .fill(isSelectedInHero ? store.activeAccent.opacity(0.08) : Color(NSColor.controlBackgroundColor))
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
        .onTapGesture {
            store.selectedDepotHeroItemID = item.id
        }
    }
}
