# Data discs and disc images

## Choosing a file system

Pick a data format in the Format Chooser, under **Data & Archival Media**, or from the **Format** menu.

- **Hybrid ISO-9660 + Joliet + UDF** (⌃⌘1) is the right choice almost every time. Windows, macOS, Linux and most DVD and Blu-ray players can read it. Long file names and Unicode survive through Joliet and UDF.
- **UDF 2.60 Optical Volume** is for files of 4 GiB or more, which ISO-9660 can't hold. Modern Windows, macOS and Linux read it; old systems and many players don't.
- **M-DISC 1,000-Year Archival Vault** (⌃⌘5) is a hybrid disc meant for M-DISC blanks, with optional PAR2 parity files so a scratched disc can still be repaired. Set the share of parity with **M-DISC PAR2 Parity Percentage**.
- **Burn Disc Image** (⌃⌘6) writes an existing .iso, .cue/.bin or .dmg exactly as it is.

Older formats are there for old machines: strict 8.3 upper-case names for DOS, Windows 95 and System 7, and an Apple Partition Map with classic HFS for Mac OS 9.

## Which computers see which files

Each staged item has **Mac** and **PC** visibility pills. Turn one off to hide that item from that kind of computer, for example a Windows installer that Mac users don't need. By default Krouton leaves out macOS clutter: .DS_Store files and the ._ files that hold resource forks. Turn on **Preserve macOS xattr & Resource Forks** to keep them.

**Customize Finder Layout** sets how the disc looks when a Mac opens it: icon or list view, icon positions, icon size and a background picture.

## Files that don't fit on one disc

When the staged files are larger than the disc size chosen at the top of the deck, Krouton plans a set. It packs the biggest files first so the set uses as few discs as possible, and the capacity bar shows one segment per disc. To decide yourself where a disc ends, right-click an item and choose **Insert Disc Break**. Krouton then keeps your order.

Every disc in a set is laid out as a BagIt bag (RFC 8493): your files sit under data/, next to:

- bagit.txt and bag-info.txt, which describe the bag;
- manifest-sha256.txt, a SHA-256 checksum for every file on that disc;
- krouton-set-index.json, which lists every disc in the set and the files on each.

So any single disc can be checked on its own with standard BagIt tools, years from now, without Krouton, and the index tells you which disc to fetch for a given file.

A file larger than the chosen disc can't be split. Pick a bigger disc size, or use UDF 2.60 on a Blu-ray.

## Burning a disc image

Drop an .iso, .cue/.bin or .dmg on the deck, or choose **Burn Disc Image**. A .cue file must sit next to the .bin files it names. Krouton writes the image sector for sector, including its boot catalog, so a bootable installer stays bootable.

## The Disc Image Depot

The Depot (⌘2) is a library of disc images you have made or collected. Select an image to see:

- whether it can boot (El Torito for PCs, Apple Partition Map for Macs) and which file systems it holds;
- the **LBA Sector Map**: where each structure sits on the disc, in 2048-byte sectors;
- the **Sector Hex Inspector**, for looking at the raw bytes of any sector;
- its SHA-256 checksum, to compare with the one a download page publishes.

The search field can also search the Internet Archive for CD and DVD images and add the results to the Depot.

**View › Inspect Hybrid ISO/UDF LBA Layout** (⌃⌘L) shows the same map for the disc you are building now, before you burn it.

## Making an image instead of a disc

Add a **Disc Image File** destination (⇧⌘D, then choose the kind) to save the disc as an .iso instead of burning it. You can burn the image later, here or on another machine, or keep it as an archive copy.
