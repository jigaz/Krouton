import SwiftUI
import Foundation
import OpticalDough

// MARK: - Sega / Dreamcast / 240p Sonic Macro-Cropped Bezier Hero Renderer

extension KroutonRecipeBlueprintView {
    func drawSonicHeroBlueprint(
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

    }

}
