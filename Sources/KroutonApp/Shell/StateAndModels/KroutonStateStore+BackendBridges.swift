import AudioKit
import Combine
import Foundation
import ImageKit
import OpticalCore
import SwiftUI
import VideoKit

// MARK: - KroutonStateStore — Calls Into the Audio, Image and Video Modules
extension KroutonStateStore {
    func compileLiveAudioCueSheet(
        albumTitle: String = "",
        albumPerformer: String = "",
        mcnCatalog: String = "",
        tracks: [KroutonRedBookTrack] = []
    ) -> String {
        audioController.project.compileCueSheet() ?? KroutonAudioEngine.compileRedBookCueSheet(
            albumTitle: albumTitle,
            albumPerformer: albumPerformer,
            mcnCatalog: mcnCatalog,
            tracks: tracks
        )
    }

    func planLiveHybridDataLayout(
        volumeLabel: String = "",
        entries: [KroutonStagedFileEntry] = [],
        isElToritoBootable: Bool = false
    ) -> KroutonHybridLayoutPlan {
        KroutonHybridImagePlanner.planHybridDataLayout(
            volumeLabel: volumeLabel,
            entries: entries,
            isElToritoBootable: isElToritoBootable
        )
    }

    func computeLiveVideoBitrateBudget(
        durationSeconds: Double = 5400.0,
        audioKbps: Int = 448,
        medium: KroutonVideoTargetMedium = .dvd5SingleLayer
    ) -> KroutonVideoBitrateBudget {
        KroutonVideoAuthoringEngine.computeBitrateBudget(
            durationSeconds: max(60.0, durationSeconds),
            audioKbps: audioKbps,
            medium: medium
        )
    }

    func stampProjectTracklistOrManifestOnDisc(albumTitle: String = "", performer: String = "") {
        if !albumTitle.isEmpty { discVolumeTitle = albumTitle }
        if !performer.isEmpty { discPerformer = performer }
        Task { @MainActor in
            _ = await AutoLabelEngine.generateAndApply(to: self)
        }
    }
}
