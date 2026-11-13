//
//  KroutonDepotHeroStudio.swift
//  Krouton — Optical Media Mastering Studio
//
//  Metal-Accelerated (.extendedLinear P3) CAD Blueprint Vector Art Studio for Disc Image Depot.
//

import SwiftUI

// MARK: - Metal GPU-Accelerated (.drawingGroup) Pop-Culture Macro-Cropped Bezier Hero Studio
struct KroutonRecipeBlueprintView: View {
    let item: KroutonPantryCatalogItem
    let accent: Color
    let isNarrow: Bool
    var useHarmony: Bool = true

    var body: some View {
        let activeStore = KroutonStateStore.shared
        let presetID = activeStore?.selectedAccentIndex ?? 6
        let effectiveID = presetID >= 0 ? presetID : (activeStore.map { $0.multicolorPresetID(forTaskID: $0.selectedTaskID, category: $0.selectedCategory) } ?? 6)
        let secondary = useHarmony ? KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark) : accent
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

            } else if item.channel.contains("Live Linux") || key.contains("linux") || (key.contains("archlinux") || key.contains("arch linux")) || key.contains("mint") || key.contains("bsd") || key.contains("alpine") {
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

            } else if key.contains("xbox") || key.contains("ps1") || key.contains("ps2") || key.contains("playstation") || key.contains("freedvd") || key.contains("unirom") || key.contains("saturn") {
                drawConsoleEmblemBlueprint(
                    key: key, context: &context, cx: cx, cy: cy,
                    accent: accent, secondary: secondary,
                    primaryStroke: primaryStroke, primaryFill: primaryFill,
                    accentStroke: accentStroke, accentFill: accentFill, faintStroke: faintStroke,
                    occludeBacking: occludeBacking
                )
            } else if key.contains("dream") || key.contains("sega") || key.contains("240p") || key.contains("sonic") {
                drawSonicHeroBlueprint(
                    context: &context, cx: cx, cy: cy,
                    accent: accent, secondary: secondary,
                    primaryStroke: primaryStroke, primaryFill: primaryFill,
                    accentStroke: accentStroke, accentFill: accentFill, faintStroke: faintStroke,
                    occludeBacking: occludeBacking
                )
            } else if key.contains("wii") || key.contains("gc") || key.contains("gamecube") || key.contains("swiss") || key.contains("nintendo") || key.contains("mario") || item.channel.contains("Console") {
                drawMarioHeroBlueprint(
                    context: &context, cx: cx, cy: cy,
                    accent: accent, secondary: secondary,
                    primaryStroke: primaryStroke, primaryFill: primaryFill,
                    accentStroke: accentStroke, accentFill: accentFill, faintStroke: faintStroke,
                    occludeBacking: occludeBacking
                )
            } else {
                drawDefaultOpticalHeroBlueprint(
                    context: &context, cx: cx, cy: cy,
                    accent: accent, secondary: secondary,
                    primaryStroke: primaryStroke, primaryFill: primaryFill,
                    accentStroke: accentStroke, accentFill: accentFill, faintStroke: faintStroke
                )
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
    }

    func drawCADNode(context: inout GraphicsContext, _ pt: CGPoint, handle: CGPoint, primaryStroke: Color) {
        var ln = Path()
        ln.move(to: pt); ln.addLine(to: handle)
        context.stroke(ln, with: .color(primaryStroke.opacity(0.55)), lineWidth: 0.9)
        let sq = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
        context.fill(Path(sq), with: .color(primaryStroke))
        let cir = CGRect(x: handle.x - 2.5, y: handle.y - 2.5, width: 5, height: 5)
        context.stroke(Path(ellipseIn: cir), with: .color(primaryStroke), lineWidth: 1.1)
    }
}
