import Foundation

// MARK: - What Burning Each Format Actually Produces

/// What pressing Burn does for a format today. This is the one place that says so: the burn
/// path (`KroutonStateStore.runTargetDestination`) refuses `.notYet` formats instead of quietly
/// writing a data disc, the manual's "still being built" list follows it, and the status sheet
/// (formats × functionality × UI) was drawn from it.
///
/// Programmer's notes (audit, November 2026):
/// - Every local burn goes through `KroutonOpticalDriveBank.startPhysicalDataBurn`, which writes
///   either a data disc (DiscRecording: ISO 9660 + Joliet, plus UDF 1.02 on DVD/BD, plus HFS+)
///   or, when exactly one burnable image is staged, that image sector for sector.
///   There is no Mode 2 Form 2 writer, so the formats that
///   need one are `.notYet`.
/// - Audio CDs (`.audioCD`, since 2026-11): `KroutonAudioDiscRenderer` (AudioKit) renders the
///   Audio CD editor's project — pauses, crossfades, trims — to one PCM file per track, and
///   `startPhysicalDataBurn(audioDisc:)` writes them session-at-once with ISRCs, the catalog
///   number and CD-Text. The burned disc is the editor's project, not the deck's file list.
public enum KroutonBurnSupport: Sendable, Equatable {
    /// The staged files become a data disc.
    case dataDisc
    /// One staged disc image is written as it is (and nothing else is accepted).
    case discImage
    /// A BDMV folder is written as a UDF 2.50 image (`KroutonUDFImageWriter`), then burned.
    case bluRayVideo
    /// The Audio CD editor's project is rendered and burned as Red Book audio tracks.
    case audioCD
    /// Burning the staged files would give the wrong kind of disc; the reason says what to do.
    case notYet(String)

    public var isBurnable: Bool {
        if case .notYet = self { return false }
        return true
    }

    public var refusal: String? {
        if case .notYet(let reason) = self { return reason }
        return nil
    }
}

extension KroutonFormatID {
    public var burnSupport: KroutonBurnSupport {
        switch self {
        // Data discs. Some promise more than DiscRecording gives them; see each note.
        case .dataHybrid, .dvdRAM:
            return .dataDisc
        case .mp3CD:
            // A data disc of the folder `KroutonCarAudioDiscPreparer` (VideoKit) builds: converted
            // with ffmpeg's LAME, renamed in play order, with PLAYLIST.M3U.
            return .dataDisc
        case .dataUDFModern:
            // The staged files as one UDF 2.50 image (`KroutonUDFImageWriter`), burned as an
            // image: files of any size, no ISO 9660 side (`KroutonStateStore.burnInputFiles`).
            return .dataDisc
        case .dataAppleAPFS:
            // The hybrid disc (HFS+ beside ISO/Joliet/UDF); there is no APFS on optical media.
            return .dataDisc
        case .dataRetroISO:
            // ISO 9660 Level 1 (8.3 names) via DiscRecording's DRISOLevel, on this Mac's burners
            // only; disc images and Krouton Server are refused for it.
            return .dataDisc
        case .mdiscVault:
            // A data disc with par2 recovery files beside the data when the PAR2 slider is above
            // Off (`KroutonParityWriter`, needs par2 from Homebrew).
            return .dataDisc
        case .dvdVideo:
            // VIDEO_TS as ISO 9660 level 1 + UDF 1.02 with the files in player order, by
            // `KroutonUDFImageWriter` (.dvdVideo) here and by Krouton Server's own writer remotely.
            return .dataDisc

        case .imageBurn, .consoleWii, .consoleGC, .consolePS2, .consolePS1, .consoleXbox,
             .consoleSaturn, .console3DO:
            return .discImage
        case .consoleDC:
            return .notYet("Dreamcast .cdi and .gdi images can't be burned yet: they need an audio session and a data session written raw.")

        case .bd25, .bd50, .bdUHD:
            return .bluRayVideo
        case .bdOnDVD:
            return .notYet("Click Make Disc Image in the AVCHD panel. It converts the videos, then opens the disc image in Burn Disc Image.")

        case .cdDA:
            return .audioCD
        case .cdExtra:
            // The audio path plus a second, data session in the same burn: DiscRecording gets a
            // layout of two sessions (the rendered tracks, then an ISO 9660 + Joliet folder track
            // with the CD-Extra files and a CDPLUS folder). The data track is Mode 1; the Blue
            // Book asks for Mode 2 XA, which DiscRecording's folder tracks don't write, but Mac
            // and Windows read Mode 1 the same. Local drives only.
            return .audioCD
        case .dtsCD:
            // The audio path, held to bit-exact input: `KroutonStateStore.burnRefusal` accepts only
            // CD-format WAV files and no crossfades, so every sample is copied unchanged.
            return .audioCD
        case .dvdAudio:
            return .notYet("DVD-Audio discs can't be made yet. Nothing was written.")
        case .vcdSVCD:
            return .notYet("Video CDs need Mode 2 Form 2 sectors, which Krouton can't write yet. Nothing was written.")
        case .photoCD:
            return .notYet("Kodak Photo CD discs can't be made. Nothing was written.")
        case .macos9HFS:
            // A classic HFS volume in an Apple Partition Map with resource forks and Finder info
            // (`KroutonHFSImageWriter`), burned as a .cdr image.
            return .dataDisc
        }
    }
}
