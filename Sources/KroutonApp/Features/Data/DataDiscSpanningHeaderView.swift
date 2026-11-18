import OpticalCore
import SwiftUI

/// Reusable disc boundary header banner for Data & Archival multi-disc spanning,
/// mirroring Audio CD's `AudioDiscHeaderBannerView` visual language.
struct DataDiscHeaderBannerView: View {
    var store: KroutonStateStore
    let disc: PlannedDisc<KroutonStagedFileEntry>
    let totalDiscs: Int
    let medium: KroutonSpanningDiscMedium
    let hasOversizeItem: Bool

    var body: some View {
        let dNum = disc.number
        let usedBytes = disc.usedUnits * 2048
        let capBytes = disc.capacityUnits * 2048
        let usedStr = ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
        let capStr = ByteCountFormatter.string(fromByteCount: capBytes, countStyle: .file)
        let defaultLabel = DiscSpanningEngine.resolvedDiscVolumeLabel(
            baseTitle: store.discVolumeTitle,
            customTitle: nil,
            discNumber: dNum,
            totalDiscs: totalDiscs
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "opticaldisc.fill")
                    .foregroundStyle(store.uiSecondaryAccent)
                Text(String(format: "DISC %d OF %d (%d Items • %@ / %@)", dNum, totalDiscs, disc.items.count, usedStr, capStr))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(store.uiSecondaryAccent)
                Spacer()

                if hasOversizeItem {
                    Label("Exceeds single \(medium.rawValue) capacity", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                }

                if disc.startedBecause == .manual, let firstItem = disc.items.first {
                    Button("Merge Into Disc \(dNum - 1)") {
                        store.toggleDataManualDiscBreak(before: firstItem.id)
                    }
                    .buttonStyle(KroutonPillButtonStyle(isOn: false))
                } else if dNum > 1 {
                    Text("Auto-Spanned (Disc \(dNum - 1) Full)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text(medium.rawValue)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Text("Disc \(dNum) Volume:").font(.caption.bold()).fixedSize()
                TextField(defaultLabel, text: store.dataDiscVolumeBinding(forDisc: dNum))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 230)

                if dNum == 1, let secondItem = disc.items.dropFirst().first {
                    Spacer()
                    Button {
                        store.toggleDataManualDiscBreak(before: secondItem.id)
                    } label: {
                        Label("Insert Disc Break", systemImage: "scissors")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(KroutonPillButtonStyle(isOn: false))
                    .help("Split subsequent staged items onto Disc 2")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Color.black.opacity(0.30)
                store.uiSecondaryAccent.opacity(0.11)
            }
        )
        .overlay(alignment: .top) {
            Rectangle().fill(store.uiSecondaryAccent.opacity(0.65)).frame(height: 1.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(store.uiSecondaryAccent.opacity(0.35)).frame(height: 1)
        }
    }
}
