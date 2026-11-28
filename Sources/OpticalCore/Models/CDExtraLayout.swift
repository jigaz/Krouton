import Foundation

// MARK: - CD-Extra (Blue Book) layout

/// The room an Enhanced CD needs: the audio session, the gap the second session costs, then the
/// data. A CD player reads only the first session; computers mount the data in the second.
///
/// Red Book / Orange Book figures, in 2,352-byte frames (75 a second): the first session's
/// lead-out on a multisession disc is 6,750 frames (90 s), every later lead-in 4,500 (60 s) and
/// lead-out 2,250 (30 s), and the data track starts after a 150-frame pregap. So the data
/// session costs 13,650 frames (about 30 MB) before its first file.
public enum KroutonCDExtraLayout {
    /// Lead-out after the audio session on a multisession disc (90 s).
    public static let firstLeadOutFrames: Int64 = 6_750
    /// Lead-in of the data session (60 s).
    public static let laterLeadInFrames: Int64 = 4_500
    /// Lead-out of the data session (30 s).
    public static let laterLeadOutFrames: Int64 = 2_250
    /// Pregap before the data track (2 s).
    public static let dataPregapFrames: Int64 = 150
    /// Frames the second session costs before its first file: 13,650.
    public static let sessionOverheadFrames = firstLeadOutFrames + laterLeadInFrames + laterLeadOutFrames + dataPregapFrames

    /// Sectors (2,048 bytes of data each) for the files, plus about 2 % and 1 MB for the
    /// ISO 9660 and Joliet directories, as the data-disc room check allows.
    public static func dataSectors(forBytes bytes: Int64) -> Int64 {
        let withDirectories = bytes + bytes / 50 + 1_048_576
        return (withDirectories + 2_047) / 2_048
    }

    /// Frames the whole disc needs from its first audio frame.
    public static func framesNeeded(audioFrames: Int64, dataBytes: Int64) -> Int64 {
        audioFrames + sessionOverheadFrames + dataSectors(forBytes: dataBytes)
    }

    /// Nil when it fits; otherwise how many seconds of audio (or how much data) to take off.
    public static func overflowMessage(audioFrames: Int64, dataBytes: Int64, capacityFrames: Int64) -> String? {
        let needed = framesNeeded(audioFrames: audioFrames, dataBytes: dataBytes)
        guard needed > capacityFrames else { return nil }
        let over = needed - capacityFrames
        let seconds = (over + 74) / 75
        let megabytes = max(1, over * 2_048 / 1_000_000)
        return "The audio, the data and the second session's lead-in and lead-out need \(seconds) seconds more than this disc holds (about \(megabytes) MB of data). Take off a track or some files. Nothing was written."
    }
}
