import Foundation
import OpticalCore

// MARK: - VerifyHarness — Suite 32: Direct Drive Commands (MMC)

/// A drive that answers from a script: opcode -> reply bytes or a failure.
struct ScriptedMMCDrive: MMCTransport {
    let replies: [UInt8: Result<[UInt8], MMCTransportError>]

    func execute(_ command: MMCCommand) async throws(MMCTransportError) -> [UInt8] {
        guard let reply = replies[command.operationCode] else { throw .unavailable("not scripted") }
        return try reply.get()
    }
}

extension KroutonTestHarness {
    mutating func runVerifyDirectDriveSuite() {
        self.runSuite("32. Direct Drive Commands: MMC Blocks, Replies and Sense Without DiscRecording") { h in
            h.check(MMCCommand.inquiry(allocation: 96).cdb == [0x12, 0, 0, 0, 96, 0], "INQUIRY is a 6-byte CDB with the allocation in bytes 3-4")
            h.check(MMCCommand.getConfiguration(startingFeature: 0x0000, allocation: 2048).cdb == [0x46, 0, 0, 0, 0, 0, 0, 0x08, 0x00, 0],
                    "GET CONFIGURATION asks for all features (RT 0) with a 16-bit allocation in bytes 7-8")
            h.check(MMCCommand.readDiscInformation(allocation: 34).cdb == [0x51, 0, 0, 0, 0, 0, 0, 0, 34, 0],
                    "READ DISC INFORMATION is a 10-byte CDB")
            h.check(MMCCommand.testUnitReady.allocationLength == 0 && MMCCommand.requestSense(allocation: 18).cdb[4] == 18,
                    "TEST UNIT READY moves no data; REQUEST SENSE puts its length in byte 4")

            let inquiry = MMCInquiry(Self.inquiryFixture)
            h.check(inquiry?.isMultimediaDevice == true && inquiry?.vendor == "PIONEER"
                    && inquiry?.product == "BD-RW   BDR-XD08" && inquiry?.revision == "1.02",
                    "INQUIRY yields the device type, vendor, product and firmware, trimmed")
            h.check(MMCInquiry(Array(Self.inquiryFixture.prefix(20))) == nil, "A short INQUIRY reply is rejected")

            let configuration = MMCConfiguration(Self.configurationFixture)
            h.check(configuration?.currentProfile.name == "DVD+R", "The current profile is the loaded disc (DVD+R)")
            h.check(configuration?.supportedProfiles.map(\.number) == [0x0009, 0x001B, 0x0041, 0x0008]
                    && configuration?.featureCodes == [0x0000, 0x0001] && configuration?.canWrite == true,
                    "The Profile List feature lists every supported profile; other features are walked past")
            let truncated = MMCConfiguration(Array(Self.configurationFixture.prefix(20)))
            h.check(truncated?.supportedProfiles.isEmpty == true, "A feature cut short by the transfer length is skipped, not over-read")

            let blank = MMCDiscInformation(Self.discInformation(byte2: 0x00))
            h.check(blank?.status == .blank && blank?.erasable == false && blank?.sessions == 1, "A blank write-once disc")
            let closed = MMCDiscInformation(Self.discInformation(byte2: 0x1E))
            h.check(closed?.status == .finalized && closed?.erasable == true && closed?.lastSessionState == 3,
                    "A finalized rewritable disc with a complete last session")

            let sense = MMCSense([0x70, 0, 0x03, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0x0C, 0x00, 0, 0, 0, 0])
            h.check(sense?.description == "3/0C/00" && sense?.meaning == "Write error", "Fixed-format sense reads as 3/0C/00, a write error")
            h.check(MMCSense([0x72] + [UInt8](repeating: 0, count: 17)) == nil, "Descriptor-format sense is not mistaken for fixed format")

            let drive = ScriptedMMCDrive(replies: [
                0x12: .success(Self.inquiryFixture),
                0x46: .failure(.checkCondition(MMCSense([0x70, 0, 0x05, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0x20, 0x00, 0, 0, 0, 0]))),
                0x51: .success(Self.discInformation(byte2: 0x00)),
            ])
            let report = Self.blocking { try? await MMCDriveReport.read(from: drive) }
            h.check(report?.inquiry.vendor == "PIONEER" && report?.configuration == nil && report?.disc?.status == .blank,
                    "A drive that rejects GET CONFIGURATION still reports who it is and what disc is loaded")
            let silent = ScriptedMMCDrive(replies: [0x12: .failure(.unavailable("gone"))])
            let failed = Self.blocking { (try? await MMCDriveReport.read(from: silent)) == nil }
            h.check(failed, "No report without an INQUIRY reply")
        }
    }

    static var inquiryFixture: [UInt8] {
        var data = [UInt8](repeating: 0, count: 36)
        data[0] = 0x05
        data[4] = 31
        data.replaceSubrange(8..<16, with: Array("PIONEER ".utf8))
        data.replaceSubrange(16..<32, with: Array("BD-RW   BDR-XD08".utf8))
        data.replaceSubrange(32..<36, with: Array("1.02".utf8))
        return data
    }

    /// Header (current profile DVD+R), Profile List (CD-R, DVD+R current, BD-R SRM, CD-ROM), Core.
    static var configurationFixture: [UInt8] {
        let profiles: [UInt8] = [0x00, 0x09, 0x00, 0x00, 0x00, 0x1B, 0x01, 0x00, 0x00, 0x41, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00]
        let body: [UInt8] = [0x00, 0x00, 0x03, UInt8(profiles.count)] + profiles + [0x00, 0x01, 0x0B, 0x08] + [UInt8](repeating: 0, count: 8)
        let length = UInt32(4 + body.count) // bytes after the length field
        return [UInt8(length >> 24), UInt8((length >> 16) & 0xFF), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF), 0, 0, 0x00, 0x1B] + body
    }

    static func discInformation(byte2: UInt8) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: 34)
        data[1] = 0x20
        data[2] = byte2
        data[3] = 1
        data[4] = 1
        data[5] = 1
        data[6] = 1
        return data
    }
}
