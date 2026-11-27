import AVFoundation
import AudioKit
import Observation
import SwiftUI
import os

// MARK: - Real-Time AVAudioSourceNode & CrossfadeParameterMailbox Auditioner

@Observable
@MainActor
final class SpliceAudioAuditioner {
    static let shared = SpliceAudioAuditioner()
    var isPlaying: Bool = false
    var playheadProgress: Double = 0.0
    var activeTrackID: UUID? = nil
    var leadLagSeconds: Double = 3.0 // ±3s, ±5s, ±10s pre/post-roll

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var mailbox: CrossfadeParameterMailbox?
    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var activeSampleRate: Double = 44_100.0
    @ObservationIgnored private var activePreRollFrames: Int = 0
    @ObservationIgnored private var activePostRollFrames: Int = 0
    @ObservationIgnored private var latestZoneFrames: Int = 0

    func stop() {
        displayTimer?.invalidate()
        displayTimer = nil
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
        mailbox = nil
        isPlaying = false
        activeTrackID = nil
        playheadProgress = 0.0
    }

    /// Called at 60/120 Hz from AudioProjectController.preview / commitTransition while the user drags handles.
    /// Publishes scalar-only CrossfadeRenderParams into the lock-free mailbox without interrupting playback.
    func updateLiveSpec(
        _ spec: KroutonTrackTransitionSpec,
        forTrackID trackID: UUID,
        suppressedAtDiscBoundary: Bool = false
    ) {
        guard isPlaying, activeTrackID == trackID, let mailbox else { return }
        let params = CrossfadeRenderParams(
            spec: spec,
            sampleRate: activeSampleRate,
            suppressedAtDiscBoundary: suppressedAtDiscBoundary
        )
        latestZoneFrames = params.overlapFrames > 0 ? params.overlapFrames : params.preGapFrames
        mailbox.publish(params)
    }

    func startTransitionAudition(
        trackID: UUID? = nil,
        outgoingURL: URL?,
        incomingURL: URL?,
        spec: KroutonTrackTransitionSpec,
        suppressedAtDiscBoundary: Bool = false
    ) {
        if isPlaying {
            stop()
            return
        }
        let preRollSec = max(1.0, min(15.0, leadLagSeconds))
        let postRollSec = max(1.0, min(15.0, leadLagSeconds))
        let maxOverlapWindowSec = 30.0
        let sampleRate = 44_100.0

        let outgoingPCM = outgoingURL.flatMap {
            try? Self.loadTailPCM(from: $0, tailSeconds: preRollSec + maxOverlapWindowSec, targetSampleRate: sampleRate)
        } ?? StereoPCM(left: [], right: [])

        let incomingPCM = incomingURL.flatMap {
            try? Self.loadHeadPCM(from: $0, headSeconds: maxOverlapWindowSec + postRollSec, targetSampleRate: sampleRate)
        } ?? StereoPCM(left: [], right: [])

        guard outgoingPCM.frameCount > 0 || incomingPCM.frameCount > 0 else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        let params = CrossfadeRenderParams(
            spec: spec,
            sampleRate: sampleRate,
            suppressedAtDiscBoundary: suppressedAtDiscBoundary
        )
        let preRollFrames = Int((preRollSec * sampleRate).rounded())
        let postRollFrames = Int((postRollSec * sampleRate).rounded())
        let box = CrossfadeParameterMailbox(params)

        let node = Self.makeSourceNode(
            format: format,
            mailbox: box,
            initialParams: params,
            preRollFrames: preRollFrames,
            outgoing: outgoingPCM,
            incoming: incomingPCM
        )

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            engine.detach(node)
            return
        }

        self.sourceNode = node
        self.mailbox = box
        self.activeSampleRate = sampleRate
        self.activePreRollFrames = preRollFrames
        self.activePostRollFrames = postRollFrames
        self.latestZoneFrames = params.overlapFrames > 0 ? params.overlapFrames : params.preGapFrames
        self.activeTrackID = trackID
        self.playheadProgress = 0.0
        self.isPlaying = true

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying, let box = self.mailbox else { return }
                let currentFrame = box.playheadFrame
                let totalFrames = max(1, self.activePreRollFrames + self.latestZoneFrames + self.activePostRollFrames)
                if currentFrame >= totalFrames {
                    self.stop()
                    return
                }
                self.playheadProgress = min(1.0, max(0.0, Double(currentFrame) / Double(totalFrames)))
            }
        }
    }

    // MARK: - Nonisolated Real-Time Render Block Factory & PCM Window Decoders

    /// Declared `nonisolated static` so Swift 6 never infers `@MainActor` isolation on the CoreAudio render callback.
    private nonisolated static func makeSourceNode(
        format: AVAudioFormat,
        mailbox: CrossfadeParameterMailbox,
        initialParams: CrossfadeRenderParams,
        preRollFrames: Int,
        outgoing: StereoPCM,
        incoming: StereoPCM
    ) -> AVAudioSourceNode {
        let cursorLock = OSAllocatedUnfairLock(initialState: CrossfadeRenderCursor(params: initialParams))
        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count >= 2,
                  let leftPtr = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightPtr = buffers[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            var cursor = cursorLock.withLock { $0 }
            if let fresh = mailbox.exchange(lastSeen: cursor.generation, playheadFrame: cursor.frame) {
                cursor.params = fresh.params
                cursor.generation = fresh.generation
            }
            let count = Int(frameCount)
            CrossfadeRenderer.render(
                left: UnsafeMutableBufferPointer(start: leftPtr, count: count),
                right: UnsafeMutableBufferPointer(start: rightPtr, count: count),
                frameCount: count,
                cursor: &cursor,
                preRollFrames: preRollFrames,
                outgoing: outgoing,
                incoming: incoming
            )
            let updatedCursor = cursor
            cursorLock.withLock { $0 = updatedCursor }
            return noErr
        }
    }

    nonisolated static func loadTailPCM(from url: URL, tailSeconds: Double, targetSampleRate: Double) throws -> StereoPCM {
        let file = try AVAudioFile(forReading: url)
        let srcFormat = file.processingFormat
        let totalFrames = file.length
        let wantedSrcFrames = AVAudioFramePosition((max(0.5, tailSeconds) * srcFormat.sampleRate).rounded())
        let startFrame = max(0, totalFrames - wantedSrcFrames)
        let readCount = AVAudioFrameCount(max(0, totalFrames - startFrame))
        file.framePosition = startFrame
        return try readStereoWindow(file: file, frameCount: readCount)
    }

    nonisolated static func loadHeadPCM(from url: URL, headSeconds: Double, targetSampleRate: Double) throws -> StereoPCM {
        let file = try AVAudioFile(forReading: url)
        let srcFormat = file.processingFormat
        let wantedSrcFrames = AVAudioFramePosition((max(0.5, headSeconds) * srcFormat.sampleRate).rounded())
        let readCount = AVAudioFrameCount(min(file.length, wantedSrcFrames))
        file.framePosition = 0
        return try readStereoWindow(file: file, frameCount: readCount)
    }

    private nonisolated static func readStereoWindow(file: AVAudioFile, frameCount: AVAudioFrameCount) throws -> StereoPCM {
        let format = file.processingFormat
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return StereoPCM(left: [], right: [])
        }
        try file.read(into: buffer, frameCount: frameCount)
        guard let channelData = buffer.floatChannelData else {
            return StereoPCM(left: [], right: [])
        }
        let n = Int(buffer.frameLength)
        let left = Array(UnsafeBufferPointer(start: channelData[0], count: n))
        let right = format.channelCount > 1
            ? Array(UnsafeBufferPointer(start: channelData[1], count: n))
            : left
        return StereoPCM(left: left, right: right)
    }
}
