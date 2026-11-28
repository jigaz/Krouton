import Foundation
import LabelKit
import OpticalCore
import SwiftUI

@MainActor
enum AutoLabelEngine {
    @discardableResult
    static func generateAndApply(to store: KroutonStateStore) async -> String {
        let items: [AutoLabelInputItem] = {
            if !store.redBookTracks.isEmpty {
                return store.redBookTracks.map {
                    AutoLabelInputItem(
                        url: $0.url,
                        title: $0.title,
                        performer: $0.performer,
                        durationSeconds: $0.durationSeconds
                    )
                }
            }
            return store.stagedFiles.map {
                AutoLabelInputItem(
                    url: $0.url,
                    title: $0.name,
                    performer: "",
                    durationSeconds: 0
                )
            }
        }()

        var currentTitle = store.discVolumeTitle.isEmpty ? store.labelDiscTitle : store.discVolumeTitle
        var currentArtist = store.discPerformer.isEmpty ? store.labelSubtitle : store.discPerformer
        // A raw volume or file name ("SUMMER_2026_FINAL") becomes words with the on-device model.
        // A title the person typed on the label is theirs, and stays.
        var tidied = false
        let typedByPerson = store.discVolumeTitle.isEmpty && !store.labelDiscTitle.isEmpty
        if !typedByPerson, KroutonLabelSuggester.needsTidying(currentTitle),
           let suggestion = await KroutonLabelSuggester.suggest(volumeName: currentTitle, performer: currentArtist,
                                                                itemNames: items.map(\.title)) {
            if !suggestion.title.isEmpty { currentTitle = suggestion.title }
            if currentArtist.isEmpty { currentArtist = suggestion.subtitle }
            if store.autoLabelSearchQuery.isEmpty { store.autoLabelSearchQuery = suggestion.artworkQuery }
            tidied = true
        }

        let composed = await AutoLabelComposer.compose(
            albumTitle: currentTitle,
            albumPerformer: currentArtist,
            formatBadge: store.selectedTaskID.uppercased(),
            items: items
        )

        store.labelWorkspaceSubStore.recordUndoSnapshot(from: store)
        store.labelDiscTitle = composed.titleText
        if !composed.subtitleText.isEmpty {
            store.labelSubtitle = composed.subtitleText
        }
        return tidied ? composed.summary + KroutonL10n.tr("; title tidied on this Mac by Apple Intelligence") : composed.summary
    }
}
