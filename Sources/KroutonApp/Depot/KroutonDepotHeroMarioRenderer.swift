import SwiftUI
import Foundation
import OpticalDough

// MARK: - Nintendo / GameCube / Wii Mario & Default Optical Gear Hero Renderers

extension KroutonRecipeBlueprintView {
    func drawMarioHeroBlueprint(
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

    }

    func drawDefaultOpticalHeroBlueprint(
        context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        accent: Color,
        secondary: Color,
        primaryStroke: Color,
        primaryFill: Color,
        accentStroke: Color,
        accentFill: Color,
        faintStroke: Color
    ) {
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
                drawCADNode(context: &context, CGPoint(x: cx - 15, y: cy + 96), handle: CGPoint(x: cx - 48, y: cy + 82), primaryStroke: primaryStroke)
    }
}

// Console Emblem Renderers
