# Settings, files and troubleshooting

## Settings

Open Settings with ⌘,. The search field at the top finds a setting by any word in it.

- **General**: appearance, accent colours, language, and whether Krouton reopens your last project.
- **Format Chooser**: which disc formats appear in the sidebar.
- **Disc Image Depot**: where images are kept.
- **Audio & Video**: whether the DVD-9 shrink keeps menus and extras.
- **Ripping & Transcoding**: AccurateRip checking and the pattern ripped files are named by.
- **Burners & Network**: connected drives, Auto-Load and Krouton Servers.
- **Labels & Printers**: disc sizes and printer tray offsets.
- **Notifications**: a banner and a sound when a burn or rip starts, finishes or fails, when Auto-Load wants the next blank, and when a Depot download is checked.
- **Accessibility & Language**: higher contrast, spoken progress for VoiceOver, and the app's language. Krouton also follows Reduce Motion in System Settings › Accessibility › Display, which turns off its animations. Translation into nine languages has started with a handful of labels; most of the app and this manual are in English for now. A change of language takes effect the next time Krouton opens; you can also set it in System Settings › General › Language & Region › Applications.

## Where Krouton keeps things

- Projects you save: wherever you choose, as .krut files.
- Your session, restored at launch: ~/Library/Application Support/app.krouton/Sessions.
- Temporary staging for burns: in your Caches folder; Krouton removes it after each burn.
- Audio rips: ~/Music/Krouton Rips.
- Keys for Krouton Servers: in your login keychain.

## The drive doesn't show up

- Choose **Disc › Rescan Optical Drives** (⌘R).
- Check that the drive appears in **System Information › Disc Burning**. If it doesn't, macOS can't see it either: try another cable or port, and give a USB drive its own power supply if it has one. Many slim USB burners need more power than a hub provides; plug them straight into the Mac.
- Close other apps that use the drive, such as Music or a disc utility.

## The burn failed

- Look at the burn report: it says how far the burn got and what the drive reported.
- Try another blank from a different batch, at a lower speed. Most failures are the disc, not the software.
- Clean the drive's lens with a lens-cleaning disc if it reads other discs badly too.
- A disc that failed midway is usually unusable. A rewritable disc can be erased and reused.

## The disc doesn't play or open elsewhere

- For data, use Hybrid ISO-9660 + Joliet + UDF. UDF-only discs and Mac-only formats can't be read everywhere.
- For an old DVD player, try DVD-R instead of DVD+R.
- Car stereos often want MP3 at a constant bit rate with ID3v2.3 tags: use the 320 or 192 kbps profile, or burn a plain audio CD.

## Reporting a problem

Choose **Help › Report a Problem**. Include what you were burning, the drive model, the kind of disc, and the burn report. **Help › Report a Drive** explains how to share what your burner can do; drive reports are collected openly at archive.krouton.app.
