#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_POP_CULTURE_CROPPED_VECTORS'
a_path = "Sources/KroutonApp/KroutonApp.swift"
with open(a_path, "r") as f:
    a_text = f.read()

start_marker = None
for candidate in [
    "// MARK: - Metal GPU-Accelerated (.drawingGroup) Pop-Culture Macro-Cropped Bezier Hero Studio",
    "// MARK: - Metal GPU-Accelerated (.drawingGroup) US Patent & Isometric Exploded-View Vector Studio",
    "// MARK: - Multi-Layer Isometric & Pixel-Matrix CAD Blueprint Hero Art Studio"
]:
    if candidate in a_text:
        start_marker = candidate
        break

assert start_marker is not None, "DepotBlueprintArtStudioView marker not found in KroutonApp.swift"

pop_culture_bezier_studio = r"""// MARK: - Metal GPU-Accelerated (.drawingGroup) Pop-Culture Macro-Cropped Bezier Hero Studio
struct DepotBlueprintArtStudioView: View {
    let item: DepotCatalogItem
    let accent: Color
    let isNarrow: Bool

    var body: some View {
        Canvas { context, size in
            // =========================================================================
            // 1. SUBTLE CAD DRAFTING MESH & GOLDEN-RATIO CONSTRUCTION ARCS
            // =========================================================================
            let step: CGFloat = 20
            var grid = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: step) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: step) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(Color.cyan.opacity(0.045)), lineWidth: 0.5)

            // Focal anchor shifted right and zoomed so art bleeds off the top/bottom/right edges!
            let cx: CGFloat = isNarrow ? size.width * 0.80 : size.width * 0.63
            let cy: CGFloat = size.height * 0.54

            // Ambient HDR Spotlight behind the cropped silhouette
            let glowR: CGFloat = 175
            context.fill(
                Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [accent.opacity(0.32), Color.cyan.opacity(0.12), Color.clear]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 8,
                    endRadius: glowR
                )
            )

            // Helper: Draws an Adobe Illustrator / Figma style Bezier Control Handle (`o---■`)
            func drawBezierHandle(anchor: CGPoint, control: CGPoint) {
                var line = Path()
                line.move(to: anchor)
                line.addLine(to: control)
                context.stroke(line, with: .color(Color.cyan.opacity(0.55)), lineWidth: 0.9)
                let sq = CGRect(x: anchor.x - 3, y: anchor.y - 3, width: 6, height: 6)
                context.fill(Path(sq), with: .color(Color.white))
                context.stroke(Path(sq), with: .color(accent), lineWidth: 1.2)
                let cir = CGRect(x: control.x - 2.5, y: control.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: cir), with: .color(Color.cyan))
            }

            let titleLower = (item.title + " " + item.id + " " + item.subtitle).lowercased()

            // =========================================================================
            // 2. MACRO-CROPPED POP-CULTURE 2D BEZIER SILHOUETTES (220% ZOOM + BLEED)
            // =========================================================================
            if item.channel.contains("Vintage Apple") || titleLower.contains("mac") || titleLower.contains("apple") {
                // === ICON 1: CLASSIC MAC OS "PICASSO" HAPPY MAC TWO-FACE BEZIER RIBBON ===
                var faceScreen = Path()
                faceScreen.addRoundedRect(
                    in: CGRect(x: cx - 105, y: cy - 115, width: 220, height: 240),
                    cornerSize: CGSize(width: 28, height: 28)
                )
                context.fill(faceScreen, with: .color(Color.cyan.opacity(0.06)))
                context.stroke(faceScreen, with: .color(Color.cyan.opacity(0.24)), style: StrokeStyle(lineWidth: 1.2, dash: [8, 5]))

                var picassoLine = Path()
                let pTop = CGPoint(x: cx + 8, y: cy - 125)
                let pNoseBridge = CGPoint(x: cx - 8, y: cy - 42)
                let pNoseTip = CGPoint(x: cx - 32, y: cy + 8)
                let pNoseBase = CGPoint(x: cx + 6, y: cy + 12)
                let pChin = CGPoint(x: cx - 4, y: cy + 125)

                picassoLine.move(to: pTop)
                picassoLine.addQuadCurve(to: pNoseBridge, control: CGPoint(x: cx + 4, y: cy - 80))
                picassoLine.addQuadCurve(to: pNoseTip, control: CGPoint(x: cx - 22, y: cy - 14))
                picassoLine.addQuadCurve(to: pNoseBase, control: CGPoint(x: cx - 14, y: cy + 14))
                picassoLine.addQuadCurve(to: pChin, control: CGPoint(x: cx + 10, y: cy + 68))

                var rightHalfFace = picassoLine
                rightHalfFace.addLine(to: CGPoint(x: cx + 120, y: cy + 125))
                rightHalfFace.addLine(to: CGPoint(x: cx + 120, y: cy - 125))
                rightHalfFace.closeSubpath()
                context.fill(rightHalfFace, with: .color(accent.opacity(0.18)))

                context.stroke(picassoLine, with: .color(Color.white.opacity(0.92)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))

                var smile = Path()
                let sLeft = CGPoint(x: cx - 58, y: cy + 28)
                let sRight = CGPoint(x: cx + 56, y: cy + 26)
                let sCtrl = CGPoint(x: cx - 2, y: cy + 82)
                smile.move(to: sLeft)
                smile.addQuadCurve(to: sRight, control: sCtrl)
                context.stroke(smile, with: .color(accent), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                var eyes = Path()
                eyes.move(to: CGPoint(x: cx - 48, y: cy - 48))
                eyes.addLine(to: CGPoint(x: cx - 48, y: cy - 22))
                eyes.move(to: CGPoint(x: cx + 38, y: cy - 48))
                eyes.addLine(to: CGPoint(x: cx + 38, y: cy - 22))
                context.stroke(eyes, with: .color(Color.cyan), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                drawBezierHandle(anchor: pNoseTip, control: CGPoint(x: cx - 56, y: cy - 10))
                drawBezierHandle(anchor: sRight, control: CGPoint(x: cx + 82, y: cy + 4))

            } else if item.channel.contains("Console") && (titleLower.contains("sega") || titleLower.contains("dream") || titleLower.contains("saturn") || titleLower.contains("240p")) {
                // === ICON 2: SEGA — SUPERSONIC SWEPT QUILLS + INTERLOCKING GOLDEN RINGS ===
                var quills = Path()
                let qStart = CGPoint(x: cx - 125, y: cy - 18)
                quills.move(to: qStart)
                quills.addCurve(to: CGPoint(x: cx + 95, y: cy - 78), control1: CGPoint(x: cx - 55, y: cy - 82), control2: CGPoint(x: cx + 25, y: cy - 88))
                quills.addCurve(to: CGPoint(x: cx + 15, y: cy - 18), control1: CGPoint(x: cx + 65, y: cy - 48), control2: CGPoint(x: cx + 40, y: cy - 30))
                quills.addCurve(to: CGPoint(x: cx + 115, y: cy - 10), control1: CGPoint(x: cx + 55, y: cy - 22), control2: CGPoint(x: cx + 85, y: cy - 18))
                quills.addCurve(to: CGPoint(x: cx + 10, y: cy + 32), control1: CGPoint(x: cx + 70, y: cy + 18), control2: CGPoint(x: cx + 40, y: cy + 26))
                quills.addCurve(to: CGPoint(x: cx + 90, y: cy + 58), control1: CGPoint(x: cx + 45, y: cy + 40), control2: CGPoint(x: cx + 70, y: cy + 48))
                quills.addCurve(to: CGPoint(x: cx - 95, y: cy + 65), control1: CGPoint(x: cx + 20, y: cy + 82), control2: CGPoint(x: cx - 45, y: cy + 78))
                quills.closeSubpath()

                context.fill(quills, with: .color(Color.cyan.opacity(0.16)))
                context.stroke(quills, with: .color(Color.cyan.opacity(0.90)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))

                for (rx, ry, rad) in [(cx - 35, cy + 10, 58.0), (cx + 42, cy - 14, 68.0)] {
                    let outer = CGRect(x: rx - rad, y: ry - rad, width: rad * 2, height: rad * 2)
                    let inner = CGRect(x: rx - rad * 0.74, y: ry - rad * 0.74, width: rad * 1.48, height: rad * 1.48)
                    var ring = Path()
                    ring.addEllipse(in: outer)
                    ring.addEllipse(in: inner)
                    context.fill(ring, with: .color(accent.opacity(0.24)), style: FillStyle(eoFill: true))
                    context.stroke(Path(ellipseIn: outer), with: .color(accent), lineWidth: 2.2)
                    context.stroke(Path(ellipseIn: inner), with: .color(accent.opacity(0.75)), lineWidth: 1.2)
                }

                drawBezierHandle(anchor: CGPoint(x: cx + 95, y: cy - 78), control: CGPoint(x: cx + 125, y: cy - 92))

            } else if item.channel.contains("Console") && (titleLower.contains("ps1") || titleLower.contains("ps2") || titleLower.contains("playstation") || titleLower.contains("freedvd") || titleLower.contains("unirom")) {
                // === ICON 3: PLAYSTATION — GIANT CROPPED SACRED GEOMETRY ===
                var tri = Path()
                tri.move(to: CGPoint(x: cx - 45, y: cy - 95))
                tri.addLine(to: CGPoint(x: cx + 15, y: cy + 8))
                tri.addLine(to: CGPoint(x: cx - 105, y: cy + 8))
                tri.closeSubpath()
                context.fill(tri, with: .color(Color.green.opacity(0.14)))
                context.stroke(tri, with: .color(Color.cyan), style: StrokeStyle(lineWidth: 3.0, lineJoin: .round))

                let cirRect = CGRect(x: cx + 4, y: cy - 88, width: 112, height: 112)
                context.fill(Path(ellipseIn: cirRect), with: .color(accent.opacity(0.18)))
                context.stroke(Path(ellipseIn: cirRect), with: .color(accent), lineWidth: 3.2)

                var cross = Path()
                let xCenter = CGPoint(x: cx - 10, y: cy + 56)
                cross.move(to: CGPoint(x: xCenter.x - 38, y: xCenter.y - 38))
                cross.addLine(to: CGPoint(x: xCenter.x + 38, y: xCenter.y + 38))
                cross.move(to: CGPoint(x: xCenter.x + 38, y: xCenter.y - 38))
                cross.addLine(to: CGPoint(x: xCenter.x - 38, y: xCenter.y + 38))
                context.stroke(cross, with: .color(Color.cyan.opacity(0.92)), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))

                let sqRect = CGRect(x: cx - 118, y: cy + 18, width: 78, height: 78)
                context.stroke(Path(roundedRect: sqRect, cornerSize: CGSize(width: 4, height: 4)), with: .color(Color.white.opacity(0.75)), lineWidth: 2.4)

                drawBezierHandle(anchor: CGPoint(x: cx - 45, y: cy - 95), control: CGPoint(x: cx - 12, y: cy - 112))

            } else if item.channel.contains("Console") {
                // === ICON 4: NINTENDO — MACRO-CROPPED PLUMBER CAP VISOR + EMBLEM BADGE & [ ? ] BLOCK ===
                var capCrown = Path()
                capCrown.move(to: CGPoint(x: cx - 115, y: cy + 12))
                capCrown.addCurve(
                    to: CGPoint(x: cx + 78, y: cy - 12),
                    control1: CGPoint(x: cx - 110, y: cy - 115),
                    control2: CGPoint(x: cx + 45, y: cy - 115)
                )
                capCrown.addCurve(
                    to: CGPoint(x: cx + 135, y: cy + 28),
                    control1: CGPoint(x: cx + 108, y: cy - 8),
                    control2: CGPoint(x: cx + 138, y: cy + 8)
                )
                capCrown.addCurve(
                    to: CGPoint(x: cx - 115, y: cy + 12),
                    control1: CGPoint(x: cx + 55, y: cy + 42),
                    control2: CGPoint(x: cx - 45, y: cy + 28)
                )
                capCrown.closeSubpath()

                context.fill(capCrown, with: .color(accent.opacity(0.22)))
                context.stroke(capCrown, with: .color(accent), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))

                let badgeRect = CGRect(x: cx - 28, y: cy - 64, width: 58, height: 44)
                context.fill(Path(ellipseIn: badgeRect), with: .color(Color.white.opacity(0.16)))
                context.stroke(Path(ellipseIn: badgeRect), with: .color(Color.white.opacity(0.92)), lineWidth: 2.2)

                var mGlyph = Path()
                mGlyph.move(to: CGPoint(x: badgeRect.minX + 12, y: badgeRect.maxY - 10))
                mGlyph.addLine(to: CGPoint(x: badgeRect.minX + 20, y: badgeRect.minY + 10))
                mGlyph.addLine(to: CGPoint(x: badgeRect.midX, y: badgeRect.midY + 4))
                mGlyph.addLine(to: CGPoint(x: badgeRect.maxX - 20, y: badgeRect.minY + 10))
                mGlyph.addLine(to: CGPoint(x: badgeRect.maxX - 12, y: badgeRect.maxY - 10))
                context.stroke(mGlyph, with: .color(Color.cyan), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                let qBox = CGRect(x: cx - 118, y: cy + 18, width: 76, height: 76)
                context.fill(Path(roundedRect: qBox, cornerSize: CGSize(width: 8, height: 8)), with: .color(Color.cyan.opacity(0.14)))
                context.stroke(Path(roundedRect: qBox, cornerSize: CGSize(width: 8, height: 8)), with: .color(Color.cyan.opacity(0.85)), lineWidth: 2.0)
                context.draw(
                    Text("?").font(.system(size: 46, weight: .heavy, design: .rounded)).foregroundColor(Color.white.opacity(0.88)),
                    at: CGPoint(x: qBox.midX, y: qBox.midY)
                )

                drawBezierHandle(anchor: CGPoint(x: cx + 78, y: cy - 12), control: CGPoint(x: cx + 105, y: cy - 48))

            } else if item.channel.contains("Live Linux") || titleLower.contains("linux") || titleLower.contains("bsd") || titleLower.contains("ubuntu") || titleLower.contains("debian") {
                // === ICON 5: LINUX & BSD — SMOOTH CUBIC BEZIER TUX SILHOUETTE + GOLDEN SPIRAL ===
                var tuxOutline = Path()
                tuxOutline.move(to: CGPoint(x: cx - 82, y: cy + 120))
                tuxOutline.addCurve(
                    to: CGPoint(x: cx - 52, y: cy - 35),
                    control1: CGPoint(x: cx - 95, y: cy + 55),
                    control2: CGPoint(x: cx - 68, y: cy + 5)
                )
                tuxOutline.addCurve(
                    to: CGPoint(x: cx + 48, y: cy - 35),
                    control1: CGPoint(x: cx - 45, y: cy - 105),
                    control2: CGPoint(x: cx + 42, y: cy - 105)
                )
                tuxOutline.addCurve(
                    to: CGPoint(x: cx + 88, y: cy + 120),
                    control1: CGPoint(x: cx + 68, y: cy + 5),
                    control2: CGPoint(x: cx + 102, y: cy + 55)
                )
                context.fill(tuxOutline, with: .color(Color.cyan.opacity(0.12)))
                context.stroke(tuxOutline, with: .color(Color.cyan.opacity(0.90)), lineWidth: 2.6)

                var beak = Path()
                beak.move(to: CGPoint(x: cx - 34, y: cy - 16))
                beak.addQuadCurve(to: CGPoint(x: cx + 34, y: cy - 16), control: CGPoint(x: cx, y: cy - 32))
                beak.addQuadCurve(to: CGPoint(x: cx, y: cy + 14), control: CGPoint(x: cx + 22, y: cy + 6))
                beak.addQuadCurve(to: CGPoint(x: cx - 34, y: cy - 16), control: CGPoint(x: cx - 22, y: cy + 6))
                beak.closeSubpath()
                context.fill(beak, with: .color(accent.opacity(0.38)))
                context.stroke(beak, with: .color(accent), lineWidth: 2.4)

                let leftEye = CGRect(x: cx - 28, y: cy - 58, width: 22, height: 30)
                let rightEye = CGRect(x: cx + 6, y: cy - 58, width: 22, height: 30)
                context.stroke(Path(ellipseIn: leftEye), with: .color(Color.white.opacity(0.92)), lineWidth: 2.2)
                context.stroke(Path(ellipseIn: rightEye), with: .color(Color.white.opacity(0.92)), lineWidth: 2.2)
                context.fill(Path(ellipseIn: CGRect(x: cx - 18, y: cy - 44, width: 8, height: 11)), with: .color(Color.cyan))
                context.fill(Path(ellipseIn: CGRect(x: cx + 10, y: cy - 44, width: 8, height: 11)), with: .color(Color.cyan))

                var swirl = Path()
                let sCenter = CGPoint(x: cx + 64, y: cy - 42)
                swirl.addArc(center: sCenter, radius: 54, startAngle: .degrees(20), endAngle: .degrees(275), clockwise: false)
                context.stroke(swirl, with: .color(accent.opacity(0.75)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [12, 4]))

                drawBezierHandle(anchor: CGPoint(x: cx + 34, y: cy - 16), control: CGPoint(x: cx + 64, y: cy - 28))

            } else if item.channel.contains("Retro PC") || titleLower.contains("dos") || titleLower.contains("win") || titleLower.contains("os/2") {
                // === ICON 6: WINDOWS 3.1/95 WAVING 4-PANE FLAG + GIANT CROPPED `C:\>_` PROMPT ===
                for row in 0..<2 {
                    for col in 0..<2 {
                        let bx = cx - 22 + CGFloat(col) * 54 - CGFloat(row) * 10
                        let by = cy - 62 + CGFloat(row) * 50 + CGFloat(col) * 8
                        var pane = Path()
                        pane.move(to: CGPoint(x: bx, y: by))
                        pane.addQuadCurve(to: CGPoint(x: bx + 44, y: by + 6), control: CGPoint(x: bx + 22, y: by - 8))
                        pane.addLine(to: CGPoint(x: bx + 36, y: by + 44))
                        pane.addQuadCurve(to: CGPoint(x: bx - 8, y: by + 38), control: CGPoint(x: bx + 14, y: by + 30))
                        pane.closeSubpath()

                        let isAccentPane = (row + col) % 2 == 0
                        context.fill(pane, with: .color(isAccentPane ? accent.opacity(0.28) : Color.cyan.opacity(0.22)))
                        context.stroke(pane, with: .color(isAccentPane ? accent : Color.cyan), lineWidth: 2.2)
                    }
                }

                for (tx, ty, sz) in [(-54.0, -38.0, 18.0), (-82.0, -24.0, 13.0), (-64.0, 12.0, 16.0), (-96.0, 4.0, 10.0), (-114.0, -14.0, 7.0)] {
                    let r = CGRect(x: cx + CGFloat(tx), y: cy + CGFloat(ty), width: CGFloat(sz), height: CGFloat(sz))
                    context.fill(Path(roundedRect: r, cornerSize: CGSize(width: 2, height: 2)), with: .color(Color.cyan.opacity(0.25)))
                    context.stroke(Path(roundedRect: r, cornerSize: CGSize(width: 2, height: 2)), with: .color(Color.cyan.opacity(0.75)), lineWidth: 1.3)
                }

                context.draw(
                    Text("C:\\>_")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.20)),
                    at: CGPoint(x: cx - 35, y: cy + 58)
                )

                drawBezierHandle(anchor: CGPoint(x: cx + 76, y: cy - 48), control: CGPoint(x: cx + 108, y: cy - 66))

            } else if item.channel.contains("Cover Discs") || titleLower.contains("doom") || titleLower.contains("quake") || titleLower.contains("scene") {
                // === ICON 7: 90S FPS / DOOM MARINE ANGULAR VISOR HELMET + IRIDESCENT CD PRISM ===
                let cdCenter = CGPoint(x: cx + 28, y: cy + 10)
                for r in [98.0, 72.0, 28.0, 14.0] {
                    let rect = CGRect(x: cdCenter.x - r, y: cdCenter.y - r, width: r * 2, height: r * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(r == 98.0 ? accent : Color.cyan.opacity(0.75)),
                        style: StrokeStyle(lineWidth: r == 98.0 ? 2.4 : 1.3, dash: r == 72.0 ? [10, 5] : [])
                    )
                }

                var visor = Path()
                visor.move(to: CGPoint(x: cx - 92, y: cy - 28))
                visor.addLine(to: CGPoint(x: cx - 28, y: cy - 48))
                visor.addLine(to: CGPoint(x: cx + 36, y: cy - 28))
                visor.addLine(to: CGPoint(x: cx + 18, y: cy + 16))
                visor.addLine(to: CGPoint(x: cx - 28, y: cy + 4))
                visor.addLine(to: CGPoint(x: cx - 74, y: cy + 16))
                visor.closeSubpath()
                context.fill(visor, with: .color(accent.opacity(0.28)))
                context.stroke(visor, with: .color(Color.white.opacity(0.92)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .bevel))

                drawBezierHandle(anchor: CGPoint(x: cx + 36, y: cy - 28), control: CGPoint(x: cx + 68, y: cy - 44))

            } else {
                // === ICON 8: SYSTEM RESCUE — MACRO OPTICAL LASER PICKUP + FOURIER HARMONIC RIBBON ===
                for r in [110.0, 82.0, 54.0, 22.0] {
                    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(r == 82.0 ? accent : Color.cyan.opacity(0.55)),
                        style: StrokeStyle(lineWidth: r == 82.0 ? 2.2 : 1.1, dash: r == 110.0 ? [12, 6] : [])
                    )
                }

                for phaseShift in [0.0, 0.65, 1.3] {
                    var wave = Path()
                    let startX = cx - 140
                    wave.move(to: CGPoint(x: startX, y: cy))
                    for stepX in stride(from: 0.0, through: 280.0, by: 8.0) {
                        let wx = startX + CGFloat(stepX)
                        let wy = cy + sin(CGFloat(stepX) * 0.045 + CGFloat(phaseShift)) * 38.0 * cos(CGFloat(stepX) * 0.015)
                        wave.addLine(to: CGPoint(x: wx, y: wy))
                    }
                    context.stroke(
                        wave,
                        with: .color(phaseShift == 0.0 ? accent : Color.cyan.opacity(0.75)),
                        lineWidth: phaseShift == 0.0 ? 2.4 : 1.2
                    )
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .clear, location: 0.24),
                    .init(color: .black.opacity(0.65), location: 0.42),
                    .init(color: .black, location: 0.62),
                    .init(color: .black.opacity(0.85), location: 0.88),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .black, location: 0.16),
                        .init(color: .black, location: 0.84),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
    }
}
"""

a_text = a_text[:a_text.index(start_marker)] + pop_culture_bezier_studio
with open(a_path, "w") as f:
    f.write(a_text)
print("[OK] Upgraded DepotBlueprintArtStudioView to Macro-Cropped, Edge-Faded Pop-Culture 2D Bezier Silhouettes!")
EOF_POP_CULTURE_CROPPED_VECTORS

swift build
git add -A
git commit -m "feat(depot-hero): add macro-cropped edge-faded 2D Bezier pop-culture silhouettes with CAD tangent handles" || true
echo "=================================================================="
echo " [SUCCESS] Pop-Culture Macro-Cropped Bezier Hero Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "=================================================================="
