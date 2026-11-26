# Data discs and disc images

## Choosing a file system

Pick a data format in the Format Chooser, under **Data & Archival Media**, or from the **Format** menu.

- **Hybrid ISO-9660 + Joliet + UDF** (⌃⌘1) is the right choice almost every time. Windows, macOS, Linux and most DVD and Blu-ray players can read it. Long file names and Unicode survive through Joliet and UDF.
- **UDF 2.50 Large-File Volume** is for files of 4 GiB or more, which ISO-9660 can't hold. Krouton writes the files as a UDF 2.50 disc of its own, with no ISO-9660 side: macOS, Windows 10 and later and Linux read it, older systems and most players don't.
- **M-DISC 1,000-Year Archival Vault** (⌃⌘5) is a hybrid disc meant for M-DISC blanks. With **PAR2** above Off, Krouton adds recovery files (KROUTON_RECOVERY.par2 and its volume) holding that percentage of the data, so damaged files can be rebuilt from the disc itself with `par2 repair`. This needs par2, which you install separately (Homebrew: brew install par2).
- **Burn Disc Image** (⌃⌘6) writes an existing .iso, .cue/.bin or .dmg exactly as it is.

Older formats are there for old machines. **DOS 8.3** writes ISO 9660 Level 1, with 8.3 upper-case names, for DOS and Windows 3.1; it burns on a drive connected to this Mac only. **Mac OS 9 (HFS)** writes a classic HFS disc inside an Apple Partition Map, the way Mac CDs were made for System 7 to Mac OS 9, and keeps what a classic Mac needs: each file's resource fork and its Finder type and creator, so programs run and documents open with the right application. Names are shortened to 31 characters. A folder holding a System file and a Finder is blessed and its boot blocks are written, which New World Macs (Mac OS 8.5–9.2) need to start up from the disc; older Macs also need CD driver partitions, which Krouton doesn't write. macOS 10.15 and later can't read HFS discs at all.

## Which computers see which files

Each staged item has **Mac** and **PC** visibility pills. Turn one off to hide that item from that kind of computer, for example a Windows installer that Mac users don't need.

**Customize Finder Layout** sets how the disc looks when a Mac opens it: icon or list view, icon positions, icon size and a background picture. It is written into disc images and Krouton Server burns, not yet into discs burned on a drive connected to this Mac.

## Files that don't fit on one disc

When the staged files are larger than the disc size chosen at the top of the deck, Krouton plans a set. It packs the biggest files first so the set uses as few discs as possible, and the capacity bar shows one segment per disc. To decide yourself where a disc ends, right-click an item and choose **Insert Disc Break**. Krouton then keeps your order.

Every disc in a set is laid out as a BagIt bag (RFC 8493): your files sit under data/, next to:

- bagit.txt and bag-info.txt, which describe the bag;
- manifest-sha256.txt, a SHA-256 checksum for every file on that disc;
- krouton-set-index.json, which lists every disc in the set and the files on each.

So any single disc can be checked on its own with standard BagIt tools, years from now, without Krouton, and the index tells you which disc to fetch for a given file.

A file larger than the chosen disc can't be split. Pick a bigger disc size, such as a Blu-ray.

## Burning a disc image

Drop an .iso, .cdr, .dmg, .cue/.bin or .toc on the deck, or choose **Burn Disc Image**. A .cue file must sit next to the .bin files it names. When the deck holds a single disc image, Krouton writes the image sector for sector, including its boot catalog, so a bootable installer stays bootable. It doesn't wrap the image in a new file system.

Krouton refuses images it can't burn faithfully, such as .cdi, .gdi, .wbfs, .rvz and .chd, and says why, instead of copying the file onto a data disc.

**Disc › Leave Disc Open for More Sessions** burns without closing the disc, so more sessions can be added later. Some live CDs, such as Puppy Linux, use this to save your changes back to the same CD-R or DVD±R. Most players and older drives read only closed discs, so leave it off otherwise.

## The Disc Image Depot

The Depot (⌘2) lists discs you can download and burn, grouped as **The Shelf** (operating systems and live CDs from the years when a CD-ROM was the exciting way to try something), **Strange and Wonderful** (odd and tiny systems, including live CDs that write back to their own disc), **Fix-It Discs** (repair, backup, partitioning and memory-testing tools) and **Console Homebrew** (open-source tools such as CleanRip and USB Loader GX for the Wii, Swiss for the GameCube and Open PS2 Loader).

The list comes from depot.krouton.app and is refreshed when Krouton starts; the last copy is kept so the Depot works offline. Each entry is checked every month: the download is fetched, its SHA-256 recorded, and the image inside checked for a valid header. Entries whose source stopped working are dropped until they're fixed. When you choose one, Krouton downloads it, checks it against that SHA-256, unpacks the image if it came in a .zip or .7z, and puts it on the deck ready to burn, with the blank it needs. Entries the Depot can't fetch for you open their own download page instead. You can point Krouton at another feed in Settings.

The Depot holds free software only: no commercial games or operating systems.

You can also open any disc image you already have. Select an image to see:

- whether it can boot (El Torito for PCs, Apple Partition Map for Macs) and which file systems it holds;
- the **LBA Sector Map**: where each structure sits on the disc, in 2048-byte sectors;
- the **Sector Hex Inspector**, for looking at the raw bytes of any sector;
- its SHA-256 checksum, to compare with the one a download page publishes.

The search field can also search the Internet Archive for CD and DVD images and add the results to the Depot.

**View › Inspect Hybrid ISO/UDF LBA Layout** (⌃⌘L) shows the same map for the disc you are building now, before you burn it.

## Making an image instead of a disc

Add a **Disc Image File** destination (⇧⌘D, then choose the kind) to save the disc as an .iso instead of burning it. You can burn the image later, here or on another machine, or keep it as an archive copy.
