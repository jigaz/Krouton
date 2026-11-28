import Foundation

// MARK: - KRSP v1 Control Channel
//
// Control frames (kind 8) carry one UTF-8 JSON object whose "type" names the message; telemetry
// frames (kind 7) carry a `SpoolTelemetryPacket`. Field names and values mirror
// `krouton-server/crates/krsp/src/control.rs` exactly; `Vectors/krsp-control-v1.txt` pins both.

/// Where a job on the server stands.
public enum SpoolJobState: String, Sendable, Equatable, CaseIterable {
    /// `mastering`: a folder upload is being unpacked and built into a disc image on the server.
    case receiving, mastering, queued, burning, verifying, done, failed, cancelled

    /// True for done, failed and cancelled.
    public var isTerminal: Bool { self == .done || self == .failed || self == .cancelled }
}

/// The disc in a server drive.
public enum SpoolMediaState: String, Sendable, Equatable {
    case unknown, noDisc, blank, appendable, complete

    /// Reads a wire value; anything unknown is `.unknown`.
    public init(wire: String) { self = SpoolMediaState(rawValue: wire) ?? .unknown }
}

/// The error codes the server sends.
public enum SpoolErrorCode: String, Sendable, Equatable {
    case badRequest, notAuthenticated, unknownDrive, unknownJob, noSpace, tooLarge
    case manifestRejected, driveBusy, pairingClosed, pairingRejected, internalError = "internal"

    /// Reads a wire value; anything unknown is `.internalError`.
    public init(wire: String) { self = SpoolErrorCode(rawValue: wire) ?? .internalError }
}

/// One drive on the server, as `drives` and `welcome` report it.
public struct SpoolDriveInfo: Sendable, Equatable, Identifiable {
    /// The drive's ID on the server.
    public let id: String
    /// The drive's name, for display.
    public let name: String
    /// The disc in the tray.
    public let media: SpoolMediaState
    /// Jobs queued or burning on this drive.
    public let queue: Int
    /// True while it burns or verifies.
    public let busy: Bool
    /// The disc families the drive writes; nil when the server can't tell (or is older than
    /// drive capabilities, 2026-11).
    public let writes: SpoolNodeCapabilities?
    /// The disc in the tray, such as "DVD+R"; nil when there is none or it isn't known.
    public let disc: String?
    /// Free space on that disc; nil when unknown.
    public let freeBytes: Int64?

    public init(id: String, name: String, media: SpoolMediaState, queue: Int, busy: Bool,
                writes: SpoolNodeCapabilities? = nil, disc: String? = nil, freeBytes: Int64? = nil) {
        self.id = id
        self.name = name
        self.media = media
        self.queue = queue
        self.busy = busy
        self.writes = writes
        self.disc = disc
        self.freeBytes = freeBytes
    }
}

/// One job on the server.
public struct SpoolJobInfo: Sendable, Equatable, Identifiable {
    /// The job's ID.
    public let job: String
    /// The drive it runs on.
    public let drive: String
    /// The disc's label.
    public let label: String
    /// Where it stands.
    public let state: SpoolJobState
    /// 0…1, or nil while the server cannot tell (indeterminate).
    public let fraction: Double?
    /// Jobs ahead of it on its drive.
    public let queueAhead: Int
    /// The server's status line.
    public let message: String
    public var id: String { job }

    public init(job: String, drive: String, label: String, state: SpoolJobState, fraction: Double?, queueAhead: Int, message: String) {
        self.job = job
        self.drive = drive
        self.label = label
        self.state = state
        self.fraction = fraction
        self.queueAhead = queueAhead
        self.message = message
    }
}

/// How the server should burn a job.
public struct SpoolBurnOptions: Sendable, Equatable {
    /// Write speed multiplier; 0 = the drive's maximum.
    public var speed: Int
    /// Reads the disc back after burning.
    public var verify: Bool
    /// Laser-off test write where the server's burn tool supports it.
    public var simulate: Bool
    /// Ejects the disc when done.
    public var eject: Bool

    public init(speed: Int = 0, verify: Bool = true, simulate: Bool = false, eject: Bool = true) {
        self.speed = speed
        self.verify = verify
        self.simulate = simulate
        self.eject = eject
    }
}

/// What a `submit` uploads: a finished 2048-byte-sector disc image, or a folder as a KRSP bundle
/// (`SpoolBundleWriter`) for the server to master first.
public enum SpoolUploadContent: String, Sendable, Equatable {
    case image, files
}

/// What the server says after authentication: who it is, its limits and its drives.
public struct SpoolServerWelcome: Sendable, Equatable {
    /// The server's name.
    public let serverName: String
    /// The server's node ID (see `SpoolNodeID`).
    public let nodeID: String
    /// The server's version.
    public let version: String
    /// The largest image it accepts.
    public let maxImageBytes: UInt64
    /// Free staging space on the server.
    public let freeBytes: UInt64
    /// File systems the server builds from folders (`iso9660`, `joliet`, `rockridge`, `udf`);
    /// empty when it only burns finished images. Absent from servers before 0.3.
    public let fileSystems: [String]
    /// Its drives.
    public let drives: [SpoolDriveInfo]

    /// True when it masters folders itself.
    public var buildsDiscsFromFolders: Bool { !fileSystems.isEmpty }
}

// MARK: - Messages

/// Every control message of KRSP v1, in both directions. The JSON shape matches the server's
/// `control.rs`; the test vectors check both.
public enum SpoolControl: Sendable, Equatable {
    /// Client: the Ed25519 identity key and the session proof.
    case auth(identityKey: Data, signature: Data)
    /// Either side: a keep-alive with a number to echo.
    case ping(UInt64)
    /// The echo of a ping.
    case pong(UInt64)
    /// Server: a request failed.
    case error(code: SpoolErrorCode, message: String, job: String?)
    /// Client: the app and this Mac's name.
    case hello(app: String, deviceName: String)
    /// Client: asks for `drives`.
    case listDrives
    /// Client: asks for `jobs`.
    case listJobs
    /// Client: starts a job; the upload follows.
    case submit(job: String, drive: String, label: String, content: SpoolUploadContent, options: SpoolBurnOptions)
    /// Client: asks for updates on a job.
    case watch(job: String)
    /// Client: cancels a job.
    case cancel(job: String)
    /// Client: ejects a drive.
    case eject(drive: String)
    /// Client: starts pairing.
    case pairStart(deviceName: String)
    /// Client: its pairing hello (identity key, ephemeral key and nonce, 80 bytes).
    case pairHello(Data)
    /// Client: whether the user confirmed the code.
    case pairConfirm(accepted: Bool)
    /// Server: after authentication.
    case welcome(SpoolServerWelcome)
    /// Server: the drives.
    case drives([SpoolDriveInfo])
    /// Server: a job was accepted.
    case accepted(job: String)
    /// Server: one job's state.
    case job(SpoolJobInfo)
    /// Server: every job.
    case jobs([SpoolJobInfo])
    /// Server: its commitment, before the reveal.
    case pairCommit(Data)
    /// Server: how pairing ended.
    case pairResult(accepted: Bool, nodeID: String, serverName: String)

    // MARK: - Encode

    /// The message as a JSON object.
    public func jsonObject() -> [String: Any] {
        switch self {
        case .auth(let key, let signature):
            ["type": "auth", "identityKey": SpoolHex.encode(key), "signature": SpoolHex.encode(signature)]
        case .ping(let n): ["type": "ping", "n": n]
        case .pong(let n): ["type": "pong", "n": n]
        case .error(let code, let message, let job):
            ["type": "error", "code": code.rawValue, "message": message, "job": job as Any? ?? NSNull()]
        case .hello(let app, let device): ["type": "hello", "app": app, "deviceName": device]
        case .listDrives: ["type": "listDrives"]
        case .listJobs: ["type": "listJobs"]
        case .submit(let job, let drive, let label, let content, let o):
            ["type": "submit", "job": job, "drive": drive, "label": label, "content": content.rawValue,
             "speed": o.speed, "verify": o.verify, "simulate": o.simulate, "eject": o.eject]
        case .watch(let job): ["type": "watch", "job": job]
        case .cancel(let job): ["type": "cancel", "job": job]
        case .eject(let drive): ["type": "eject", "drive": drive]
        case .pairStart(let device): ["type": "pairStart", "deviceName": device]
        case .pairHello(let hello): ["type": "pairHello", "hello": SpoolHex.encode(hello)]
        case .pairConfirm(let accepted): ["type": "pairConfirm", "accepted": accepted]
        case .welcome(let w):
            ["type": "welcome", "serverName": w.serverName, "nodeId": w.nodeID, "version": w.version,
             "maxImageBytes": w.maxImageBytes, "freeBytes": w.freeBytes, "fileSystems": w.fileSystems,
             "drives": w.drives.map(Self.driveObject)]
        case .drives(let drives): ["type": "drives", "drives": drives.map(Self.driveObject)]
        case .accepted(let job): ["type": "accepted", "job": job]
        case .job(let info): Self.jobObject(info).merging(["type": "job"]) { _, new in new }
        case .jobs(let jobs): ["type": "jobs", "jobs": jobs.map(Self.jobObject)]
        case .pairCommit(let c): ["type": "pairCommit", "commitment": SpoolHex.encode(c)]
        case .pairResult(let accepted, let node, let server):
            ["type": "pairResult", "accepted": accepted, "nodeId": node, "serverName": server]
        }
    }

    /// The message as a control frame.
    public func frame() -> SpoolFrame {
        let json = (try? JSONSerialization.data(withJSONObject: jsonObject(), options: [.sortedKeys])) ?? Data("{}".utf8)
        return SpoolFrame(header: SpoolFrameHeader(kind: .control), payload: [UInt8](json))
    }

    static func driveObject(_ d: SpoolDriveInfo) -> [String: Any] {
        var object: [String: Any] = ["id": d.id, "name": d.name, "media": d.media.rawValue, "queue": d.queue, "busy": d.busy]
        // Only what is known goes on the wire; a missing key means unknown.
        if let writes = d.writes { object["writes"] = writes.rawValue }
        if let disc = d.disc { object["disc"] = disc }
        if let free = d.freeBytes { object["freeBytes"] = free }
        return object
    }

    static func jobObject(_ j: SpoolJobInfo) -> [String: Any] {
        ["job": j.job, "drive": j.drive, "label": j.label, "state": j.state.rawValue,
         "fraction": j.fraction as Any? ?? NSNull(), "queueAhead": j.queueAhead, "message": j.message]
    }
}

// MARK: - Decode

extension SpoolControl {
    /// Reads a control frame (at most 256 KiB of JSON); nil for anything else.
    public init?(frame: SpoolFrame) {
        guard frame.header.kind == .control, frame.payload.count <= 256 * 1024,
              let object = try? JSONSerialization.jsonObject(with: Data(frame.payload)) as? [String: Any] else { return nil }
        self.init(jsonObject: object)
    }

    /// Reads a message from a JSON object; nil when the type is unknown or a field is missing or
    /// wrong.
    public init?(jsonObject o: [String: Any]) {
        guard let type = o["type"] as? String else { return nil }
        let s = { (k: String) in o[k] as? String }
        let n = { (k: String) in (o[k] as? NSNumber)?.uint64Value }
        let b = { (k: String) in o[k] as? Bool }
        let hex = { (k: String) in s(k).flatMap(SpoolHex.decode) }
        switch type {
        case "auth":
            guard let key = hex("identityKey"), key.count == 32, let sig = hex("signature"), sig.count == 64 else { return nil }
            self = .auth(identityKey: key, signature: sig)
        case "ping": guard let v = n("n") else { return nil }; self = .ping(v)
        case "pong": guard let v = n("n") else { return nil }; self = .pong(v)
        case "error":
            guard let code = s("code"), let message = s("message") else { return nil }
            self = .error(code: SpoolErrorCode(wire: code), message: message, job: s("job"))
        case "hello": guard let a = s("app"), let d = s("deviceName") else { return nil }; self = .hello(app: a, deviceName: d)
        case "listDrives": self = .listDrives
        case "listJobs": self = .listJobs
        case "submit":
            guard let job = s("job"), let drive = s("drive"), let label = s("label"), let speed = n("speed"),
                  let verify = b("verify"), let simulate = b("simulate"), let eject = b("eject") else { return nil }
            let content: SpoolUploadContent
            if o["content"] == nil {
                content = .image
            } else if let wire = s("content"), let known = SpoolUploadContent(rawValue: wire) {
                content = known
            } else {
                return nil
            }
            self = .submit(job: job, drive: drive, label: label, content: content,
                           options: SpoolBurnOptions(speed: Int(clamping: speed), verify: verify, simulate: simulate, eject: eject))
        case "watch": guard let j = s("job") else { return nil }; self = .watch(job: j)
        case "cancel": guard let j = s("job") else { return nil }; self = .cancel(job: j)
        case "eject": guard let d = s("drive") else { return nil }; self = .eject(drive: d)
        case "pairStart": guard let d = s("deviceName") else { return nil }; self = .pairStart(deviceName: d)
        case "pairHello": guard let h = hex("hello"), h.count == 80 else { return nil }; self = .pairHello(h)
        case "pairConfirm": guard let a = b("accepted") else { return nil }; self = .pairConfirm(accepted: a)
        case "welcome":
            guard let name = s("serverName"), let node = s("nodeId"), let version = s("version"),
                  let max = n("maxImageBytes"), let free = n("freeBytes"), let drives = Self.drives(o["drives"]) else { return nil }
            let fileSystems: [String]
            if o["fileSystems"] == nil {
                fileSystems = []
            } else if let list = o["fileSystems"] as? [String] {
                fileSystems = list
            } else {
                return nil
            }
            self = .welcome(SpoolServerWelcome(serverName: name, nodeID: node, version: version, maxImageBytes: max,
                                               freeBytes: free, fileSystems: fileSystems, drives: drives))
        case "drives": guard let d = Self.drives(o["drives"]) else { return nil }; self = .drives(d)
        case "accepted": guard let j = s("job") else { return nil }; self = .accepted(job: j)
        case "job": guard let j = Self.job(o) else { return nil }; self = .job(j)
        case "jobs":
            guard let list = o["jobs"] as? [[String: Any]] else { return nil }
            let jobs = list.compactMap(Self.job)
            guard jobs.count == list.count else { return nil }
            self = .jobs(jobs)
        case "pairCommit": guard let c = hex("commitment"), c.count == 32 else { return nil }; self = .pairCommit(c)
        case "pairResult":
            guard let a = b("accepted"), let node = s("nodeId"), let server = s("serverName") else { return nil }
            self = .pairResult(accepted: a, nodeID: node, serverName: server)
        default:
            return nil
        }
    }

    static func drives(_ value: Any?) -> [SpoolDriveInfo]? {
        guard let list = value as? [[String: Any]] else { return nil }
        let drives: [SpoolDriveInfo] = list.compactMap { d in
            guard let id = d["id"] as? String, let name = d["name"] as? String, let media = d["media"] as? String,
                  let queue = (d["queue"] as? NSNumber)?.intValue, let busy = d["busy"] as? Bool else { return nil }
            let writes = (d["writes"] as? NSNumber).map { SpoolNodeCapabilities(rawValue: $0.uint32Value).intersection(.writesAny) }
            let disc = (d["disc"] as? String).flatMap { $0.count <= 256 ? $0 : nil }
            let free = (d["freeBytes"] as? NSNumber)?.int64Value
            return SpoolDriveInfo(id: id, name: name, media: SpoolMediaState(wire: media), queue: queue, busy: busy,
                                  writes: writes, disc: disc, freeBytes: free)
        }
        return drives.count == list.count ? drives : nil
    }

    static func job(_ o: [String: Any]) -> SpoolJobInfo? {
        guard let job = o["job"] as? String, let drive = o["drive"] as? String, let label = o["label"] as? String,
              let state = (o["state"] as? String).flatMap(SpoolJobState.init(rawValue:)),
              let ahead = (o["queueAhead"] as? NSNumber)?.intValue, let message = o["message"] as? String else { return nil }
        let fraction = (o["fraction"] as? NSNumber)?.doubleValue.clamped01
        return SpoolJobInfo(job: job, drive: drive, label: label, state: state, fraction: fraction, queueAhead: ahead, message: message)
    }
}

// MARK: - Telemetry Frames

extension SpoolTelemetryPacket {
    /// Decodes a kind-7 telemetry frame; nil for anything else.
    public init?(frame: SpoolFrame) {
        guard frame.header.kind == .telemetry,
              let packet = try? JSONDecoder().decode(SpoolTelemetryPacket.self, from: Data(frame.payload)) else { return nil }
        self = packet
    }
}

// MARK: - Hex

/// Lowercase hex, as the control messages carry keys and signatures.
public enum SpoolHex {
    /// Lowercase hex of `data`.
    public static func encode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// The bytes of `text`; nil for odd length or a non-hex character.
    public static func decode(_ text: String) -> Data? {
        let chars = Array(text.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var out = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
            out.append(hi << 4 | lo)
            i += 2
        }
        return out
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): c - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): c - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): c - UInt8(ascii: "A") + 10
        default: nil
        }
    }
}

extension Double {
    var clamped01: Double? { isFinite ? Swift.min(1, Swift.max(0, self)) : nil }
}
