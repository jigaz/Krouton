import OpticalCore
import SwiftUI

struct KroutonWorkflowBlueprintView: View {
    let item: KroutonDepotCatalogItem
    let accent: Color
    let isNarrow: Bool
    var useHarmony: Bool = true

    var body: some View {
        let activeStore = KroutonStateStore.shared
        let presetID = activeStore?.selectedAccentIndex ?? 6
        let effectiveID = presetID >= 0 ? presetID : (activeStore.map { $0.multicolorPresetID(forTaskID: $0.selectedTaskID, category: $0.selectedCategory) } ?? 6)
        let secondary = useHarmony ? KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark) : accent

        Canvas { context, size in
            let step: CGFloat = 18
            var grid = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: step) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: step) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(secondary.opacity(0.045)), lineWidth: 0.5)

            let cx: CGFloat = isNarrow ? size.width * 0.79 : size.width * 0.62
            let cy: CGFloat = size.height * 0.53
            let primaryStroke = secondary
            let primaryFill = secondary.opacity(0.24)
            let accentStroke = accent
            let accentFill = accent.opacity(0.36)
            let faintStroke = secondary.opacity(0.18)

            let glowR: CGFloat = 180
            context.fill(
                Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [accent.opacity(0.30), secondary.opacity(0.12), Color.clear]),
                    center: CGPoint(x: cx, y: cy), startRadius: 6, endRadius: glowR
                )
            )

            for r in [CGFloat(96), CGFloat(68), CGFloat(38), CGFloat(16)] {
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(r == 68 ? accentStroke.opacity(0.65) : faintStroke),
                    style: StrokeStyle(lineWidth: r == 68 ? 1.4 : 0.9, dash: r == 96 ? [8, 4, 2, 4] : [])
                )
            }

            let key = (item.id + " " + item.title + " " + item.channel).lowercased()
            let sectorCount = key.contains("console") ? 6 : (key.contains("linux") || key.contains("bsd") ? 8 : 4)
            for i in 0..<sectorCount {
                let baseDeg = Double(i) * (360.0 / Double(sectorCount)) - 22.0
                var wedge = Path()
                wedge.addArc(center: CGPoint(x: cx, y: cy), radius: 84, startAngle: .degrees(baseDeg), endAngle: .degrees(baseDeg + 24.0), clockwise: false)
                wedge.addArc(center: CGPoint(x: cx, y: cy), radius: 44, startAngle: .degrees(baseDeg + 24.0), endAngle: .degrees(baseDeg), clockwise: true)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(i % 2 == 0 ? accentFill : primaryFill))
                context.stroke(wedge, with: .color(i % 2 == 0 ? accentStroke : primaryStroke), lineWidth: 1.5)

                let rad = baseDeg * .pi / 180.0
                let pt = CGPoint(x: cx + CGFloat(cos(rad)) * 84, y: cy + CGFloat(sin(rad)) * 84)
                let handle = CGPoint(x: cx + CGFloat(cos(rad + 0.18)) * 102, y: cy + CGFloat(sin(rad + 0.18)) * 102)
                drawCADNode(context: &context, pt, handle: handle, primaryStroke: primaryStroke, accent: accent)
            }

            let hubRect = CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44)
            context.fill(Path(ellipseIn: hubRect), with: .color(primaryFill))
            context.stroke(Path(ellipseIn: hubRect), with: .color(accentStroke), lineWidth: 2.2)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .clear, location: 0.22),
                    .init(color: .black.opacity(0.70), location: 0.40),
                    .init(color: .black, location: 0.60),
                    .init(color: .black.opacity(0.88), location: 0.88),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        )
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowsHitTesting(false)
    }

    private func drawCADNode(context: inout GraphicsContext, _ pt: CGPoint, handle: CGPoint, primaryStroke: Color, accent: Color) {
        var ln = Path()
        ln.move(to: pt); ln.addLine(to: handle)
        context.stroke(ln, with: .color(primaryStroke.opacity(0.55)), lineWidth: 0.9)
        let sq = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
        context.fill(Path(sq), with: .color(primaryStroke))
        context.stroke(Path(sq), with: .color(accent), lineWidth: 1.1)
        let cir = CGRect(x: handle.x - 2.5, y: handle.y - 2.5, width: 5, height: 5)
        context.fill(Path(ellipseIn: cir), with: .color(accent))
    }
}
