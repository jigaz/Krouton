import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - Hero Banner Text Outline & Contrast Halo Modifier
private struct KroutonHeroTextOutlineModifier: ViewModifier {
    let inkColor = Color(red: 0.02, green: 0.04, blue: 0.10)

    func body(content: Content) -> some View {
        content
            .shadow(color: inkColor.opacity(0.98), radius: 0.6, x: -1.0, y: -1.0)
            .shadow(color: inkColor.opacity(0.98), radius: 0.6, x:  1.0, y: -1.0)
            .shadow(color: inkColor.opacity(0.98), radius: 0.6, x: -1.0, y:  1.0)
            .shadow(color: inkColor.opacity(0.98), radius: 0.6, x:  1.0, y:  1.0)
            .shadow(color: inkColor.opacity(0.90), radius: 3.5, x:  0.0, y:  1.5)
    }
}

private extension View {
    func heroTextOutline() -> some View {
        modifier(KroutonHeroTextOutlineModifier())
    }
}


struct KroutonDepotHeroBannerView: View {
    @ObservedObject var store: KroutonStateStore
    let item: KroutonDepotCatalogItem
    let isNarrow: Bool

    var body: some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
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

            // 2. Multi-Layer Isometric & Pixel-Matrix CAD Blueprint Art Workspace
            //    Masked with a directional fade gradient so foreground typography pops with 100% clarity!
            KroutonWorkflowBlueprintView(item: item, accent: store.activeAccent, isNarrow: isNarrow, useHarmony: store.enableSecondaryAccentUITints).id("\(item.id)-\(store.enableSecondaryAccentUITints)")
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.16), location: 0.00),
                            .init(color: .white.opacity(0.28), location: isNarrow ? 0.45 : 0.36),
                            .init(color: .white.opacity(0.88), location: isNarrow ? 0.78 : 0.62),
                            .init(color: .white.opacity(1.00), location: 1.00)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // 3. Foreground Layout: Left Info Column + Open Vector Showcase + Right Schematic Box
            HStack(alignment: .center, spacing: 12) {
                depotCardLeftDetailsColumn
                if !isNarrow {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent))
                            Text("DISC CONTENT SCHEMATIC")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
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
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
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

    @ViewBuilder
    var depotCardLeftDetailsColumn: some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let segments = item.blueprintSectorSegments
        VStack(alignment: .leading, spacing: 8) {
                    // Top Micro Telemetry Header (Frosted Dark Pill for 100% Contrast Across All Swatches)
                    HStack(spacing: 5) {
                        Image(systemName: item.sfSymbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.cyan)
                        Text("\(item.architecture) • \(item.bootStandard)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.48))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))

                    // Selected Title + Version (Traced dark outline halo on white title + frosted version badge)
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: isNarrow ? 15 : 19, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .heroTextOutline()
                        Text("v\(item.version)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.52))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 0.8))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .frame(maxWidth: 460, alignment: .leading)
                        .heroTextOutline()

                    Spacer(minLength: 2)

                    // Bottom Row: 3-Segment CAD Sector Map + Stage & Hex Action Buttons
                    HStack(spacing: 8) {
                        if !isNarrow {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 2) {
                                    ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(seg.label)
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text(seg.lbaRange)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.cyan.opacity(0.9))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .background(
                                            idx == 0 ? (store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent).opacity(0.28) : (idx == 1 ? Color.green.opacity(0.26) : store.activeAccent.opacity(0.36))
                                        )
                                        .overlay(Rectangle().stroke((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.activeAccent).opacity(0.32), lineWidth: 0.6))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 5))

                                EmptyView()
                            }
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
                                    let compactSize = isNarrow ? item.sizeDisplay.replacingOccurrences(of: " (80mm)", with: "") : item.sizeDisplay
                                    Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE (\(compactSize))" : "GET (\(compactSize))"))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 10.5, weight: .heavy))
                                .padding(.horizontal, isNarrow ? 11 : 14)
                                .padding(.vertical, 6)
                                .background(isStaged ? Color.green : store.activeAccent)
                                .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
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
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.45) : Color.white.opacity(0.14)))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: isNarrow ? 0 : 95) // Open showcase space so the Vector Blueprint Art shines through!

    }

}
