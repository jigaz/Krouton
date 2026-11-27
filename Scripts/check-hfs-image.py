#!/usr/bin/env python3
"""Reads a Krouton classic-HFS image (Apple Partition Map + HFS Standard) with nothing shared
with the Swift writer, and checks what krouton-verify Suite 38 put in it.

Usage: check-hfs-image.py classic.cdr
"""
import struct
import sys

def weight_table():
    # Apple's RelString order (Linux fs/hfs/string.c caseorder), restated here on purpose.
    rows = """
00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F
20 22 23 28 29 2A 2B 2C 2F 30 31 32 33 34 35 36 37 38 39 3A 3B 3C 3D 3E 3F 40 41 42 43 44 45 46
47 48 57 59 5D 5F 66 68 6A 6C 72 74 76 78 7A 7E 8C 8E 90 92 95 97 9E A0 A2 A4 A7 A9 AA AB AC AD
4E 48 57 59 5D 5F 66 68 6A 6C 72 74 76 78 7A 7E 8C 8E 90 92 95 97 9E A0 A2 A4 A7 AF B0 B1 B2 B3
4A 4C 5A 60 7B 7F 98 4F 49 51 4A 4B 4C 5A 60 63 64 65 6E 6F 70 71 7B 84 85 86 7F 80 9A 9B 9C 98
B4 B5 B6 B7 B8 B9 BA 94 BB BC BD BE BF C0 4D 81 C1 C2 C3 C4 C5 C6 C7 C8 C9 CA CB 55 8A CC 4D 81
CD CE CF D0 D1 D2 D3 26 27 D4 20 49 4B 80 82 82 D5 D6 24 25 2D 2E D7 D8 A6 D9 DA DB DC DD DE DF
E0 E1 E2 E3 E4 E5 E6 E7 E8 E9 EA EB EC ED EE EF F0 F1 F2 F3 F4 F5 F6 F7 F8 F9 FA FB FC FD FE FF
"""
    table = [int(x, 16) for x in rows.split()]
    assert len(table) == 256
    return table


W = weight_table()


def key_order(parent, name):
    return (parent, [W[b] for b in name], len(name))


def fail(message):
    print(f"FAIL: {message}")
    sys.exit(1)


def main(path):
    img = open(path, "rb").read()
    if img[0:2] != b"ER":
        fail("no driver descriptor")
    entries = struct.unpack(">I", img[512 + 4:512 + 8])[0]
    hfs = None
    for i in range(entries):
        e = img[512 * (1 + i):512 * (2 + i)]
        if e[0:2] != b"PM":
            fail(f"partition entry {i} has no PM signature")
        if e[48:57] == b"Apple_HFS":
            hfs = struct.unpack(">I", e[8:12])[0] * 512
    if hfs is None:
        fail("no Apple_HFS partition")
    mdb = img[hfs + 1024:hfs + 1536]
    if mdb[0:2] != b"BD":
        fail("no HFS signature")
    (nmalblks,) = struct.unpack(">H", mdb[18:20])
    (alblksiz,) = struct.unpack(">I", mdb[20:24])
    (albst,) = struct.unpack(">H", mdb[28:30])
    vname = mdb[37:37 + mdb[36]]
    filcnt, dircnt = struct.unpack(">II", mdb[84:92])
    ct_size = struct.unpack(">I", mdb[146:150])[0]
    ct_start, ct_count = struct.unpack(">HH", mdb[150:154])

    def block(n):
        return hfs + albst * 512 + n * alblksiz

    if ct_size != ct_count * alblksiz:
        fail("catalog size and extent disagree")
    catalog = img[block(ct_start):block(ct_start) + ct_size]
    header = catalog[0:512]
    if header[8] != 1:
        fail("catalog node 0 is not a header node")
    depth, root, nrecs, first, last, nodesize, keylen = struct.unpack(">HIIIIHH", header[14:36])
    if nodesize != 512 or keylen != 37:
        fail("catalog node size or key length wrong")
    # Walk the leaves left to right.
    records, keys, node = [], [], first
    while node:
        n = catalog[node * 512:(node + 1) * 512]
        if n[8] != 0xFF:
            fail(f"node {node} in the leaf chain is not a leaf")
        count = struct.unpack(">H", n[10:12])[0]
        for i in range(count):
            off = struct.unpack(">H", n[512 - 2 * (i + 1):512 - 2 * i])[0]
            klen = n[off]
            parent = struct.unpack(">I", n[off + 2:off + 6])[0]
            name = n[off + 7:off + 7 + n[off + 6]]
            data_at = off + 1 + klen
            data_at += data_at % 2
            records.append((parent, name, n[data_at:data_at + 102]))
            keys.append(key_order(parent, name))
        node = struct.unpack(">I", n[0:4])[0]
    if len(records) != nrecs:
        fail(f"header says {nrecs} records, leaves hold {len(records)}")
    if keys != sorted(keys):
        fail("catalog records are not in RelString order")
    # Rebuild paths.
    dirs = {1: ("", 0)}
    for parent, name, data in records:
        if data[0] == 1:
            dirs[struct.unpack(">I", data[6:10])[0]] = (name.decode("mac_roman"), parent)

    def path_of(cnid):
        parts = []
        while cnid in dirs and cnid != 1:
            name, cnid = dirs[cnid]
            parts.append(name)
        return "/".join(reversed(parts[:-1]))

    files = {}
    for parent, name, data in records:
        if data[0] == 2:
            full = (path_of(parent) + "/" if path_of(parent) else "") + name.decode("mac_roman")
            ftype, creator = data[4:8], data[8:12]
            dst, dlen = struct.unpack(">HI", data[24:30])
            rst, rlen = struct.unpack(">HI", data[34:40])
            fork = img[block(dst):block(dst) + dlen] if dlen else b""
            rfork = img[block(rst):block(rst) + rlen] if rlen else b""
            files[full] = (ftype, creator, fork, rfork)
    print("volume:", vname.decode("mac_roman"), "| files:", sorted(files))
    expect = {
        "Read Me": (None, None, b"Read me first\r", b""),
        "SimpleText": (b"APPL", b"ttxt", b"", bytes((i * 7) & 0xFF for i in range(5000))),
        "Banana": (None, None, b"b", b""),
        "System Folder/Extensions/apple Ext": (None, None, b"\x42" * 70000, b""),
    }
    for name, (ftype, creator, fork, rfork) in expect.items():
        if name not in files:
            fail(f"{name} is missing")
        got = files[name]
        if ftype and (got[0], got[1]) != (ftype, creator):
            fail(f"{name}: type/creator {got[0]}/{got[1]}")
        if got[2] != fork or got[3] != rfork:
            fail(f"{name}: forks differ")
    longs = [f for f in files if f.startswith("A name much")]
    if len(longs) != 1 or len(longs[0].encode("mac_roman")) != 31:
        fail("the long name wasn't cut to 31 characters")
    if vname != b"Krouton Classic" or filcnt != 7 or dircnt != 2:
        fail(f"MDB counts: {vname} {filcnt} files {dircnt} folders")
    if nmalblks * alblksiz < len(catalog):
        fail("allocation blocks don't cover the catalog")
    print("HFS image OK")


if __name__ == "__main__":
    main(sys.argv[1])
