import SwiftUI
import AudioKit

struct SpliceCanvasArea: View {
    let snapshot: SpliceCanvasSnapshot
    let palette: SplicePalette
    let trackNumber: Int
    let outgoingTitle: String
    let incomingTitle: String
    let onPreview: (KroutonTrackTransitionSpec) -> Void
    let onCommit: (KroutonTrackTransitionSpec) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @ObservedObject private var auditioner = SpliceAudioAuditioner.shared
    @State private var hoverPoint: CGPoint?
    @State private var activeTarget: SpliceDragTarget?
    @State private var hoveredHiddenMidTarget: SpliceDragTarget?

    var body: some View {
        GeometryReader { proxy in
            let geometry = SpliceCanvasGeometry(
                size: proxy.size,
                spec: snapshot.spec,
                horizontalZoom: snapshot.horizontalZoom
            )
            ZStack(alignment: .topLeading) {
                SpliceWaveformCanvas(snapshot: snapshot, geometry: geometry, palette: palette)
                    .equatable()

                SpliceHandleOverlay(
                    snapshot: snapshot,
                    geometry: geometry,
                    palette: palette,
                    trackNumber: trackNumber,
                    outgoingTitle: outgoingTitle,
                    incomingTitle: incomingTitle,
                    hoverPoint: hoverPoint,
                    activeTarget: activeTarget,
                    hoveredHiddenMidTarget: hoveredHiddenMidTarget,
                    playheadProgress: auditioner.isPlaying ? auditioner.playheadProgress : nil
                )
            }
            .modifier(SpliceDragModifier(
                spec: snapshot.spec,
                hoverPoint: $hoverPoint,
                activeTarget: $activeTarget,
                hoveredHiddenMidTarget: $hoveredHiddenMidTarget,
                geometry: geometry,
                onPreview: onPreview
            ) { _, new in
                onCommit(new)
            })
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(contrast == .increased ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SpliceHandleOverlay: View {
    let snapshot: SpliceCanvasSnapshot
    let geometry: SpliceCanvasGeometry
    let palette: SplicePalette
    let trackNumber: Int
    let outgoingTitle: String
    let incomingTitle: String
    let hoverPoint: CGPoint?
    let activeTarget: SpliceDragTarget?
    let hoveredHiddenMidTarget: SpliceDragTarget?
    let playheadProgress: Double?

    private var spec: KroutonTrackTransitionSpec { snapshot.spec }
    private var topY: CGFloat { SpliceCanvasGeometry.rulerHeight }

    var body: some View {
        let h = geometry.size.height
        let zoneX0 = geometry.zoneX0
        let zoneX1 = geometry.zoneX1
        let index01X = geometry.index01X

        ZStack(alignment: .topLeading) {
            HStack(spacing: 5) {
                Circle().fill(palette.outgoing).frame(width: 6, height: 6)
                Text(String(format: "OUT: %02d %@", trackNumber, outgoingTitle))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7).padding(.vertical, 2.5)
            .background(Color.black.opacity(0.68))
            .clipShape(Capsule())
            .padding(.leading, 40).padding(.top, topY + 14)

            HStack(spacing: 5) {
                Circle().fill(palette.incoming).frame(width: 6, height: 6)
                Text(String(format: "IN: %02d %@", trackNumber + 1, incomingTitle))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7).padding(.vertical, 2.5)
            .background(Color.black.opacity(0.68))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 8).padding(.bottom, 6)

            // Red Book INDEX 01 Marker
            Path { path in
                path.move(to: CGPoint(x: index01X, y: 0))
                path.addLine(to: CGPoint(x: index01X, y: h))
            }
            .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            let idx01Sec = snapshot.mode == .crossfade ? (spec.overlapSeconds * spec.spliceIndex01Ratio) : (snapshot.mode == .gap ? spec.preGapSeconds : 0)
            HStack(spacing: 3) {
                Text(String(format: "INDEX 01 • %02d • %@", trackNumber + 1, formatMMSSFF(idx01Sec)))
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                Image(systemName: "play.fill").font(.system(size: 6))
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.orange)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .position(x: min(geometry.size.width - 75, max(75, index01X)), y: 11)

            // Track-Aware Red Book Sub-Index Markers (INDEX 02..99)
            ForEach(geometry.subIndexDescriptors) { desc in
                let flagColor = desc.isIncomingTrack ? palette.incoming : palette.outgoing
                let owningTrackNum = desc.isIncomingTrack ? (trackNumber + 1) : trackNumber
                Path { path in
                    path.move(to: CGPoint(x: desc.x, y: 0))
                    path.addLine(to: CGPoint(x: desc.x, y: h))
                }
                .stroke(flagColor.opacity(0.90), style: StrokeStyle(lineWidth: 1.3, dash: [3, 3]))

                Text(String(format: "%02d • IDX %02d", owningTrackNum, desc.redBookIndexNumber))
                    .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(flagColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: min(geometry.size.width - 38, max(38, desc.x)), y: 11)
            }

            if snapshot.mode == .crossfade {
                railBadge(number: 1, color: palette.outgoing, seconds: 0)
                    .position(x: zoneX0, y: topY + 13)
                railBadge(number: 2, color: palette.incoming, seconds: spec.overlapSeconds)
                    .position(x: zoneX1, y: topY + 13)

                // Subtle ghost ring when hovering over the hidden vicinity of an unspawned mid-curve handle
                if hoveredHiddenMidTarget == .fadeOutMidHandle, geometry.fadeOutMidHandle == nil {
                    Circle()
                        .strokeBorder(palette.outgoing.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .frame(width: 13, height: 13)
                        .position(geometry.fadeOutMidAnchor)
                }
                if hoveredHiddenMidTarget == .fadeInMidHandle, geometry.fadeInMidHandle == nil {
                    Circle()
                        .strokeBorder(palette.incoming.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .frame(width: 13, height: 13)
                        .position(geometry.fadeInMidAnchor)
                }

                // Spawned On-Demand Fade-Out Mid Handle (t = 0.25) — double-click to remove
                if let outMidPt = geometry.fadeOutMidHandle {
                    midCurveHandleView(
                        color: palette.outgoing,
                        isActive: activeTarget == .fadeOutMidHandle
                    )
                    .position(outMidPt)
                }

                // Spawned On-Demand Fade-In Mid Handle (t = 0.75) — double-click to remove
                if let inMidPt = geometry.fadeInMidHandle {
                    midCurveHandleView(
                        color: palette.incoming,
                        isActive: activeTarget == .fadeInMidHandle
                    )
                    .position(inMidPt)
                }

                // Center Tension Handle
                VStack(spacing: 1) {
                    Image(systemName: "arrowtriangle.up.fill").font(.system(size: 6.5))
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 6.5))
                }
                .padding(.horizontal, 5).padding(.vertical, 3.5)
                .background(activeTarget == .curveBody ? KroutonPillMetrics.activeFill : Color.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.55), radius: 3)
                .position(geometry.centerHandle)
            } else if snapshot.mode == .gap {
                railBadge(number: 1, color: .white.opacity(0.75), seconds: 0)
                    .position(x: zoneX0, y: topY + 13)
                railBadge(number: 2, color: .white.opacity(0.75), seconds: spec.preGapSeconds)
                    .position(x: zoneX1, y: topY + 13)

                Text(String(format: "INDEX 00 SILENCE • %@ (%df)", formatMMSSFF(spec.preGapSeconds), spec.preGapRedBookFrames))
                    .kroutonReadout()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .position(x: (zoneX0 + zoneX1) * 0.5, y: topY + (h - topY) * 0.5)
            }

            if let pt = hoverPoint {
                hoverCallout(at: pt)
            }

            if let progress = playheadProgress {
                let px = geometry.size.width * CGFloat(progress)
                Rectangle().fill(Color.green).frame(width: 2, height: h).position(x: px, y: h * 0.5)
            }
        }
    }

    @ViewBuilder
    private func midCurveHandleView(color: Color, isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: isActive ? 15 : 13, height: isActive ? 15 : 13)
            Circle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: isActive ? 15 : 13, height: isActive ? 13 : 13)
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 6.5, weight: .black))
                .foregroundStyle(.black)
        }
        .shadow(color: .black.opacity(0.6), radius: 2.5)
    }

    @ViewBuilder
    private func railBadge(number: Int, color: Color, seconds: Double) -> some View {
        HStack(spacing: 3) {
            Text("\(number)")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .frame(width: 15, height: 15)
                .background(color)
                .foregroundStyle(.black)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
            Text(formatMMSSFF(seconds))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .fixedSize()
    }

    @ViewBuilder
    private func hoverCallout(at pt: CGPoint) -> some View {
        let w = geometry.size.width
        let x0 = geometry.zoneX0, x1 = geometry.zoneX1
        let tOverlap = max(0.0, min(1.0, Double((pt.x - x0) / max(1.0, x1 - x0))))
        let gOut = pt.x < x0 ? 1.0 : (pt.x > x1 ? 0.0 : spec.effectiveGainOut(at: tOverlap))
        let gIn = pt.x > x1 ? 1.0 : (pt.x < x0 ? 0.0 : spec.effectiveGainIn(at: tOverlap))
        let dbOut = gOut > 0.001 ? formatDB(20.0 * log10(gOut)) : "-∞ dB"
        let dbIn = gIn > 0.001 ? formatDB(20.0 * log10(gIn)) : "-∞ dB"
        let relSec = (Double(pt.x / max(1.0, w)) - 0.5) * geometry.effectiveSpanSeconds
        let hint: String = {
            if hoveredHiddenMidTarget == .fadeOutMidHandle { return " • Click to add Fade-Out Handle" }
            if hoveredHiddenMidTarget == .fadeInMidHandle { return " • Click to add Fade-In Handle" }
            if activeTarget == .fadeOutMidHandle || activeTarget == .fadeInMidHandle { return " • Double-click handle to remove" }
            return ""
        }()
        let label = String(format: "%@ • Out %@ • In %@%@", formatMMSSFF(abs(relSec)), dbOut, dbIn, hint)

        Text(label)
            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.black.opacity(0.88))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
            .position(x: min(w - 135, max(135, pt.x)), y: max(36, min(geometry.size.height - 16, pt.y - 16)))
            .allowsHitTesting(false)
    }

    private func formatDB(_ db: Double) -> String {
        abs(db) < 0.05 ? "0.0 dB" : String(format: "%+.1f dB", db)
    }

    private func formatMMSSFF(_ seconds: Double) -> String {
        let frames = Int64((max(0.0, seconds) * 75.0).rounded())
        return KroutonMarmaladeModule.formatFramesToMMSSFF(frames)
    }
}
