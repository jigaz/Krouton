import AudioKit
import Combine
import Foundation
import ImageKit
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import VideoKit

// MARK: - Live Backend Engine Bridge Across Culinary Modules
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

    func computeLiveCDTextPackCount(
        albumTitle: String = "",
        albumPerformer: String = "",
        tracks: [KroutonRedBookTrack] = []
    ) -> Int {
        if let compiled = audioController.project.compileCDTextBlock() {
            return compiled.packs.count
        }
        let albumFields: [CDTextField: String] = [.title: albumTitle, .performer: albumPerformer]
        let trackFields: [[CDTextField: String]] = tracks.map { [.title: $0.title, .performer: $0.performer] }
        return (try? CDTextBlockCompiler.compile(CDTextInput(album: albumFields, tracks: trackFields)).packs.count) ?? 0
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
