import SwiftUI
import Foundation
import OpticalDough

// MARK: - Xbox, PlayStation & Sega Saturn Macro-Cropped Bezier Emblem Renderers

extension KroutonRecipeBlueprintView {
    func drawConsoleEmblemBlueprint(
        key: String,
        context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        accent: Color,
        secondary: Color,
        primaryStroke: Color,
        primaryFill: Color,
        accentStroke: Color,
        accentFill: Color,
        faintStroke: Color,
        occludeBacking: Color
    ) {
        if key.contains("xbox") {
                // --- 5. XBOX V2 (1:1 Exact SVG Spherical Wedge & Tapered X-Groove Reconstruction) ---
                // Normalized on a unit circle (R = 88pt) matching Xbox_Logo.svg:
                // - Upper X-intersection sits high at y = -0.28R
                // - Lower X-crotch apex sits at y = -0.02R with a rounded fillet
                // - Side cheek wedges taper to razor-sharp tips at +52 degrees (bottom-right) and +128 degrees (bottom-left)
                let R: CGFloat = 88.0
                func xpt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
                    CGPoint(x: cx + nx * R, y: cy + ny * R)
                }

                let occludeDark = occludeBacking
                func drawOccludedWedge(_ path: Path, fill: Color, stroke: Color, lineWidth: CGFloat = 2.3) {
                    context.fill(path, with: .color(occludeDark))
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }

                // Subtle Outer Construction Sphere Ring & Crosshair
                context.stroke(
                    Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)),
                    with: .color(faintStroke),
                    style: StrokeStyle(lineWidth: 0.9, dash: [6, 4])
                )

                // =====================================================================
                // 1. TOP SPHERICAL CROWN WEDGE (Shallow cap between the upper X-cuts)
                //    Outer rim sweeps from -123° (top-left) to -57° (top-right),
                //    inner V-edges curve down to the upper X-apex at (0.0, -0.44)
                // =====================================================================
                var topCrown = Path()
                topCrown.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: R,
                    startAngle: .degrees(-123),
                    endAngle: .degrees(-57),
                    clockwise: false
                )
                // Right inner curve of top wedge sweeping down-left to the upper apex
                topCrown.addCurve(
                    to: xpt(0.0, -0.44),
                    control1: xpt(0.38, -0.74),
                    control2: xpt(0.18, -0.58)
                )
                // Left inner curve sweeping back up-left to -123° (-0.545, -0.839)
                topCrown.addCurve(
                    to: xpt(-0.545, -0.839),
                    control1: xpt(-0.18, -0.58),
                    control2: xpt(-0.38, -0.74)
                )
                topCrown.closeSubpath()
                drawOccludedWedge(topCrown, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.3)

                // =====================================================================
                // 2. LEFT SPHERICAL CHEEK WEDGE (Crescent wing tapering to a sharp lower-left tip)
                //    Outer rim sweeps from +129° (lower-left sharp tip) clockwise up to -142° (upper-left shoulder)
                // =====================================================================
                var leftCheek = Path()
                leftCheek.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: R,
                    startAngle: .degrees(129),
                    endAngle: .degrees(-142),
                    clockwise: false
                )
                // Upper-left inner cut slanting down-right to the left X-waist vertex (-0.23, -0.22)
                leftCheek.addCurve(
                    to: xpt(-0.23, -0.22),
                    control1: xpt(-0.62, -0.52),
                    control2: xpt(-0.42, -0.38)
                )
                // Long sweeping concave lower-left blade edge tapering all the way to the sharp tip at +129° (-0.629, +0.777)
                leftCheek.addCurve(
                    to: xpt(-0.629, 0.777),
                    control1: xpt(-0.48, 0.08),
                    control2: xpt(-0.64, 0.44)
                )
                leftCheek.closeSubpath()
                drawOccludedWedge(leftCheek, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.3)

                // =====================================================================
                // 3. RIGHT SPHERICAL CHEEK WEDGE (Symmetric crescent wing tapering to lower-right tip)
                //    Outer rim sweeps from -38° (upper-right shoulder) clockwise down to +51° (lower-right sharp tip)
                // =====================================================================
                var rightCheek = Path()
                rightCheek.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: R,
                    startAngle: .degrees(-38),
                    endAngle: .degrees(51),
                    clockwise: false
                )
                // Long sweeping concave lower-right blade edge rising up-left to the right X-waist vertex (+0.23, -0.22)
                rightCheek.addCurve(
                    to: xpt(0.23, -0.22),
                    control1: xpt(0.64, 0.44),
                    control2: xpt(0.48, 0.08)
                )
                // Upper-right inner cut slanting up-right back to -38° (+0.788, -0.616)
                rightCheek.addCurve(
                    to: xpt(0.788, -0.616),
                    control1: xpt(0.42, -0.38),
                    control2: xpt(0.62, -0.52)
                )
                rightCheek.closeSubpath()
                drawOccludedWedge(rightCheek, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.3)

                // =====================================================================
                // 4. LARGE BOTTOM SPHERICAL BASE WEDGE (Highlighted in Accent!)
                //    Outer rim sweeps along bottom from +59° (bottom-right) to +121° (bottom-left),
                //    rising along two sweeping convex arcs to the rounded central apex at (0.0, -0.02)
                // =====================================================================
                var bottomBase = Path()
                bottomBase.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: R,
                    startAngle: .degrees(59),
                    endAngle: .degrees(121),
                    clockwise: false
                )
                // Left inner wall of bottom wedge curving up-right to the rounded central apex
                bottomBase.addCurve(
                    to: xpt(-0.04, 0.00),
                    control1: xpt(-0.46, 0.56),
                    control2: xpt(-0.26, 0.22)
                )
                // Rounded central apex fillet at the heart of the X
                bottomBase.addQuadCurve(
                    to: xpt(0.04, 0.00),
                    control: xpt(0.0, -0.04)
                )
                // Right inner wall of bottom wedge curving down-right back to +59° (+0.515, +0.857)
                bottomBase.addCurve(
                    to: xpt(0.515, 0.857),
                    control1: xpt(0.26, 0.22),
                    control2: xpt(0.46, 0.56)
                )
                bottomBase.closeSubpath()
                drawOccludedWedge(bottomBase, fill: accentFill, stroke: accentStroke, lineWidth: 2.5)

                // Tapered Specular Reflection Crescent inside the Bottom Spherical Wedge
                var reflectionCrescent = Path()
                reflectionCrescent.move(to: xpt(-0.39, 0.71))
                // Lower outer curve of the reflection (swells thicker at the center)
                reflectionCrescent.addQuadCurve(to: xpt(0.39, 0.71), control: xpt(0.0, 0.89))
                // Upper inner curve returning to the left needle tip
                reflectionCrescent.addQuadCurve(to: xpt(-0.39, 0.71), control: xpt(0.0, 0.82))
                reflectionCrescent.closeSubpath()
                context.fill(reflectionCrescent, with: .color(primaryStroke.opacity(0.68)))

            } else if key.contains("ps1") || key.contains("ps2") || key.contains("playstation") || key.contains("freedvd") || key.contains("unirom") {
                // --- 6. PLAYSTATION (1:1 Exact SVG Coordinate Reconstruction of Standing 'P' + Slotted Floor 'S') ---
                let scale: CGFloat = 1.08
                func ppt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
                    CGPoint(x: cx + dx * scale, y: cy + dy * scale)
                }

                // =====================================================================
                // A. LEFT HALF OF THE FLOOR 'S' (Emerges from behind the left edge of 'P')
                //    Features the outer U-curve AND the inner negative-space slot!
                // =====================================================================
                var sLeft = Path()
                // 1. Top-back edge emerging from behind 'P' at x = -24, slanting down-left
                sLeft.move(to: ppt(-24, 6))
                sLeft.addLine(to: ppt(-82, 28))
                // 2. Outer left U-turn curve (Yellow end-cap in reference)
                sLeft.addCurve(
                    to: ppt(-80, 66),
                    control1: ppt(-112, 39),
                    control2: ppt(-110, 58)
                )
                // 3. Front-bottom edge of left loop returning to 'P' at x = -24
                sLeft.addCurve(
                    to: ppt(-24, 58),
                    control1: ppt(-58, 72),
                    control2: ppt(-38, 64)
                )
                // 4. Step up along the hidden 'P' boundary into the inner negative-space slot
                sLeft.addLine(to: ppt(-24, 45))
                sLeft.addLine(to: ppt(-58, 57))
                // 5. Inner round U-cap of the left negative-space slot!
                sLeft.addCurve(
                    to: ppt(-65, 45),
                    control1: ppt(-72, 62),
                    control2: ppt(-76, 49)
                )
                // 6. Upper inner wall of the left slot returning to 'P' at x = -24
                sLeft.addLine(to: ppt(-24, 30))
                sLeft.closeSubpath()

                context.fill(sLeft, with: .color(primaryFill))
                context.stroke(sLeft, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.0, lineJoin: .round))

                // Isometric color-band seam lines across the left 'S' wing (matching the Yellow/Teal/Blue divisions)
                var sLeftSeams = Path()
                sLeftSeams.move(to: ppt(-82, 28)); sLeftSeams.addLine(to: ppt(-65, 45))
                sLeftSeams.move(to: ppt(-58, 57)); sLeftSeams.addLine(to: ppt(-36, 65))
                sLeftSeams.move(to: ppt(-40, 12)); sLeftSeams.addLine(to: ppt(-24, 18))
                context.stroke(sLeftSeams, with: .color(primaryStroke.opacity(0.65)), lineWidth: 1.4)

                // =====================================================================
                // B. RIGHT HALF OF THE FLOOR 'S' (Emerges from the right edge of 'P' at x = +8)
                //    Features the sweeping right U-turn AND the inner negative-space slot!
                // =====================================================================
                var sRight = Path()
                // 1. Upper-left edge starting at the 'P' stem (x = +8, y = +18) sweeping out to the right U-turn
                sRight.move(to: ppt(8, 18))
                sRight.addCurve(
                    to: ppt(84, 12),
                    control1: ppt(32, 9),
                    control2: ppt(62, 6)
                )
                // 2. Outer right U-turn curve (Blue loop in reference)
                sRight.addCurve(
                    to: ppt(86, 50),
                    control1: ppt(114, 18),
                    control2: ppt(114, 40)
                )
                // 3. Long front-bottom straight edge slanting down-left all the way back to the bottom of 'P' (x = +8, y = +79)
                sRight.addLine(to: ppt(8, 79))
                // 4. Step up along the 'P' stem to the bottom of the right negative-space slot (x = +8, y = +55)
                sRight.addLine(to: ppt(8, 55))
                sRight.addLine(to: ppt(62, 35))
                // 5. Inner round U-cap of the right negative-space slot!
                sRight.addCurve(
                    to: ppt(55, 23),
                    control1: ppt(76, 30),
                    control2: ppt(70, 18)
                )
                // 6. Upper inner wall of the right slot returning to the 'P' stem (x = +8, y = +40)
                sRight.addLine(to: ppt(8, 40))
                sRight.closeSubpath()

                context.fill(sRight, with: .color(primaryFill))
                context.stroke(sRight, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.0, lineJoin: .round))

                // Highlight the front-bottom triangular end-cap & isometric seam lines on the right 'S' wing
                var sRightCap = Path()
                sRightCap.move(to: ppt(8, 55))
                sRightCap.addLine(to: ppt(38, 68))
                sRightCap.addLine(to: ppt(8, 79))
                sRightCap.closeSubpath()
                context.fill(sRightCap, with: .color(accentFill.opacity(0.55)))

                var sRightSeams = Path()
                sRightSeams.move(to: ppt(8, 55));  sRightSeams.addLine(to: ppt(38, 68))
                sRightSeams.move(to: ppt(8, 18));  sRightSeams.addLine(to: ppt(44, 31))
                sRightSeams.move(to: ppt(46, 39)); sRightSeams.addLine(to: ppt(86, 50))
                context.stroke(sRightSeams, with: .color(primaryStroke.opacity(0.65)), lineWidth: 1.4)

                // =====================================================================
                // C. TALL STANDING 3D 'P' MONOLITH (Clean Flat Isometric Plane — No Extra Split Line!)
                // =====================================================================
                var pMonolith = Path()
                // 1. Top-left peak (-24, -88)
                pMonolith.move(to: ppt(-24, -88))
                // 2. Slanted roof sweeping down-right into the outer bowl curve
                pMonolith.addLine(to: ppt(22, -70))
                pMonolith.addCurve(
                    to: ppt(64, -10),
                    control1: ppt(50, -59),
                    control2: ppt(64, -36)
                )
                // 3. Lower curve of the 'P' bowl tucking back in to x = +20
                pMonolith.addCurve(
                    to: ppt(20, 8),
                    control1: ppt(64, 14),
                    control2: ppt(42, 16)
                )
                // 4. Vertical inner wall of the 'P' bowl rising straight up to the rounded slot arch
                pMonolith.addLine(to: ppt(20, -43))
                pMonolith.addCurve(
                    to: ppt(8, -46),
                    control1: ppt(20, -52),
                    control2: ppt(8, -54)
                )
                // 5. Right vertical edge of the main stem dropping straight down to the bottom-right corner (8, 82)
                pMonolith.addLine(to: ppt(8, 82))
                // 6. Isometric slanted bottom base slanting up-left to (-24, 70)
                pMonolith.addLine(to: ppt(-24, 70))
                pMonolith.closeSubpath()

                context.fill(pMonolith, with: .color(accentFill))
                context.stroke(pMonolith, with: .color(accentStroke), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))

            } else if key.contains("saturn") {
                // --- 7A. SEGA SATURN (1:1 3D Planet Orb + Interlocking Front/Back Double Orbital Rings) ---
                let px = cx + 8, py = cy - 4
                let pR: CGFloat = 46
                let planetRect = CGRect(x: px - pR, y: py - pR, width: pR * 2, height: pR * 2)
                context.fill(Path(ellipseIn: planetRect), with: .color(primaryFill))
                context.stroke(Path(ellipseIn: planetRect), with: .color(primaryStroke), lineWidth: 2.4)

                // Specular crescent highlight inside top-right of planet orb
                var crest = Path()
                crest.addArc(center: CGPoint(x: px, y: py), radius: pR - 7, startAngle: .degrees(-75), endAngle: .degrees(-15), clockwise: false)
                context.stroke(crest, with: .color(accentStroke), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                // Sweeping Double Saturn Rings Tilted at -22 Degrees wrapping around the orb
                for (rRx, rRy, yOff, isOuter) in [(98.0, 25.0, -5.0, true), (80.0, 19.0, 7.0, false)] {
                    var ringArc = Path()
                    for deg in stride(from: -42.0, through: 222.0, by: 4.0) {
                        let rad = deg * .pi / 180.0
                        let x0 = CGFloat(cos(rad) * rRx)
                        let y0 = CGFloat(sin(rad) * rRy) + CGFloat(yOff)
                        let rot = -21.0 * .pi / 180.0
                        let rx = px + x0 * CGFloat(cos(rot)) - y0 * CGFloat(sin(rot))
                        let ry = py + x0 * CGFloat(sin(rot)) + y0 * CGFloat(cos(rot))
                        if deg == -42.0 { ringArc.move(to: CGPoint(x: rx, y: ry)) }
                        else { ringArc.addLine(to: CGPoint(x: rx, y: ry)) }
                    }
                    context.stroke(
                        ringArc,
                        with: .color(isOuter ? accentStroke : primaryStroke),
                        style: StrokeStyle(lineWidth: isOuter ? 7.0 : 5.0, lineCap: .round)
                    )
                }

        }
    }
}
