import Galette
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import OpticalDough

private struct ConsoleDeckDescriptor {
    let narrowTitle: String
    let headline: String
    let subtext: String
    let primaryToggleLabel: String
    let secondaryToggleLabel: String
    let footerIcon: String
    let footerNote: String
    let usesDVDROMBitset: Bool
}

struct KroutonRetroConsoleWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var romWriteModeDAO96SubQ: Bool = true
    @State private var romBitsetDVDROM: Bool = true
    @State private var romPerformOPCBeforeWrite: Bool = true
    @State private var xboxLayerBreakPreset: String = "Auto (.dvd / Calculate Optimal)"
    @State private var ps1AutoMergeMultiBinAndCHD: Bool = true
    @State private var wiiLayerMode: String = "Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)"
    @State private var selectedSoftPatch: KroutonSoftPatchFormat = .none
    @State private var exportCompanionCHD: Bool = false

    private var descriptor: ConsoleDeckDescriptor {
        switch spec.id {
        case "console-wii":
            return ConsoleDeckDescriptor(
                narrowTitle: "WII RVL-006 DECK",
                headline: "Drop Nintendo Wii Disc Image (.RVZ, .WBFS, .ISO)",
                subtext: "Verifies RVL-006 partition tables, rebuilds scrubbed sectors, and aligns Dual-Layer DVD9 break LBA 2084960.",
                primaryToggleLabel: "DVD-ROM Bitset + 32 KB ECC Alignment",
                secondaryToggleLabel: "Auto-Rebuild Scrubbed .RVZ / .WBFS Partitions",
                footerIcon: "arrow.triangle.2.circlepath",
                footerNote: "Accepts .ISO, .WBFS & Dolphin .RVZ • Layer Break LBA 2084960 Ready",
                usesDVDROMBitset: true
            )
        case "console-gc":
            return ConsoleDeckDescriptor(
                narrowTitle: "GAMECUBE DOL-006 DECK",
                headline: "Drop GameCube Mini-DVD Image (.RVZ, .GCM, .ISO)",
                subtext: "Verifies 1,459,978,240-byte (712,880 LBA) DOL-006 layout, 32 KB ECC alignment, and 3.0 GB outer-edge laser padding.",
                primaryToggleLabel: "DVD-ROM Book Type + 32 KB ECC Alignment",
                secondaryToggleLabel: "Pad 1.46 GB Image to 3.0 GB Outer Edge",
                footerIcon: "cpu",
                footerNote: "Exact 80mm Mini-DVD Target: 1,459,978,240 Bytes (712,880 LBA)",
                usesDVDROMBitset: true
            )
        case "console-ps2":
            return ConsoleDeckDescriptor(
                narrowTitle: "PS2 MECHACON DECK",
                headline: "Drop PlayStation 2 Disc Image (.ISO, .CHD, .CUE + .BIN)",
                subtext: "Auto-detects PS2 CD-ROM (<700 MB Mode 2 XA) vs PS2 DVD-ROM (UDF 1.02 + ISO9660 Bridge) and SYSTEM.CNF boot ID.",
                primaryToggleLabel: "Stamp Book Type as DVD-ROM (PS2 Mechacon)",
                secondaryToggleLabel: "Apply ESR DVD-Video Descriptor Patch (FMCB)",
                footerIcon: "opticaldisc",
                footerNote: "Auto-Detects PS2 CD (<700 MB Mode 2 XA) vs PS2 DVD (UDF 1.02)",
                usesDVDROMBitset: true
            )
        case "console-xbox":
            return ConsoleDeckDescriptor(
                narrowTitle: "XBOX XDVDFS DECK",
                headline: "Drop Xbox Disc Image (.ISO, .XISO, .DVD)",
                subtext: "Verifies Microsoft XDVDFS partition headers, SS/DMI/PFI stealth sectors, and XGD2 (1913760) / XGD3 (2133520) layer breaks.",
                primaryToggleLabel: "DVD+R DL → DVD-ROM Bitset",
                secondaryToggleLabel: "Verify SS/DMI/PFI Stealth Security Sectors",
                footerIcon: "checkmark.shield.fill",
                footerNote: "XDVDFS Topology • Locks L0→L1 Layer Break (1913760 / 2133520)",
                usesDVDROMBitset: true
            )
        case "console-ps3":
            return ConsoleDeckDescriptor(
                narrowTitle: "PS3 BD-ROM (UDF 2.50)",
                headline: "Drop PlayStation 3 BD-ROM Image (.ISO or PS3_GAME Folder)",
                subtext: "Authors UDF 2.50 PlayStation 3 BD-ROM volumes with PS3_GAME / PS3_DISC.SFB headers and 32-sector Blu-ray ECC alignment.",
                primaryToggleLabel: "Generate PS3_DISC.SFB & Strict UDF 2.50 Layout",
                secondaryToggleLabel: "Disable BD Linear Defect Mgmt (Full-Speed Read)",
                footerIcon: "opticaldisc.fill",
                footerNote: "BD-R SL (25 GB) / DL (50 GB) • Verifies PS3_GAME/PARAM.SFO",
                usesDVDROMBitset: true
            )
        default:
            return ConsoleDeckDescriptor(
                narrowTitle: "CONSOLE CD/XA DECK",
                headline: "Drop Console Disc Image (.CUE + .BIN, .CHD, .CDI, .GDI)",
                subtext: "Verifies 2,352-byte Mode 2 XA sectors, System Area boot licenses, Red Book CD-DA 2s pre-gaps, and MIL-CD self-boot.",
                primaryToggleLabel: "DAO/96 Raw Mode 2 XA (2,352 B/sec + SubQ)",
                secondaryToggleLabel: "Auto-Expand .CHD / .CDI / .GDI Multi-Track Archives",
                footerIcon: "laser.burst",
                footerNote: "4x–8x CLV Guard Active • High-Reflectivity 700 MB CD-R Only",
                usesDVDROMBitset: false
            )
        }
    }

    var body: some View {
        let desc = descriptor
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store, paddingAmount: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: spec.sfSymbol).foregroundStyle(store.activeAccent)
                        Text(isCenterWorkspaceNarrow ? desc.narrowTitle : KroutonL10n.tr("RETRO CONSOLE HARDWARE MASTERING PROFILE"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Toggle(isCenterWorkspaceNarrow ? "OPC" : "Perform OPC Before Write", isOn: $romPerformOPCBeforeWrite)
                            .toggleStyle(.checkbox).font(.caption).fixedSize()
                    }
                    Divider().opacity(0.5)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .leading)], spacing: 6) {
                        Toggle(KroutonL10n.tr(desc.primaryToggleLabel), isOn: desc.usesDVDROMBitset ? $romBitsetDVDROM : $romWriteModeDAO96SubQ)
                            .toggleStyle(.checkbox).font(.caption.bold()).lineLimit(1)
                        Toggle(KroutonL10n.tr(desc.secondaryToggleLabel), isOn: $ps1AutoMergeMultiBinAndCHD)
                            .toggleStyle(.checkbox).font(.caption).lineLimit(1)
                    }
                    if spec.id == "console-wii" || spec.id == "console-xbox" {
                        HStack(spacing: 8) {
                            Text(spec.id == "console-wii" ? "Layer Mode:" : "Layer Break:").font(.caption.bold())
                            if spec.id == "console-wii" {
                                Picker("", selection: $wiiLayerMode) {
                                    Text("Auto (DVD5 / DVD9 DL)").tag("Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)")
                                    Text("Single-Layer DVD5").tag("Single-Layer DVD5")
                                    Text("Dual-Layer DVD9 (LBA 2084960)").tag("Dual-Layer DVD9")
                                }.labelsHidden().font(.caption)
                            } else {
                                Picker("", selection: $xboxLayerBreakPreset) {
                                    Text("Auto (.dvd Descriptor)").tag("Auto (.dvd / Calculate Optimal)")
                                    Text("XGD2 Lock (LBA 1913760)").tag("XGD2 (1913760)")
                                    Text("XGD3 Lock (LBA 2133520)").tag("XGD3 (2133520)")
                                }.labelsHidden().font(.caption)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    HStack(spacing: 12) {
                        Picker("Soft-Patch ROM:", selection: $selectedSoftPatch) {
                            ForEach(KroutonSoftPatchFormat.allCases) { fmt in Text(fmt.rawValue).tag(fmt) }
                        }.font(.caption).frame(width: 255)
                        Toggle("Export Compressed .CHD (LZMA+FLAC)", isOn: $exportCompanionCHD)
                            .toggleStyle(.checkbox).font(.caption.bold())
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: desc.footerIcon).font(.system(size: 10)).foregroundStyle(store.uiSecondaryAccent)
                        Text(desc.footerNote).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
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

                if store.stagedFiles.isEmpty {
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: spec.sfSymbol,
                        headline: isCenterWorkspaceNarrow ? "Drop Console Disc Image" : desc.headline,
                        subtitle: desc.subtext
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.stagedFiles) { entry in
                                let patchInfo = KroutonGaletteModule.evaluateRetroSoftPatchAndCHD(fileName: entry.name, byteSize: entry.byteSize, patchFormat: selectedSoftPatch, exportCHD: exportCompanionCHD)
                                let modeBadge = selectedSoftPatch == .none ? patchInfo.chdCompressionBadge : "\(patchInfo.chdCompressionBadge) • Patched \(patchInfo.patchedSectorCount) Sec (EDC \(patchInfo.edcChecksumHex) + P/Q ECC)"
                                HStack(spacing: 12) {
                                    Image(systemName: "opticaldisc.fill").foregroundStyle(store.activeAccent).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(entry.name).font(.system(size: 12, weight: .semibold))
                                            if entry.isConvertibleBinOrIso {
                                                Button(entry.conversionTargetLabel) { store.convertStagedBinOrIso(id: entry.id) }
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .buttonStyle(.bordered).controlSize(.mini)
                                            }
                                        }
                                        Text("\(entry.url.path) • \(modeBadge)").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(entry.sectorsLBA) LBA").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(store.activeAccent)
                                    Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                    Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                Divider()
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
        }
    }
}
