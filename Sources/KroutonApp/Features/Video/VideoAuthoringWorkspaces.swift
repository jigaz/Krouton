import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

struct KroutonVideoAuthoringWorkspaceView: View {
    var store: KroutonStateStore
    let spec: KroutonOpticalWorkflowSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var showVideoBitratePopover: Bool = false
    // These formats burn a folder that is already authored: VIDEO_TS for DVD-Video, BDMV for
    // Blu-ray (`burnSupport` .dataDisc / .bluRayVideo). Krouton doesn't author menus, change the
    // video standard, place a layer break or edit HDR metadata, so there are no controls for
    // them; AVCHD has its own panel (`KroutonAVCHDPanelView`), which converts and authors.

    private var isVCDFormat: Bool {
        spec.id == "vcd-svcd" || spec.technicalName.contains("VCD")
    }

    private var videoDeckHeaderTitle: String {
        if isVCDFormat { return "WHITE BOOK VCD / SVCD (MODE 2 FORM 2 • NOT BURNABLE YET)" }
        if spec.id == "bd-on-dvd" { return "AVCHD HIGH-DEFINITION ON RED-LASER DVD (UDF 2.50)" }
        if spec.technicalName.contains("BD") { return "BLU-RAY VIDEO: AN AUTHORED BDMV FOLDER ON UDF 2.50" }
        return "DVD-VIDEO: AN AUTHORED VIDEO_TS FOLDER ON UDF 1.02 + ISO 9660"
    }

    var body: some View {
        let isDualLayer = spec.technicalName.contains("DL") || spec.technicalName.contains("DVD-9") || spec.colloquialName.contains("50 GB") || spec.colloquialName.contains("UHD") || spec.id == "dvd-video"
        let isBluRay = spec.technicalName.contains("BD") || spec.technicalName.contains("AVCHD")

        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "film.stack.fill").foregroundStyle(store.activeAccent)
                        Text(videoDeckHeaderTitle).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(isBluRay ? "Add the folder holding BDMV" : "Add the folder holding VIDEO_TS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.green).lineLimit(1)
                        Button {
                            showVideoBitratePopover.toggle()
                        } label: {
                            Label("Bitrate & Fit", systemImage: "gauge.with.dots.needle.67percent").font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .popover(isPresented: $showVideoBitratePopover, arrowEdge: .bottom) {
                            KroutonVideoBitratePopoverView(store: store, spec: spec, isBluRay: isBluRay, isDualLayer: isDualLayer)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .kroutonMenuInspectVideoBitrate)) { _ in showVideoBitratePopover = true }
                    }

                    HStack(spacing: 10) {
                        Text("Disc Title:").font(.caption.bold()).fixedSize()
                        TextField("DVD_VIDEO", text: Bindable(store).discVolumeTitle).textFieldStyle(.roundedBorder).frame(minWidth: 110, maxWidth: 155)
                        Text(isBluRay
                             ? "Author the BDMV folder in a Blu-ray authoring app first; Krouton writes it as a UDF 2.50 disc."
                             : "Author VIDEO_TS in a DVD authoring app first. To shrink a dual-layer DVD, use Copy › Duplicate Disc.")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }

            if spec.id == "bd-on-dvd" {
                KroutonAVCHDPanelView(store: store)
            }
            videoStagingDropZoneSection(isBluRay: isBluRay)
        }
    }

    // MARK: - Drop Zone

    @ViewBuilder
    private func videoStagingDropZoneSection(isBluRay: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.kroutonControlSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).strokeBorder(
                        isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                    )
                )

            if store.stagedFiles.isEmpty {
                KroutonEmptyDropZoneView(
                    store: store,
                    isDropTargeted: isDropTargeted,
                    sfSymbol: "film.circle.fill",
                    headline: "Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, HEVC 10-Bit, VOB, VIDEO_TS, BDMV)",
                    subtitle: "Click any staged VTS row's Mux & Chapters pill to adjust audio lip-sync delay (ms), Softsub vs. Burn-In captions, and 90 kHz PTS chapter timestamps."
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text("TITLE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
                        Text("VIDEO STREAM & CHAPTER TOPOLOGY").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text("MUX / SUBS / CHAPTERS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 195, alignment: .center)
                        Text("SECTORS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 82, alignment: .trailing)
                        Text("SIZE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 68, alignment: .trailing)
                        Spacer().frame(width: 18)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6).background(Color.black.opacity(0.18))
                    Divider()

                    let plan = store.dataDiscPlan(forFormatID: spec.id)
                    let activeMedium = store.resolvedDataDiscMedium(forFormatID: spec.id)
                    let oversizeIDs: Set<UUID> = Set(plan.issues.compactMap { issue in
                        if case .itemExceedsDisc(let id, _, _) = issue { return id }
                        return nil
                    })
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(plan.discs) { disc in
                                if plan.discs.count > 1 || !oversizeIDs.isEmpty {
                                    DataDiscHeaderBannerView(
                                        store: store,
                                        disc: disc,
                                        totalDiscs: plan.discs.count,
                                        medium: activeMedium,
                                        hasOversizeItem: disc.items.contains { oversizeIDs.contains($0.id) }
                                    )
                                }
                                ForEach(Array(disc.items.enumerated()), id: \.element.id) { idx, entry in
                                let vProbe = KroutonMediaPrepEngine.probeFile(entry.url)

                                HStack(spacing: 10) {
                                    Text(String(format: "VTS_%02d", idx + 1)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 48, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                        Text(vProbe.shortHardwareBadge)
                                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()

                                    Text("\(entry.sectorsLBA) LBA").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 82, alignment: .trailing)
                                    Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 68, alignment: .trailing)
                                    Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel(KroutonL10n.tr("Remove Item")).help(KroutonL10n.tr("Remove Item")).frame(width: 18)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                Divider()
                            }
                            }
                        }
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
    }
}
