import AudioKit
import SwiftUI

// The splice canvas as a standalone view fed by an immutable snapshot.
//
// Replaces the four `draw…` methods in AudioCrossfadeCanvasView+Drawing.swift.
// Because the renderer owns no state and reads nothing from the parent view, the
// parent's @State can go back to `private`, and this file can be read, tested
// and previewed on its own.
//
// Per-frame cost: no file access, no PeakPyramid construction, no sample scans.
// The peak arrays were built once by AudioAnalysisService; drawing reads a few
// values per bar and builds five paths.
//

struct SpliceCanvasSnapshot: Equatable, Sendable {
    var spec: KroutonTrackTransitionSpec
    /// Nil while the file is still being analysed or could not be read.
    var outgoingTail: FramePeaks?
    var incomingHead: FramePeaks?
    var superimposed: Bool
    var showSum: Bool
    /// Tints frames near the window's loudest peak. This is an amplitude
    /// highlight, not transient detection; label the control accordingly.
    var highlightLoudFrames: Bool
    var horizontalZoom: Double = 1.0
    var isMiniGhostMode: Bool = false

    var mode: SpliceTransitionMode {
        if spec.isCrossfading { return .crossfade }
        return spec.preGapSeconds <= 0.01 ? .gapless : .gap
    }
}

struct SplicePalette: Equatable, Sendable {
    var outgoing = Color(red: 0.95, green: 0.38, blue: 0.28)
    var incoming = Color(red: 0.36, green: 0.68, blue: 0.98)
    var highlight = Color.yellow
    var outgoingHighlight = Color(red: 0.74, green: 0.98, blue: 0.24)
    var incomingHighlight = Color(red: 1.00, green: 0.76, blue: 0.12)
}

struct SpliceWaveformCanvas: View, Equatable {
    let snapshot: SpliceCanvasSnapshot
    let geometry: SpliceCanvasGeometry
    let palette: SplicePalette

    init(snapshot: SpliceCanvasSnapshot, geometry: SpliceCanvasGeometry, palette: SplicePalette = SplicePalette()) {
        self.snapshot = snapshot
        self.geometry = geometry
        self.palette = palette
    }

    // Views are main-actor types in Swift 6; Equatable is not, so == is spelled out.
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
// Use it as `SpliceWaveformCanvas(...).equatable()` so SwiftUI skips the redraw
// when neither the snapshot nor the geometry changed (hover moves, for example).

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

    // MARK: - Time mapping

    /// Seconds per point, taken from the zone so bars line up with the rails.
    private var secondsPerPoint: Double {
        let zoneWidth = Double(x1 - x0)
        switch snapshot.mode {
        case .crossfade where zoneWidth > 1: return spec.overlapSeconds / zoneWidth
        case .gap where zoneWidth > 1: return spec.preGapSeconds / zoneWidth
        default: return geometry.effectiveSpanSeconds / Double(max(1, size.width))
        }
    }

    /// The outgoing track's last sample sits here; the incoming track's first sits at `incomingStartX`.
    private var outgoingEndX: CGFloat { snapshot.mode == .crossfade ? x1 : x0 }
    private var incomingStartX: CGFloat { snapshot.mode == .crossfade ? x0 : x1 }

    // MARK: - Layers

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

    private func drawWaveforms(_ context: inout GraphicsContext) {
        let outMidY = rulerHeight + bodyHeight * (snapshot.superimposed ? 0.5 : 0.25)
        let inMidY = rulerHeight + bodyHeight * (snapshot.superimposed ? 0.5 : 0.75)
        let maxAmplitude = bodyHeight * (snapshot.superimposed ? 0.42 : 0.21)
        let step = size.width / CGFloat(Self.barCount)
        let barWidth = max(1.5, step - 1.1)
        let framesPerPoint = secondsPerPoint * 75.0
        let isCrossfade = snapshot.mode == .crossfade

        // One shared display scale keeps the two tracks' relative loudness honest.
        // It affects drawing only; the peak readout uses the unscaled values.
        let loudest = max(snapshot.outgoingTail?.maximum ?? 0, snapshot.incomingHead?.maximum ?? 0, 0.05)
        let displayScale = CGFloat(1 / loudest)
        let highlightThreshold = loudest * 0.8

        var outOutside = Path(), outInside = Path(), inOutside = Path(), inInside = Path(), outHighlighted = Path(), inHighlighted = Path()

        for bar in 0..<Self.barCount {
            let x = CGFloat(bar) * step
            let progress = max(0, min(1, Double((x - x0) / max(1, x1 - x0))))

            if let tail = snapshot.outgoingTail, x <= outgoingEndX {
                // Frames counted back from the end of the outgoing track.
                let last = tail.values.count - Int(Double(outgoingEndX - x - step) * framesPerPoint)
                let first = tail.values.count - Int(Double(outgoingEndX - x) * framesPerPoint)
                if let peak = tail.peak(in: first..<max(first + 1, last)) {
                    let inZone = isCrossfade && x >= x0
                    let gain = inZone ? spec.effectiveGainOut(at: progress) : 1
                    let height = min(maxAmplitude * 1.05, maxAmplitude * CGFloat(peak) * displayScale * CGFloat(gain))
                    let rect = CGRect(x: x, y: outMidY - height, width: barWidth, height: max(1.5, height * 2))
                    if snapshot.highlightLoudFrames, peak > highlightThreshold { outHighlighted.addRect(rect) }
                    else if inZone { outInside.addRect(rect) } else { outOutside.addRect(rect) }
                }
            }

            if let head = snapshot.incomingHead, x + step >= incomingStartX {
                // Frames counted forward from the start of the incoming track.
                let first = Int(Double(x - incomingStartX) * framesPerPoint)
                let last = Int(Double(x + step - incomingStartX) * framesPerPoint)
                if let peak = head.peak(in: first..<max(first + 1, last)) {
                    let inZone = isCrossfade && x <= x1
                    let gain = inZone ? spec.effectiveGainIn(at: progress) : 1
                    let height = min(maxAmplitude * 1.05, maxAmplitude * CGFloat(peak) * displayScale * CGFloat(gain))
                    let rect = CGRect(x: x, y: inMidY - height, width: barWidth, height: max(1.5, height * 2))
                    if snapshot.highlightLoudFrames, peak > highlightThreshold { inHighlighted.addRect(rect) }
                    else if inZone { inInside.addRect(rect) } else { inOutside.addRect(rect) }
                }
            }
        }

        let outside = snapshot.superimposed ? 0.65 : 0.78
        let inside = snapshot.superimposed ? 0.46 : 0.58
        context.fill(outOutside, with: .color(palette.outgoing.opacity(outside)))
        context.fill(outInside, with: .color(palette.outgoing.opacity(inside)))
        context.fill(inOutside, with: .color(palette.incoming.opacity(outside)))
        context.fill(inInside, with: .color(palette.incoming.opacity(inside)))
        context.fill(outHighlighted, with: .color(palette.outgoingHighlight))
        context.fill(inHighlighted, with: .color(palette.incomingHighlight))
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
            // Power sum: flat at 1.0 for an equal-power fade of unrelated material.
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
