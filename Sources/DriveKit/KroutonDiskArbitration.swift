import DiskArbitration
import Foundation
import OpticalCore

// MARK: - Disk Arbitration

/// Lets go of a mounted disc so Krouton can talk to the drive directly. macOS won't grant
/// exclusive access to a drive whose disc is mounted.
public enum KroutonDiskArbitration {
    private final class Reply: Sendable {
        let continuation: CheckedContinuation<String?, Never>
        init(_ continuation: CheckedContinuation<String?, Never>) { self.continuation = continuation }
    }

    /// Unmounts every volume on the whole disc named `bsdName` (for example `disk4`).
    public static func unmount(bsdName: String) async throws(MMCTransportError) {
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            throw .unavailable("Disk Arbitration is not available")
        }
        let queue = DispatchQueue(label: "app.krouton.diskarbitration")
        DASessionSetDispatchQueue(session, queue)
        defer { DASessionSetDispatchQueue(session, nil) }
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) else {
            throw .unavailable("The disc \(bsdName) is no longer there")
        }
        let refusal: String? = await withCheckedContinuation { continuation in
            let context = Unmanaged.passRetained(Reply(continuation)).toOpaque()
            DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionWhole), { _, dissenter, context in
                guard let context else { return }
                let reply = Unmanaged<Reply>.fromOpaque(context).takeRetainedValue()
                if let dissenter {
                    let message = DADissenterGetStatusString(dissenter) as String?
                    reply.continuation.resume(returning: message ?? String(format: "status 0x%08X", DADissenterGetStatus(dissenter)))
                } else {
                    reply.continuation.resume(returning: nil)
                }
            }, context)
        }
        if let refusal {
            throw .unavailable("macOS wouldn't let go of the disc (\(refusal)). Close any windows or apps using it and try again.")
        }
    }
}
