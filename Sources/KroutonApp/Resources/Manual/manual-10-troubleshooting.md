# Settings, files and troubleshooting

## Settings

Open Settings with ⌘,. The search field at the top finds a setting by any word in it.

- **General**: appearance, accent colours, language, and whether Krouton reopens your last project. **Keep these settings in iCloud** shares appearance, units, notifications and their sounds, the label template and the menu bar choice with your other Macs signed in to the same iCloud account; language, drives, servers and keys stay on each Mac. If iCloud already holds another Mac's settings, Krouton asks which to keep. Turning it off leaves the settings as they are. Builds you make yourself aren't signed for iCloud and say so.
- **Format Chooser**: which disc formats appear in the sidebar.
- **Disc Image Depot**: where images are kept.
- **Audio & Video**: whether DVD copies and shrinks keep their menus, or play every title in order without them.
- **Ripping & Transcoding**: AccurateRip checking and the pattern ripped files are named by.
- **Burners & Network**: connected drives, Auto-Load and Krouton Servers.
- **Labels & Printers**: disc sizes and printer tray offsets.
- **Notifications**: a banner and a sound when a burn or rip starts, finishes or fails, when Auto-Load wants the next blank, and when a Depot download is checked. Each event has its own sound: one of Krouton's synth voices (Toaster Ding, Burnt Toast, Spindle Trill, Tray Lock and others) or a macOS system sound. The play button tries it, and the sliders button shapes it: pitch, played backwards, lo-fi and metallic. With **Give each drive its own pitch** on, each burner sounds a different interval, so you can tell by ear which one finished or wants a disc. **Show progress in the menu bar** puts a disc and a percentage in the menu bar while a burn, rescue, AVCHD build or Depot download runs (or always, or never); click it to see each one and to open Krouton. These choices are kept between launches.
- **Accessibility & Language**: higher contrast, spoken progress for VoiceOver, and the app's language. Krouton also follows Reduce Motion in System Settings › Accessibility › Display, which turns off its animations. Translation into nine languages has started with a handful of labels; most of the app and this manual are in English for now. A change of language takes effect the next time Krouton opens; you can also set it in System Settings › General › Language & Region › Applications.
- **Storage & Reset**: shows how much space Krouton's caches, saved session and burn history take, and clears each one. You can also reset Settings to their defaults or the destination queues to one burner card, forget all paired Krouton Servers, give this Mac new server keys (every server then has to be paired again), or do all of these at once with **Reset Krouton**. Each asks first and says what goes and what stays. None of them touches your projects, rips, or images you saved, or what's open now. Caches can't be emptied while a burn, copy or download is running.

## Where Krouton keeps things

- Projects you save: wherever you choose, as .krut files.
- Your session, restored at launch: ~/Library/Application Support/app.krouton/Sessions.
- Temporary staging for burns: in your Caches folder; Krouton removes it after each burn.
- Audio rips: ~/Music/Krouton Rips.
- Keys for Krouton Servers: in your login keychain.

## A project or session from another version

A project saved by an older or newer Krouton opens even when it lacks settings this version has, or holds choices it doesn't know. Those settings take the values a new project starts with, and the banner says how many. A destination, track or source file that can't be read at all is left out, and the banner counts those too; the rest of the project opens. The same applies to the session Krouton restores at launch. If a file isn't a Krouton project, or is damaged, the banner says it couldn't be opened.

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
