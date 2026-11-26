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
///   There is no Mode 2 Form 2, CD+G subchannel or HFS-standard writer, so the formats that
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
        case .dataHybrid, .mp3CD, .dvdRAM:
            return .dataDisc
        case .dataUDFModern:
            // NOTE: DiscRecording writes UDF 1.02, not 2.60. Files over 4 GiB still land on the
            // UDF side. KroutonUDFImageWriter (UDF 2.50) could replace this path.
            return .dataDisc
        case .dataAppleAPFS:
            // NOTE: HFS+ (not APFS) alongside ISO/Joliet/UDF; no resource-fork or xattr handling.
            return .dataDisc
        case .dataRetroISO:
            // NOTE: no 8.3 enforcement; DiscRecording's ISO names may be long for DOS.
            return .dataDisc
        case .mdiscVault:
            // NOTE: a plain data disc; the PAR2 slider in the workspace creates no parity files.
            return .dataDisc
        case .dvdVideo:
            // NOTE: VIDEO_TS on DiscRecording's UDF 1.02 + ISO, without the VIDEO_TS file ordering
            // Krouton Server's writer guarantees. Most players read it; check one disc first.
            return .dataDisc

        case .imageBurn, .consoleWii, .consoleGC, .consolePS2, .consolePS1, .consolePS3, .consoleXbox,
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
            return .notYet("Enhanced CDs need a second, data session after the audio, which Krouton can't write yet. Choose Audio CD for the music alone. Nothing was written.")
        case .dtsCD:
            return .notYet("DTS CDs must carry the DTS stream bit for bit, and Krouton's audio path decodes and mixes every track, so it can't promise that yet. Nothing was written.")
        case .cdG:
            return .notYet("CD+G graphics live in the subchannel, which Krouton can't write yet. Choose Audio CD for the music alone. Nothing was written.")
        case .dvdAudio, .sacdR:
            return .notYet("DVD-Audio and SACD discs can't be made yet. Nothing was written.")
        case .videoSVCD, .vcdSVCD:
            return .notYet("Video CDs need Mode 2 Form 2 sectors, which Krouton can't write yet. Nothing was written.")
        case .photoCD:
            return .notYet("Kodak Photo CD discs can't be made. Nothing was written.")
        case .macos9HFS:
            return .notYet("Classic HFS discs with an Apple Partition Map can't be made yet; a data disc (HFS+) would not boot or open on Mac OS 9. Nothing was written.")
        }
    }
}
