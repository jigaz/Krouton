import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Dual-Swatch Primary / Secondary Harmony Toggle Switch
struct KroutonDualHarmonySwitch: View {
    @Binding var isOn: Bool
    let primaryColor: Color
    let secondaryColor: Color

    var body: some View {
        Button {
            withAnimation(kroutonMotion(.spring(response: 0.24, dampingFraction: 0.78))) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                // Left Side: Primary Swatch Color
                HStack(spacing: 4) {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 8, height: 8)
                    Text("PRIMARY")
                        .font(.system(size: 9, weight: isOn ? .medium : .bold, design: .monospaced))
                        .foregroundStyle(isOn ? Color.secondary : primaryColor)
                }

                // Dual-Color Capsule Track + Sliding Thumb
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: primaryColor.opacity(isOn ? 0.50 : 0.88), location: 0.0),
                                    .init(color: primaryColor.opacity(0.45), location: 0.48),
                                    .init(color: secondaryColor.opacity(0.55), location: 0.52),
                                    .init(color: secondaryColor.opacity(isOn ? 0.92 : 0.40), location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [primaryColor.opacity(0.85), secondaryColor.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.1
                                )
                        )

                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 1, height: 12)

                    HStack {
                        if isOn { Spacer(minLength: 0) }
                        Circle()
                            .fill(isOn ? secondaryColor : primaryColor)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.90), lineWidth: 1.4))
                            .shadow(color: (isOn ? secondaryColor : primaryColor).opacity(0.55), radius: 4, x: 0, y: 1)
                        if !isOn { Spacer(minLength: 0) }
                    }
                    .padding(.horizontal, 2.5)
                }
                .frame(width: 48, height: 22)

                // Right Side: Secondary Harmony Color
                HStack(spacing: 4) {
                    Text("HARMONY")
                        .font(.system(size: 9, weight: isOn ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(isOn ? secondaryColor : Color.secondary)
                    Circle()
                        .fill(secondaryColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isOn ? secondaryColor.opacity(0.45) : primaryColor.opacity(0.30),
                                lineWidth: 1
                            )
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pure SwiftUI FileDocument for Non-Blocking Krumb Artifact Exports
struct SpoolPlainTextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .log] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let str = String(data: data, encoding: .utf8) {
            self.text = str
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
