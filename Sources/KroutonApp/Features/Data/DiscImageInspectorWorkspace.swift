import Foundation
import ImageKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DiscImageInspectorWorkspace

struct KroutonDiscImageInspectorWorkspaceView: View {
    var store: KroutonStateStore
    let spec: KroutonOpticalWorkflowSpec
    @Binding var isDropTargeted: Bool
    let onPromptToAddFiles: () -> Void
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    // NOTE(status, 2026-11): display-only. `DRBurn.layout(forImageFile:)` chooses the write mode
    // itself, and nothing hashes the image before burning (the inspector's SHA-256 button does,
    // on request). Verify after burning is the destination card's Verify switch.
    @State private var discImageWriteMethod: String = "DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)"
    @State private var verifyImageSHA256BeforeBurn: Bool = true
    @State private var selectedDepotEntryID: UUID? = nil
    @State private var inspectedImageLBA: Int = 16
    @State private var customLBAText: String = "16"
    @State private var computedImageSHA256: String = ""
    @State private var imageActionStatusBanner: String = ""
    @State private var inspectionReport: DiscImageInspectionReport? = nil

    private var activeEntry: KroutonStagedFileEntry? {
        if let selID = selectedDepotEntryID,
           let matched = store.stagedFiles.first(where: { $0.id == selID }) {
            return matched
        }
        return store.stagedFiles.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "opticaldisc.fill").foregroundStyle(store.activeAccent)
                        Text("DISC IMAGE DEPOT • BOOT INSPECTOR, CONVERTER & SECTOR VIEWER")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(imageActionStatusBanner.isEmpty ? ".ISO • .DMG • .CDR • .BIN/.CUE • .IMG" : "[ \(imageActionStatusBanner) ]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(imageActionStatusBanner.isEmpty ? .secondary : store.activeAccent).lineLimit(1)
                    }
                    HStack(spacing: 12) {
                        Picker(KroutonL10n.tr("Laser Write Topology:"), selection: $discImageWriteMethod) {
                            Text("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                            Text("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                            Text("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                        }.font(.caption.bold())
                        Toggle(KroutonL10n.tr("Verify SHA-256 Digest Before Write"), isOn: $verifyImageSHA256BeforeBurn).toggleStyle(.checkbox).font(.caption.bold())
                        Spacer(minLength: 0)
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).strokeBorder(
                            isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                        )
                    )

                if let entry = activeEntry {
                    VStack(alignment: .leading, spacing: 10) {
                        if store.stagedFiles.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(store.stagedFiles) { item in
                                        Button(item.name) {
                                            selectedDepotEntryID = item.id
                                            computedImageSHA256 = ""
                                            refreshInspection(for: item)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .tint(item.id == entry.id ? store.activeAccent : .secondary)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "opticaldisc.fill").font(.title2).foregroundStyle(store.activeAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name).font(.headline)
                                Text("\(entry.url.path) • \(entry.sectorsLBA) LBA (\(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)))")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button(conversionButtonLabel(for: entry)) {
                                store.convertStagedBinOrIso(id: entry.id)
                                imageActionStatusBanner = "Converting \(entry.name)..."
                            }
                            .buttonStyle(.borderedProminent).tint(store.activeAccent).controlSize(.small)

                            Button(KroutonL10n.tr("Mount")) {
                                do {
                                    let vol = try DiscImageDepotOperations.mountDiskImageInFinder(url: inspectionReport?.resolvedBinURL ?? entry.url)
                                    imageActionStatusBanner = "Mounted: \(vol)"
                                } catch {
                                    imageActionStatusBanner = error.localizedDescription
                                }
                            }
                            .buttonStyle(.bordered).controlSize(.small)

                            Button(KroutonL10n.tr("Verify")) {
                                let res = DiscImageDepotOperations.verifyDiskImageIntegrity(url: entry.url)
                                computedImageSHA256 = KroutonElToritoBootInspector.computeSHA256Hex(url: inspectionReport?.resolvedBinURL ?? entry.url)
                                imageActionStatusBanner = res.isValid ? "Verified OK" : "SHA-256 Computed"
                            }
                            .buttonStyle(.bordered).controlSize(.small)

                            Button(KroutonL10n.tr("Add Image...")) { onPromptToAddFiles() }.buttonStyle(.bordered).controlSize(.small)
                        }

                        if let report = inspectionReport {
                            HStack(spacing: 8) {
                                depotBadge(report.classification.detectedFilesystems.joined(separator: " + "), color: store.activeAccent)
                                depotBadge(report.classification.isBootable ? "BOOTABLE: \(report.classification.bootStandard)" : report.classification.bootStandard,
                                           color: report.classification.isBootable ? .green : .secondary)
                                depotBadge("Target: \(report.classification.recommendedMediaBadge)", color: .blue)
                                depotBadge("\(report.classification.totalSectors2048) Sectors (2048B)", color: .secondary)
                                Spacer()
                            }

                            if !report.cueTracks.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CUE SHEET TRACK TABLE (\(report.cueTracks.count) TRACKS)")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                                    ForEach(report.cueTracks) { trk in
                                        HStack(spacing: 10) {
                                            Text(String(format: "Track %02d", trk.trackNumber))
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            Text(trk.mode.rawValue)
                                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(store.activeAccent)
                                            Text(trk.title).font(.caption).lineLimit(1)
                                            Spacer()
                                            Text("INDEX 01 LBA \(trk.index01LBA)")
                                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }

                        if !computedImageSHA256.isEmpty {
                            Text("SHA-256: \(computedImageSHA256)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.green)
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Text("Sector Hex Inspector:").font(.caption.bold())
                            ForEach([(0, "LBA 0 (System)"), (16, "LBA 16 (PVD)"), (17, "LBA 17 (El Torito)"), (256, "LBA 256 (UDF)")], id: \.0) { lba, title in
                                Button(title) {
                                    inspectedImageLBA = lba
                                    customLBAText = "\(lba)"
                                }
                                .buttonStyle(.bordered).controlSize(.mini)
                                .tint(inspectedImageLBA == lba ? store.activeAccent : .secondary)
                            }
                            TextField("LBA", text: $customLBAText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 72)
                                .onSubmit {
                                    if let val = Int(customLBAText.trimmingCharacters(in: .whitespaces)), val >= 0 {
                                        inspectedImageLBA = val
                                    }
                                }
                            Spacer()
                        }

                        ScrollView {
                            let dumpURL = inspectionReport?.resolvedBinURL ?? entry.url
                            Text(KroutonElToritoBootInspector.readSectorHexDump(url: dumpURL, lba: inspectedImageLBA).map { "\($0.offsetHex)  \($0.hexBytes)  |\($0.asciiText)|" }.joined(separator: "\n"))
                                .font(.system(size: 10.5, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(14)
                    .onAppear { refreshInspection(for: entry) }
                    .onChange(of: entry.id) { _, _ in refreshInspection(for: entry) }
                    .onChange(of: entry.name) { _, _ in refreshInspection(for: entry) }
                } else {
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "opticaldisc.fill",
                        headline: "Drop .ISO, .BIN/.CUE, .DMG, .CDR, or .IMG Disc Images into the Depot",
                        subtitle: "Classify ISO-9660/UDF/El Torito bootability, parse .CUE tracks, convert .BIN/.DMG/.ISO, mount in Finder, and inspect 2,048B/2,352B LBA sectors."
                    )
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
        }
    }

    private func refreshInspection(for entry: KroutonStagedFileEntry) {
        inspectionReport = DiscImageDepotOperations.inspectImageFile(at: entry.url)
    }

    private func conversionButtonLabel(for entry: KroutonStagedFileEntry) -> String {
        let lower = entry.name.lowercased()
        if lower.hasSuffix(".bin") || lower.hasSuffix(".cue") { return "Extract .ISO (2048B)" }
        if lower.hasSuffix(".dmg") { return "Convert to .ISO" }
        return "Convert to .DMG"
    }

    private func depotBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
