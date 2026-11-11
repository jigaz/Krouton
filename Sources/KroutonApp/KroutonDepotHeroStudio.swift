//
//  KroutonDepotHeroStudio.swift
//  Krouton — Optical Media Mastering Studio
//
//  Metal-Accelerated (.extendedLinear P3) CAD Blueprint Vector Art Studio for Disc Image Depot.
//

import SwiftUI
import AppKit

// MARK: - Metal GPU-Accelerated (.drawingGroup) Pop-Culture Macro-Cropped Bezier Hero Studio
struct DepotBlueprintArtStudioView: View {
    let item: DepotCatalogItem
    let accent: Color
    let isNarrow: Bool
    var useHarmony: Bool = true

    var body: some View {
        let secondary = useHarmony ? accent.perceptualSplitComplement : accent
        let occludeBacking = useHarmony ? accent.blueprintOccludeBacking : Color(red: 0.05, green: 0.06, blue: 0.08)

        Canvas { context, size in
            // =========================================================================
            // 1. ARCHITECTURAL CAD SUB-GRID & PERCEPTUAL SPLIT-COMPLEMENTARY PALETTE
            // =========================================================================
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

            // Focal anchor zoomed & positioned so macro-cropped art bleeds off top/right/bottom
            let cx: CGFloat = isNarrow ? size.width * 0.79 : size.width * 0.62
            let cy: CGFloat = size.height * 0.53

            // Dynamic Two-Tone Palette (Active Swatch + Perceptual Split-Complementary Secondary)
            let primaryStroke = secondary
            let primaryFill   = secondary.opacity(0.28)
            let accentStroke  = accent
            let accentFill    = accent.opacity(0.42)
            let faintStroke   = secondary.opacity(0.18)

            // Ambient radial glow behind the artwork
            let glowR: CGFloat = 185
            context.fill(
                Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [accent.opacity(0.32), secondary.opacity(0.14), Color.clear]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 6,
                    endRadius: glowR
                )
            )

            // Subtle construction ring
            let constructR: CGFloat = 96
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - constructR, y: cy - constructR, width: constructR * 2, height: constructR * 2)),
                with: .color(faintStroke),
                style: StrokeStyle(lineWidth: 0.8, dash: [8, 4, 2, 4])
            )

            func drawCADNode(_ pt: CGPoint, handle: CGPoint) {
                var ln = Path()
                ln.move(to: pt); ln.addLine(to: handle)
                context.stroke(ln, with: .color(primaryStroke.opacity(0.55)), lineWidth: 0.9)
                let sq = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                context.fill(Path(sq), with: .color(primaryStroke))
                context.stroke(Path(sq), with: .color(accent), lineWidth: 1.2)
                let cr = CGRect(x: handle.x - 2.5, y: handle.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: cr), with: .color(accent))
            }

            let key = (item.id + " " + item.title + " " + item.channel + " " + item.subtitle).lowercased()

            // =========================================================================
            // BATCH 1: HIGH-PRECISION 1:1 TWO-TONE VECTOR RECONSTRUCTIONS
            // =========================================================================
            if key.contains("fedora") {
                // --- 1. FEDORA (1:1 Teardrop Badge + Infinity Loop & Crossbar 'f') ---
                // Outer asymmetric Fedora speech-bubble / teardrop badge (3 round corners, 1 bottom-left corner)
                let bR: CGFloat = 86
                var badge = Path()
                badge.move(to: CGPoint(x: cx - bR, y: cy))
                badge.addLine(to: CGPoint(x: cx - bR, y: cy + bR * 0.78))
                badge.addQuadCurve(
                    to: CGPoint(x: cx - bR * 0.78, y: cy + bR),
                    control: CGPoint(x: cx - bR, y: cy + bR)
                )
                badge.addLine(to: CGPoint(x: cx, y: cy + bR))
                badge.addArc(center: CGPoint(x: cx, y: cy), radius: bR, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: true)
                badge.closeSubpath()
                context.fill(badge, with: .color(primaryFill))
                context.stroke(badge, with: .color(primaryStroke), lineWidth: 2.2)

                // Exact Fedora Infinity ('∞') under-ribbon in Primary Cyan
                let loopR: CGFloat = 29
                let leftCenter  = CGPoint(x: cx - loopR, y: cy + loopR - 4)
                let rightCenter = CGPoint(x: cx + loopR, y: cy - loopR - 4)

                var underRibbon = Path()
                underRibbon.addArc(center: leftCenter, radius: loopR, startAngle: .degrees(90), endAngle: .degrees(360), clockwise: false)
                underRibbon.addLine(to: CGPoint(x: cx, y: rightCenter.y))
                underRibbon.addArc(center: rightCenter, radius: loopR, startAngle: .degrees(180), endAngle: .degrees(-45), clockwise: false)
                context.stroke(
                    underRibbon,
                    with: .color(primaryStroke.opacity(0.65)),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                )

                // Exact Fedora Foreground 'f' Stem, Top Hook, Bottom Tail & Crossbar in Accent
                var fOver = Path()
                // Bottom-left tail of the 'f' curving up into the vertical stem
                fOver.addArc(center: leftCenter, radius: loopR, startAngle: .degrees(125), endAngle: .degrees(0), clockwise: true)
                // Vertical stem rising from bottom loop to top loop
                fOver.addLine(to: CGPoint(x: cx, y: rightCenter.y))
                // Top-right hook of the 'f'
                fOver.addArc(center: rightCenter, radius: loopR, startAngle: .degrees(180), endAngle: .degrees(315), clockwise: false)

                // Horizontal crossbar of the 'f' with rounded pill caps
                var crossbar = Path()
                crossbar.move(to: CGPoint(x: cx - 30, y: cy - 4))
                crossbar.addLine(to: CGPoint(x: cx + 28, y: cy - 4))

                context.stroke(fOver, with: .color(accentFill), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                context.stroke(fOver, with: .color(accentStroke), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                context.stroke(crossbar, with: .color(accentStroke), style: StrokeStyle(lineWidth: 16, lineCap: .round))

                // Precision CAD outline trace over the entire infinity-f glyph
                context.stroke(fOver, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                drawCADNode(rightCenter, handle: CGPoint(x: cx + 68, y: cy - 52))

            } else if key.contains("debian") || key.contains("ubuntu") || key.contains("tails") {
                // --- 2. DEBIAN (Exact 28-Curve Calligraphic Brushstroke Swirl + Inner Chin Notch & Shards) ---
                let s: CGFloat = 1.18
                func pt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
                    CGPoint(x: cx + dx * s, y: cy + dy * s)
                }

                // Main Calligraphic Swirl Body (Outer rim with authentic dry-brush notches -> Inner spiral wall)
                var swirl = Path()
                swirl.move(to: pt(26, -14)) // Inner upper-right tip of the curl
                // Inner curl sweeping counter-clockwise (up -> left -> down -> right)
                swirl.addCurve(to: pt(-24, -18), control1: pt(14, -36), control2: pt(-14, -36))
                swirl.addCurve(to: pt(-12, 26),  control1: pt(-34, -2),  control2: pt(-30, 18))
                swirl.addCurve(to: pt(34, 8),    control1: pt(4, 34),    control2: pt(26, 26))
                // Sweeping up the right outer wall toward the top crown
                swirl.addCurve(to: pt(12, -56),  control1: pt(48, -14),  control2: pt(38, -46))
                // Top-left broad brushstroke belly
                swirl.addCurve(to: pt(-62, -16), control1: pt(-18, -68), control2: pt(-54, -48))
                // Left outer wall sweeping down into the long tapering bottom tail
                swirl.addCurve(to: pt(-48, 52),  control1: pt(-72, 12),  control2: pt(-64, 36))
                swirl.addCurve(to: pt(-8, 86),   control1: pt(-36, 68),  control2: pt(-22, 80))
                // Sharp bottom tail tip!
                swirl.addLine(to: pt(-18, 76))
                // Returning along the inner edge of the outer wall (with brushstroke feather steps)
                swirl.addCurve(to: pt(-52, 18),  control1: pt(-38, 60),  control2: pt(-50, 40))
                swirl.addCurve(to: pt(-38, -36), control1: pt(-54, -8),  control2: pt(-48, -26))
                swirl.addCurve(to: pt(22, -40),  control1: pt(-20, -52), control2: pt(8, -52))
                swirl.addCurve(to: pt(46, 6),    control1: pt(38, -26),  control2: pt(48, -8))
                swirl.addCurve(to: pt(-10, 38),  control1: pt(42, 28),   control2: pt(14, 42))
                // Authentic Debian double-feathered bottom-inner curl tail
                swirl.addCurve(to: pt(-34, 4),   control1: pt(-26, 34),  control2: pt(-36, 20))
                swirl.addCurve(to: pt(-14, -28), control1: pt(-32, -12), control2: pt(-24, -24))
                swirl.addCurve(to: pt(26, -14),  control1: pt(-2, -32),  control2: pt(16, -26))
                swirl.closeSubpath()

                context.fill(swirl, with: .color(accentFill))
                context.stroke(swirl, with: .color(accentStroke), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))

                // Detached Inner Brush Shards (The 3 signature marks inside the eye of the Debian swirl!)
                var innerShards = Path()
                // Bottom-center chin dash
                innerShards.move(to: pt(2, 15))
                innerShards.addLine(to: pt(13, 14))
                innerShards.addLine(to: pt(9, 18))
                innerShards.closeSubpath()
                // Lower-right crescent fleck
                innerShards.move(to: pt(19, 10))
                innerShards.addQuadCurve(to: pt(25, 2), control: pt(24, 8))
                innerShards.addLine(to: pt(21, 9))
                innerShards.closeSubpath()
                // Mid-right vertical fleck
                innerShards.move(to: pt(27, -4))
                innerShards.addLine(to: pt(29, -9))
                innerShards.addLine(to: pt(26, -7))
                innerShards.closeSubpath()
                context.fill(innerShards, with: .color(primaryStroke))

                // Outer Dry-Brush Splatter Notches along Top, Right & Left Rim
                for (x0, y0, x1, y1, x2, y2) in [
                    (-68.0, -14.0, -72.0, -22.0, -65.0, -19.0),
                    (-2.0, -62.0, 12.0, -64.0, 4.0, -58.0),
                    (48.0, -18.0, 54.0, -8.0, 46.0, -10.0),
                    (44.0, 22.0, 38.0, 32.0, 40.0, 20.0),
                    (-26.0, 26.0, -16.0, 40.0, -24.0, 32.0)
                ] {
                    var notch = Path()
                    notch.move(to: pt(CGFloat(x0), CGFloat(y0)))
                    notch.addLine(to: pt(CGFloat(x1), CGFloat(y1)))
                    notch.addLine(to: pt(CGFloat(x2), CGFloat(y2)))
                    notch.closeSubpath()
                    context.fill(notch, with: .color(primaryStroke))
                }
                drawCADNode(pt(-38, -36), handle: pt(-72, -56))

            } else if key.contains("sgi") || key.contains("irix") {
                // --- 3. SGI (1:1 Isometric 6-Facet Interlocking Tubular Cube Logo) ---
                // Exact 30-degree isometric basis vectors for the 6 SGI cube limbs
                let R: CGFloat = 88.0
                // Six outer hexagonal vertices (0=TopLeft, 1=TopRight, 2=MidRight, 3=BotRight, 4=BotLeft, 5=MidLeft)
                let angles: [Double] = [-120, -60, 0, 60, 120, 180]
                for i in 0..<6 {
                    let a1 = angles[i] * .pi / 180.0
                    let a2 = angles[(i + 1) % 6] * .pi / 180.0
                    let midA = (angles[i] + 30.0) * .pi / 180.0

                    // Outer corner vertex, adjacent corner vertex, and inner Y-junction vertex
                    let vOuter1 = CGPoint(x: cx + CGFloat(cos(a1)) * R, y: cy + CGFloat(sin(a1)) * R)
                    let vOuter2 = CGPoint(x: cx + CGFloat(cos(a2)) * R, y: cy + CGFloat(sin(a2)) * R)
                    let vInner  = CGPoint(x: cx + CGFloat(cos(midA)) * (R * 0.22), y: cy + CGFloat(sin(midA)) * (R * 0.22))

                    // Construct the folded V-shaped tubular ribbon for each of the 6 cube faces
                    var limb = Path()
                    limb.move(to: vInner)
                    limb.addLine(to: vOuter1)
                    limb.addLine(to: vOuter2)
                    limb.closeSubpath()

                    // Inset triangle cutout to form the hollow SGI thick-walled tube
                    let insetC = CGPoint(
                        x: (vInner.x + vOuter1.x + vOuter2.x) / 3.0,
                        y: (vInner.y + vOuter1.y + vOuter2.y) / 3.0
                    )
                    var innerCut = Path()
                    for v in [vInner, vOuter1, vOuter2] {
                        let pt = CGPoint(x: insetC.x + (v.x - insetC.x) * 0.46, y: insetC.y + (v.y - insetC.y) * 0.46)
                        if v == vInner { innerCut.move(to: pt) } else { innerCut.addLine(to: pt) }
                    }
                    innerCut.closeSubpath()

                    var compound = limb
                    compound.addPath(innerCut)

                    let useAccent = (i % 2 == 0)
                    context.fill(compound, with: .color(useAccent ? accentFill : primaryFill), style: FillStyle(eoFill: true))
                    context.stroke(
                        limb,
                        with: .color(useAccent ? accentStroke : primaryStroke),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        innerCut,
                        with: .color(useAccent ? accentStroke : primaryStroke),
                        style: StrokeStyle(lineWidth: 1.8, lineJoin: .round)
                    )
                }
                drawCADNode(CGPoint(x: cx, y: cy), handle: CGPoint(x: cx + 62, y: cy - 36))

            } else if item.channel.contains("Live Linux") || key.contains("linux") || key.contains("arch") || key.contains("mint") || key.contains("bsd") || key.contains("alpine") {
                // --- 4. LINUX TUX (1:1 High-Precision Line-Art Seated Penguin Reconstruction) ---
                // 1) Outer Crown, Neck S-Curve & Seated Hip Contour (Exact match to Screenshot 6.26.35 PM)
                var outerTux = Path()
                outerTux.move(to: CGPoint(x: cx - 32, y: cy + 68)) // Bottom groin between feet
                outerTux.addLine(to: CGPoint(x: cx + 30, y: cy + 68))
                // Right hip + right flipper outer edge + right neck S-curve up to dome of head
                outerTux.addCurve(
                    to: CGPoint(x: cx + 68, y: cy + 16),
                    control1: CGPoint(x: cx + 52, y: cy + 56),
                    control2: CGPoint(x: cx + 74, y: cy + 38)
                )
                outerTux.addCurve(
                    to: CGPoint(x: cx + 34, y: cy - 48),
                    control1: CGPoint(x: cx + 64, y: cy - 8),
                    control2: CGPoint(x: cx + 38, y: cy - 26)
                )
                // Top of Penguin Head Dome
                outerTux.addCurve(
                    to: CGPoint(x: cx - 34, y: cy - 48),
                    control1: CGPoint(x: cx + 32, y: cy - 102),
                    control2: CGPoint(x: cx - 32, y: cy - 102)
                )
                // Left neck S-curve + left flipper outer edge down to left hip
                outerTux.addCurve(
                    to: CGPoint(x: cx - 66, y: cy + 18),
                    control1: CGPoint(x: cx - 38, y: cy - 26),
                    control2: CGPoint(x: cx - 62, y: cy - 8)
                )
                outerTux.addCurve(
                    to: CGPoint(x: cx - 32, y: cy + 68),
                    control1: CGPoint(x: cx - 70, y: cy + 38),
                    control2: CGPoint(x: cx - 50, y: cy + 56)
                )
                outerTux.closeSubpath()
                context.fill(outerTux, with: .color(primaryFill))
                context.stroke(outerTux, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))

                // 2) Pear-Shaped White/Accent Inner Belly Patch
                var belly = Path()
                belly.move(to: CGPoint(x: cx - 22, y: cy - 22))
                belly.addCurve(
                    to: CGPoint(x: cx - 44, y: cy + 44),
                    control1: CGPoint(x: cx - 34, y: cy - 4),
                    control2: CGPoint(x: cx - 52, y: cy + 20)
                )
                belly.addQuadCurve(
                    to: CGPoint(x: cx + 42, y: cy + 44),
                    control: CGPoint(x: cx, y: cy + 64)
                )
                belly.addCurve(
                    to: CGPoint(x: cx + 22, y: cy - 22),
                    control1: CGPoint(x: cx + 50, y: cy + 20),
                    control2: CGPoint(x: cx + 34, y: cy - 4)
                )
                belly.closeSubpath()
                context.fill(belly, with: .color(accentFill.opacity(0.55)))
                context.stroke(belly, with: .color(accentStroke), lineWidth: 2.0)

                // 3) Inner Flipper Crease Lines (Left & Right Arm Highlights from Reference)
                var flipperCreases = Path()
                flipperCreases.move(to: CGPoint(x: cx - 38, y: cy - 4))
                flipperCreases.addQuadCurve(to: CGPoint(x: cx - 44, y: cy + 32), control: CGPoint(x: cx - 52, y: cy + 14))
                flipperCreases.move(to: CGPoint(x: cx + 38, y: cy - 6))
                flipperCreases.addQuadCurve(to: CGPoint(x: cx + 46, y: cy + 22), control: CGPoint(x: cx + 50, y: cy + 8))
                context.stroke(flipperCreases, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

                // 4) Wide-Set Oval Eyes + Cross-Eyed Pupils Tucked Above the Beak
                let lEye = CGRect(x: cx - 23, y: cy - 56, width: 19, height: 25)
                let rEye = CGRect(x: cx + 4, y: cy - 56, width: 21, height: 26)
                context.fill(Path(ellipseIn: lEye), with: .color(primaryFill))
                context.fill(Path(ellipseIn: rEye), with: .color(primaryFill))
                context.stroke(Path(ellipseIn: lEye), with: .color(primaryStroke), lineWidth: 2.0)
                context.stroke(Path(ellipseIn: rEye), with: .color(primaryStroke), lineWidth: 2.0)
                // Pupils
                context.fill(Path(ellipseIn: CGRect(x: cx - 15, y: cy - 46, width: 8, height: 12)), with: .color(accentStroke))
                context.fill(Path(ellipseIn: CGRect(x: cx + 9, y: cy - 46, width: 9, height: 13)), with: .color(accentStroke))

                // 5) Contoured Beak with Nostril Dots & Inner Smile Line
                var beak = Path()
                beak.move(to: CGPoint(x: cx - 26, y: cy - 30))
                beak.addCurve(
                    to: CGPoint(x: cx + 26, y: cy - 30),
                    control1: CGPoint(x: cx - 14, y: cy - 44),
                    control2: CGPoint(x: cx + 14, y: cy - 44)
                )
                beak.addCurve(
                    to: CGPoint(x: cx, y: cy - 12),
                    control1: CGPoint(x: cx + 28, y: cy - 20),
                    control2: CGPoint(x: cx + 14, y: cy - 12)
                )
                beak.addCurve(
                    to: CGPoint(x: cx - 26, y: cy - 30),
                    control1: CGPoint(x: cx - 14, y: cy - 12),
                    control2: CGPoint(x: cx - 28, y: cy - 20)
                )
                beak.closeSubpath()
                context.fill(beak, with: .color(accentFill))
                context.stroke(beak, with: .color(accentStroke), lineWidth: 2.2)

                // Smile crease + two nostril dots inside beak
                var smileCrease = Path()
                smileCrease.move(to: CGPoint(x: cx - 20, y: cy - 28))
                smileCrease.addQuadCurve(to: CGPoint(x: cx + 20, y: cy - 28), control: CGPoint(x: cx, y: cy - 17))
                context.stroke(smileCrease, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                context.fill(Path(ellipseIn: CGRect(x: cx - 6, y: cy - 36, width: 3, height: 2)), with: .color(primaryStroke))
                context.fill(Path(ellipseIn: CGRect(x: cx + 3, y: cy - 36, width: 3, height: 2)), with: .color(primaryStroke))

                // 6) Large 3-Lobed Webbed Feet (Tilted Outward on Bottom Left & Right)
                // Left Webbed Foot
                var leftFoot = Path()
                leftFoot.move(to: CGPoint(x: cx - 34, y: cy + 54))
                leftFoot.addQuadCurve(to: CGPoint(x: cx - 64, y: cy + 28), control: CGPoint(x: cx - 48, y: cy + 32))
                leftFoot.addQuadCurve(to: CGPoint(x: cx - 88, y: cy + 48), control: CGPoint(x: cx - 78, y: cy + 36))
                leftFoot.addQuadCurve(to: CGPoint(x: cx - 84, y: cy + 72), control: CGPoint(x: cx - 94, y: cy + 62))
                leftFoot.addQuadCurve(to: CGPoint(x: cx - 42, y: cy + 84), control: CGPoint(x: cx - 64, y: cy + 86))
                leftFoot.addQuadCurve(to: CGPoint(x: cx - 34, y: cy + 54), control: CGPoint(x: cx - 26, y: cy + 74))
                leftFoot.closeSubpath()
                context.fill(leftFoot, with: .color(accentFill))
                context.stroke(leftFoot, with: .color(accentStroke), lineWidth: 2.2)

                // Right Webbed Foot
                var rightFoot = Path()
                rightFoot.move(to: CGPoint(x: cx + 26, y: cy + 52))
                rightFoot.addQuadCurve(to: CGPoint(x: cx + 58, y: cy + 26), control: CGPoint(x: cx + 38, y: cy + 28))
                rightFoot.addQuadCurve(to: CGPoint(x: cx + 86, y: cy + 52), control: CGPoint(x: cx + 76, y: cy + 34))
                rightFoot.addQuadCurve(to: CGPoint(x: cx + 82, y: cy + 76), control: CGPoint(x: cx + 92, y: cy + 66))
                rightFoot.addQuadCurve(to: CGPoint(x: cx + 34, y: cy + 86), control: CGPoint(x: cx + 58, y: cy + 88))
                rightFoot.addQuadCurve(to: CGPoint(x: cx + 26, y: cy + 52), control: CGPoint(x: cx + 18, y: cy + 74))
                rightFoot.closeSubpath()
                context.fill(rightFoot, with: .color(accentFill))
                context.stroke(rightFoot, with: .color(accentStroke), lineWidth: 2.2)

                drawCADNode(CGPoint(x: cx + 58, y: cy + 26), handle: CGPoint(x: cx + 84, y: cy + 8))

            } else if key.contains("xbox") {
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

            } else if key.contains("dream") || key.contains("sega") || key.contains("240p") || key.contains("sonic") {
                // --- 7B. SONIC AT FULL SPEED V2 (1:1 Occluded Painter's-Order Line-Art Reconstruction) ---
                // Normalized directly from the 1024x1024 reference image: center (500, 500) -> (cx, cy)
                let s: CGFloat = 0.215
                func spt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: cx + (x - 490.0) * s, y: cy + (y - 495.0) * s)
                }

                // Opaque dark blueprint backing color so foreground limbs cleanly occlude background lines!
                let occludeDark = occludeBacking

                // Helper: Draws a filled + stroked closed shape with opaque backing so lines behind it never bleed through
                func drawOccludedLayer(_ path: Path, fill: Color, stroke: Color, lineWidth: CGFloat = 2.2) {
                    context.fill(path, with: .color(occludeDark))
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }

                // =====================================================================
                // LAYER 1: COMIC-BOOK TAPERED VELOCITY WEDGES & EXTENDED SLIPSTREAM
                // =====================================================================
                var comicWedges = Path()
                // Tapered comic-ink wedges radiating along the 38-degree sprint vector
                for (xFar, yFar, spread, xNear, yNear) in [
                    (-650.0, -420.0, 26.0, 290.0, 145.0),
                    (-580.0, -310.0, 18.0, 220.0, 210.0),
                    (-720.0, -290.0, 32.0, 195.0, 315.0),
                    (-640.0, -150.0, 20.0, 210.0, 420.0),
                    (-690.0,  -20.0, 28.0, 145.0, 530.0),
                    (-590.0,  120.0, 22.0, 290.0, 725.0),
                    (-480.0,  260.0, 24.0, 445.0, 920.0),
                    ( -40.0, -380.0, 18.0, 760.0, 165.0),
                    ( 120.0, -360.0, 14.0, 845.0, 140.0)
                ] {
                    comicWedges.move(to: spt(CGFloat(xFar), CGFloat(yFar)))
                    comicWedges.addLine(to: spt(CGFloat(xNear), CGFloat(yNear)))
                    comicWedges.addLine(to: spt(CGFloat(xFar), CGFloat(yFar + spread)))
                    comicWedges.closeSubpath()
                }
                context.fill(comicWedges, with: .color(primaryStroke.opacity(0.32)))

                var fineStreaks = Path()
                for (x0, y0, x1, y1) in [
                    (-700.0, -450.0, 360.0, 110.0),
                    (-610.0, -350.0, 250.0, 190.0),
                    (-660.0, -220.0, 210.0, 355.0),
                    (-580.0,  -90.0, 180.0, 445.0),
                    (-620.0,   45.0, 165.0, 585.0),
                    (-540.0,  185.0, 310.0, 775.0),
                    (-420.0,  310.0, 475.0, 955.0),
                    (  40.0, -370.0, 810.0, 155.0)
                ] {
                    fineStreaks.move(to: spt(CGFloat(x0), CGFloat(y0)))
                    fineStreaks.addLine(to: spt(CGFloat(x1), CGFloat(y1)))
                }
                context.stroke(fineStreaks, with: .color(primaryStroke.opacity(0.50)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                // =====================================================================
                // LAYER 2: TRAILING REAR LEG, SOCK CUFF & BUCKLED POWER SNEAKER
                // =====================================================================
                // Rear Sneaker Body (With curved sole arch, toe contour lines & side buckle)
                var rearShoe = Path()
                rearShoe.move(to: spt(395, 585))
                rearShoe.addCurve(to: spt(305, 765), control1: spt(335, 620), control2: spt(300, 695))
                rearShoe.addCurve(to: spt(355, 895), control1: spt(308, 835), control2: spt(328, 885))
                rearShoe.addCurve(to: spt(448, 720), control1: spt(398, 902), control2: spt(442, 815))
                rearShoe.closeSubpath()
                drawOccludedLayer(rearShoe, fill: accentFill.opacity(0.65), stroke: accentStroke, lineWidth: 2.2)

                // Rear Shoe Inner Sole Rim, Toe Shading & Side Strap Buckle
                var rearShoeDetail = Path()
                rearShoeDetail.move(to: spt(390, 602))
                rearShoeDetail.addCurve(to: spt(352, 882), control1: spt(320, 665), control2: spt(318, 820))
                // White strap across instep + rectangular buckle on left
                rearShoeDetail.move(to: spt(322, 705))
                rearShoeDetail.addQuadCurve(to: spt(428, 785), control: spt(375, 755))
                rearShoeDetail.move(to: spt(318, 725))
                rearShoeDetail.addQuadCurve(to: spt(418, 805), control: spt(368, 775))
                // Buckle box
                rearShoeDetail.addRect(CGRect(x: spt(320, 704).x, y: spt(320, 704).y, width: 22 * s, height: 22 * s))
                context.stroke(rearShoeDetail, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

                // Puffy Folded Ankle Sock Cuff on Rear Leg
                var rearSockCuff = Path()
                rearSockCuff.move(to: spt(395, 598))
                rearSockCuff.addCurve(to: spt(472, 695), control1: spt(435, 595), control2: spt(478, 645))
                rearSockCuff.addCurve(to: spt(380, 685), control1: spt(465, 735), control2: spt(405, 735))
                rearSockCuff.addCurve(to: spt(395, 598), control1: spt(362, 650), control2: spt(370, 605))
                rearSockCuff.closeSubpath()
                drawOccludedLayer(rearSockCuff, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.1)

                // Short Leg Cylinder inside Rear Sock Cuff
                var rearLeg = Path()
                rearLeg.move(to: spt(435, 588))
                rearLeg.addLine(to: spt(396, 652))
                rearLeg.addQuadCurve(to: spt(438, 678), control: spt(412, 675))
                rearLeg.addLine(to: spt(468, 625))
                rearLeg.closeSubpath()
                drawOccludedLayer(rearLeg, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.0)

                // =====================================================================
                // LAYER 3: TORSO & ROUNDED BELLY PATCH (CONNECTING HEAD TO LEGS)
                // =====================================================================
                var torso = Path()
                torso.move(to: spt(425, 565))
                torso.addCurve(to: spt(435, 655), control1: spt(418, 595), control2: spt(420, 635))
                torso.addCurve(to: spt(615, 640), control1: spt(475, 685), control2: spt(575, 680))
                torso.addLine(to: spt(605, 575))
                torso.closeSubpath()
                drawOccludedLayer(torso, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                var bellyPatch = Path()
                bellyPatch.move(to: spt(440, 642))
                bellyPatch.addCurve(to: spt(612, 632), control1: spt(485, 610), control2: spt(565, 608))
                bellyPatch.addCurve(to: spt(440, 642), control1: spt(575, 675), control2: spt(485, 675))
                bellyPatch.closeSubpath()
                drawOccludedLayer(bellyPatch, fill: accentFill, stroke: accentStroke, lineWidth: 2.0)

                // =====================================================================
                // LAYER 4: SWEPT-BACK HEAD QUILLS & FEATHER CONTOUR HATCHING
                // =====================================================================
                var headQuills = Path()
                // Start at right temple above right eye -> sweep over massive top crown quill
                headQuills.move(to: spt(770, 325))
                headQuills.addCurve(to: spt(435, 42),  control1: spt(720, 145), control2: spt(585, 45))
                headQuills.addLine(to: spt(434, 152))
                // Quill 2 (Upper-left large curved spike)
                headQuills.addCurve(to: spt(202, 182), control1: spt(355, 96),  control2: spt(265, 118))
                headQuills.addCurve(to: spt(390, 292), control1: spt(275, 205), control2: spt(345, 245))
                // Quill 3 (Mid-left sweeping spike)
                headQuills.addCurve(to: spt(196, 412), control1: spt(305, 272), control2: spt(235, 328))
                headQuills.addCurve(to: spt(382, 435), control1: spt(258, 398), control2: spt(328, 408))
                // Quill 4 (Lower small spike above shoulder)
                headQuills.addCurve(to: spt(292, 478), control1: spt(345, 438), control2: spt(315, 455))
                headQuills.addCurve(to: spt(425, 502), control1: spt(338, 482), control2: spt(385, 492))
                headQuills.addLine(to: spt(680, 480))
                headQuills.closeSubpath()
                drawOccludedLayer(headQuills, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.5)

                // Interior Feather / Root Hatching Lines inside the Quills
                var quillContours = Path()
                // Top crown double contour
                quillContours.move(to: spt(755, 315))
                quillContours.addCurve(to: spt(585, 105), control1: spt(715, 205), control2: spt(655, 140))
                quillContours.move(to: spt(742, 305))
                quillContours.addCurve(to: spt(635, 155), control1: spt(710, 235), control2: spt(675, 185))
                // Upper-left quill root feathers
                quillContours.move(to: spt(202, 182)); quillContours.addQuadCurve(to: spt(412, 248), control: spt(315, 188))
                quillContours.move(to: spt(245, 198)); quillContours.addQuadCurve(to: spt(405, 268), control: spt(335, 218))
                // Mid-left quill root feathers
                quillContours.move(to: spt(196, 412)); quillContours.addQuadCurve(to: spt(405, 385), control: spt(305, 378))
                quillContours.move(to: spt(248, 405)); quillContours.addQuadCurve(to: spt(402, 408), control: spt(325, 395))
                // Cheek curve behind left eye
                quillContours.move(to: spt(418, 355))
                quillContours.addQuadCurve(to: spt(452, 515), control: spt(398, 440))
                context.stroke(quillContours, with: .color(primaryStroke.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                // =====================================================================
                // LAYER 5: FOREGROUND LEFT EAR (WITH FUR ZIG-ZAG) & FAR-RIGHT EAR
                // =====================================================================
                var leftEar = Path()
                leftEar.move(to: spt(462, 318))
                leftEar.addCurve(to: spt(486, 122), control1: spt(455, 245), control2: spt(468, 175))
                leftEar.addCurve(to: spt(615, 282), control1: spt(535, 165), control2: spt(582, 225))
                leftEar.closeSubpath()
                drawOccludedLayer(leftEar, fill: accentFill, stroke: accentStroke, lineWidth: 2.3)

                var leftEarInner = Path()
                leftEarInner.move(to: spt(478, 308))
                leftEarInner.addCurve(to: spt(496, 156), control1: spt(476, 248), control2: spt(485, 195))
                leftEarInner.addCurve(to: spt(592, 278), control1: spt(535, 192), control2: spt(568, 238))
                // Authentic Jagged Fur Tuft inside Left Ear
                leftEarInner.move(to: spt(496, 252))
                leftEarInner.addLine(to: spt(538, 260))
                leftEarInner.addLine(to: spt(505, 272))
                leftEarInner.addLine(to: spt(542, 285))
                leftEarInner.addLine(to: spt(486, 302))
                context.stroke(leftEarInner, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

                var rightEar = Path()
                rightEar.move(to: spt(755, 225))
                rightEar.addCurve(to: spt(892, 152), control1: spt(805, 190), control2: spt(852, 165))
                rightEar.addCurve(to: spt(815, 358), control1: spt(882, 225), control2: spt(852, 298))
                rightEar.closeSubpath()
                drawOccludedLayer(rightEar, fill: accentFill, stroke: accentStroke, lineWidth: 2.3)

                var rightEarInner = Path()
                rightEarInner.move(to: spt(778, 255))
                rightEarInner.addLine(to: spt(868, 185))
                rightEarInner.addLine(to: spt(808, 342))
                rightEarInner.closeSubpath()
                context.fill(rightEarInner, with: .color(primaryFill))
                context.stroke(rightEarInner, with: .color(primaryStroke), lineWidth: 1.7)

                // =====================================================================
                // LAYER 6: SCULPTED 3D BROW RIM, EYE APERTURES, MUZZLE, SMIRK & NOSE
                // =====================================================================
                // Eye Sclera Apertures (Left & Right)
                var eyeApertures = Path()
                eyeApertures.move(to: spt(475, 488))
                eyeApertures.addCurve(to: spt(525, 375), control1: spt(465, 435), control2: spt(488, 378))
                eyeApertures.addCurve(to: spt(675, 535), control1: spt(578, 372), control2: spt(635, 455))
                eyeApertures.addCurve(to: spt(792, 372), control1: spt(710, 455), control2: spt(758, 372))
                eyeApertures.addCurve(to: spt(768, 528), control1: spt(822, 372), control2: spt(805, 465))
                eyeApertures.closeSubpath()
                drawOccludedLayer(eyeApertures, fill: occludeDark, stroke: primaryStroke, lineWidth: 2.4)

                // Sculpted 3D Upper Brow Rim (Double-line thickness arching over both eyes & dipping into center V-scowl)
                var browRim = Path()
                browRim.move(to: spt(468, 482))
                browRim.addCurve(to: spt(528, 362), control1: spt(455, 425), control2: spt(482, 365))
                browRim.addCurve(to: spt(675, 512), control1: spt(582, 358), control2: spt(638, 438))
                browRim.addCurve(to: spt(796, 358), control1: spt(712, 438), control2: spt(762, 355))
                browRim.addCurve(to: spt(775, 525), control1: spt(835, 360), control2: spt(818, 462))
                // Center vertical scowl creases above bridge of brow
                browRim.move(to: spt(665, 465)); browRim.addLine(to: spt(652, 415))
                browRim.move(to: spt(682, 472)); browRim.addLine(to: spt(688, 428))
                browRim.move(to: spt(708, 445)); browRim.addQuadCurve(to: spt(705, 295), control: spt(712, 365))
                context.stroke(browRim, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

                // Fierce Vertical Oval Pupils Tucked Under the V-Brow
                var pupils = Path()
                pupils.addEllipse(in: CGRect(x: spt(610, 455).x, y: spt(610, 455).y, width: 38 * s, height: 82 * s))
                pupils.addEllipse(in: CGRect(x: spt(715, 455).x, y: spt(715, 455).y, width: 36 * s, height: 78 * s))
                context.fill(pupils, with: .color(accentStroke))

                // Iconic Cheek-to-Chin Muzzle (High left cheek pouch -> dips under V-brow -> rises to right cheek)
                var muzzle = Path()
                muzzle.move(to: spt(456, 512))
                // High rounded left cheek pouch
                muzzle.addCurve(to: spt(575, 528), control1: spt(458, 472), control2: spt(518, 488))
                // Dip under the center V-brow and nose bridge
                muzzle.addCurve(to: spt(725, 542), control1: spt(625, 558), control2: spt(685, 558))
                // Right cheek pouch curving up & around
                muzzle.addCurve(to: spt(782, 528), control1: spt(752, 532), control2: spt(775, 515))
                muzzle.addCurve(to: spt(735, 612), control1: spt(790, 548), control2: spt(768, 588))
                // Chin & lower jaw sweeping back up to the left cheek
                muzzle.addCurve(to: spt(542, 622), control1: spt(685, 652), control2: spt(605, 652))
                muzzle.addCurve(to: spt(456, 512), control1: spt(485, 595), control2: spt(454, 552))
                muzzle.closeSubpath()
                drawOccludedLayer(muzzle, fill: accentFill, stroke: accentStroke, lineWidth: 2.4)

                // Confident Smirk Line + Corner Cheek Dimple inside Muzzle
                var smirk = Path()
                smirk.move(to: spt(532, 552))
                smirk.addCurve(to: spt(632, 625), control1: spt(558, 585), control2: spt(595, 615))
                // Dimple bracket at top-left of smirk
                smirk.move(to: spt(518, 555))
                smirk.addQuadCurve(to: spt(544, 548), control: spt(532, 548))
                context.stroke(smirk, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                // 3D Pointed Oval Nose Mounted on the Upper-Right Ridge of the Muzzle (With Specular Highlight!)
                var nose = Path()
                nose.move(to: spt(668, 578))
                nose.addCurve(to: spt(755, 592), control1: spt(692, 562), control2: spt(738, 568))
                nose.addCurve(to: spt(668, 578), control1: spt(745, 618), control2: spt(682, 608))
                nose.closeSubpath()
                context.fill(nose, with: .color(occludeDark))
                context.stroke(nose, with: .color(primaryStroke), lineWidth: 2.2)
                // Curved white/cyan highlight inside top of nose
                var noseShine = Path()
                noseShine.move(to: spt(688, 580))
                noseShine.addQuadCurve(to: spt(732, 586), control: spt(712, 575))
                context.stroke(noseShine, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

                // =====================================================================
                // LAYER 7: EXTENDED RIGHT ARM (LEFT SIDE), PUFF CUFF & SPLAYED 5-FINGER HAND
                // =====================================================================
                // Splayed 5-Finger Glove (Drawn first, then the wrist cuff overlaps the wrist, then arm plugs into cuff!)
                var splayedGlove = Path()
                splayedGlove.move(to: spt(255, 485))
                // Top index finger
                splayedGlove.addCurve(to: spt(162, 502), control1: spt(215, 480), control2: spt(182, 488))
                splayedGlove.addCurve(to: spt(158, 535), control1: spt(148, 512), control2: spt(148, 526))
                // Middle finger
                splayedGlove.addCurve(to: spt(136, 562), control1: spt(142, 542), control2: spt(134, 552))
                splayedGlove.addCurve(to: spt(158, 586), control1: spt(136, 574), control2: spt(146, 582))
                // Ring & pinky fingers
                splayedGlove.addCurve(to: spt(144, 615), control1: spt(144, 595), control2: spt(140, 605))
                splayedGlove.addCurve(to: spt(188, 632), control1: spt(152, 628), control2: spt(170, 634))
                splayedGlove.addCurve(to: spt(215, 618), control1: spt(198, 628), control2: spt(208, 622))
                // Downward extended thumb with knuckle bend
                splayedGlove.addCurve(to: spt(252, 688), control1: spt(232, 642), control2: spt(242, 668))
                splayedGlove.addCurve(to: spt(282, 675), control1: spt(264, 698), control2: spt(278, 690))
                splayedGlove.addCurve(to: spt(268, 595), control1: spt(282, 648), control2: spt(265, 620))
                splayedGlove.closeSubpath()
                drawOccludedLayer(splayedGlove, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                // Interior Finger Creases & Palm Lines inside Splayed Glove
                var gloveDetails = Path()
                gloveDetails.move(to: spt(158, 535)); gloveDetails.addLine(to: spt(198, 528))
                gloveDetails.move(to: spt(158, 586)); gloveDetails.addLine(to: spt(198, 568))
                gloveDetails.move(to: spt(172, 612)); gloveDetails.addLine(to: spt(205, 595))
                gloveDetails.move(to: spt(218, 555)); gloveDetails.addQuadCurve(to: spt(242, 605), control: spt(238, 578))
                context.stroke(gloveDetails, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                // Puffy Tilted Wrist Cuff Ring on Left Arm
                var leftWristCuff = Path()
                leftWristCuff.move(to: spt(288, 476))
                leftWristCuff.addCurve(to: spt(345, 575), control1: spt(328, 478), control2: spt(355, 535))
                leftWristCuff.addCurve(to: spt(275, 598), control1: spt(335, 605), control2: spt(298, 612))
                leftWristCuff.addCurve(to: spt(242, 512), control1: spt(250, 580), control2: spt(236, 545))
                leftWristCuff.addCurve(to: spt(288, 476), control1: spt(248, 488), control2: spt(268, 475))
                leftWristCuff.closeSubpath()
                drawOccludedLayer(leftWristCuff, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                // Tapered Arm Tube Plugging Smoothly into the Cuff Opening (Occluding the inner cuff rim!)
                var leftArmTube = Path()
                leftArmTube.move(to: spt(302, 512))
                leftArmTube.addCurve(to: spt(465, 568), control1: spt(355, 522), control2: spt(415, 545))
                leftArmTube.addLine(to: spt(488, 612))
                leftArmTube.addCurve(to: spt(300, 555), control1: spt(425, 592), control2: spt(355, 568))
                leftArmTube.closeSubpath()
                drawOccludedLayer(leftArmTube, fill: accentFill, stroke: accentStroke, lineWidth: 2.2)

                // =====================================================================
                // LAYER 8: FORESHORTENED KICKING FRONT SNEAKER & 14 WAVY TREAD GROOVES
                // =====================================================================
                // Upper Red/Accent Shoe Vamp & Ankle Sock Cuff behind the big front sole
                var frontShoeUpper = Path()
                frontShoeUpper.move(to: spt(512, 668))
                frontShoeUpper.addCurve(to: spt(462, 795), control1: spt(475, 695), control2: spt(455, 745))
                frontShoeUpper.addLine(to: spt(545, 815))
                frontShoeUpper.addLine(to: spt(575, 668))
                frontShoeUpper.closeSubpath()
                drawOccludedLayer(frontShoeUpper, fill: accentFill.opacity(0.65), stroke: accentStroke, lineWidth: 2.1)

                // Giant Foreshortened Oval Shoe Sole (Tilted at +12 Degrees)
                var frontSoleOuter = Path()
                frontSoleOuter.move(to: spt(585, 668))
                frontSoleOuter.addCurve(to: spt(656, 825), control1: spt(638, 672), control2: spt(668, 745))
                frontSoleOuter.addCurve(to: spt(528, 962), control1: spt(642, 902), control2: spt(592, 962))
                frontSoleOuter.addCurve(to: spt(476, 822), control1: spt(475, 962), control2: spt(465, 895))
                frontSoleOuter.addCurve(to: spt(585, 668), control1: spt(488, 742), control2: spt(532, 665))
                frontSoleOuter.closeSubpath()
                drawOccludedLayer(frontSoleOuter, fill: accentFill, stroke: accentStroke, lineWidth: 2.5)

                // Inner Sole Rim + 13 Wavy Horizontal Grip Treads inside the Front Shoe Sole
                var frontSoleInner = Path()
                frontSoleInner.move(to: spt(582, 686))
                frontSoleInner.addCurve(to: spt(638, 822), control1: spt(624, 690), control2: spt(648, 752))
                frontSoleInner.addCurve(to: spt(532, 944), control1: spt(626, 892), control2: spt(584, 944))
                frontSoleInner.addCurve(to: spt(494, 822), control1: spt(488, 944), control2: spt(484, 885))
                frontSoleInner.addCurve(to: spt(582, 686), control1: spt(505, 752), control2: spt(540, 684))
                frontSoleInner.closeSubpath()
                context.fill(frontSoleInner, with: .color(occludeDark))
                context.stroke(frontSoleInner, with: .color(primaryStroke), lineWidth: 1.9)

                var wavyTreads = Path()
                for ty in stride(from: 704.0, through: 928.0, by: 17.5) {
                    let norm = (ty - 815.0) / 128.0
                    let halfW = max(16.0, 62.0 * sqrt(max(0.0, 1.0 - norm * norm)))
                    let midX = 566.0 - (ty - 815.0) * 0.22
                    let lx = CGFloat(midX - halfW)
                    let rx = CGFloat(midX + halfW)
                    let yVal = CGFloat(ty)
                    wavyTreads.move(to: spt(lx, yVal - 3))
                    wavyTreads.addCurve(
                        to: spt(rx, yVal + 5),
                        control1: spt(lx + CGFloat(halfW) * 0.65, yVal - 8),
                        control2: spt(rx - CGFloat(halfW) * 0.65, yVal + 10)
                    )
                }
                context.stroke(wavyTreads, with: .color(primaryStroke.opacity(0.90)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                // =====================================================================
                // LAYER 9: CLENCHED FORWARD LEFT FIST & WRIST CUFF (BOTTOM-RIGHT)
                // =====================================================================
                // Forward Wrist Cuff Ring emerging from right shoulder/chest
                var fwdCuff = Path()
                fwdCuff.move(to: spt(718, 668))
                fwdCuff.addCurve(to: spt(815, 608), control1: spt(732, 625), control2: spt(775, 598))
                fwdCuff.addCurve(to: spt(842, 642), control1: spt(832, 612), control2: spt(842, 626))
                fwdCuff.addCurve(to: spt(735, 695), control1: spt(805, 655), control2: spt(762, 675))
                fwdCuff.closeSubpath()
                drawOccludedLayer(fwdCuff, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                // Clenched Forward Fist with 4 Articulated Curled Fingers & Thumb
                var fwdFist = Path()
                fwdFist.move(to: spt(732, 682))
                fwdFist.addCurve(to: spt(835, 615), control1: spt(752, 635), control2: spt(795, 610))
                fwdFist.addCurve(to: spt(905, 725), control1: spt(878, 622), control2: spt(908, 675))
                fwdFist.addCurve(to: spt(825, 782), control1: spt(902, 762), control2: spt(865, 785))
                fwdFist.addCurve(to: spt(732, 682), control1: spt(775, 778), control2: spt(730, 735))
                fwdFist.closeSubpath()
                drawOccludedLayer(fwdFist, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.4)

                // Interior Finger Knuckle & Thumb Creases inside Forward Fist
                var fwdFistLines = Path()
                // Thumb curl on left of fist
                fwdFistLines.move(to: spt(768, 665))
                fwdFistLines.addCurve(to: spt(795, 732), control1: spt(798, 672), control2: spt(805, 708))
                fwdFistLines.addCurve(to: spt(758, 715), control1: spt(782, 742), control2: spt(760, 732))
                // Curled fingers on right of fist
                fwdFistLines.move(to: spt(838, 632)); fwdFistLines.addCurve(to: spt(812, 755), control1: spt(852, 678), control2: spt(838, 725))
                fwdFistLines.move(to: spt(868, 652)); fwdFistLines.addCurve(to: spt(845, 768), control1: spt(878, 695), control2: spt(865, 738))
                fwdFistLines.move(to: spt(888, 678)); fwdFistLines.addCurve(to: spt(872, 765), control1: spt(895, 712), control2: spt(885, 742))
                context.stroke(fwdFistLines, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

            } else if key.contains("wii") || key.contains("gc") || key.contains("gamecube") || key.contains("swiss") || key.contains("nintendo") || key.contains("mario") || item.channel.contains("Console") {
                // --- 8. JUMPING MARIO V2 (1:1 Multi-Layer Painter-Occluded Line-Art Reconstruction) ---
                // Shifted down +10pt at 1.02x scale so the raised fist knuckles & kicked boot frame cleanly!
                let s: CGFloat = 1.02
                func mpt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
                    CGPoint(x: cx + dx * s, y: (cy + 10.0) + dy * s)
                }

                let occludeDark = occludeBacking

                func drawOccluded(_ path: Path, fill: Color, stroke: Color, lineWidth: CGFloat = 2.2) {
                    context.fill(path, with: .color(occludeDark))
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }

                // =====================================================================
                // LAYER 1: EXTENDED LOWER-LEFT BOOT & LEFT ARM SLEEVE (DEEP BACKGROUND)
                // =====================================================================
                // Extended Left Boot (Bottom-Left)
                var leftBoot = Path()
                leftBoot.move(to: mpt(-40, 74))
                leftBoot.addCurve(to: mpt(-12, 68), control1: mpt(-31, 75), control2: mpt(-19, 73))
                leftBoot.addCurve(to: mpt(-11, 95), control1: mpt(-5, 77),  control2: mpt(-5, 89))
                leftBoot.addCurve(to: mpt(-37, 94), control1: mpt(-17, 100), control2: mpt(-31, 100))
                leftBoot.addCurve(to: mpt(-40, 74), control1: mpt(-41, 89), control2: mpt(-41, 81))
                leftBoot.closeSubpath()
                drawOccluded(leftBoot, fill: accentFill.opacity(0.65), stroke: accentStroke, lineWidth: 2.2)

                // Left Boot Sole Rim
                var leftBootSole = Path()
                leftBootSole.move(to: mpt(-39, 88))
                leftBootSole.addCurve(to: mpt(-11, 88), control1: mpt(-29, 94), control2: mpt(-18, 93))
                context.stroke(leftBootSole, with: .color(primaryStroke), lineWidth: 1.8)

                // Raised Left Arm Sleeve (Rising vertically from left shoulder behind the head)
                var leftSleeve = Path()
                leftSleeve.move(to: mpt(-54, -55))
                leftSleeve.addCurve(to: mpt(-49, -6),  control1: mpt(-53, -36), control2: mpt(-50, -18))
                leftSleeve.addCurve(to: mpt(-61, 19),  control1: mpt(-53, 3),   control2: mpt(-58, 12))
                leftSleeve.addLine(to: mpt(-30, 8))
                leftSleeve.addLine(to: mpt(-31, -52))
                leftSleeve.closeSubpath()
                drawOccluded(leftSleeve, fill: accentFill.opacity(0.55), stroke: accentStroke, lineWidth: 2.2)

                // Right Arm Sleeve + Shoulder (Behind chest & right fist)
                var rightSleeve = Path()
                rightSleeve.move(to: mpt(10, 4))
                rightSleeve.addLine(to: mpt(26, 2))
                rightSleeve.addLine(to: mpt(26, 30))
                rightSleeve.addLine(to: mpt(9, 28))
                rightSleeve.closeSubpath()
                drawOccluded(rightSleeve, fill: accentFill.opacity(0.50), stroke: accentStroke, lineWidth: 2.1)

                // =====================================================================
                // LAYER 2: RAISED GLOVED FIST & PUFF WRIST CUFF (TOP-LEFT)
                // =====================================================================
                var raisedFist = Path()
                raisedFist.move(to: mpt(-55, -59))
                raisedFist.addCurve(to: mpt(-57, -79), control1: mpt(-59, -66), control2: mpt(-59, -73))
                // 4 Scalloped Finger Knuckles across the top of the fist
                raisedFist.addCurve(to: mpt(-48, -92), control1: mpt(-56, -86), control2: mpt(-53, -90))
                raisedFist.addCurve(to: mpt(-35, -96), control1: mpt(-44, -95), control2: mpt(-40, -96))
                raisedFist.addCurve(to: mpt(-23, -91), control1: mpt(-30, -96), control2: mpt(-26, -94))
                raisedFist.addCurve(to: mpt(-18, -81), control1: mpt(-19, -88), control2: mpt(-17, -84))
                // Tucked Thumb Knuckle on the right side of the raised fist
                raisedFist.addCurve(to: mpt(-14, -67), control1: mpt(-13, -79), control2: mpt(-12, -72))
                raisedFist.addCurve(to: mpt(-27, -55), control1: mpt(-16, -61), control2: mpt(-21, -57))
                raisedFist.closeSubpath()
                drawOccluded(raisedFist, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.4)

                // Interior Finger Roll & Thumb Crease Lines inside Raised Fist
                var fistCreases = Path()
                // Curled thumb contour wrapping into palm
                fistCreases.move(to: mpt(-18, -81))
                fistCreases.addCurve(to: mpt(-35, -74), control1: mpt(-23, -81), control2: mpt(-31, -79))
                fistCreases.addCurve(to: mpt(-42, -82), control1: mpt(-39, -72), control2: mpt(-43, -77))
                fistCreases.addCurve(to: mpt(-34, -89), control1: mpt(-42, -86), control2: mpt(-38, -88))
                // Knuckle divider creases
                fistCreases.move(to: mpt(-48, -92)); fistCreases.addCurve(to: mpt(-42, -82), control1: mpt(-45, -88), control2: mpt(-43, -85))
                fistCreases.move(to: mpt(-35, -96)); fistCreases.addCurve(to: mpt(-31, -83), control1: mpt(-33, -91), control2: mpt(-32, -87))
                fistCreases.move(to: mpt(-23, -91)); fistCreases.addCurve(to: mpt(-23, -80), control1: mpt(-23, -87), control2: mpt(-23, -83))
                // Lower palm crease
                fistCreases.move(to: mpt(-45, -66))
                fistCreases.addQuadCurve(to: mpt(-24, -65), control: mpt(-34, -60))
                context.stroke(fistCreases, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))

                // Puff Wrist Cuff Ring (Occludes the seam between sleeve and glove!)
                var leftCuff = Path()
                leftCuff.move(to: mpt(-59, -56))
                leftCuff.addCurve(to: mpt(-26, -53), control1: mpt(-48, -48), control2: mpt(-34, -48))
                leftCuff.addCurve(to: mpt(-29, -61), control1: mpt(-23, -55), control2: mpt(-24, -59))
                leftCuff.addCurve(to: mpt(-58, -62), control1: mpt(-38, -56), control2: mpt(-49, -56))
                leftCuff.addCurve(to: mpt(-59, -56), control1: mpt(-62, -60), control2: mpt(-62, -58))
                leftCuff.closeSubpath()
                drawOccluded(leftCuff, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                // =====================================================================
                // LAYER 3: TORSO SHIRT, OVERALL BIB, WAISTLINE, FLY & EXTENDED LEFT LEG
                // =====================================================================
                // Center Shirt Chest Triangle (Between collar and overall bib)
                var shirtChest = Path()
                shirtChest.move(to: mpt(-28, -2))
                shirtChest.addLine(to: mpt(10, 4))
                shirtChest.addLine(to: mpt(6, 22))
                shirtChest.addLine(to: mpt(-32, 16))
                shirtChest.closeSubpath()
                drawOccluded(shirtChest, fill: accentFill.opacity(0.55), stroke: accentStroke, lineWidth: 2.0)

                // Overall Bib + Trousers + Extended Left Leg (Closed Occluded Silhouette)
                var overalls = Path()
                overalls.move(to: mpt(-61, 19)) // Left waist hip
                overalls.addLine(to: mpt(-46, 4))
                overalls.addLine(to: mpt(-26, 9)) // Center bib top-left
                overalls.addQuadCurve(to: mpt(2, 14), control: mpt(-12, 13)) // Bib neckline
                overalls.addLine(to: mpt(14, 28))
                overalls.addLine(to: mpt(20, 50))
                overalls.addLine(to: mpt(-13, 71)) // Inner left leg ankle
                overalls.addCurve(to: mpt(-39, 76), control1: mpt(-20, 75), control2: mpt(-31, 77)) // Left leg cuff
                overalls.addCurve(to: mpt(-62, 25), control1: mpt(-51, 64), control2: mpt(-64, 45)) // Left outer thigh
                overalls.closeSubpath()
                drawOccluded(overalls, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                // Double Waistline Seam, Rectangular Center Fly Tab & Crotch Seam
                var overallSeams = Path()
                overallSeams.move(to: mpt(-61, 19))
                overallSeams.addCurve(to: mpt(-19, 41), control1: mpt(-51, 30), control2: mpt(-35, 39))
                overallSeams.move(to: mpt(-62, 25))
                overallSeams.addCurve(to: mpt(-20, 46), control1: mpt(-51, 36), control2: mpt(-35, 44))
                // Center rectangular fly tab below belt
                overallSeams.move(to: mpt(-32, 43))
                overallSeams.addLine(to: mpt(-32, 53))
                overallSeams.addLine(to: mpt(-24, 53))
                overallSeams.addLine(to: mpt(-24, 45))
                // Crotch horizontal crease
                overallSeams.move(to: mpt(-34, 58))
                overallSeams.addQuadCurve(to: mpt(-12, 58), control: mpt(-22, 60))
                context.stroke(overallSeams, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                // Left Overall Strap & Large Circular Button
                var leftStrap = Path()
                leftStrap.move(to: mpt(-30, -4))
                leftStrap.addLine(to: mpt(-49, 19))
                leftStrap.addLine(to: mpt(-41, 27))
                leftStrap.addLine(to: mpt(-29, 24))
                leftStrap.addLine(to: mpt(-23, 1))
                leftStrap.closeSubpath()
                drawOccluded(leftStrap, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)
                context.fill(Path(ellipseIn: CGRect(x: mpt(-44, 11).x, y: mpt(-44, 11).y, width: 12 * s, height: 12 * s)), with: .color(accentStroke))

                // Right Overall Strap & Large Circular Button
                var rightStrap = Path()
                rightStrap.move(to: mpt(-1, 4))
                rightStrap.addLine(to: mpt(-1, 28))
                rightStrap.addLine(to: mpt(11, 29))
                rightStrap.addLine(to: mpt(10, 5))
                rightStrap.closeSubpath()
                drawOccluded(rightStrap, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)
                context.fill(Path(ellipseIn: CGRect(x: mpt(-0.5, 15).x, y: mpt(-0.5, 15).y, width: 11 * s, height: 12 * s)), with: .color(accentStroke))

                // =====================================================================
                // LAYER 4: RAISED RIGHT THIGH/KNEE & KICKED FOREGROUND BOOT
                //    (Occludes the lower edge of the right strap & belt, just like Reference!)
                // =====================================================================
                var raisedLeg = Path()
                raisedLeg.move(to: mpt(-21, 46))
                raisedLeg.addCurve(to: mpt(29, 39), control1: mpt(-10, 17), control2: mpt(15, 18))
                raisedLeg.addLine(to: mpt(2, 68))
                raisedLeg.addLine(to: mpt(-16, 60))
                raisedLeg.closeSubpath()
                drawOccluded(raisedLeg, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.3)

                // Knee Fabric Bend Creases inside Raised Right Leg
                var kneeCreases = Path()
                kneeCreases.move(to: mpt(-14, 34))
                kneeCreases.addCurve(to: mpt(-6, 56), control1: mpt(-10, 42), control2: mpt(-8, 50))
                kneeCreases.move(to: mpt(-5, 36))
                kneeCreases.addLine(to: mpt(-2, 49))
                context.stroke(kneeCreases, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))

                // Kicked-Up Right Boot (Foreground Lower-Right with Thick Treaded Sole & Heel Block)
                var rightBoot = Path()
                rightBoot.move(to: mpt(-6, 62))
                rightBoot.addCurve(to: mpt(42, 41), control1: mpt(3, 41),   control2: mpt(24, 33))
                rightBoot.addCurve(to: mpt(49, 68), control1: mpt(52, 46),  control2: mpt(54, 59))
                rightBoot.addCurve(to: mpt(10, 80), control1: mpt(42, 78),  control2: mpt(24, 83))
                rightBoot.addCurve(to: mpt(-6, 62), control1: mpt(0, 77),   control2: mpt(-7, 69))
                rightBoot.closeSubpath()
                drawOccluded(rightBoot, fill: accentFill, stroke: accentStroke, lineWidth: 2.5)

                // Boot Sole Arch & Divided Heel Block inside Kicked Right Boot
                var bootSole = Path()
                bootSole.move(to: mpt(-3, 69))
                bootSole.addCurve(to: mpt(48, 62), control1: mpt(11, 52), control2: mpt(34, 51))
                bootSole.move(to: mpt(2, 72))
                bootSole.addLine(to: mpt(28, 78))
                bootSole.move(to: mpt(15, 67))
                bootSole.addLine(to: mpt(14, 75))
                context.stroke(bootSole, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

                // =====================================================================
                // LAYER 5: BENT RIGHT WRIST CUFF & CLENCHED FOREGROUND FIST (MID-RIGHT)
                // =====================================================================
                // Tilted Wrist Cuff Ring
                var rightWristCuff = Path()
                rightWristCuff.move(to: mpt(18, 9))
                rightWristCuff.addCurve(to: mpt(35, 34), control1: mpt(18, 23), control2: mpt(25, 33))
                rightWristCuff.addLine(to: mpt(41, 29))
                rightWristCuff.addLine(to: mpt(25, 4))
                rightWristCuff.closeSubpath()
                drawOccluded(rightWristCuff, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.1)

                // Clenched Right Gloved Fist
                var rightFist = Path()
                rightFist.move(to: mpt(24, -1))
                rightFist.addCurve(to: mpt(48, -3), control1: mpt(31, -8),  control2: mpt(42, -8))
                rightFist.addCurve(to: mpt(55, 22), control1: mpt(56, 3),   control2: mpt(58, 15))
                rightFist.addCurve(to: mpt(32, 29), control1: mpt(50, 29),  control2: mpt(40, 31))
                rightFist.addCurve(to: mpt(21, 14), control1: mpt(25, 26),  control2: mpt(21, 20))
                rightFist.closeSubpath()
                drawOccluded(rightFist, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.3)

                // Right Fist Thumb & Finger Roll Lines
                var rFistLines = Path()
                rFistLines.move(to: mpt(24, -1))
                rFistLines.addCurve(to: mpt(34, 15), control1: mpt(34, 0), control2: mpt(37, 9))
                rFistLines.addCurve(to: mpt(26, 13), control1: mpt(31, 17), control2: mpt(27, 16))
                rFistLines.move(to: mpt(37, 6));  rFistLines.addLine(to: mpt(51, 5))
                rFistLines.move(to: mpt(37, 14)); rFistLines.addLine(to: mpt(53, 13))
                rFistLines.move(to: mpt(36, 21)); rFistLines.addLine(to: mpt(50, 21))
                context.stroke(rFistLines, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))

                // =====================================================================
                // LAYER 6: CLOSED HEAD CONTOUR, CAP DOME, VISOR BRIM & 'M' EMBLEM
                // =====================================================================
                // 1) Domed Cap Crown (Drawn before visor so visor lip overlaps the cap base cleanly!)
                var capDome = Path()
                capDome.move(to: mpt(-32, -48))
                capDome.addCurve(to: mpt(12, -79), control1: mpt(-26, -70), control2: mpt(-8, -80))
                capDome.addCurve(to: mpt(41, -41), control1: mpt(30, -78), control2: mpt(42, -60))
                capDome.addCurve(to: mpt(34, -28), control1: mpt(41, -35), control2: mpt(38, -30))
                capDome.addLine(to: mpt(-29, -38))
                capDome.closeSubpath()
                drawOccluded(capDome, fill: accentFill, stroke: accentStroke, lineWidth: 2.4)

                // Circular / Oval 'M' Emblem on Front of Cap (Occluded so cap fill doesn't muddy the 'M')
                var emblemOval = Path()
                emblemOval.move(to: mpt(2, -64))
                emblemOval.addCurve(to: mpt(29, -59), control1: mpt(8, -75), control2: mpt(25, -72))
                emblemOval.addCurve(to: mpt(2, -64),  control1: mpt(31, -49), control2: mpt(-1, -53))
                emblemOval.closeSubpath()
                drawOccluded(emblemOval, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.0)

                var capM = Path()
                capM.move(to: mpt(6, -59))
                capM.addLine(to: mpt(12, -68))
                capM.addLine(to: mpt(16, -62))
                capM.addLine(to: mpt(22, -67))
                capM.addLine(to: mpt(24, -56))
                context.stroke(capM, with: .color(accentStroke), style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round))

                // 2) Closed Head, Cheek, Chin & Right Ear Silhouette (Occludes background grid & collar!)
                var headSilhouette = Path()
                headSilhouette.move(to: mpt(-29, -38))
                headSilhouette.addCurve(to: mpt(-31, -8),  control1: mpt(-33, -28), control2: mpt(-33, -18))
                headSilhouette.addCurve(to: mpt(-3, 6),    control1: mpt(-29, 2),   control2: mpt(-16, 7))
                headSilhouette.addCurve(to: mpt(22, -7),   control1: mpt(8, 5),    control2: mpt(17, 0))
                // Right Ear lobe
                headSilhouette.addCurve(to: mpt(34, -10),  control1: mpt(26, -5),   control2: mpt(31, -6))
                headSilhouette.addCurve(to: mpt(34, -28),  control1: mpt(39, -15),  control2: mpt(39, -24))
                headSilhouette.addCurve(to: mpt(-29, -38), control1: mpt(18, -50),  control2: mpt(-10, -52))
                headSilhouette.closeSubpath()
                drawOccluded(headSilhouette, fill: primaryFill.opacity(0.38), stroke: primaryStroke, lineWidth: 2.3)

                // 3) Curved Visor Brim Lip (Drawn ON TOP of upper forehead for crisp occlusion!)
                var visorBrim = Path()
                visorBrim.move(to: mpt(-31, -45))
                visorBrim.addCurve(to: mpt(36, -33), control1: mpt(-12, -63), control2: mpt(22, -59))
                visorBrim.addCurve(to: mpt(31, -26), control1: mpt(37, -29), control2: mpt(35, -26))
                visorBrim.addCurve(to: mpt(-29, -37), control1: mpt(18, -48), control2: mpt(-10, -51))
                visorBrim.closeSubpath()
                drawOccluded(visorBrim, fill: primaryFill, stroke: primaryStroke, lineWidth: 2.2)

                // =====================================================================
                // LAYER 7: FACIAL FEATURES WITH STRICT PAINTER'S OCCLUSION
                //    Order: Ear/Sideburn/Brows -> Eyes -> Mouth -> Mustache -> Nose ON TOP!
                // =====================================================================
                // Right Sideburn Block, Ear Acoustic Crease & Eyebrows
                var sideburn = Path()
                sideburn.move(to: mpt(23, -29))
                sideburn.addLine(to: mpt(29, -27))
                sideburn.addLine(to: mpt(27, -14))
                sideburn.addLine(to: mpt(22, -16))
                sideburn.closeSubpath()
                context.fill(sideburn, with: .color(accentStroke))

                var earAndBrows = Path()
                // Inner ear spiral
                earAndBrows.move(to: mpt(29, -22))
                earAndBrows.addQuadCurve(to: mpt(28, -13), control: mpt(33, -17))
                // Left & Right arched eyebrows
                earAndBrows.move(to: mpt(-21, -42))
                earAndBrows.addQuadCurve(to: mpt(-4, -41), control: mpt(-12, -49))
                earAndBrows.move(to: mpt(11, -38))
                earAndBrows.addQuadCurve(to: mpt(24, -30), control: mpt(19, -42))
                context.stroke(earAndBrows, with: .color(accentStroke), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                // Left & Right Concentric Eyes (Drawn BEFORE Mustache & Nose so Nose cleanly occludes their lower-inner rims!)
                let leftEyeRect  = CGRect(x: mpt(-19, -41).x, y: mpt(-19, -41).y, width: 13 * s, height: 17 * s)
                let rightEyeRect = CGRect(x: mpt(6, -38).x,   y: mpt(6, -38).y,   width: 13 * s, height: 17 * s)
                drawOccluded(Path(ellipseIn: leftEyeRect),  fill: occludeDark, stroke: primaryStroke, lineWidth: 2.0)
                drawOccluded(Path(ellipseIn: rightEyeRect), fill: occludeDark, stroke: primaryStroke, lineWidth: 2.0)
                // Iris rings + Pupils + Specular catchlights
                context.stroke(Path(ellipseIn: leftEyeRect.insetBy(dx: 2.2 * s, dy: 2.5 * s)),  with: .color(primaryStroke.opacity(0.75)), lineWidth: 1.3)
                context.stroke(Path(ellipseIn: rightEyeRect.insetBy(dx: 2.2 * s, dy: 2.5 * s)), with: .color(primaryStroke.opacity(0.75)), lineWidth: 1.3)
                context.fill(Path(ellipseIn: leftEyeRect.insetBy(dx: 4.0 * s, dy: 4.5 * s)),  with: .color(primaryStroke))
                context.fill(Path(ellipseIn: rightEyeRect.insetBy(dx: 4.0 * s, dy: 4.5 * s)), with: .color(primaryStroke))

                // Open Smiling Mouth + Tongue Arch + Chin Dimple (Drawn under lower mustache edge)
                var mouth = Path()
                mouth.move(to: mpt(-15, -10))
                mouth.addCurve(to: mpt(7, -9), control1: mpt(-14, 2), control2: mpt(4, 2))
                mouth.closeSubpath()
                drawOccluded(mouth, fill: occludeDark, stroke: primaryStroke, lineWidth: 2.0)

                var tongueAndChin = Path()
                tongueAndChin.move(to: mpt(-10, -3))
                tongueAndChin.addQuadCurve(to: mpt(3, -3), control: mpt(-3, -6))
                // Subtle chin crease below mouth
                tongueAndChin.move(to: mpt(-8, 1))
                tongueAndChin.addQuadCurve(to: mpt(1, 1), control: mpt(-3, 3))
                context.stroke(tongueAndChin, with: .color(primaryStroke), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

                // Iconic 6-Scallop Mustache (Occludes the bottom of the eyes & top of the mouth!)
                var mustache = Path()
                mustache.move(to: mpt(-24, -27))
                mustache.addCurve(to: mpt(-28, -18), control1: mpt(-28, -25), control2: mpt(-30, -21))
                mustache.addCurve(to: mpt(-20, -12), control1: mpt(-27, -14), control2: mpt(-24, -12))
                mustache.addCurve(to: mpt(-9, -8),   control1: mpt(-18, -9),  control2: mpt(-13, -7))
                mustache.addCurve(to: mpt(2, -8),    control1: mpt(-5, -6),   control2: mpt(-1, -6))
                mustache.addCurve(to: mpt(14, -9),   control1: mpt(6, -6),    control2: mpt(11, -6))
                mustache.addCurve(to: mpt(23, -15),  control1: mpt(18, -9),   control2: mpt(22, -11))
                mustache.addCurve(to: mpt(21, -23),  control1: mpt(25, -18),  control2: mpt(24, -21))
                mustache.addCurve(to: mpt(-24, -27), control1: mpt(8, -16),   control2: mpt(-10, -18))
                mustache.closeSubpath()
                drawOccluded(mustache, fill: accentFill, stroke: accentStroke, lineWidth: 2.4)

                // Large Bulbous Oval Nose (Drawn LAST on the face with `drawOccluded` so zero eye or mustache lines bleed through it!)
                let noseRect = CGRect(x: mpt(-13, -31).x, y: mpt(-13, -31).y, width: 27 * s, height: 20 * s)
                drawOccluded(Path(ellipseIn: noseRect), fill: primaryFill, stroke: primaryStroke, lineWidth: 2.5)

            } else {
                // --- 5. QUAKE II GOLD-STANDARD BENCHMARK (Razor Crescent + Twin Flared Spikes) ---
                var crescent = Path()
                crescent.addArc(center: CGPoint(x: cx, y: cy - 18), radius: 74, startAngle: .degrees(-68), endAngle: .degrees(248), clockwise: false)
                crescent.addArc(center: CGPoint(x: cx, y: cy - 12), radius: 60, startAngle: .degrees(248), endAngle: .degrees(-68), clockwise: true)
                crescent.closeSubpath()
                context.fill(crescent, with: .color(primaryFill))
                context.stroke(crescent, with: .color(primaryStroke), lineWidth: 2.2)

                // Top horizontal serif cap across both Roman numeral II pillars
                var topCap = Path()
                topCap.move(to: CGPoint(x: cx - 34, y: cy - 22))
                topCap.addLine(to: CGPoint(x: cx + 34, y: cy - 22))
                topCap.addQuadCurve(to: CGPoint(x: cx + 23, y: cy - 12), control: CGPoint(x: cx + 25, y: cy - 20))
                topCap.addLine(to: CGPoint(x: cx - 23, y: cy - 12))
                topCap.addQuadCurve(to: CGPoint(x: cx - 34, y: cy - 22), control: CGPoint(x: cx - 25, y: cy - 20))
                topCap.closeSubpath()
                context.fill(topCap, with: .color(accentFill))
                context.stroke(topCap, with: .color(accentStroke), lineWidth: 1.8)

                for sx in [cx - 15, cx + 15] {
                    var spike = Path()
                    spike.move(to: CGPoint(x: sx - 8, y: cy - 14))
                    spike.addLine(to: CGPoint(x: sx + 8, y: cy - 14))
                    spike.addLine(to: CGPoint(x: sx + 7, y: cy + 32))
                    spike.addLine(to: CGPoint(x: sx, y: cy + 96))
                    spike.addLine(to: CGPoint(x: sx - 7, y: cy + 32))
                    spike.closeSubpath()
                    context.fill(spike, with: .color(accentFill))
                    context.stroke(spike, with: .color(accentStroke), lineWidth: 2.0)
                }
                drawCADNode(CGPoint(x: cx - 15, y: cy + 96), handle: CGPoint(x: cx - 48, y: cy + 82))
            }
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
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.86),
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
