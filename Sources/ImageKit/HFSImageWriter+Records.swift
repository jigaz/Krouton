import Foundation
import OpticalCore

// MARK: - Catalog Records

extension KroutonHFSImageWriter {
    /// Every catalog record, in catalog order: for each folder its record (under its parent)
    /// and its thread (under itself, with an empty name); for each file its record.
    static func catalogRecords(_ items: [Item], stamp: UInt32, blockSize: UInt64) -> [KroutonHFSBTree.Record] {
        var records: [KroutonHFSBTree.Record] = []
        for item in items {
            let parentID: UInt32 = item.cnid == 2 ? 1 : items[item.parent].cnid
            if item.isDir {
                records.append(.init(parent: parentID, name: item.name, data: directoryRecord(item, stamp: stamp)))
                records.append(.init(parent: item.cnid, name: [], data: threadRecord(type: 3, parent: parentID, name: item.name)))
            } else {
                records.append(.init(parent: parentID, name: item.name, data: fileRecord(item, blockSize: blockSize)))
            }
        }
        return records.sorted { KroutonHFSOrder.precedes(($0.parent, $0.name), ($1.parent, $1.name)) }
    }

    /// cdrDirRec, 70 bytes.
    static func directoryRecord(_ item: Item, stamp: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 70)
        d[0] = 1
        d.replaceSubrange(4..<6, with: KroutonBytes.be16(UInt16(min(item.children.count, 65_535))))
        d.replaceSubrange(6..<10, with: KroutonBytes.be32(item.cnid))
        let created = item.cnid == 2 ? stamp : item.modified
        d.replaceSubrange(10..<14, with: KroutonBytes.be32(created))
        d.replaceSubrange(14..<18, with: KroutonBytes.be32(item.modified))
        // DInfo (16) and DXInfo (16) from the folder's Finder info.
        d.replaceSubrange(22..<54, with: item.finderInfo)
        return d
    }

    /// cdrFilRec, 102 bytes: one extent per fork, as the forks are contiguous.
    static func fileRecord(_ item: Item, blockSize: UInt64) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 102)
        d[0] = 2
        d[2] = 0x80 // record in use
        d.replaceSubrange(4..<20, with: item.finderInfo[0..<16])
        d.replaceSubrange(20..<24, with: KroutonBytes.be32(item.cnid))
        let dataPhysical = roundUp(item.dataLength, blockSize)
        let resourceLength = UInt64(item.resource.count)
        let resourcePhysical = roundUp(resourceLength, blockSize)
        d.replaceSubrange(24..<26, with: KroutonBytes.be16(UInt16(item.dataStart)))
        d.replaceSubrange(26..<30, with: KroutonBytes.be32(UInt32(item.dataLength)))
        d.replaceSubrange(30..<34, with: KroutonBytes.be32(UInt32(dataPhysical)))
        d.replaceSubrange(34..<36, with: KroutonBytes.be16(UInt16(item.resourceStart)))
        d.replaceSubrange(36..<40, with: KroutonBytes.be32(UInt32(resourceLength)))
        d.replaceSubrange(40..<44, with: KroutonBytes.be32(UInt32(resourcePhysical)))
        d.replaceSubrange(44..<48, with: KroutonBytes.be32(item.modified))
        d.replaceSubrange(48..<52, with: KroutonBytes.be32(item.modified))
        d.replaceSubrange(56..<72, with: item.finderInfo[16..<32])
        if dataPhysical > 0 {
            d.replaceSubrange(74..<76, with: KroutonBytes.be16(UInt16(item.dataStart)))
            d.replaceSubrange(76..<78, with: KroutonBytes.be16(UInt16(dataPhysical / blockSize)))
        }
        if resourcePhysical > 0 {
            d.replaceSubrange(86..<88, with: KroutonBytes.be16(UInt16(item.resourceStart)))
            d.replaceSubrange(88..<90, with: KroutonBytes.be16(UInt16(resourcePhysical / blockSize)))
        }
        return d
    }

    /// cdrThdRec, 46 bytes.
    static func threadRecord(type: UInt8, parent: UInt32, name: [UInt8]) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 46)
        d[0] = type
        d.replaceSubrange(10..<14, with: KroutonBytes.be32(parent))
        d[14] = UInt8(name.count)
        d.replaceSubrange(15..<15 + name.count, with: name)
        return d
    }

    // MARK: - Volume Header and Partition Map

    static func masterDirectoryBlock(_ items: [Item], stamp: UInt32, blockSize: UInt64, totalBlocks: UInt16,
                                     freeBlocks: UInt16, firstBlockSector: UInt16,
                                     extentsBlocks: UInt16, catalogBlocks: UInt16) -> [UInt8] {
        var m = [UInt8](repeating: 0, count: 512)
        func put(_ at: Int, _ bytes: [UInt8]) { m.replaceSubrange(at..<at + bytes.count, with: bytes) }
        let root = items[0]
        let rootFiles = root.children.filter { !items[$0].isDir }.count
        put(0, KroutonBytes.be16(0x4244))
        put(2, KroutonBytes.be32(stamp)); put(6, KroutonBytes.be32(stamp))
        put(10, KroutonBytes.be16(0x8100))            // written cleanly, locked (a CD is read-only)
        put(12, KroutonBytes.be16(UInt16(rootFiles)))
        put(14, KroutonBytes.be16(3))                 // volume bitmap from sector 3
        put(16, KroutonBytes.be16(totalBlocks - freeBlocks))
        put(18, KroutonBytes.be16(totalBlocks))
        put(20, KroutonBytes.be32(UInt32(blockSize)))
        put(24, KroutonBytes.be32(UInt32(blockSize * 4)))
        put(28, KroutonBytes.be16(firstBlockSector))
        put(30, KroutonBytes.be32(firstCNID + UInt32(items.count - 1)))
        put(34, KroutonBytes.be16(freeBlocks))
        put(36, [UInt8(root.name.count)] + root.name)
        put(74, KroutonBytes.be32(UInt32(extentsBlocks) * UInt32(blockSize)))
        put(78, KroutonBytes.be32(UInt32(catalogBlocks) * UInt32(blockSize)))
        put(82, KroutonBytes.be16(UInt16(root.children.count - rootFiles)))
        put(84, KroutonBytes.be32(UInt32(items.filter { !$0.isDir }.count)))
        put(88, KroutonBytes.be32(UInt32(items.filter(\.isDir).count - 1)))
        put(130, KroutonBytes.be32(UInt32(extentsBlocks) * UInt32(blockSize)))
        put(134, KroutonBytes.be16(0) + KroutonBytes.be16(extentsBlocks))
        put(146, KroutonBytes.be32(UInt32(catalogBlocks) * UInt32(blockSize)))
        put(150, KroutonBytes.be16(extentsBlocks) + KroutonBytes.be16(catalogBlocks))
        return m
    }

    /// Block 0: the driver descriptor ("ER"), 512-byte blocks, no drivers.
    static func driverDescriptor(totalBlocks: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        d.replaceSubrange(0..<2, with: KroutonBytes.be16(0x4552))
        d.replaceSubrange(2..<4, with: KroutonBytes.be16(512))
        d.replaceSubrange(4..<8, with: KroutonBytes.be32(totalBlocks))
        return d
    }

    /// One partition map entry ("PM").
    static func mapEntry(count: UInt32, start: UInt32, length: UInt32, name: String, type: String, status: UInt32) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        func put(_ at: Int, _ bytes: [UInt8]) { d.replaceSubrange(at..<at + bytes.count, with: bytes) }
        put(0, KroutonBytes.be16(0x504D))
        put(4, KroutonBytes.be32(count))
        put(8, KroutonBytes.be32(start))
        put(12, KroutonBytes.be32(length))
        put(16, Array(name.utf8.prefix(31)))
        put(48, Array(type.utf8.prefix(31)))
        put(80, KroutonBytes.be32(0))
        put(84, KroutonBytes.be32(length))
        put(88, KroutonBytes.be32(status))
        return d
    }
}
