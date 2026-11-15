import Foundation

/// Feature model owning optical rip/extraction parameters, VideoOven fit-to-disc options, and LAN server settings.
public struct RipSettings: Equatable, Sendable {
    public var defaultCrossfadeSec: Double = 3.5
    public var autoBeatmatchSoundAnalysis: Bool = true
    public var carSafeMP3Mode: Bool = true
    public var singleVideoFirstPlay: Bool = true
    public var fitToDiscPreserveMenus: Bool = true
    public var fitToDiscStripForeignDubs: Bool = true
    public var videoToolboxTwoPassVBR: Bool = true

    public var driveReadOffsetSamples: Int = 48
    public var paranoiaErrorRetries: Int = 16
    public var verifyAccurateRip: Bool = true
    public var writeCueSheetLog: Bool = true
    public var hardwareDeinterlaceVideo: Bool = true
    public var passthroughAtmosTrueHD: Bool = true
    public var namingTokens: [String] = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]

    public var enableNetworkServerSharing: Bool = true
    public var serverRingBufferMB: Double = 256.0
    public var preStageImageToServerSSD: Bool = true
    public var forceDVDROMBookType: Bool = true
    public var disableBDDefectManagementForVideo: Bool = true

    public init() {}

    public var namingPreviewString: String {
        let joined = namingTokens.joined()
        return joined.isEmpty ? "" : "\(joined).flac"
    }
}
