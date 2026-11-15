import SwiftUI
import UniformTypeIdentifiers
import AudioKit
import OpticalCore

// MARK: - Multi-Track Batch Selection Bar & Inline Disc 2+ Spanning Header Card

struct AudioBatchSelectionActionBarView: View {
    @ObservedObject var store: KroutonStateStore
    let controller: AudioProjectController
    @Binding var selectedTrackIDs: Set<UUID>
    @Binding var isrcDrafts: [UUID: String]
    @Binding var invalidISRCTrackIDs: Set<UUID>

    @State private var showISRCBatchPopover: Bool = false
    @State private var batchISRCSeed: String = ""

    private var project: AudioProject { controller.project }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(store.activeAccent)
                Text("\(selectedTrackIDs.count) Selected")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            }

            Divider().frame(height: 14)

            Text("Transitions:")
                .kroutonReadout()

            Button("Gapless (0s)") {
                controller.applyBatchTransition(to: selectedTrackIDs, actionName: "Batch Set Gapless") {
                    $0.switched(to: .gapless)
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))

            Button("2s Pause") {
                controller.applyBatchTransition(to: selectedTrackIDs, actionName: "Batch Set 2s Pause") {
                    var s = $0.switched(to: .gap)
                    s.preGapSeconds = 2.0
                    return s
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))

            Button("2.5s X-Fade") {
                controller.applyBatchTransition(to: selectedTrackIDs, actionName: "Batch Set Crossfade") {
                    $0.switched(to: .crossfade)
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))

            Divider().frame(height: 14)

            Button("Use Album Artist") {
                guard !project.albumPerformer.isEmpty else { return }
                controller.applyBatchPerformer(project.albumPerformer, to: selectedTrackIDs)
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))
            .disabled(project.albumPerformer.isEmpty)
            .help("Stamp the Album Artist onto all checked tracks")

            Button("Auto-ISRC…") {
                showISRCBatchPopover.toggle()
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: showISRCBatchPopover))
            .popover(isPresented: $showISRCBatchPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SEQUENTIAL ISO 3901 ISRC GENERATOR")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    Text("Assigns incrementing 12-char ISRCs to the \(selectedTrackIDs.count) selected track(s) in disc order.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("CCXXXYYNNNNN (12 chars)", text: $batchISRCSeed)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 140)
                        Button("Apply") {
                            let applied = controller.assignSequentialISRCs(baseISRC: batchISRCSeed, to: selectedTrackIDs)
                            if applied > 0 {
                                isrcDrafts.removeAll()
                                invalidISRCTrackIDs.removeAll()
                                showISRCBatchPopover = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(store.activeAccent)
                        .controlSize(.small)
                        .disabled(batchISRCSeed.filter { !$0.isWhitespace && $0 != "-" }.count != 12)
                    }
                }
                .padding(12)
                .frame(width: 310)
            }

            Button("Clear Sub-Indexes") {
                controller.applyBatchTransition(to: selectedTrackIDs, actionName: "Clear Sub-Indexes") {
                    var s = $0
                    s.subIndexRatios.removeAll()
                    return s
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))

            Spacer(minLength: 4)

            Button {
                let ids = selectedTrackIDs
                selectedTrackIDs.removeAll()
                controller.removeTracks(ids)
                for id in ids { store.removeStagedFile(id: id) }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "trash")
                    Text("Remove (\(selectedTrackIDs.count))")
                }
            }
            .buttonStyle(KroutonPillButtonStyle(isOn: false))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(store.activeAccent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.activeAccent.opacity(0.35), lineWidth: 1)
        )
    }
}

struct AudioAdditionalDiscHeaderView: View {
    @ObservedObject var store: KroutonStateStore
    let controller: AudioProjectController
    let disc: AudioDisc
    let totalDiscs: Int
    let isProvisional: Bool
    let splitsContinuousRun: Bool

    var body: some View {
        let dNum = disc.number
        let usedStr = KroutonMarmaladeModule.formatFramesToMMSSFF(disc.usedFrames)
        let capStr = KroutonMarmaladeModule.formatFramesToMMSSFF(disc.capacityFrames)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "opticaldisc.fill")
                    .foregroundStyle(store.uiSecondaryAccent)
                Text(String(format: "DISC %d OF %d (%d Tracks • %@ / %@)", dNum, totalDiscs, disc.tracks.count, usedStr, capStr))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(store.uiSecondaryAccent)
                Spacer()
                if isProvisional {
                    Text("PROVISIONAL")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.25))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                if splitsContinuousRun {
                    Label("Splits continuous transition", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                }
                if disc.startedBecause == .manual, let firstTrack = disc.tracks.first {
                    Button("Merge Into Disc \(dNum - 1)") {
                        controller.toggleManualDiscBreak(before: firstTrack.id)
                    }
                    .buttonStyle(KroutonPillButtonStyle(isOn: false))
                } else {
                    Text(disc.startedBecause == .itemLimit ? "99-Track Limit" : "Auto-Spanned (Disc \(dNum - 1) Full)")
                        .kroutonReadout()
                }
            }

            HStack(spacing: 10) {
                Text("Disc \(dNum) Album:").font(.caption.bold())
                TextField("Disc \(dNum) Album Title (≤60 Latin-1 chars)", text: controller.discTitleBinding(forDisc: dNum))
                    .textFieldStyle(.roundedBorder)

                Text("Artist:").font(.caption.bold())
                TextField("Disc \(dNum) Performer", text: controller.discPerformerBinding(forDisc: dNum))
                    .textFieldStyle(.roundedBorder)

                Text("UPC/EAN:").font(.caption.bold())
                TextField("12/13 digits", text: controller.discUPCBinding(forDisc: dNum))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 125)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            ZStack {
                Color.black.opacity(0.32)
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

struct AudioTrackReorderDropDelegate: DropDelegate {
    let targetTrackID: UUID
    let controller: AudioProjectController
    @Binding var draggedTrackID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedTrackID,
              draggedID != targetTrackID,
              let fromIdx = controller.project.index(of: draggedID),
              let toIdx = controller.project.index(of: targetTrackID) else { return }
        withAnimation(.easeInOut(duration: 0.14)) {
            controller.moveTrack(from: fromIdx, to: toIdx)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTrackID = nil
        return true
    }
}
