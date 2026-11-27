import Foundation
import IOKit
import IOKit.scsi
import OpticalCore

// MARK: - Direct Drive Access (prototype, read-only)

/// Talks MMC straight to a CD/DVD/BD burner through IOKit's authoring-device interface
/// (`SCSITaskLib`), without DiscRecording. This is the path Krouton keeps if Apple retires its
/// burning frameworks: the same kernel family serves every USB and SCSI storage device.
///
/// The prototype only reads (INQUIRY, GET CONFIGURATION, READ DISC INFORMATION). Commands are
/// built and parsed by OpticalCore's `MMCCommand` family, so the burning sequence can be added and
/// tested against a scripted drive before it ever touches a real one.
public enum KroutonMMCDirectAccess {
    /// A burner the system lists as an authoring device.
    public struct Drive: Sendable, Equatable, Identifiable {
        public let id: UInt64
        public let vendor: String
        public let product: String
        public let revision: String
    }

    /// Every authoring device, with the identity the kernel already read (no I/O to the drive).
    public static func authoringDrives() -> [Drive] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, authoringMatch(), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var drives: [Drive] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &entryID)
            let traits = characteristics(of: service)
            drives.append(Drive(id: entryID,
                                vendor: traits["Vendor Name"] as? String ?? "",
                                product: traits["Product Name"] as? String ?? "Optical drive",
                                revision: traits["Product Revision Level"] as? String ?? ""))
        }
        return drives
    }

    /// Lines for a drive report (Report a drive, burn logs): identity, MMCProfile support and the
    /// MMCDiscInformation of the loaded disc, from an MMCInquiry and an MMCConfiguration.
    public static func describe(_ report: MMCDriveReport) -> [String] {
        let who: MMCInquiry = report.inquiry
        var lines = ["\(who.vendor) \(who.product) (firmware \(who.revision))"]
        if let configuration: MMCConfiguration = report.configuration {
            let writable: [MMCProfile] = configuration.supportedProfiles.filter(\.isWritable)
            lines.append("Writes: " + (writable.isEmpty ? "nothing (a reader)" : writable.map(\.name).joined(separator: ", ")))
            lines.append("Loaded: \(configuration.currentProfile.name)")
        }
        if let disc: MMCDiscInformation = report.disc {
            lines.append("Disc: \(disc.status), \(disc.sessions) session(s), \(disc.erasable ? "erasable" : "write-once")")
        }
        return lines
    }

    static func authoringMatch() -> CFDictionary {
        ["IOPropertyMatch": ["SCSITaskDeviceCategory": "SCSITaskAuthoringDevice"]] as CFDictionary
    }

    static func characteristics(of service: io_object_t) -> [String: Any] {
        let key = "Device Characteristics" as CFString
        for options in [IOOptionBits(kIORegistryIterateRecursively),
                        IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)] {
            if let found = IORegistryEntrySearchCFProperty(service, kIOServicePlane, key, kCFAllocatorDefault, options)
                as? [String: Any] {
                return found
            }
        }
        return [:]
    }
}

// MARK: - Session

/// One drive held with exclusive access. Each command is its own SCSI task, released at once.
/// IOKit's calls here are synchronous; the actor keeps them off every other thread's way.
public actor KroutonMMCDeviceSession: MMCTransport {
    // Interface addresses, kept as integers so `deinit` (nonisolated) may release them.
    private var pluginAddress: UInt = 0
    private var mmcAddress: UInt = 0
    private var deviceAddress: UInt = 0
    private var exclusive = false

    private var device: UnsafeMutablePointer<UnsafeMutablePointer<SCSITaskDeviceInterface>?>? {
        UnsafeMutablePointer(bitPattern: deviceAddress)
    }

    public init(registryID: UInt64) throws(MMCTransportError) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(registryID))
        guard service != 0 else { throw .unavailable("The drive is no longer connected") }
        defer { IOObjectRelease(service) }

        var pluginRef: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        let created = IOCreatePlugInInterfaceForService(service, Self.mmcUserClientType, Self.plugInInterface, &pluginRef, &score)
        guard created == KERN_SUCCESS, let pluginRef else {
            throw .unavailable(String(format: "IOKit has no MMC interface for this drive (0x%08X)", created))
        }
        pluginAddress = UInt(bitPattern: pluginRef)

        var mmcRaw: LPVOID?
        let queried = pluginRef.pointee?.pointee.QueryInterface?(pluginRef, CFUUIDGetUUIDBytes(Self.mmcInterface), &mmcRaw)
        guard queried == 0, let mmcRaw else { throw .unavailable("The drive's MMC interface could not be opened") }
        let mmcRef = mmcRaw.assumingMemoryBound(to: UnsafeMutablePointer<MMCDeviceInterface>?.self)
        mmcAddress = UInt(bitPattern: mmcRef)

        guard let deviceRef = mmcRef.pointee?.pointee.GetSCSITaskDeviceInterface?(mmcRef) else {
            throw .unavailable("The drive's SCSI task interface could not be opened")
        }
        deviceAddress = UInt(bitPattern: deviceRef)
        guard deviceRef.pointee?.pointee.ObtainExclusiveAccess?(deviceRef) == KERN_SUCCESS else {
            throw .unavailable("The drive is in use. Eject or unmount its disc, quit other burning apps, and try again.")
        }
        exclusive = true
    }

    public func execute(_ command: MMCCommand) async throws(MMCTransportError) -> [UInt8] {
        guard let device, let task = device.pointee?.pointee.CreateSCSITask?(device) else {
            throw .unavailable("The drive session is closed")
        }
        defer { _ = task.pointee?.pointee.Release?(task) }

        var cdb = command.cdb
        var buffer = [UInt8](repeating: 0, count: max(1, command.allocationLength))
        var sense = SCSI_Sense_Data()
        var transferred: UInt64 = 0
        let statusSize = MemoryLayout<SCSITaskStatus>.size
        let statusRaw = UnsafeMutableRawPointer.allocate(byteCount: statusSize, alignment: MemoryLayout<SCSITaskStatus>.alignment)
        statusRaw.initializeMemory(as: UInt8.self, repeating: 0, count: statusSize)
        defer { statusRaw.deallocate() }
        let status = statusRaw.bindMemory(to: SCSITaskStatus.self, capacity: 1)

        let result: IOReturn = buffer.withUnsafeMutableBytes { bytes in
            guard let functions = task.pointee?.pointee else { return Self.ioReturnError }
            _ = functions.SetCommandDescriptorBlock?(task, &cdb, UInt8(cdb.count))
            _ = functions.SetTimeoutDuration?(task, 30_000)
            if command.allocationLength > 0 {
                var element = SCSITaskSGElement(address: .init(UInt(bitPattern: bytes.baseAddress)), length: .init(bytes.count))
                _ = functions.SetScatterGatherEntries?(task, &element, 1, UInt64(bytes.count), Self.fromTargetToInitiator)
            }
            return functions.ExecuteTaskSync?(task, &sense, status, &transferred) ?? Self.ioReturnError
        }
        guard result == KERN_SUCCESS else {
            throw .unavailable(String(format: "The command 0x%02X could not be sent (0x%08X)", command.operationCode, result))
        }
        // 0x00 GOOD; anything else (0x02 CHECK CONDITION) carries sense data.
        guard statusRaw.load(as: UInt8.self) == 0x00 else {
            throw .checkCondition(MMCSense(withUnsafeBytes(of: sense) { Array($0) }))
        }
        return Array(buffer.prefix(Int(min(transferred, UInt64(buffer.count)))))
    }

    /// Gives the drive back to the system (which remounts a disc it had to let go of).
    public func close() {
        Self.release(plugin: pluginAddress, mmc: mmcAddress, device: deviceAddress, exclusive: exclusive)
        (pluginAddress, mmcAddress, deviceAddress, exclusive) = (0, 0, 0, false)
    }

    deinit {
        Self.release(plugin: pluginAddress, mmc: mmcAddress, device: deviceAddress, exclusive: exclusive)
    }

    private static func release(plugin pluginAddress: UInt, mmc mmcAddress: UInt, device deviceAddress: UInt, exclusive: Bool) {
        let device = UnsafeMutablePointer<UnsafeMutablePointer<SCSITaskDeviceInterface>?>(bitPattern: deviceAddress)
        let mmc = UnsafeMutablePointer<UnsafeMutablePointer<MMCDeviceInterface>?>(bitPattern: mmcAddress)
        let plugin = UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>(bitPattern: pluginAddress)
        if let device {
            if exclusive { _ = device.pointee?.pointee.ReleaseExclusiveAccess?(device) }
            _ = device.pointee?.pointee.Release?(device)
        }
        if let mmc { _ = mmc.pointee?.pointee.Release?(mmc) }
        if let plugin { IODestroyPlugInInterface(plugin) }
    }

    // MARK: - SCSITaskLib constants (function-like macros, so Swift cannot import them)

    static let fromTargetToInitiator: UInt8 = 2 // kSCSIDataTransfer_FromTargetToInitiator
    static let ioReturnError = IOReturn(bitPattern: 0xE000_02BC) // kIOReturnError
    static var mmcUserClientType: CFUUID {
        CFUUIDGetConstantUUIDWithBytes(nil, 0x97, 0xAB, 0xCF, 0x2C, 0x23, 0xCC, 0x11, 0xD5,
                                       0xA0, 0xE8, 0x00, 0x30, 0x65, 0x70, 0x48, 0x66)
    }
    static var mmcInterface: CFUUID {
        CFUUIDGetConstantUUIDWithBytes(nil, 0x1F, 0x65, 0x11, 0x06, 0x23, 0xCC, 0x11, 0xD5,
                                       0xBB, 0xDB, 0x00, 0x30, 0x65, 0x70, 0x48, 0x66)
    }
    static var plugInInterface: CFUUID {
        CFUUIDGetConstantUUIDWithBytes(nil, 0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
                                       0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)
    }
}
