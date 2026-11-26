#!/usr/bin/env python3
"""Mounts the disc images the `disc` tests wrote (KROUTON_DISC_OUT) with this computer's own
file-system drivers and checks every file and folder against the tree each was built from.

    python3 scripts/check_disc_images.py <dir>

Linux mounts each image as UDF and, where there is one, as ISO 9660 with and without Joliet
(needs sudo); macOS attaches it with hdiutil; Windows mounts it with Mount-DiskImage. Standard
library only.
"""

import os
import platform
import subprocess
import sys
import tempfile
import time
from pathlib import Path

IMAGES = {"udf-data": ("udf", "iso9660", "joliet"), "udf-dvd": ("udf", "iso9660"), "udf-bd": ("udf",)}


def listing(root: Path) -> dict:
    """path → bytes for files, path + '/' → b'' for folders."""
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        rel = Path(dirpath).relative_to(root)
        for d in dirnames:
            out[(rel / d).as_posix() + "/"] = b""
        for f in filenames:
            out[(rel / f).as_posix()] = (Path(dirpath) / f).read_bytes()
    # Windows and macOS add their own entries to a mounted volume's root.
    return {k: v for k, v in out.items() if not k.startswith(("System Volume Information", ".fseventsd", ".Trashes"))}


def compare(kind: str, mounted: dict, tree: dict, exact_names: bool) -> list:
    problems = []
    if exact_names:
        for path in sorted(tree.keys() - mounted.keys()):
            problems.append(f"{kind}: missing {path!r}")
        for path in sorted(mounted.keys() - tree.keys()):
            problems.append(f"{kind}: unexpected {path!r}")
        for path in sorted(tree.keys() & mounted.keys()):
            if tree[path] != mounted[path]:
                problems.append(f"{kind}: {path!r} differs ({len(mounted[path])} bytes, expected {len(tree[path])})")
    else:
        if len(mounted) != len(tree):
            problems.append(f"{kind}: {len(mounted)} entries, expected {len(tree)}")
        if sorted(mounted.values()) != sorted(tree.values()):
            problems.append(f"{kind}: file contents differ")
    return problems


def run(*args: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(args)}: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def check_linux(image: Path, tree: dict, kinds: tuple) -> list:
    problems = []
    options = {"udf": "-t udf -o loop,ro,utf8", "iso9660": "-t iso9660 -o loop,ro,nojoliet,norock",
               "joliet": "-t iso9660 -o loop,ro,norock,utf8"}
    for kind in kinds:
        with tempfile.TemporaryDirectory() as mnt:
            try:
                run("sudo", "mount", *options[kind].split(), str(image), mnt)
            except RuntimeError as error:
                problems.append(f"{kind}: could not mount: {error}")
                continue
            try:
                mounted = listing(Path(mnt))
                if kind == "joliet":
                    # Joliet is UCS-2: characters outside it become '_'.
                    renamed = {k.replace("😀", "_"): v for k, v in tree.items()}
                    problems += compare(kind, mounted, renamed, exact_names=True)
                else:
                    problems += compare(kind, mounted, tree, exact_names=(kind == "udf"))
            finally:
                run("sudo", "umount", mnt)
    if "udf" in kinds:
        print(run("udfinfo", str(image)).strip())
    return problems


def check_macos(image: Path, tree: dict, kinds: tuple) -> list:
    with tempfile.TemporaryDirectory() as mnt:
        try:
            run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mnt, str(image))
        except RuntimeError as error:
            return [f"could not attach: {error}"]
        try:
            fs = run("stat", "-f", "%T", mnt).strip()
            print(f"{image.parent.name}: macOS mounted it as {fs}")
            return compare(f"macOS ({fs})", listing(Path(mnt)), tree, exact_names=True)
        finally:
            for _ in range(5):
                try:
                    run("hdiutil", "detach", mnt)
                    break
                except RuntimeError:
                    time.sleep(1)


def check_windows(image: Path, tree: dict, kinds: tuple) -> list:
    path = str(image.resolve())
    try:
        letter = run("powershell", "-NoProfile", "-Command",
                     f"(Mount-DiskImage -ImagePath '{path}' -PassThru | Get-Volume).DriveLetter").strip()
    except RuntimeError as error:
        return [f"could not mount: {error}"]
    try:
        fs = run("powershell", "-NoProfile", "-Command", f"(Get-Volume -DriveLetter {letter}).FileSystem").strip()
        print(f"{image.parent.name}: Windows mounted it as {fs} on {letter}:")
        return compare(f"Windows ({fs})", listing(Path(f"{letter}:\\")), tree, exact_names=True)
    finally:
        run("powershell", "-NoProfile", "-Command", f"Dismount-DiskImage -ImagePath '{path}' | Out-Null")


def main() -> int:
    base = Path(sys.argv[1])
    check = {"Linux": check_linux, "Darwin": check_macos, "Windows": check_windows}[platform.system()]
    failures = 0
    for name, kinds in IMAGES.items():
        folder = base / name
        problems = check(folder / "disc.iso", listing(folder / "tree"), kinds)
        for problem in problems:
            print(f"FAIL {name}: {problem}")
        if not problems:
            print(f"ok   {name}: {', '.join(kinds) if platform.system() == 'Linux' else 'every file matches'}")
        failures += len(problems)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
