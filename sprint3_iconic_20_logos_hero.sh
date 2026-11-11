#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_ICONIC_20_LOGOS_HERO_STUDIO'
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

iconic_20_studio = r"""// MARK: - Metal GPU-Accelerated (.drawingGroup) Pop-Culture Macro-Cropped Bezier Hero Studio
struct DepotBlueprintArtStudioView: View {
    let item: DepotCatalogItem
    let accent: Color
    let isNarrow: Bool

    var body: some View {
        Canvas { context, size in
            // =========================================================================
            // 1. ARCHITECTURAL CAD SUB-GRID & GOLDEN RATIO CONSTRUCTION ARCS
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
            context.stroke(grid, with: .color(Color.cyan.opacity(0.04)), lineWidth: 0.5)

            // Focal anchor zoomed & positioned so macro-cropped art bleeds off top/right/bottom!
            let cx: CGFloat = isNarrow ? size.width * 0.79 : size.width * 0.62
            let cy: CGFloat = size.height * 0.53

            // Multi-stop HDR ambient radial glow behind the artwork
            let glowR: CGFloat = 185
            context.fill(
                Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [accent.opacity(0.35), Color.cyan.opacity(0.14), Color.clear]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 6,
                    endRadius: glowR
                )
            )

            // Subtle golden-ratio construction ring
            let constructR: CGFloat = 94
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - constructR, y: cy - constructR, width: constructR * 2, height: constructR * 2)),
                with: .color(Color.cyan.opacity(0.14)),
                style: StrokeStyle(lineWidth: 0.8, dash: [8, 4, 2, 4])
            )

            // Illustrator / CAD Bezier tangent handle (`o---■`) for studio authenticity
            func drawCADNode(_ pt: CGPoint, handle: CGPoint) {
                var ln = Path()
                ln.move(to: pt); ln.addLine(to: handle)
                context.stroke(ln, with: .color(Color.cyan.opacity(0.55)), lineWidth: 0.9)
                let sq = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                context.fill(Path(sq), with: .color(.white))
                context.stroke(Path(sq), with: .color(accent), lineWidth: 1.2)
                let cr = CGRect(x: handle.x - 2.5, y: handle.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: cr), with: .color(.cyan))
            }

            let key = (item.id + " " + item.title + " " + item.channel + " " + item.subtitle).lowercased()

            // =========================================================================
            // 2. 18 BESPOKE MACRO-CROPPED VECTOR COMPOSITIONS (FROM THE 20 REFERENCES)
            // =========================================================================

            if key.contains("fedora") {
                // --- 1. FEDORA INFINITY-F (`∞` -> `f`) TEARDROP RIBBON ---
                var badge = Path()
                badge.addRoundedRect(in: CGRect(x: cx - 88, y: cy - 88, width: 176, height: 176), cornerSize: CGSize(width: 78, height: 78))
                context.fill(badge, with: .color(Color.blue.opacity(0.18)))
                context.stroke(badge, with: .color(Color.cyan.opacity(0.45)), lineWidth: 1.8)

                // Lower-left infinity loop + upper-right 'f' hook
                var inf = Path()
                inf.addArc(center: CGPoint(x: cx - 34, y: cy + 28), radius: 34, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: false)
                inf.addLine(to: CGPoint(x: cx, y: cy - 32))
                inf.addArc(center: CGPoint(x: cx + 34, y: cy - 32), radius: 34, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: false)
                context.stroke(inf, with: .color(Color.cyan.opacity(0.48)), style: StrokeStyle(lineWidth: 20, lineCap: .round))

                // Bright white/accent 'f' stem & crossbar
                var fStem = Path()
                fStem.move(to: CGPoint(x: cx - 36, y: cy + 62))
                fStem.addQuadCurve(to: CGPoint(x: cx, y: cy + 24), control: CGPoint(x: cx, y: cy + 62))
                fStem.addLine(to: CGPoint(x: cx, y: cy - 34))
                fStem.addArc(center: CGPoint(x: cx + 32, y: cy - 34), radius: 32, startAngle: .degrees(180), endAngle: .degrees(325), clockwise: false)
                fStem.move(to: CGPoint(x: cx - 32, y: cy - 4))
                fStem.addLine(to: CGPoint(x: cx + 28, y: cy - 4))
                context.stroke(fStem, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                drawCADNode(CGPoint(x: cx, y: cy - 4), handle: CGPoint(x: cx + 52, y: cy - 24))

            } else if key.contains("debian") || key.contains("ubuntu") || key.contains("tails") {
                // --- 2. DEBIAN ORGANIC CALLIGRAPHIC GOLDEN SWIRL ---
                var swirl = Path()
                var theta: Double = 0.2
                var first = true
                while theta <= 8.2 {
                    let r = 5.5 * exp(0.28 * theta)
                    let px = cx + CGFloat(cos(theta) * r) - 10
                    let py = cy + CGFloat(sin(theta) * r) - 6
                    if first { swirl.move(to: CGPoint(x: px, y: py)); first = false }
                    else { swirl.addLine(to: CGPoint(x: px, y: py)) }
                    theta += 0.08
                }
                // Second offset spiral to create the tapered brushstroke crescent fill
                var thetaBack: Double = 8.2
                while thetaBack >= 0.2 {
                    let r = (5.5 * exp(0.28 * thetaBack)) * 0.78 + 4.0
                    let px = cx + CGFloat(cos(thetaBack + 0.18) * r) - 10
                    let py = cy + CGFloat(sin(thetaBack + 0.18) * r) - 6
                    swirl.addLine(to: CGPoint(x: px, y: py))
                    thetaBack -= 0.08
                }
                swirl.closeSubpath()
                context.fill(swirl, with: .linearGradient(Gradient(colors: [accent, Color.pink.opacity(0.85), Color.cyan]), startPoint: CGPoint(x: cx - 80, y: cy - 80), endPoint: CGPoint(x: cx + 80, y: cy + 80)))
                context.stroke(swirl, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
                drawCADNode(CGPoint(x: cx - 54, y: cy - 42), handle: CGPoint(x: cx - 88, y: cy - 64))

            } else if key.contains("sgi") || key.contains("irix") {
                // --- 3. SGI (SILICON GRAPHICS) INTERLOCKING 3D HEXAGONAL CUBE TUBES ---
                for deg in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0] {
                    let rad = deg * .pi / 180.0
                    let nextRad = (deg + 60.0) * .pi / 180.0
                    let rOuter: CGFloat = 86
                    let rInner: CGFloat = 34
                    var chevron = Path()
                    let p0 = CGPoint(x: cx + cos(rad) * rInner * 0.45, y: cy + sin(rad) * rInner * 0.45)
                    let p1 = CGPoint(x: cx + cos(rad - 0.12) * rOuter, y: cy + sin(rad - 0.12) * rOuter)
                    let p2 = CGPoint(x: cx + cos(nextRad + 0.12) * rOuter, y: cy + sin(nextRad + 0.12) * rOuter)
                    chevron.move(to: p0)
                    chevron.addLine(to: p1)
                    chevron.addLine(to: p2)
                    chevron.closeSubpath()
                    let isEven = Int(deg / 60.0) % 2 == 0
                    context.fill(chevron, with: .color(isEven ? Color.cyan.opacity(0.16) : accent.opacity(0.20)))
                    context.stroke(
                        chevron,
                        with: .color(isEven ? Color.cyan : accent),
                        style: StrokeStyle(lineWidth: 7.5, lineCap: .round, lineJoin: .round)
                    )
                }
                drawCADNode(CGPoint(x: cx, y: cy), handle: CGPoint(x: cx + 48, y: cy - 28))

            } else if key.contains("rhapsody") || key.contains("next") || key.contains("au-x") {
                // --- 4. PAUL RAND 28°-TILTED ISOMETRIC NeXT CUBE (N-e-X-T) ---
                var cube = Path()
                let cTop = CGPoint(x: cx + 12, y: cy - 92)
                let cRight = CGPoint(x: cx + 96, y: cy - 12)
                let cMid = CGPoint(x: cx - 18, y: cy + 44)
                let cLeft = CGPoint(x: cx - 94, y: cy - 36)
                let cBotLeft = CGPoint(x: cx - 44, y: cy + 104)
                let cBotRight = CGPoint(x: cx + 68, y: cy + 52)

                cube.move(to: cTop); cube.addLine(to: cRight); cube.addLine(to: cMid); cube.addLine(to: cLeft); cube.closeSubpath()
                context.fill(cube, with: .color(Color.black.opacity(0.72)))
                context.stroke(cube, with: .color(.white.opacity(0.90)), lineWidth: 2.2)

                var sides = Path()
                sides.move(to: cLeft); sides.addLine(to: cBotLeft); sides.addLine(to: cMid)
                sides.move(to: cMid); sides.addLine(to: cBotLeft); sides.addLine(to: cBotRight); sides.addLine(to: cRight)
                context.fill(sides, with: .color(accent.opacity(0.22)))
                context.stroke(sides, with: .color(Color.cyan.opacity(0.80)), lineWidth: 1.8)

                // Iconic 4-Quadrant Color-Coded 'N' 'e' 'X' 'T' Typography
                context.draw(Text("N").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.orange), at: CGPoint(x: cx - 34, y: cy - 34))
                context.draw(Text("e").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.yellow), at: CGPoint(x: cx + 22, y: cy - 42))
                context.draw(Text("X").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.green), at: CGPoint(x: cx - 16, y: cy + 8))
                context.draw(Text("T").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.pink), at: CGPoint(x: cx + 38, y: cy - 2))

            } else if key.contains("beos") || key.contains("haiku") {
                // --- 5. BeOS SPLIT BLUE/RED SERIF + BICOLOR HORIZONTAL DIVIDER BAR ---
                context.draw(
                    Text("B").font(.system(size: 74, weight: .bold, design: .serif)).foregroundColor(Color.cyan),
                    at: CGPoint(x: cx - 36, y: cy - 42)
                )
                context.draw(
                    Text("e").font(.system(size: 74, weight: .bold, design: .serif)).foregroundColor(Color(red: 0.96, green: 0.26, blue: 0.22)),
                    at: CGPoint(x: cx + 22, y: cy - 42)
                )
                // Iconic Split Blue / Red Horizontal Bar
                let leftBar = CGRect(x: cx - 68, y: cy - 2, width: 68, height: 10)
                let rightBar = CGRect(x: cx, y: cy - 2, width: 68, height: 10)
                context.fill(Path(leftBar), with: .color(Color.cyan))
                context.fill(Path(rightBar), with: .color(Color(red: 0.96, green: 0.26, blue: 0.22)))

                context.draw(
                    Text("OS").font(.system(size: 68, weight: .light, design: .rounded)).foregroundColor(.white.opacity(0.88)),
                    at: CGPoint(x: cx - 4, y: cy + 48)
                )
                drawCADNode(CGPoint(x: cx, y: cy + 3), handle: CGPoint(x: cx + 82, y: cy - 18))

            } else if key.contains("os2") || key.contains("warp") {
                // --- 6. IBM OS/2 WARP TILTED DIAMOND + 4 OVERLAPPING COLOR RINGS + PAUL RAND 8-BAR ---
                var diamond = Path()
                diamond.move(to: CGPoint(x: cx, y: cy - 98))
                diamond.addLine(to: CGPoint(x: cx + 98, y: cy))
                diamond.addLine(to: CGPoint(x: cx, y: cy + 98))
                diamond.addLine(to: CGPoint(x: cx - 98, y: cy))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(Color.black.opacity(0.68)))
                context.stroke(diamond, with: .color(Color.cyan.opacity(0.75)), lineWidth: 2.0)

                let rings: [(CGFloat, CGFloat, Color)] = [
                    (-26, -28, Color.red),
                    (32, -22, Color.cyan),
                    (-30, 26, Color.yellow),
                    (24, 30, Color.green)
                ]
                for (ox, oy, col) in rings {
                    let rRect = CGRect(x: cx + ox - 32, y: cy + oy - 32, width: 64, height: 64)
                    context.stroke(Path(ellipseIn: rRect), with: .color(col.opacity(0.90)), lineWidth: 2.6)
                    context.draw(
                        Text("OS/2").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(col),
                        at: CGPoint(x: cx + ox, y: cy + oy)
                    )
                }

                // Paul Rand 8-Stripe Horizontal Scanline Pattern on Left
                var stripes = Path()
                for sIdx in 0..<8 {
                    let sy = cy - 42 + CGFloat(sIdx) * 11
                    stripes.addRect(CGRect(x: cx - 122, y: sy, width: 34, height: 5))
                }
                context.fill(stripes, with: .color(accent.opacity(0.65)))

            } else if key.contains("amiga") || key.contains("aros") || key.contains("icaros") {
                // --- 7. AMIGA TWIN PARALLEL RAINBOW CHECKMARK SLASHES ---
                for offset in [0.0, 22.0] {
                    var check = Path()
                    let sx = cx - 82 + CGFloat(offset)
                    check.move(to: CGPoint(x: sx, y: cy + 8))
                    check.addLine(to: CGPoint(x: sx + 26, y: cy + 56))
                    check.addLine(to: CGPoint(x: sx + 104, y: cy - 78))
                    context.stroke(
                        check,
                        with: .linearGradient(
                            Gradient(colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red]),
                            startPoint: CGPoint(x: sx, y: cy + 56),
                            endPoint: CGPoint(x: sx + 104, y: cy - 78)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                }
                context.draw(
                    Text("AMIGA").font(.system(size: 32, weight: .black, design: .serif)).foregroundColor(.white.opacity(0.28)),
                    at: CGPoint(x: cx + 42, y: cy + 42)
                )

            } else if key.contains("bmug") || key.contains("hypercard") || key.contains("1984") || key.contains("system71") {
                // --- 8. BMUG LEAPING TORCH-BEARER + 1984 SUSAN KARE MINIMALIST LINE-ART MAC ---
                // 1984 Continuous Line-Art Macintosh Sketch on Left
                var sketchMac = Path()
                sketchMac.addRoundedRect(in: CGRect(x: cx - 92, y: cy - 58, width: 68, height: 82), cornerSize: CGSize(width: 6, height: 6))
                sketchMac.addRoundedRect(in: CGRect(x: cx - 80, y: cy - 46, width: 44, height: 34), cornerSize: CGSize(width: 3, height: 3))
                // Curving Mouse Cord & Keyboard
                sketchMac.move(to: CGPoint(x: cx - 92, y: cy + 36))
                sketchMac.addQuadCurve(to: CGPoint(x: cx - 52, y: cy + 68), control: CGPoint(x: cx - 108, y: cy + 58))
                context.stroke(sketchMac, with: .color(Color.cyan.opacity(0.85)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                // BMUG Dynamic Leaping Runner Silhouette on Right
                var runner = Path()
                runner.move(to: CGPoint(x: cx - 12, y: cy + 48))
                runner.addQuadCurve(to: CGPoint(x: cx + 32, y: cy - 12), control: CGPoint(x: cx + 4, y: cy - 4))
                runner.addLine(to: CGPoint(x: cx + 88, y: cy - 38)) // Extended Torch Arm
                runner.move(to: CGPoint(x: cx + 24, y: cy + 4))
                runner.addQuadCurve(to: CGPoint(x: cx + 82, y: cy + 68), control: CGPoint(x: cx + 62, y: cy + 18))
                context.stroke(runner, with: .color(accent), style: StrokeStyle(lineWidth: 9.0, lineCap: .round, lineJoin: .round))
                drawCADNode(CGPoint(x: cx + 88, y: cy - 38), handle: CGPoint(x: cx + 112, y: cy - 56))

            } else if key.contains("macaddict") || key.contains("macworld") {
                // --- 9. MACADDICT 3D EXTRUDED 'Mac' SERIF + BLUE 'ADDICT' PROGRESS BAR ---
                // Blue Progress-Bar Banner across lower middle
                let barRect = CGRect(x: cx - 96, y: cy + 12, width: 192, height: 38)
                let capRect = CGRect(x: barRect.maxX, y: cy + 12, width: 18, height: 38)
                context.fill(Path(barRect), with: .color(Color.blue.opacity(0.65)))
                context.fill(Path(capRect), with: .color(.white.opacity(0.85)))
                context.stroke(Path(barRect.union(capRect)), with: .color(Color.cyan), lineWidth: 2.0)

                // 3D Extruded Drop-Shadow 'Mac' above the bar
                context.draw(
                    Text("Mac").font(.system(size: 74, weight: .black, design: .serif)).foregroundColor(.black.opacity(0.85)),
                    at: CGPoint(x: cx - 4, y: cy - 22)
                )
                context.draw(
                    Text("Mac").font(.system(size: 74, weight: .black, design: .serif)).foregroundColor(.white.opacity(0.95)),
                    at: CGPoint(x: cx - 9, y: cy - 27)
                )
                context.draw(
                    Text("A D D I C T").font(.system(size: 20, weight: .heavy, design: .monospaced)).italic().foregroundColor(.white),
                    at: CGPoint(x: barRect.midX, y: barRect.midY)
                )

            } else if key.contains("pcgamer") || key.contains("quake") || key.contains("doom") || key.contains("cnet") || item.channel.contains("Cover Discs") {
                // --- 10. QUAKE II / NINE-INCH-NAILS RAZOR CRESCENT RING + TWIN VERTICAL SPIKES ---
                var crescent = Path()
                crescent.addArc(center: CGPoint(x: cx, y: cy - 18), radius: 74, startAngle: .degrees(-68), endAngle: .degrees(248), clockwise: false)
                crescent.addArc(center: CGPoint(x: cx, y: cy - 12), radius: 60, startAngle: .degrees(248), endAngle: .degrees(-68), clockwise: true)
                crescent.closeSubpath()
                context.fill(crescent, with: .color(Color.cyan.opacity(0.32)))
                context.stroke(crescent, with: .color(Color.cyan), lineWidth: 2.2)

                // Twin Tapered Quake II Roman Numeral Spikes Piercing Downward
                for sx in [cx - 16, cx + 16] {
                    var spike = Path()
                    spike.move(to: CGPoint(x: sx - 14, y: cy - 22))
                    spike.addLine(to: CGPoint(x: sx + 14, y: cy - 22))
                    spike.addLine(to: CGPoint(x: sx + 7, y: cy - 14))
                    spike.addLine(to: CGPoint(x: sx + 7, y: cy + 32))
                    spike.addLine(to: CGPoint(x: sx, y: cy + 96)) // Razor point
                    spike.addLine(to: CGPoint(x: sx - 7, y: cy + 32))
                    spike.addLine(to: CGPoint(x: sx - 7, y: cy - 14))
                    spike.closeSubpath()
                    context.fill(spike, with: .color(accent.opacity(0.45)))
                    context.stroke(spike, with: .color(accent), lineWidth: 2.0)
                }
                drawCADNode(CGPoint(x: cx - 16, y: cy + 96), handle: CGPoint(x: cx - 48, y: cy + 82))

            } else if key.contains("saturn") {
                // --- 11. SEGA SATURN 3D ORB + INTERLOCKING DOUBLE SWOOSH ORBITAL RINGS ---
                let orbR: CGFloat = 52
                let orbRect = CGRect(x: cx - orbR, y: cy - orbR, width: orbR * 2, height: orbR * 2)
                context.fill(
                    Path(ellipseIn: orbRect),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.85), Color.blue.opacity(0.65), Color.black.opacity(0.85)]),
                        center: CGPoint(x: cx - 16, y: cy - 18),
                        startRadius: 4,
                        endRadius: orbR
                    )
                )
                context.stroke(Path(ellipseIn: orbRect), with: .color(Color.cyan), lineWidth: 2.0)

                // Sweeping Double Orbital Ribbon wrapping across the front of the planet
                for yShift in [-8.0, 10.0] {
                    var orbit = Path()
                    orbit.move(to: CGPoint(x: cx - 96, y: cy + 24 + CGFloat(yShift)))
                    orbit.addQuadCurve(
                        to: CGPoint(x: cx + 96, y: cy - 22 + CGFloat(yShift)),
                        control: CGPoint(x: cx + 8, y: cy + 38 + CGFloat(yShift))
                    )
                    context.stroke(orbit, with: .color(yShift < 0 ? .white.opacity(0.92) : accent), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
                }

            } else if key.contains("dream") || key.contains("sega") || key.contains("240p") {
                // --- 12. SONIC FULL-SPEED DIAGONAL VELOCITY LINES + SWEPT QUILLS & SEGA DOUBLE-RIBBON ---
                // High-Velocity Diagonal Action Speed Lines across the background
                var speedLines = Path()
                for offset in stride(from: -130.0, through: 130.0, by: 18.0) {
                    speedLines.move(to: CGPoint(x: cx - 110 + CGFloat(offset) * 0.5, y: cy - 95))
                    speedLines.addLine(to: CGPoint(x: cx + 30 + CGFloat(offset) * 0.5, y: cy + 95))
                }
                context.stroke(speedLines, with: .color(Color.cyan.opacity(0.18)), lineWidth: 1.6)

                // Sonic's 3 Swept-Back Aerodynamic Quills + Sharp Triangular Ear + Furrowed Brow
                var sonic = Path()
                sonic.move(to: CGPoint(x: cx + 62, y: cy - 18))
                sonic.addQuadCurve(to: CGPoint(x: cx - 68, y: cy - 72), control: CGPoint(x: cx + 12, y: cy - 82))
                sonic.addQuadCurve(to: CGPoint(x: cx - 28, y: cy - 34), control: CGPoint(x: cx - 48, y: cy - 48))
                sonic.addQuadCurve(to: CGPoint(x: cx - 92, y: cy - 22), control: CGPoint(x: cx - 68, y: cy - 38))
                sonic.addQuadCurve(to: CGPoint(x: cx - 34, y: cy + 4), control: CGPoint(x: cx - 64, y: cy - 4))
                sonic.addQuadCurve(to: CGPoint(x: cx - 84, y: cy + 32), control: CGPoint(x: cx - 68, y: cy + 16))
                sonic.addQuadCurve(to: CGPoint(x: cx + 28, y: cy + 44), control: CGPoint(x: cx - 24, y: cy + 48))
                sonic.closeSubpath()
                context.fill(sonic, with: .color(Color.cyan.opacity(0.22)))
                context.stroke(sonic, with: .color(Color.cyan), style: StrokeStyle(lineWidth: 2.8, lineJoin: .round))

                // SEGA Inline Double-Stripe Parallel Track Emblem on Right
                var segaTrack = Path()
                segaTrack.addRoundedRect(in: CGRect(x: cx + 18, y: cy - 54, width: 64, height: 108), cornerSize: CGSize(width: 24, height: 24))
                context.stroke(segaTrack, with: .color(accent), lineWidth: 6.0)
                context.stroke(segaTrack, with: .color(.black), lineWidth: 2.0)

            } else if key.contains("xbox") {
                // --- 13. XBOX SPHERICAL ORB SLICED BY 4 CONCAVE TAPERED X-BLADES ---
                let xR: CGFloat = 78
                let sphere = CGRect(x: cx - xR, y: cy - xR, width: xR * 2, height: xR * 2)
                context.fill(Path(ellipseIn: sphere), with: .color(Color.green.opacity(0.18)))
                context.stroke(Path(ellipseIn: sphere), with: .color(Color.green.opacity(0.85)), lineWidth: 2.4)

                // Sweeping Concave X-Cuts across the Sphere
                var xBlades = Path()
                xBlades.move(to: CGPoint(x: cx - 58, y: cy - 58))
                xBlades.addQuadCurve(to: CGPoint(x: cx + 62, y: cy + 54), control: CGPoint(x: cx + 6, y: cy - 8))
                xBlades.move(to: CGPoint(x: cx + 58, y: cy - 58))
                xBlades.addQuadCurve(to: CGPoint(x: cx - 62, y: cy + 54), control: CGPoint(x: cx - 6, y: cy - 8))
                context.stroke(xBlades, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                context.stroke(xBlades, with: .color(accent), style: StrokeStyle(lineWidth: 6, lineCap: .round))

            } else if key.contains("ps1") || key.contains("ps2") || key.contains("playstation") || key.contains("freedvd") || key.contains("unirom") {
                // --- 14. PLAYSTATION STANDING 3D RED 'P' + FLAT PERSPECTIVE FLOOR 'S' SHADOW ---
                // 1) Flat Isometric Floor 'S' Ribbon (Yellow / Teal / Blue) Lying in 3D Perspective Beneath the 'P'
                var floorS = Path()
                floorS.move(to: CGPoint(x: cx - 88, y: cy + 48))
                floorS.addQuadCurve(to: CGPoint(x: cx + 8, y: cy + 16), control: CGPoint(x: cx - 54, y: cy + 68))
                floorS.addQuadCurve(to: CGPoint(x: cx + 92, y: cy + 44), control: CGPoint(x: cx + 68, y: cy - 4))
                floorS.addQuadCurve(to: CGPoint(x: cx - 12, y: cy + 72), control: CGPoint(x: cx + 38, y: cy + 84))
                context.stroke(
                    floorS,
                    with: .linearGradient(
                        Gradient(colors: [.yellow, .teal, .cyan, .blue]),
                        startPoint: CGPoint(x: cx - 88, y: cy + 48),
                        endPoint: CGPoint(x: cx + 92, y: cy + 44)
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )

                // 2) Tall Vertical 3D Standing 'P' Monolith Rising From the Center
                var standP = Path()
                standP.move(to: CGPoint(x: cx - 18, y: cy + 78))
                standP.addLine(to: CGPoint(x: cx - 18, y: cy - 86))
                standP.addLine(to: CGPoint(x: cx + 22, y: cy - 72))
                standP.addArc(center: CGPoint(x: cx + 22, y: cy - 30), radius: 42, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                standP.addLine(to: CGPoint(x: cx + 4, y: cy + 12))
                standP.addLine(to: CGPoint(x: cx + 4, y: cy + 84))
                standP.closeSubpath()
                context.fill(standP, with: .color(Color(red: 0.92, green: 0.14, blue: 0.20).opacity(0.85)))
                context.stroke(standP, with: .color(.white.opacity(0.92)), lineWidth: 2.2)

            } else if item.channel.contains("Console") || key.contains("swiss") || key.contains("gc") || key.contains("wii") {
                // --- 15. MARIO JUMPING FIST-UP SILHOUETTE + 'M' CAP EMBLEM & SCALLOPED MUSTACHE ---
                // Raised Gloved Fist & Upper Arm on Left
                var fist = Path()
                fist.addRoundedRect(in: CGRect(x: cx - 86, y: cy - 92, width: 46, height: 44), cornerSize: CGSize(width: 16, height: 16))
                fist.move(to: CGPoint(x: cx - 78, y: cy - 48))
                fist.addLine(to: CGPoint(x: cx - 72, y: cy + 28))
                fist.move(to: CGPoint(x: cx - 46, y: cy - 48))
                fist.addLine(to: CGPoint(x: cx - 44, y: cy + 12))
                context.fill(fist, with: .color(Color.white.opacity(0.14)))
                context.stroke(fist, with: .color(Color.cyan), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

                // Domed Cap + Circular 'M' Badge
                var cap = Path()
                cap.move(to: CGPoint(x: cx - 42, y: cy - 22))
                cap.addCurve(to: CGPoint(x: cx + 64, y: cy - 14), control1: CGPoint(x: cx - 38, y: cy - 88), control2: CGPoint(x: cx + 58, y: cy - 82))
                cap.addQuadCurve(to: CGPoint(x: cx - 42, y: cy - 22), control: CGPoint(x: cx + 12, y: cy - 38))
                context.fill(cap, with: .color(accent.opacity(0.32)))
                context.stroke(cap, with: .color(accent), lineWidth: 2.6)

                let mCircle = CGRect(x: cx - 4, y: cy - 64, width: 34, height: 28)
                context.stroke(Path(ellipseIn: mCircle), with: .color(.white), lineWidth: 2.0)
                var mPath = Path()
                mPath.move(to: CGPoint(x: mCircle.minX + 6, y: mCircle.maxY - 6))
                mPath.addLine(to: CGPoint(x: mCircle.minX + 11, y: mCircle.minY + 6))
                mPath.addLine(to: CGPoint(x: mCircle.midX, y: mCircle.midY + 3))
                mPath.addLine(to: CGPoint(x: mCircle.maxX - 11, y: mCircle.minY + 6))
                mPath.addLine(to: CGPoint(x: mCircle.maxX - 6, y: mCircle.maxY - 6))
                context.stroke(mPath, with: .color(.white), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                // Bulbous Nose + Iconic Scalloped Mustache Below
                let nose = CGRect(x: cx - 14, y: cy - 12, width: 38, height: 28)
                context.fill(Path(ellipseIn: nose), with: .color(Color.cyan.opacity(0.22)))
                context.stroke(Path(ellipseIn: nose), with: .color(.white), lineWidth: 2.4)

                var stache = Path()
                stache.move(to: CGPoint(x: cx - 34, y: cy + 4))
                stache.addQuadCurve(to: CGPoint(x: cx - 14, y: cy + 24), control: CGPoint(x: cx - 34, y: cy + 22))
                stache.addQuadCurve(to: CGPoint(x: cx + 6, y: cy + 26), control: CGPoint(x: cx - 4, y: cy + 32))
                stache.addQuadCurve(to: CGPoint(x: cx + 32, y: cy + 16), control: CGPoint(x: cx + 24, y: cy + 30))
                context.stroke(stache, with: .color(accent), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

            } else if item.channel.contains("Vintage Apple") || key.contains("macos") || key.contains("system") {
                // --- 16. CLASSIC MAC OS EVOLUTION: 1995 PICASSO TWO-FACE + 2001 AQUA / BITTEN APPLE ---
                // 1) Bitten Apple Silhouette Contour in Background Right
                var apple = Path()
                let ax = cx + 44, ay = cy + 6
                apple.move(to: CGPoint(x: ax, y: ay - 38))
                apple.addCurve(to: CGPoint(x: ax - 42, y: ay - 10), control1: CGPoint(x: ax - 18, y: ay - 46), control2: CGPoint(x: ax - 42, y: ay - 32))
                apple.addCurve(to: CGPoint(x: ax - 16, y: ay + 48), control1: CGPoint(x: ax - 42, y: ay + 18), control2: CGPoint(x: ax - 28, y: ay + 48))
                apple.addQuadCurve(to: CGPoint(x: ax, y: ay + 42), control: CGPoint(x: ax - 8, y: ay + 42))
                apple.addQuadCurve(to: CGPoint(x: ax + 16, y: ay + 48), control: CGPoint(x: ax + 8, y: ay + 42))
                apple.addCurve(to: CGPoint(x: ax + 38, y: ay + 14), control1: CGPoint(x: ax + 26, y: ay + 48), control2: CGPoint(x: ax + 34, y: ay + 30))
                // Right-side Bite Concavity
                apple.addArc(center: CGPoint(x: ax + 44, y: ay - 8), radius: 18, startAngle: .degrees(115), endAngle: .degrees(245), clockwise: false)
                apple.addCurve(to: CGPoint(x: ax, y: ay - 38), control1: CGPoint(x: ax + 30, y: ay - 36), control2: CGPoint(x: ax + 14, y: ay - 44))
                apple.closeSubpath()
                // Top Leaf
                apple.addEllipse(in: CGRect(x: ax - 2, y: ay - 60, width: 16, height: 20))
                context.fill(apple, with: .linearGradient(Gradient(colors: [Color.cyan.opacity(0.24), accent.opacity(0.18)]), startPoint: CGPoint(x: ax, y: ay - 60), endPoint: CGPoint(x: ax, y: ay + 48)))
                context.stroke(apple, with: .color(Color.cyan.opacity(0.75)), lineWidth: 2.0)

                // 2) 1995-2002 Classic Mac OS Two-Tone Picasso Face Badge on Left
                let faceRect = CGRect(x: cx - 88, y: cy - 58, width: 108, height: 108)
                context.fill(Path(roundedRect: faceRect, cornerSize: CGSize(width: 10, height: 10)), with: .color(Color.blue.opacity(0.22)))
                context.stroke(Path(roundedRect: faceRect, cornerSize: CGSize(width: 10, height: 10)), with: .color(.white.opacity(0.65)), lineWidth: 1.8)

                var picasso = Path()
                picasso.move(to: CGPoint(x: faceRect.midX + 6, y: faceRect.minY - 12))
                picasso.addQuadCurve(to: CGPoint(x: faceRect.midX - 14, y: faceRect.midY + 6), control: CGPoint(x: faceRect.midX - 6, y: faceRect.midY - 22))
                picasso.addLine(to: CGPoint(x: faceRect.midX + 4, y: faceRect.midY + 6))
                picasso.addQuadCurve(to: CGPoint(x: faceRect.midX + 10, y: faceRect.maxY + 12), control: CGPoint(x: faceRect.midX + 4, y: faceRect.midY + 34))
                context.stroke(picasso, with: .color(.white), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                var macSmile = Path()
                macSmile.move(to: CGPoint(x: faceRect.minX + 22, y: faceRect.midY + 18))
                macSmile.addQuadCurve(to: CGPoint(x: faceRect.maxX - 22, y: faceRect.midY + 18), control: CGPoint(x: faceRect.midX, y: faceRect.midY + 42))
                context.stroke(macSmile, with: .color(accent), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

            } else if item.channel.contains("Live Linux") || key.contains("linux") || key.contains("arch") || key.contains("mint") || key.contains("bsd") {
                // --- 17. LINUX TUX FULL SEATED PENGUIN SILHOUETTE (TEARDROP BELLY + NOSTRIL BEAK + WEBBED FEET) ---
                // Outer Head + Shoulders Silhouette
                var body = Path()
                body.move(to: CGPoint(x: cx - 58, y: cy + 68))
                body.addCurve(to: CGPoint(x: cx - 38, y: cy - 38), control1: CGPoint(x: cx - 64, y: cy + 20), control2: CGPoint(x: cx - 44, y: cy - 10))
                body.addCurve(to: CGPoint(x: cx + 38, y: cy - 38), control1: CGPoint(x: cx - 36, y: cy - 92), control2: CGPoint(x: cx + 36, y: cy - 92))
                body.addCurve(to: CGPoint(x: cx + 58, y: cy + 68), control1: CGPoint(x: cx + 44, y: cy - 10), control2: CGPoint(x: cx + 64, y: cy + 20))
                context.fill(body, with: .color(Color.black.opacity(0.65)))
                context.stroke(body, with: .color(Color.cyan), lineWidth: 2.5)

                // White Teardrop Belly Pouch
                let belly = CGRect(x: cx - 42, y: cy - 12, width: 84, height: 84)
                context.fill(Path(ellipseIn: belly), with: .color(Color.white.opacity(0.16)))
                context.stroke(Path(ellipseIn: belly), with: .color(.white.opacity(0.88)), lineWidth: 2.0)

                // Wide-Set Oval Eyes Tucked into Top of Smiling Beak
                context.stroke(Path(ellipseIn: CGRect(x: cx - 24, y: cy - 48, width: 18, height: 24)), with: .color(.white), lineWidth: 2.2)
                context.stroke(Path(ellipseIn: CGRect(x: cx + 6, y: cy - 48, width: 18, height: 24)), with: .color(.white), lineWidth: 2.2)

                var beak = Path()
                beak.move(to: CGPoint(x: cx - 28, y: cy - 22))
                beak.addQuadCurve(to: CGPoint(x: cx + 28, y: cy - 22), control: CGPoint(x: cx, y: cy - 36))
                beak.addQuadCurve(to: CGPoint(x: cx - 28, y: cy - 22), control: CGPoint(x: cx, y: cy + 4))
                context.fill(beak, with: .color(accent.opacity(0.45)))
                context.stroke(beak, with: .color(accent), lineWidth: 2.4)

                // Three-Toed Webbed Feet on Bottom Left & Right
                for fx in [cx - 52, cx + 18] {
                    let foot = CGRect(x: fx, y: cy + 44, width: 38, height: 44)
                    context.fill(Path(roundedRect: foot, cornerSize: CGSize(width: 12, height: 12)), with: .color(accent.opacity(0.32)))
                    context.stroke(Path(roundedRect: foot, cornerSize: CGSize(width: 12, height: 12)), with: .color(accent), lineWidth: 2.2)
                }

            } else {
                // --- 18. MS-DOS INTERLOCKING 'D-O-S' RINGS + STACKED 'MS' & BIOS BOX FRAME ---
                // Double-Line IBM BIOS Boot Frame in Background
                let biosFrame = CGRect(x: cx - 98, y: cy - 72, width: 196, height: 144)
                context.stroke(Path(biosFrame), with: .color(Color.cyan.opacity(0.30)), lineWidth: 1.5)
                context.stroke(Path(biosFrame.insetBy(dx: 4, dy: 4)), with: .color(Color.cyan.opacity(0.20)), lineWidth: 1.0)

                // Stacked Bold 'MS' Above
                context.draw(
                    Text("MS").font(.system(size: 62, weight: .black, design: .rounded)).foregroundColor(Color.cyan.opacity(0.85)),
                    at: CGPoint(x: cx, y: cy - 34)
                )

                // Interlocking Red 'D', Purple 'O', Yellow 'S' Geometric Rings Below
                context.draw(
                    Text("D").font(.system(size: 64, weight: .black, design: .rounded)).foregroundColor(Color(red: 0.94, green: 0.22, blue: 0.22)),
                    at: CGPoint(x: cx - 44, y: cy + 32)
                )
                context.draw(
                    Text("O").font(.system(size: 64, weight: .black, design: .rounded)).foregroundColor(Color.purple.opacity(0.95)),
                    at: CGPoint(x: cx, y: cy + 32)
                )
                context.draw(
                    Text("S").font(.system(size: 64, weight: .black, design: .rounded)).foregroundColor(accent),
                    at: CGPoint(x: cx + 44, y: cy + 32)
                )
                drawCADNode(CGPoint(x: cx + 44, y: cy + 32), handle: CGPoint(x: cx + 86, y: cy + 14))
            }
        }
        // Dual-Axis Artistic Edge-Fade Mask (Blends smoothly into the Hero gradient on all 4 sides)
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
        // Metal GPU Offloading (.drawingGroup) with 16-bit Extended Linear Color
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
    }
}
"""

a_text = a_text[:a_text.index(start_marker)] + iconic_20_studio
with open(a_path, "w") as f:
    f.write(a_text)
print("[OK] Built all 18 bespoke macro-cropped vector Hero artworks from the 20 reference logos!")
EOF_ICONIC_20_LOGOS_HERO_STUDIO

swift build
git add -A
git commit -m "feat(depot-hero): draw 18 bespoke GPU-accelerated macro-cropped vector logos from 20 design references" || true
echo "=================================================================="
echo " [SUCCESS] All 20 Reference Logos Integrated into Hero Studio!"
echo " Switch to Xcode and press Command + R to test!"
echo "=================================================================="
