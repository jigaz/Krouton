import AudioKit
import SwiftUI

// MARK: - SpliceCanvasSnapshot & SplicePalette

struct SpliceCanvasSnapshot: Equatable, Sendable {
    var spec: KroutonTrackTransitionSpec
    var outgoingTail: FramePeaks?
    var incomingHead: FramePeaks?
    var superimposed: Bool
    var showSum: Bool
    var highlightLoudFrames: Bool
    var horizontalZoom: Double = 1.0
    var isMiniGhostMode: Bool = false

    var mode: SpliceTransitionMode {
        if spec.isCrossfading { return .crossfade }
        return spec.preGapSeconds <= 0.01 ? .gapless : .gap
    }
}

struct SplicePalette: Equatable, Sendable {
    var outgoing: Color
    var incoming: Color
    var highlight: Color
    var outgoingHighlight: Color
    var incomingHighlight: Color

    init(
        outgoing: Color = Color(red: 0.95, green: 0.38, blue: 0.28),
        incoming: Color = Color(red: 0.36, green: 0.68, blue: 0.98),
        highlight: Color = .yellow
    ) {
        self.outgoing = outgoing
        self.incoming = incoming
        self.highlight = highlight
        self.outgoingHighlight = Self.themePeakOffshoot(from: outgoing, hueShift: -0.095)
        self.incomingHighlight = Self.themePeakOffshoot(from: incoming, hueShift: 0.095)
    }

    /// Pure-SwiftUI color resolver that derives a luminous, high-contrast off-shoot of a track's theme color.
    static func themePeakOffshoot(from base: Color, hueShift: Double) -> Color {
        let resolved = base.resolve(in: EnvironmentValues())
        let r = Double(min(1, max(0, resolved.red)))
        let g = Double(min(1, max(0, resolved.green)))
        let b = Double(min(1, max(0, resolved.blue)))
        let (h, s, _) = rgbToHSB(r: r, g: g, b: b)

        var shiftedH = (h + hueShift).truncatingRemainder(dividingBy: 1.0)
        if shiftedH < 0 { shiftedH += 1.0 }
        let offshootS = min(0.82, max(0.42, s * 0.68))
        let (or, og, ob) = hsbToRGB(h: shiftedH, s: offshootS, b: 1.0)

        return Color(
            red: min(1.0, or * 0.78 + 0.22),
            green: min(1.0, og * 0.78 + 0.20),
            blue: min(1.0, ob * 0.78 + 0.12)
        )
    }

    static func interpolate(from a: Color, to b: Color, t: Double) -> Color {
        let clamped = min(1.0, max(0.0, t))
        guard clamped > 0.001 else { return a }
        guard clamped < 0.999 else { return b }
        let ra = a.resolve(in: EnvironmentValues())
        let rb = b.resolve(in: EnvironmentValues())
        return Color(
            red: Double(ra.red) + (Double(rb.red) - Double(ra.red)) * clamped,
            green: Double(ra.green) + (Double(rb.green) - Double(ra.green)) * clamped,
            blue: Double(ra.blue) + (Double(rb.blue) - Double(ra.blue)) * clamped
        )
    }

    private static func rgbToHSB(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV
        var hue = 0.0
        if delta > 0.00001 {
            if maxV == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
            } else if maxV == g {
                hue = ((b - r) / delta) + 2.0
            } else {
                hue = ((r - g) / delta) + 4.0
            }
            hue /= 6.0
            if hue < 0 { hue += 1.0 }
        }
        let sat = maxV <= 0.00001 ? 0.0 : (delta / maxV)
        return (hue, sat, maxV)
    }

    private static func hsbToRGB(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let c = b * s
        let x = c * (1.0 - abs(((h * 6.0).truncatingRemainder(dividingBy: 2.0)) - 1.0))
        let m = b - c
        let sector = Int(floor(h * 6.0)) % 6
        let (r1, g1, b1): (Double, Double, Double)
        switch sector {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return (r1 + m, g1 + m, b1 + m)
    }
}

// MARK: - SpliceWaveformCanvas

struct SpliceWaveformCanvas: View, Equatable {
    let snapshot: SpliceCanvasSnapshot
    let geometry: SpliceCanvasGeometry
    let palette: SplicePalette

    init(snapshot: SpliceCanvasSnapshot, geometry: SpliceCanvasGeometry, palette: SplicePalette = SplicePalette()) {
        self.snapshot = snapshot
        self.geometry = geometry
        self.palette = palette
    }

    nonisolated static func == (lhs: SpliceWaveformCanvas, rhs: SpliceWaveformCanvas) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.geometry == rhs.geometry && lhs.palette == rhs.palette
    }

    var body: some View {
        Canvas { context, size in
            SpliceCanvasRenderer(snapshot: snapshot, geometry: geometry, palette: palette, size: size)
                .draw(in: &context)
        }
    }
}

// MARK: - SpliceCanvasRenderer

private struct SpliceCanvasRenderer {
    let snapshot: SpliceCanvasSnapshot
    let geometry: SpliceCanvasGeometry
    let palette: SplicePalette
    let size: CGSize

    private static let barCount = 136
    private static let curveSteps = 56

    private var spec: KroutonTrackTransitionSpec { snapshot.spec }
    private var rulerHeight: CGFloat { snapshot.isMiniGhostMode ? 0 : SpliceCanvasGeometry.rulerHeight }
    private var bodyHeight: CGFloat { size.height - rulerHeight }
    private var x0: CGFloat { geometry.zoneX0 }
    private var x1: CGFloat { geometry.zoneX1 }

    func draw(in context: inout GraphicsContext) {
        if !snapshot.isMiniGhostMode {
            drawGridAndScales(&context)
            drawZoneBackdrop(&context)
        }
        drawWaveforms(&context)
        if snapshot.mode == .crossfade { drawGainCurves(&context) }
    }

    private var secondsPerPoint: Double {
        let zoneWidth = Double(x1 - x0)
        switch snapshot.mode {
        case .crossfade where zoneWidth > 1: return spec.overlapSeconds / zoneWidth
        case .gap where zoneWidth > 1: return spec.preGapSeconds / zoneWidth
        default: return geometry.effectiveSpanSeconds / Double(max(1, size.width))
        }
    }

    private var outgoingEndX: CGFloat { snapshot.mode == .crossfade ? x1 : x0 }
    private var incomingStartX: CGFloat { snapshot.mode == .crossfade ? x0 : x1 }

    private func drawGridAndScales(_ context: inout GraphicsContext) {
        let splitY = rulerHeight + bodyHeight * 0.5
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: rulerHeight)), with: .color(.black.opacity(0.55)))

        let tickCount = 8
        var grid = Path()
        for tick in 0...tickCount {
            let fraction = Double(tick) / Double(tickCount)
            let x = size.width * CGFloat(fraction)
            let isInterior = tick > 0 && tick < tickCount
            if isInterior {
                grid.move(to: CGPoint(x: x, y: rulerHeight))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            grid.move(to: CGPoint(x: x, y: rulerHeight - 5))
            grid.addLine(to: CGPoint(x: x, y: rulerHeight))

            if isInterior, abs(x - geometry.index01X) > 62 {
                let seconds = (Double(x - (geometry.zoneX0 + geometry.zoneX1) * 0.5) * secondsPerPoint)
                let label = Text(String(format: "%+.1fs", seconds))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                context.draw(label, at: CGPoint(x: x, y: 11))
            }
        }
        context.stroke(grid, with: .color(.white.opacity(0.05)), lineWidth: 0.75)

        let scale: [(String, CGFloat)] = snapshot.superimposed
            ? [("0 dB", rulerHeight + 10), ("-6 dB", splitY), ("-12 dB", size.height - 9)]
            : [("0 dB", rulerHeight + 8), ("-6 dB", rulerHeight + bodyHeight * 0.25), ("-12 dB", splitY - 7),
               ("0 dB", splitY + 8), ("-6 dB", rulerHeight + bodyHeight * 0.75), ("-12 dB", size.height - 7)]
        for (text, y) in scale {
            let label = Text(text).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.38))
            context.draw(label, at: CGPoint(x: 17, y: y))
        }

        var dividers = Path()
        dividers.move(to: CGPoint(x: 0, y: rulerHeight)); dividers.addLine(to: CGPoint(x: size.width, y: rulerHeight))
        dividers.move(to: CGPoint(x: 0, y: splitY)); dividers.addLine(to: CGPoint(x: size.width, y: splitY))
        context.stroke(dividers, with: .color(.white.opacity(snapshot.superimposed ? 0.10 : 0.18)), lineWidth: 1)
    }

    private func drawZoneBackdrop(_ context: inout GraphicsContext) {
        guard x1 - x0 > 4 else { return }
        let isCrossfade = snapshot.mode == .crossfade
        let zone = CGRect(x: x0, y: rulerHeight, width: x1 - x0, height: bodyHeight)
        context.fill(Path(zone), with: .color(.white.opacity(isCrossfade ? 0.04 : 0.02)))

        if isCrossfade {
            var hatch = Path()
            var startX = x0 - size.height
            while startX < x1 {
                let from = CGPoint(x: max(x0, startX), y: max(rulerHeight, rulerHeight + x0 - startX))
                let to = CGPoint(x: min(x1, startX + size.height), y: min(size.height, rulerHeight + x1 - startX))
                if from.x < x1, to.x > x0 { hatch.move(to: from); hatch.addLine(to: to) }
                startX += 14
            }
            context.stroke(hatch, with: .color(.white.opacity(0.05)), lineWidth: 0.9)
        }

        var rails = Path()
        rails.move(to: CGPoint(x: x0, y: rulerHeight)); rails.addLine(to: CGPoint(x: x0, y: size.height))
        rails.move(to: CGPoint(x: x1, y: rulerHeight)); rails.addLine(to: CGPoint(x: x1, y: size.height))
        context.stroke(rails, with: .color(.white.opacity(0.32)), lineWidth: 1.1)
    }

    /// Anti-aliased continuous envelope sampler over floating-point frame coordinates [startFrame, endFrame].
    /// Eliminates integer-truncation skipping and bar-hopping when adjusting overlapSeconds or rails.
    private func sampleSmoothPeak(from peaks: FramePeaks, startFrame: Double, endFrame: Double) -> Float? {
        let count = peaks.values.count
        guard count > 0 else { return nil }
        let lo = min(startFrame, endFrame)
        let hi = max(startFrame, endFrame)
        let center = (lo + hi) * 0.5
        let halfSpan = max(0.75, (hi - lo) * 0.5)
        let kLo = center - halfSpan
        let kHi = center + halfSpan

        if kHi < 0.0 || kLo >= Double(count) { return nil }

        let iStart = max(0, Int(floor(kLo)))
        let iEnd = min(count - 1, Int(ceil(kHi)))
        guard iStart <= iEnd else { return nil }

        var weightedMax: Double = 0.0
        var weightSum: Double = 0.0
        var weightedAvg: Double = 0.0

        for idx in iStart...iEnd {
            let dist = abs(Double(idx) + 0.5 - center) / max(0.75, halfSpan + 0.45)
            guard dist < 1.0 else { continue }
            // Smooth raised-cosine window that preserves true peak crests while feathering bar edges
            let w = 0.5 * (1.0 + cos(dist * .pi))
            let val = Double(peaks.values[idx])
            weightedMax = max(weightedMax, val * pow(w, 0.16))
            weightedAvg += val * w
            weightSum += w
        }
        guard weightSum > 0.0001 else { return nil }
        let avg = weightedAvg / weightSum
        return Float(weightedMax * 0.92 + avg * 0.08)
    }

    private func smoothPeakProminence(peak: Float, trackReference: Float) -> Double {
        let floorT = Double(trackReference) * 0.50
        let ceilT = Double(trackReference) * 0.76
        guard ceilT > floorT else { return 0.0 }
        let u = min(1.0, max(0.0, (Double(peak) - floorT) / (ceilT - floorT)))
        let smooth = u * u * (3.0 - 2.0 * u)
        return pow(smooth, 0.75)
    }

    private func drawWaveforms(_ context: inout GraphicsContext) {
        let outMidY = rulerHeight + bodyHeight * (snapshot.superimposed ? 0.5 : 0.25)
        let inMidY = rulerHeight + bodyHeight * (snapshot.superimposed ? 0.5 : 0.75)
        let maxAmplitude = bodyHeight * (snapshot.superimposed ? 0.42 : 0.21)
        let step = size.width / CGFloat(Self.barCount)
        let barWidth = max(1.5, step - 1.1)
        let framesPerPoint = secondsPerPoint * 75.0
        let isCrossfade = snapshot.mode == .crossfade

        let outMax = snapshot.outgoingTail?.maximum ?? 0
        let inMax = snapshot.incomingHead?.maximum ?? 0
        let loudest = max(outMax, inMax, 0.05)
        let outRef = max(outMax, loudest * 0.35, 0.05)
        let inRef = max(inMax, loudest * 0.35, 0.05)
        let displayScale = CGFloat(1 / loudest)
        let baseOutsideAlpha = snapshot.superimposed ? 0.68 : 0.80
        let baseInsideAlpha = snapshot.superimposed ? 0.54 : 0.66

        for bar in 0..<Self.barCount {
            let x = CGFloat(bar) * step
            let barCenter = x + step * 0.5
            let progress = max(0, min(1, Double((barCenter - x0) / max(1, x1 - x0))))

            if let tail = snapshot.outgoingTail, x <= outgoingEndX {
                let total = Double(tail.values.count)
                let f0 = total - Double(outgoingEndX - x) * framesPerPoint
                let f1 = total - Double(outgoingEndX - (x + step)) * framesPerPoint
                if let peak = sampleSmoothPeak(from: tail, startFrame: f0, endFrame: f1) {
                    let inZone = isCrossfade && barCenter >= x0
                    let gain = inZone ? spec.effectiveGainOut(at: progress) : 1.0
                    let height = min(maxAmplitude * 1.05, maxAmplitude * CGFloat(peak) * displayScale * CGFloat(gain))
                    let rect = CGRect(x: x, y: outMidY - height, width: barWidth, height: max(1.5, height * 2))

                    let rawProminence = snapshot.highlightLoudFrames ? smoothPeakProminence(peak: peak, trackReference: outRef) : 0.0
                    // Fade peak highlight intensity & opacity smoothly along the outgoing gain curve
                    let gainEnvelope = inZone ? pow(max(0.0, min(1.0, gain)), 0.65) : 1.0
                    let effectivePeakMix = min(1.0, rawProminence * (0.38 + 0.72 * gainEnvelope))
                    let barColor = SplicePalette.interpolate(from: palette.outgoing, to: palette.outgoingHighlight, t: effectivePeakMix)
                    let baseAlpha = inZone ? (baseInsideAlpha * (0.22 + 0.78 * gainEnvelope)) : baseOutsideAlpha
                    let finalAlpha = min(0.96, baseAlpha + effectivePeakMix * 0.34 * gainEnvelope)

                    context.fill(Path(rect), with: .color(barColor.opacity(finalAlpha)))
                }
            }

            if let head = snapshot.incomingHead, x + step >= incomingStartX {
                let f0 = Double(x - incomingStartX) * framesPerPoint
                let f1 = Double(x + step - incomingStartX) * framesPerPoint
                if let peak = sampleSmoothPeak(from: head, startFrame: f0, endFrame: f1) {
                    let inZone = isCrossfade && barCenter <= x1
                    let gain = inZone ? spec.effectiveGainIn(at: progress) : 1.0
                    let height = min(maxAmplitude * 1.05, maxAmplitude * CGFloat(peak) * displayScale * CGFloat(gain))
                    let rect = CGRect(x: x, y: inMidY - height, width: barWidth, height: max(1.5, height * 2))

                    let rawProminence = snapshot.highlightLoudFrames ? smoothPeakProminence(peak: peak, trackReference: inRef) : 0.0
                    // Fade peak highlight intensity & opacity smoothly along the incoming gain curve
                    let gainEnvelope = inZone ? pow(max(0.0, min(1.0, gain)), 0.65) : 1.0
                    let effectivePeakMix = min(1.0, rawProminence * (0.38 + 0.72 * gainEnvelope))
                    let barColor = SplicePalette.interpolate(from: palette.incoming, to: palette.incomingHighlight, t: effectivePeakMix)
                    let baseAlpha = inZone ? (baseInsideAlpha * (0.22 + 0.78 * gainEnvelope)) : baseOutsideAlpha
                    let finalAlpha = min(0.96, baseAlpha + effectivePeakMix * 0.34 * gainEnvelope)

                    context.fill(Path(rect), with: .color(barColor.opacity(finalAlpha)))
                }
            }
        }
    }

    private func drawGainCurves(_ context: inout GraphicsContext) {
        func y(for gain: Double) -> CGFloat {
            rulerHeight + bodyHeight * (1 - CGFloat(min(1, max(0, gain)) * 0.86 + 0.07))
        }
        var outCurve = Path(), inCurve = Path(), sumCurve = Path()
        var outFill = Path(), inFill = Path()
        outFill.move(to: CGPoint(x: x0, y: size.height))
        inFill.move(to: CGPoint(x: x0, y: size.height))

        for step in 0...Self.curveSteps {
            let t = Double(step) / Double(Self.curveSteps)
            let x = x0 + (x1 - x0) * CGFloat(t)
            let gainOut = spec.effectiveGainOut(at: t), gainIn = spec.effectiveGainIn(at: t)
            let outPoint = CGPoint(x: x, y: y(for: gainOut))
            let inPoint = CGPoint(x: x, y: y(for: gainIn))
            let sumPoint = CGPoint(x: x, y: y(for: (gainOut * gainOut + gainIn * gainIn).squareRoot()))
            if step == 0 {
                outCurve.move(to: outPoint); inCurve.move(to: inPoint); sumCurve.move(to: sumPoint)
            } else {
                outCurve.addLine(to: outPoint); inCurve.addLine(to: inPoint); sumCurve.addLine(to: sumPoint)
            }
            outFill.addLine(to: outPoint)
            inFill.addLine(to: inPoint)
        }

        if snapshot.superimposed {
            outFill.addLine(to: CGPoint(x: x1, y: size.height)); outFill.closeSubpath()
            inFill.addLine(to: CGPoint(x: x1, y: size.height)); inFill.closeSubpath()
            context.fill(outFill, with: .color(palette.outgoing.opacity(0.14)))
            context.fill(inFill, with: .color(palette.incoming.opacity(0.14)))
        }
        context.stroke(outCurve, with: .color(palette.outgoing), lineWidth: 2.3)
        context.stroke(inCurve, with: .color(palette.incoming), lineWidth: 2.3)
        if snapshot.showSum {
            context.stroke(sumCurve, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
    }
}
