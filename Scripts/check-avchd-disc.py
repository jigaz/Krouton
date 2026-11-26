#!/usr/bin/env python3
"""Reads back the AVCHD sample disc krouton-verify Suite 36 authors in CI.

    python3 Scripts/check-avchd-disc.py <KROUTON_AVCHD_OUT>

libbluray (the library VLC, Kodi and mpv play Blu-rays with) opens the BDMV folder and the
UDF 2.50 image, lists the title, its clips and chapters, seeks by time through the EP map and
reads the stream there; hdiutil mounts the image and every file must match the folder.
Standard library only; libbluray comes from Homebrew.
"""

import ctypes
import ctypes.util
import filecmp
import os
import subprocess
import sys
import tempfile
from pathlib import Path


class TitleInfo(ctypes.Structure):
    _fields_ = [
        ("idx", ctypes.c_uint32),
        ("playlist", ctypes.c_uint32),
        ("duration", ctypes.c_uint64),
        ("clip_count", ctypes.c_uint32),
        ("angle_count", ctypes.c_uint8),
        ("chapter_count", ctypes.c_uint32),
        ("mark_count", ctypes.c_uint32),
    ]


def load():
    for candidate in ("/opt/homebrew/lib/libbluray.dylib", "/usr/local/lib/libbluray.dylib", ctypes.util.find_library("bluray")):
        if candidate and (os.path.exists(candidate) or not candidate.startswith("/")):
            lib = ctypes.CDLL(candidate)
            lib.bd_open.restype = ctypes.c_void_p
            lib.bd_open.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
            lib.bd_get_titles.restype = ctypes.c_uint32
            lib.bd_get_titles.argtypes = [ctypes.c_void_p, ctypes.c_uint8, ctypes.c_uint32]
            lib.bd_get_title_info.restype = ctypes.POINTER(TitleInfo)
            lib.bd_get_title_info.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint]
            lib.bd_free_title_info.argtypes = [ctypes.POINTER(TitleInfo)]
            lib.bd_select_title.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
            lib.bd_get_title_size.restype = ctypes.c_uint64
            lib.bd_get_title_size.argtypes = [ctypes.c_void_p]
            lib.bd_seek_time.restype = ctypes.c_int64
            lib.bd_seek_time.argtypes = [ctypes.c_void_p, ctypes.c_uint64]
            lib.bd_read.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
            lib.bd_close.argtypes = [ctypes.c_void_p]
            return lib
    sys.exit("libbluray not found (brew install libbluray)")


def check_bluray(lib, path: Path) -> list:
    problems = []
    bd = lib.bd_open(str(path).encode(), None)
    if not bd:
        return [f"libbluray could not open {path}"]
    try:
        titles = lib.bd_get_titles(bd, 0, 0)
        if titles != 1:
            problems.append(f"{titles} titles, expected 1")
            return problems
        info = lib.bd_get_title_info(bd, 0, 0)
        t = info.contents
        seconds = t.duration / 90000
        print(f"  {path.name}: playlist {t.playlist:05d}, {seconds:.2f} s, {t.clip_count} clips, {t.chapter_count} chapters")
        if t.clip_count != 2:
            problems.append(f"{t.clip_count} clips, expected 2")
        if t.chapter_count != 2:
            problems.append(f"{t.chapter_count} chapters, expected one per clip")
        if not 19.0 <= seconds <= 21.5:
            problems.append(f"title lasts {seconds:.2f} s, expected about 20 (12 + 8)")
        lib.bd_free_title_info(info)
        if lib.bd_select_title(bd, 0) != 1:
            return problems + ["bd_select_title failed"]
        size = lib.bd_get_title_size(bd)
        buffer = ctypes.create_string_buffer(6144)
        last = -1
        for second in (0, 5, 11, 13, 18):
            position = lib.bd_seek_time(bd, second * 90000)
            got = lib.bd_read(bd, buffer, 6144)
            print(f"  seek {second:2d} s -> byte {position:,} of {size:,}, read {got}")
            if position < 0 or got <= 0:
                problems.append(f"seeking to {second} s failed ({position}, {got})")
            elif position <= last and second > 0:
                problems.append(f"seeking to {second} s did not move forward ({position} after {last})")
            last = position
    finally:
        lib.bd_close(bd)
    return problems


def check_mount(image: Path, folder: Path) -> list:
    with tempfile.TemporaryDirectory() as mnt:
        result = subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mnt, str(image)],
                                capture_output=True, text=True)
        if result.returncode != 0:
            return [f"hdiutil could not attach the image: {result.stderr.strip()}"]
        try:
            problems = []
            for root, _, files in os.walk(folder):
                rel = Path(root).relative_to(folder)
                for name in files:
                    mounted = Path(mnt) / rel / name
                    if not mounted.exists():
                        problems.append(f"missing on the disc: {rel / name}")
                    elif not filecmp.cmp(Path(root) / name, mounted, shallow=False):
                        problems.append(f"differs on the disc: {rel / name}")
            print(f"  image mounted by macOS; {sum(len(f) for _, _, f in os.walk(folder))} files compared")
            return problems
        finally:
            subprocess.run(["hdiutil", "detach", mnt], capture_output=True)


def main() -> int:
    out = Path(sys.argv[1])
    lib = load()
    problems = []
    print("BDMV folder:")
    problems += check_bluray(lib, out / "disc")
    print("UDF 2.50 image:")
    problems += check_bluray(lib, out / "disc.iso")
    problems += check_mount(out / "disc.iso", out / "disc")
    for problem in problems:
        print(f"FAIL {problem}")
    print("ok" if not problems else f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
