# Command line and Shortcuts

## The krouton command

Run Krouton with a subcommand and it works in the terminal without opening a window. Inside the app bundle the program is Krouton.app/Contents/MacOS/Krouton; link it into your path as krouton.

- `krouton drives` lists connected burners, their firmware and the disc in each.
- `krouton formats` lists every kind of disc Krouton can make and the disc sizes each allows.
- `krouton inspect <image> [--sha256]` describes an .iso, .dmg, .bin or .cue: whether it boots, its file systems and its size in sectors, plus its SHA-256 with --sha256.
- `krouton span [--medium <size>] <files…>` plans how files would be split across discs. Sizes are cd650, cd700, cd800, minidvd, dvd5, dvd9, bd25, bd50, bdxl100 and bdxl128.
- `krouton iso -V <title> -o <out.iso> <folder>` builds a hybrid UDF, ISO-9660 and Joliet image from a folder.
- `krouton completions zsh` (or bash, fish) prints tab completion for your shell.
- `krouton --version` and `krouton --help`.

Add --json to drives, formats, inspect and span for output a script can read. `man krouton` has the full reference when Krouton is installed with Homebrew.

Examples:

- `krouton inspect ~/Downloads/debian.iso --sha256` before burning a download, to compare with the checksum on the website.
- `krouton span --medium bd25 ~/Photos/2025` to see how many Blu-rays a year of photos needs.

## Shortcuts and Siri

Krouton adds these actions to the Shortcuts app:

- **List Optical Drives & Media Status**
- **Inspect Optical Disc Image**, optionally with a SHA-256 checksum
- **Calculate Multi-Disc Spanning Plan**
- **Master Hybrid UDF/ISO-9660 Disc Image** from a folder
- **Open Krouton Mastering Format**, which opens Krouton on a given kind of disc

You can ask Siri, for example, "List optical drives in Krouton" or "Plan multi-disc span in Krouton". A useful shortcut: every Friday, build an image of a project folder and save it to an external drive.
