import AudioKit
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

        let currentTitle = store.discVolumeTitle.isEmpty ? store.labelDiscTitle : store.discVolumeTitle
        let currentArtist = store.discPerformer.isEmpty ? store.labelSubtitle : store.discPerformer

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
        return composed.summary
    }
}
