import SwiftUI
import UniformTypeIdentifiers
import Foundation
import OpticalCore

struct KroutonDiscImageInspectorWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonOpticalWorkflowSpec
    @Binding var isDropTargeted: Bool
    let onPromptToAddFiles: () -> Void
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var discImageWriteMethod: String = "DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)"
    @State private var verifyImageSHA256BeforeBurn: Bool = true
    @State private var inspectedImageLBA: Int = 17
    @State private var computedImageSHA256: String = ""
    @State private var imageActionStatusBanner: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "opticaldisc.fill").foregroundStyle(store.activeAccent)
                        Text("SECTOR-EXACT DISC IMAGE INSPECTOR & BOOTABLE OS BURNER")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(imageActionStatusBanner.isEmpty ? ".ISO • .DMG • .CDR • .BIN/.CUE" : "[ \(imageActionStatusBanner) ]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(imageActionStatusBanner.isEmpty ? .secondary : store.activeAccent).lineLimit(1)
                    }
                    HStack(spacing: 12) {
                        Picker("Laser Write Topology:", selection: $discImageWriteMethod) {
                            Text("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                            Text("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                            Text("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                        }.font(.caption.bold())
                        Toggle("Verify SHA-256 Digest Before Write", isOn: $verifyImageSHA256BeforeBurn).toggleStyle(.checkbox).font(.caption.bold())
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

                if let entry = store.stagedFiles.first {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "opticaldisc.fill").font(.title2).foregroundStyle(store.activeAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name).font(.headline)
                                Text("\(entry.url.path) • \(entry.sectorsLBA) LBA (\(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)))")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if entry.isConvertibleBinOrIso {
                                Button(entry.conversionTargetLabel) {
                                    store.convertStagedBinOrIso(id: entry.id)
                                    imageActionStatusBanner = "Converted \(entry.name)"
                                }.buttonStyle(.borderedProminent).tint(store.activeAccent).controlSize(.small)
                            }
                            Button("Compute SHA-256") {
                                computedImageSHA256 = KroutonElToritoBootInspector.computeSHA256Hex(url: entry.url)
                                imageActionStatusBanner = "SHA-256 Verified"
                            }.buttonStyle(.bordered).controlSize(.small)
                            Button("Replace...") { onPromptToAddFiles() }.buttonStyle(.bordered).controlSize(.small)
                        }
                        if !computedImageSHA256.isEmpty {
                            Text("SHA-256: \(computedImageSHA256)").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.green)
                        }
                        Divider()
                        HStack(spacing: 8) {
                            Text("Jump to Sector:").font(.caption.bold())
                            ForEach([(0, "LBA 0 (System)"), (16, "LBA 16 (PVD)"), (17, "LBA 17 (El Torito)"), (256, "LBA 256 (UDF)")], id: \.0) { lba, title in
                                Button(title) { inspectedImageLBA = lba }
                                    .buttonStyle(.bordered).controlSize(.mini)
                                    .tint(inspectedImageLBA == lba ? store.activeAccent : .secondary)
                            }
                            Spacer()
                        }
                        ScrollView {
                            Text(KroutonElToritoBootInspector.readSectorHexDump(url: entry.url, lba: inspectedImageLBA).map { "\($0.offsetHex)  \($0.hexBytes)  |\($0.asciiText)|" }.joined(separator: "\n"))
                                .font(.system(size: 10.5, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(14)
                } else {
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "opticaldisc.fill",
                        headline: "Drop an .ISO, .BIN/.CUE, .DMG, .CDR, or .IMG Disc Image to Inspect & Burn",
                        subtitle: "Inspect live 2,048-byte / 2,352-byte LBA sectors (PVD LBA 16, El Torito Boot Catalog LBA 17, UDF Anchor LBA 256) and verify SHA-256 before burning."
                    )
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
        }
    }
}
