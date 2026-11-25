import Foundation

// MARK: - KRSP v1 Control Channel
//
// Control frames (kind 8) carry one UTF-8 JSON object whose "type" names the message; telemetry
// frames (kind 7) carry a `SpoolTelemetryPacket`. Field names and values mirror
// `krouton-server/crates/krsp/src/control.rs` exactly; `Vectors/krsp-control-v1.txt` pins both.

public enum SpoolJobState: String, Sendable, Equatable, CaseIterable {
    case receiving, queued, burning, verifying, done, failed, cancelled

    public var isTerminal: Bool { self == .done || self == .failed || self == .cancelled }
}

public enum SpoolMediaState: String, Sendable, Equatable {
    case unknown, noDisc, blank, appendable, complete

    public init(wire: String) { self = SpoolMediaState(rawValue: wire) ?? .unknown }
}

public enum SpoolErrorCode: String, Sendable, Equatable {
    case badRequest, notAuthenticated, unknownDrive, unknownJob, noSpace, tooLarge
    case manifestRejected, driveBusy, pairingClosed, pairingRejected, internalError = "internal"

    public init(wire: String) { self = SpoolErrorCode(rawValue: wire) ?? .internalError }
}

public struct SpoolDriveInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let media: SpoolMediaState
    /// Jobs queued or burning on this drive.
    public let queue: Int
    public let busy: Bool

    public init(id: String, name: String, media: SpoolMediaState, queue: Int, busy: Bool) {
        self.id = id
        self.name = name
        self.media = media
        self.queue = queue
        self.busy = busy
    }
}

public struct SpoolJobInfo: Sendable, Equatable, Identifiable {
    public let job: String
    public let drive: String
    public let label: String
    public let state: SpoolJobState
    /// 0…1, or nil while the server cannot tell (indeterminate).
    public let fraction: Double?
    public let queueAhead: Int
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

public struct SpoolBurnOptions: Sendable, Equatable {
    /// Write speed multiplier; 0 = the drive's maximum.
    public var speed: Int
    public var verify: Bool
    /// Laser-off test write where the server's burn tool supports it.
    public var simulate: Bool
    public var eject: Bool

    public init(speed: Int = 0, verify: Bool = true, simulate: Bool = false, eject: Bool = true) {
        self.speed = speed
        self.verify = verify
        self.simulate = simulate
        self.eject = eject
    }
}

public struct SpoolServerWelcome: Sendable, Equatable {
    public let serverName: String
    public let nodeID: String
    public let version: String
    public let maxImageBytes: UInt64
    public let freeBytes: UInt64
    public let drives: [SpoolDriveInfo]
}

// MARK: - Messages

public enum SpoolControl: Sendable, Equatable {
    case auth(identityKey: Data, signature: Data)
    case ping(UInt64)
    case pong(UInt64)
    case error(code: SpoolErrorCode, message: String, job: String?)
    case hello(app: String, deviceName: String)
    case listDrives
    case listJobs
    case submit(job: String, drive: String, label: String, options: SpoolBurnOptions)
    case watch(job: String)
    case cancel(job: String)
    case eject(drive: String)
    case pairStart(deviceName: String)
    case pairHello(Data)
    case pairConfirm(accepted: Bool)
    case welcome(SpoolServerWelcome)
    case drives([SpoolDriveInfo])
    case accepted(job: String)
    case job(SpoolJobInfo)
    case jobs([SpoolJobInfo])
    case pairCommit(Data)
    case pairResult(accepted: Bool, nodeID: String, serverName: String)

    // MARK: - Encode

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
        case .submit(let job, let drive, let label, let o):
            ["type": "submit", "job": job, "drive": drive, "label": label,
             "speed": o.speed, "verify": o.verify, "simulate": o.simulate, "eject": o.eject]
        case .watch(let job): ["type": "watch", "job": job]
        case .cancel(let job): ["type": "cancel", "job": job]
        case .eject(let drive): ["type": "eject", "drive": drive]
        case .pairStart(let device): ["type": "pairStart", "deviceName": device]
        case .pairHello(let hello): ["type": "pairHello", "hello": SpoolHex.encode(hello)]
        case .pairConfirm(let accepted): ["type": "pairConfirm", "accepted": accepted]
        case .welcome(let w):
            ["type": "welcome", "serverName": w.serverName, "nodeId": w.nodeID, "version": w.version,
             "maxImageBytes": w.maxImageBytes, "freeBytes": w.freeBytes, "drives": w.drives.map(Self.driveObject)]
        case .drives(let drives): ["type": "drives", "drives": drives.map(Self.driveObject)]
        case .accepted(let job): ["type": "accepted", "job": job]
        case .job(let info): Self.jobObject(info).merging(["type": "job"]) { _, new in new }
        case .jobs(let jobs): ["type": "jobs", "jobs": jobs.map(Self.jobObject)]
        case .pairCommit(let c): ["type": "pairCommit", "commitment": SpoolHex.encode(c)]
        case .pairResult(let accepted, let node, let server):
            ["type": "pairResult", "accepted": accepted, "nodeId": node, "serverName": server]
        }
    }

    public func frame() -> SpoolFrame {
        let json = (try? JSONSerialization.data(withJSONObject: jsonObject(), options: [.sortedKeys])) ?? Data("{}".utf8)
        return SpoolFrame(header: SpoolFrameHeader(kind: .control), payload: [UInt8](json))
    }

    static func driveObject(_ d: SpoolDriveInfo) -> [String: Any] {
        ["id": d.id, "name": d.name, "media": d.media.rawValue, "queue": d.queue, "busy": d.busy]
    }

    static func jobObject(_ j: SpoolJobInfo) -> [String: Any] {
        ["job": j.job, "drive": j.drive, "label": j.label, "state": j.state.rawValue,
         "fraction": j.fraction as Any? ?? NSNull(), "queueAhead": j.queueAhead, "message": j.message]
    }
}

// MARK: - Decode

extension SpoolControl {
    public init?(frame: SpoolFrame) {
        guard frame.header.kind == .control, frame.payload.count <= 256 * 1024,
              let object = try? JSONSerialization.jsonObject(with: Data(frame.payload)) as? [String: Any] else { return nil }
        self.init(jsonObject: object)
    }

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
            self = .submit(job: job, drive: drive, label: label,
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
            self = .welcome(SpoolServerWelcome(serverName: name, nodeID: node, version: version,
                                               maxImageBytes: max, freeBytes: free, drives: drives))
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
            return SpoolDriveInfo(id: id, name: name, media: SpoolMediaState(wire: media), queue: queue, busy: busy)
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

public enum SpoolHex {
    public static func encode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

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
