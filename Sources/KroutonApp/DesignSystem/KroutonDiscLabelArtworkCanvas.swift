import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough
import Crustini

// MARK: - 120mm Optical Disc Label Studio Artwork Renderer (Primary + Secondary Harmony)
struct KroutonDiscLabelArtworkCanvas: View {
    let preset: KroutonSliceLabelGeometry
    let template: KroutonCroutonLabelStyle
    let title: String
    let subtitle: String
    let performer: String
    let mcnBarcode: String
    let trackLines: [String]
    let showTracklist: Bool
    let primaryColor: Color
    let harmonyColor: Color
    let isExportMode: Bool
    let diameterPoints: CGFloat

    var body: some View {
        let holeRatio = CGFloat(max(0.12, min(0.45, preset.innerDiameterMM / max(1.0, preset.outerDiameterMM))))
        let holeDiameter = diameterPoints * holeRatio

        ZStack {
            // 1. Base Disc Surface by Template
            switch template {
            case .synthGrid:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.08, green: 0.09, blue: 0.12),
                                Color(red: 0.04, green: 0.05, blue: 0.07)
                            ],
                            center: .center,
                            startRadius: holeDiameter * 0.4,
                            endRadius: diameterPoints * 0.52
                        )
                    )
                    .overlay(
                        Circle()
                            .fill(primaryColor.opacity(0.24))
                    )
            case .vinylGrooves:
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                primaryColor.opacity(0.85),
                                Color.black.opacity(0.92),
                                harmonyColor.opacity(0.75),
                                Color.black.opacity(0.92),
                                primaryColor.opacity(0.85)
                            ],
                            center: .center
                        )
                    )
            case .dualHalftone:
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, Color(red: 0.07, green: 0.08, blue: 0.10), harmonyColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            case .archivalSpec:
                Circle()
                    .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                    .overlay(
                        Circle().strokeBorder(primaryColor, lineWidth: diameterPoints * 0.035)
                    )
            }

            // 2. Precision CAD Grid / Concentric Telemetry Rings
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxR = size.width / 2

                if template == .synthGrid || template == .archivalSpec {
                    let step: CGFloat = size.width / 16.0
                    var grid = Path()
                    for x in stride(from: CGFloat(0), through: size.width, by: step) {
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat(0), through: size.height, by: step) {
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(
                        grid,
                        with: .color(template == .archivalSpec ? primaryColor.opacity(0.16) : harmonyColor.opacity(0.18)),
                        lineWidth: 0.75
                    )
                }

                // Concentric LBA / Groove rings
                for frac in [0.92, 0.78, 0.64, 0.46] {
                    let r = maxR * CGFloat(frac)
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    let ringPath = Path(ellipseIn: rect)
                    context.stroke(
                        ringPath,
                        with: .color(frac == 0.78 ? harmonyColor.opacity(0.65) : primaryColor.opacity(0.40)),
                        style: StrokeStyle(lineWidth: frac == 0.92 ? 2.0 : 1.0, dash: frac == 0.64 ? [5, 3] : [])
                    )
                }

                // Crosshair registration ticks around the hub
                var ticks = Path()
                ticks.move(to: CGPoint(x: center.x, y: size.height * 0.04))
                ticks.addLine(to: CGPoint(x: center.x, y: size.height * 0.12))
                ticks.move(to: CGPoint(x: center.x, y: size.height * 0.88))
                ticks.addLine(to: CGPoint(x: center.x, y: size.height * 0.96))
                ticks.move(to: CGPoint(x: size.width * 0.04, y: center.y))
                ticks.addLine(to: CGPoint(x: size.width * 0.12, y: center.y))
                ticks.move(to: CGPoint(x: size.width * 0.88, y: center.y))
                ticks.addLine(to: CGPoint(x: size.width * 0.96, y: center.y))
                context.stroke(ticks, with: .color(harmonyColor.opacity(0.75)), lineWidth: 1.2)
            }
            .clipShape(Circle())

            // 3. Disc Typography & Staged Tracklist Manifest (Left & Right of Spindle Hub)
            let fgText: Color = (template == .archivalSpec) ? Color.black.opacity(0.88) : .white
            let badgeBg: Color = (template == .archivalSpec) ? primaryColor : harmonyColor

            VStack(spacing: 2) {
                Text("KROUTON OPTICAL MASTER")
                    .font(.system(size: diameterPoints * 0.026, weight: .heavy, design: .monospaced))
                    .foregroundStyle(template == .archivalSpec ? primaryColor : harmonyColor)
                    .padding(.top, diameterPoints * 0.085)

                Text(title.isEmpty ? "KROUTON_DISC" : title)
                    .font(.system(size: diameterPoints * 0.046, weight: .black, design: .rounded))
                    .foregroundStyle(fgText)
                    .lineLimit(1)
                    .frame(maxWidth: diameterPoints * 0.68)

                Spacer()

                // Left & Right Wing Panels flanking the spindle hole
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DISC SPEC")
                            .font(.system(size: diameterPoints * 0.024, weight: .heavy, design: .monospaced))
                            .foregroundStyle(badgeBg)
                        Text("120mm OPTICAL")
                        Text("MCN \(mcnBarcode.prefix(8))")
                        Text("ECC VERIFIED")
                    }
                    .font(.system(size: diameterPoints * 0.023, weight: .bold, design: .monospaced))
                    .foregroundStyle(fgText.opacity(0.86))
                    .frame(width: diameterPoints * 0.27, alignment: .leading)

                    Spacer(minLength: holeDiameter + 14)

                    if showTracklist {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("MANIFEST")
                                .font(.system(size: diameterPoints * 0.024, weight: .heavy, design: .monospaced))
                                .foregroundStyle(badgeBg)
                            ForEach(Array(trackLines.prefix(5).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: diameterPoints * 0.022, weight: .semibold, design: .monospaced))
                        .foregroundStyle(fgText.opacity(0.88))
                        .frame(width: diameterPoints * 0.29, alignment: .leading)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PERFORMER")
                                .font(.system(size: diameterPoints * 0.024, weight: .heavy, design: .monospaced))
                                .foregroundStyle(badgeBg)
                            Text(performer)
                                .lineLimit(1)
                        }
                        .font(.system(size: diameterPoints * 0.024, weight: .bold, design: .monospaced))
                        .foregroundStyle(fgText.opacity(0.88))
                        .frame(width: diameterPoints * 0.27, alignment: .trailing)
                    }
                }
                .padding(.horizontal, diameterPoints * 0.06)

                Spacer()

                Text(subtitle.isEmpty ? "ISO9660 / UDF / RED BOOK MASTER" : subtitle)
                    .font(.system(size: diameterPoints * 0.030, weight: .bold, design: .monospaced))
                    .foregroundStyle(fgText.opacity(0.90))
                    .lineLimit(1)
                    .frame(maxWidth: diameterPoints * 0.64)

                Text(String(format: "OUTER %.0fMM • HUB %.0fMM", preset.outerDiameterMM, preset.innerDiameterMM))
                    .font(.system(size: diameterPoints * 0.023, weight: .heavy, design: .monospaced))
                    .foregroundStyle(template == .archivalSpec ? primaryColor : harmonyColor)
                    .padding(.bottom, diameterPoints * 0.085)
            }
            .frame(width: diameterPoints, height: diameterPoints)

            // 4. Outer Polycarbonate Rim & Clamping Ring + Center Spindle Cutout
            Circle()
                .strokeBorder(harmonyColor.opacity(0.75), lineWidth: 2.0)
                .frame(width: diameterPoints, height: diameterPoints)

            Circle()
                .stroke(primaryColor.opacity(0.55), style: StrokeStyle(lineWidth: 3.0, dash: [6, 3]))
                .frame(width: holeDiameter + 18, height: holeDiameter + 18)

            Circle()
                .fill(isExportMode ? Color.white : Color.kroutonWindowSurface)
                .frame(width: holeDiameter, height: holeDiameter)
                .overlay(
                    Circle()
                        .stroke(harmonyColor.opacity(0.85), lineWidth: 1.5)
                )
        }
        .frame(width: diameterPoints, height: diameterPoints)
        .clipShape(Circle())
    }
}


// MARK: - Native SwiftUI .fileExporter Bridge for 300-DPI 120mm Disc Label PNG
struct KroutonPNGFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var pngData: Data

    init(pngData: Data = Data()) {
        self.pngData = pngData
    }

    init(configuration: ReadConfiguration) throws {
        self.pngData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: pngData)
    }
}

@MainActor
final class KroutonLabelExportBridge: ObservableObject {
    static let shared = KroutonLabelExportBridge()
    @Published var isShowingExporter: Bool = false
    @Published var document: KroutonPNGFileDocument = KroutonPNGFileDocument()
    @Published var defaultFilename: String = "Krouton_120mm_Label.png"

    func presentPNGExport(pngData: Data, defaultFilename: String) {
        self.document = KroutonPNGFileDocument(pngData: pngData)
        self.defaultFilename = defaultFilename
        self.isShowingExporter = true
    }
}

struct KroutonLabelExportSheetModifier: ViewModifier {
    @ObservedObject private var bridge = KroutonLabelExportBridge.shared
    func body(content: Content) -> some View {
        content.fileExporter(
            isPresented: $bridge.isShowingExporter,
            document: bridge.document,
            contentType: .png,
            defaultFilename: bridge.defaultFilename
        ) { result in
            if case .success(let outURL) = result {
                KroutonOSDesktopBridge.revealURLsInFinder([outURL])
            }
        }
    }
}
