import Foundation
import Observation

/// Feature model owning optical rip/extraction parameters, VideoOven fit-to-disc options, and LAN server settings.
@Observable
@MainActor
final class RipSettings {
    var defaultCrossfadeSec: Double = 3.5
    var autoBeatmatchSoundAnalysis: Bool = true
    var carSafeMP3Mode: Bool = true
    var singleVideoFirstPlay: Bool = true
    var fitToDiscPreserveMenus: Bool = true
    var fitToDiscStripForeignDubs: Bool = true
    var videoToolboxTwoPassVBR: Bool = true

    var driveReadOffsetSamples: Int = 48
    var paranoiaErrorRetries: Int = 16
    var verifyAccurateRip: Bool = true
    var writeCueSheetLog: Bool = true
    var hardwareDeinterlaceVideo: Bool = true
    var passthroughAtmosTrueHD: Bool = true
    var namingTokens: [String] = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]

    var enableNetworkServerSharing: Bool = true
    var serverRingBufferMB: Double = 256.0
    var preStageImageToServerSSD: Bool = true
    var forceDVDROMBookType: Bool = true
    var disableBDDefectManagementForVideo: Bool = true

    init() {}

    var namingPreviewString: String {
        let joined = namingTokens.joined()
        return joined.isEmpty ? "" : "\(joined).flac"
    }
}
