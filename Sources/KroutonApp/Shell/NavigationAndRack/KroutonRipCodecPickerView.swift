import AudioKit
import SwiftUI

// MARK: - Rip Codec Picker

/// The four formats Krouton rips to, for the Copy workspace and the queue's rip cards.
struct KroutonRipCodecPickerView: View {
    @Binding var codec: KroutonRipCodec

    var body: some View {
        Picker("Format", selection: $codec) {
            ForEach(KroutonRipCodec.allCases) { option in
                Self.label(for: option).tag(option)
            }
        }
        .labelsHidden()
        .font(.caption)
    }

    /// Literals, so the String Catalog picks the names up.
    static func label(for codec: KroutonRipCodec) -> Text {
        switch codec {
        case .flac: return Text("FLAC (Lossless)")
        case .alac: return Text("Apple Lossless (ALAC)")
        case .wav: return Text("WAV (Uncompressed PCM)")
        case .aiff: return Text("AIFF (1:1 Red Book PCM)")
        }
    }
}
