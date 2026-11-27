import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - RetroConsoleWorkspaces

/// Console disc images: Krouton reads each image's own header to say what it is, and tells you
/// plainly what a burned copy will and won't do on the real console.
struct KroutonRetroConsoleWorkspaceView: View {
    var store: KroutonStateStore
    let spec: KroutonOpticalWorkflowSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var identities: [UUID: KroutonConsoleDisc] = [:]

    private var acceptedTypes: String {
        switch spec.id {
        case "console-wii", "console-gc", "console-ps2", "console-xbox": return ".iso"
        case "console-dc": return ".cdi (audio + data) or .cue/.bin (.gdi is identified but not burned)"
        default: return ".cue/.bin"
        }
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store, paddingAmount: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: spec.sfSymbol).foregroundStyle(store.activeAccent)
                        Text(KroutonL10n.tr("CONSOLE DISC IMAGES"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    Text("Drop your own \(acceptedTypes) image. Krouton reads its header to tell you what it is, then burns it exactly as it is. Consoles were built to refuse burned discs, so each image below says what the console needs to play one.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
                        headline: "Drop a \(spec.colloquialName) disc image",
                        subtitle: "Homebrew boot discs such as Swiss, Unirom and DreamShell are in the Disc Image Depot."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.stagedFiles) { entry in
                                stagedRow(entry, identity: identities[entry.id])
                                Divider()
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
        }
        .task(id: store.stagedFiles.map(\.id)) {
            let entries = store.stagedFiles.map { ($0.id, $0.url) }
            let found = await Task.detached(priority: .utility) {
                Dictionary(entries.map { ($0.0, KroutonConsoleDiscIdentifier.identify(url: $0.1)) }, uniquingKeysWith: { first, _ in first })
            }.value
            identities = found
        }
    }

    // MARK: - Staged Image Row

    @ViewBuilder
    private func stagedRow(_ entry: KroutonStagedFileEntry, identity: KroutonConsoleDisc?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: identity?.canBurn == false ? "exclamationmark.triangle.fill" : "opticaldisc.fill")
                .foregroundStyle(identity?.canBurn == false ? Color.orange : store.activeAccent).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.system(size: 12, weight: .semibold))
                    if entry.isConvertibleBinOrIso {
                        Button(entry.conversionTargetLabel) { store.convertStagedBinOrIso(id: entry.id) }
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .buttonStyle(.bordered).controlSize(.mini)
                    }
                }
                if let identity {
                    Text(Self.summary(of: identity))
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(store.activeAccent)
                    Text(identity.advice)
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Burn to: \(identity.recommendedMedia)")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    Text("Reading the image header…").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain).accessibilityLabel(KroutonL10n.tr("Remove Item")).help(KroutonL10n.tr("Remove Item"))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    static func summary(of disc: KroutonConsoleDisc) -> String {
        guard disc.platform != .unknown else { return "Not a console disc Krouton recognises" }
        var parts = ["\(disc.platform.rawValue) disc"]
        if let title = disc.title { parts.append(title) }
        if let id = disc.gameID { parts.append(id) }
        if let region = disc.region { parts.append(region) }
        return parts.joined(separator: " · ")
    }
}
