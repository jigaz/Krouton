import Foundation
import Network
import os

// MARK: - One TLS Connection to a Krouton Server

/// Owns one mutually-authenticated TLS connection: frames in and out, plus the upload pipeline
/// when an image is being sent (extent reads stay off the main actor). Control messages and
/// telemetry surface through `events`.
public actor SpoolServerConnection {
    /// What arrives on the connection.
    public enum Event: Sendable {
        /// A control message.
        case control(SpoolControl)
        /// A telemetry frame.
        case telemetry(SpoolTelemetryPacket)
        /// Upload progress: extents acknowledged of the total, and the sender's phase.
        case upload(acknowledged: Int, total: Int, phase: SpoolUploadSender.Phase)
    }

    /// Why the connection failed or closed.
    public enum Failure: Error, Sendable, Equatable {
        /// The server couldn't be reached, or the transport failed.
        case unreachable(String)
        /// The endpoint policy refused the address.
        case refusedAddress(SpoolEndpointDenial)
        /// The server's key didn't match the pin.
        case untrustedServer
        /// The connection closed.
        case closed
        /// The server sent something the protocol doesn't allow.
        case protocolError(String)
    }

    /// Control messages, telemetry and upload progress, in order. Finishes when the connection
    /// closes.
    public nonisolated let events: AsyncThrowingStream<Event, Error>
    /// TLS 1.3 exporter for this connection: what both session proofs sign.
    public nonisolated let exporter: Data
    /// The key pin the server presented (checked by `acceptPin` during the handshake).
    public nonisolated let serverPin: Data

    private let connection: NWConnection
    private let channel: any SpoolTransportChannel
    private let continuation: AsyncThrowingStream<Event, Error>.Continuation
    private var decoder = SpoolFrameDecoder()
    private var upload: Upload?
    private var pump: Task<Void, Never>?

    private struct Upload {
        var sender: SpoolUploadSender
        let file: FileHandle
        let fileBytes: UInt64
    }

    private init(connection: NWConnection, exporter: Data, serverPin: Data) {
        self.connection = connection
        self.channel = NWSpoolChannel(connection)
        self.exporter = exporter
        self.serverPin = serverPin
        (events, continuation) = AsyncThrowingStream.makeStream(of: Event.self, throwing: Error.self)
    }

    // MARK: - Opening

    /// Connects and completes TLS. `acceptPin` decides whether the server's key is trusted (a
    /// paired server's stored pin, or anything during pairing, where the code comparison decides).
    public static func open(
        to endpoint: NWEndpoint,
        identity: SecIdentity,
        policy: SpoolEndpointPolicy,
        acceptPin: @escaping @Sendable (Data) -> Bool
    ) async throws -> SpoolServerConnection {
        let queue = DispatchQueue(label: "app.krouton.spool.tls")
        let seenPin = OSAllocatedUnfairLock<Data?>(initialState: nil)
        guard let parameters = SpoolTLS.mutualTLSParameters(
            localIdentity: identity,
            isPinnedPeerKey: { pin in
                seenPin.withLock { $0 = pin }
                return acceptPin(pin)
            },
            verificationQueue: queue
        ) else { throw Failure.protocolError("Could not set up TLS") }

        let connection = NWConnection(to: endpoint, using: parameters)
        try await waitUntilReady(connection, queue: queue)

        if let reached = SpoolIPAddress(reached: connection.currentPath?.remoteEndpoint) {
            let verdict: SpoolAddressVerdict = policy.evaluate(reached)
            if case .denied(let reason) = verdict {
                connection.cancel()
                throw Failure.refusedAddress(reason)
            }
        }
        guard let pin = seenPin.withLock({ $0 }), let exporter = SpoolTLS.exporterSecret(of: connection) else {
            connection.cancel()
            throw Failure.untrustedServer
        }
        let opened = SpoolServerConnection(connection: connection, exporter: exporter, serverPin: pin)
        await opened.startPump()
        return opened
    }

    private static func waitUntilReady(_ connection: NWConnection, queue: DispatchQueue) async throws {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let finish: @Sendable (Result<Void, Error>) -> Void = { result in
                let first = resumed.withLock { (done: inout Bool) -> Bool in
                    defer { done = true }
                    return !done
                }
                if first { continuation.resume(with: result) }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(()))
                case .failed(let error):
                    finish(.failure(Failure.unreachable(error.localizedDescription)))
                case .waiting(let error):
                    // TLS rejections and unreachable hosts land here; do not wait for a retry.
                    connection.cancel()
                    finish(.failure(Failure.unreachable(error.localizedDescription)))
                case .cancelled:
                    finish(.failure(Failure.closed))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 15) {
                connection.cancel()
                finish(.failure(Failure.unreachable("Timed out")))
            }
        }
    }

    // MARK: - Traffic

    private func startPump() {
        pump = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let data = try await channel.receive(maximumLength: 1 << 20)
                if data.isEmpty {
                    continuation.finish(throwing: Failure.closed)
                    return
                }
                for frame in try decoder.push([UInt8](data)) {
                    try await route(frame)
                }
            } catch {
                continuation.finish(throwing: error)
                return
            }
        }
    }

    private func route(_ frame: SpoolFrame) async throws {
        let kind: SpoolFrameKind = frame.header.kind
        switch kind {
        case .control:
            guard let message = SpoolControl(frame: frame) else { throw Failure.protocolError("Unreadable control message") }
            continuation.yield(.control(message))
        case .telemetry:
            if let packet = SpoolTelemetryPacket(frame: frame) { continuation.yield(.telemetry(packet)) }
        case .bitmapReply, .credit, .extentAck, .extentReject, .manifestMismatch:
            try await feedUpload(frame)
        default:
            throw Failure.protocolError("Unexpected frame from the server")
        }
    }

    /// Sends control messages.
    public func send(_ messages: [SpoolControl]) async throws {
        try await send(frames: messages.map { $0.frame() })
    }

    /// Sends frames in one write.
    public func send(frames: [SpoolFrame]) async throws {
        guard !frames.isEmpty else { return }
        do {
            try await channel.send(Data(frames.flatMap { $0.encoded() }))
        } catch {
            let transport: SpoolTransportError = error
            throw transport == .closed ? Failure.closed : Failure.unreachable("\(transport)")
        }
    }

    /// Stops receiving, closes any upload file and the connection, and ends `events`.
    public func close() async {
        pump?.cancel()
        if let upload { try? upload.file.close() }
        upload = nil
        await channel.cancel()
        continuation.finish()
    }

    // MARK: - Upload Pipeline

    /// Starts (or resumes) sending `file` under `manifest`. The server answers the bitmap query
    /// with what it already holds, so only missing extents travel.
    public func startUpload(file: URL, manifest: SpoolTransferManifest) async throws {
        let handle = try FileHandle(forReadingFrom: file)
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? UInt64) ?? 0
        let budget = 32 * 1_048_576
        var sender = SpoolUploadSender(manifest: manifest,
                                       maxInFlight: SpoolUploadSender.maxInFlight(forMemoryBudget: budget, manifest: manifest))
        let opening = sender.connect()
        upload = Upload(sender: sender, file: handle, fileBytes: size)
        try await send(frames: opening)
    }

    private func feedUpload(_ frame: SpoolFrame) async throws {
        guard var current = upload else { return }
        let manifest = current.sender.manifest
        let handle = current.file
        let fileBytes = current.fileBytes
        let out = try current.sender.receive(frame.encoded()) { index in
            Self.readExtent(index, manifest: manifest, from: handle, fileBytes: fileBytes)
        }
        let phase = current.sender.phase
        let acknowledged = current.sender.acknowledged.committedCount
        if phase == .complete || phase == .manifestMismatch {
            try? handle.close()
            upload = nil
        } else {
            upload = current
        }
        try await send(frames: out)
        continuation.yield(.upload(acknowledged: acknowledged, total: manifest.extentCount, phase: phase))
    }

    /// Reads one extent; bytes past the end of the file read as zeros (the image is padded to whole
    /// 2048-byte sectors for the manifest).
    static func readExtent(_ index: Int, manifest: SpoolTransferManifest, from handle: FileHandle, fileBytes: UInt64) -> [UInt8] {
        let range = manifest.byteRange(ofExtent: index)
        var bytes = [UInt8](repeating: 0, count: range.count)
        let start = UInt64(range.lowerBound)
        guard start < fileBytes else { return bytes }
        let available = Int(min(UInt64(range.count), fileBytes - start))
        do {
            try handle.seek(toOffset: start)
            if let data = try handle.read(upToCount: available) {
                bytes.replaceSubrange(0..<data.count, with: data)
            }
        } catch {
            // A short read makes the extent's digest wrong; the server rejects it and the sender
            // gives up after three rejects (`sourceChanged`), which surfaces as a failed upload.
        }
        return bytes
    }
}

// MARK: - Manifest From a File

extension SpoolTransferManifest {
    /// Hashes an image file extent by extent, padding it to whole 2048-byte sectors.
    public static func forImage(at url: URL, sectorsPerExtent: Int = defaultSectorsPerExtent) throws -> SpoolTransferManifest {
        let sectorSize = 2048
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        guard size > 0 else { throw SpoolServerConnection.Failure.protocolError("The image is empty") }
        let totalSectors = Int((size + UInt64(sectorSize) - 1) / UInt64(sectorSize))
        let extentBytes = sectorSize * sectorsPerExtent
        let extentCount = (totalSectors + sectorsPerExtent - 1) / sectorsPerExtent
        var leaves: [[UInt8]] = []
        leaves.reserveCapacity(extentCount)
        for index in 0..<extentCount {
            let start = index * extentBytes
            let length = min(extentBytes, totalSectors * sectorSize - start)
            var chunk = [UInt8]((try handle.read(upToCount: length)) ?? Data())
            if chunk.count < length { chunk += [UInt8](repeating: 0, count: length - chunk.count) }
            leaves.append(leafDigest(chunk))
        }
        return SpoolTransferManifest(sectorSize: sectorSize, sectorsPerExtent: sectorsPerExtent,
                                     totalSectors: totalSectors, leafDigests: leaves)
    }
}
