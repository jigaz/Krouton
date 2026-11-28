#!/usr/bin/env python3
"""Writes a folder of original, copyright-free sample content for burning demos.

    python3 -I Scripts/demo/make-demo-files.py                 # ~/Desktop/Krouton Demo Files
    python3 -I Scripts/demo/make-demo-files.py --out /tmp/demo

Everything is generated here (standard library only), and the output is the same byte for byte on
every run: procedurally drawn PNG "photos", a set of 44.1 kHz 16-bit stereo WAV tracks for an
audio-CD project, a few text and Markdown documents, and some nested folders. About 40 MB in all,
so it fits a CD, a DVD or a Blu-ray.
"""

import argparse
import math
import os
import random
import struct
import sys
import wave
import zlib
from pathlib import Path

MARKER = "About These Files.md"
FIXED_MTIME = 1767268800  # 2026-01-01 12:00 UTC, so folder listings look the same every time

# MARK: - PNG


def write_png(path, width, height, row_fn):
    """Writes an 8-bit RGB PNG. row_fn(y) returns the row's width*3 bytes."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        raw += row_fn(y)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def clamp(v):
    return 0 if v < 0 else 255 if v > 255 else int(v)


def hsv(h, s, v):
    """h in [0, 1), s and v in [0, 1] -> (r, g, b) floats 0-255."""
    h = (h % 1.0) * 6.0
    i = int(h)
    f = h - i
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r, g, b = ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))[i % 6]
    return r * 255, g * 255, b * 255


class Grain:
    """Deterministic film grain, so the pictures look less synthetic (and compress like photos)."""

    def __init__(self, seed, width, amount):
        rng = random.Random(seed)
        self.rows = [[rng.randint(-amount, amount) for _ in range(width)] for _ in range(97)]

    def row(self, y):
        return self.rows[(y * 31) % len(self.rows)]


def picture_aurora(w, h):
    grain = Grain(1, w, 7)
    wave_a = [math.sin(x / w * math.pi * 3.0) for x in range(w)]
    wave_b = [math.sin(x / w * math.pi * 7.0 + 1.3) for x in range(w)]

    def row(y):
        t = y / h
        out = bytearray()
        g = grain.row(y)
        for x in range(w):
            centre = 0.35 + 0.12 * wave_a[x] + 0.04 * wave_b[x]
            band = max(0.0, 1.0 - abs(t - centre) * 6.0) ** 2
            r = 8 + 40 * t + 90 * band * (0.5 + 0.5 * wave_b[x])
            gg = 18 + 30 * t + 220 * band
            b = 45 + 70 * (1 - t) + 80 * band
            n = g[x]
            out += bytes((clamp(r + n), clamp(gg + n), clamp(b + n)))
        return out

    return row


def picture_sunset(w, h):
    grain = Grain(2, w, 6)
    sun_x, sun_y, sun_r = w * 0.62, h * 0.58, h * 0.16
    dx2 = [(x - sun_x) ** 2 for x in range(w)]

    def row(y):
        t = y / h
        g = grain.row(y)
        out = bytearray()
        if t < 0.66:
            sky = (255 * (0.55 + 0.45 * t), 90 + 120 * t, 130 - 100 * t)
        else:
            k = (t - 0.66) / 0.34
            sky = (60 - 40 * k, 40 - 20 * k, 90 - 30 * k)  # water
        stripe = (y // 6) % 2 if t >= 0.66 else 0
        dy2 = (y - sun_y) ** 2
        for x in range(w):
            r, gg, b = sky
            d = math.sqrt(dx2[x] + dy2)
            if d < sun_r and t < 0.66:
                r, gg, b = 255, 225 - 60 * (d / sun_r), 120
            elif t >= 0.66 and abs(x - sun_x) < sun_r * (1.2 - (t - 0.66)) and stripe:
                r, gg, b = r + 150, gg + 110, b + 40  # the sun's reflection
            else:
                glow = max(0.0, 1.0 - d / (sun_r * 4))
                r, gg, b = r + 60 * glow, gg + 40 * glow, b + 10 * glow
            n = g[x]
            out += bytes((clamp(r + n), clamp(gg + n), clamp(b + n)))
        return out

    return row


def picture_plasma(w, h):
    grain = Grain(3, w, 4)
    sx = [math.sin(x * 0.011) for x in range(w)]
    sy = [math.sin(y * 0.017) for y in range(h)]
    sxy = [math.sin(i * 0.007) for i in range(w + h)]
    sxmy = [math.sin(i * 0.013) for i in range(w + h)]

    def row(y):
        g = grain.row(y)
        out = bytearray()
        for x in range(w):
            v = (sx[x] + sy[y] + sxy[x + y] + sxmy[x - y + h]) / 4.0
            r, gg, b = hsv(0.5 + v * 0.75, 0.75, 0.95)
            n = g[x]
            out += bytes((clamp(r + n), clamp(gg + n), clamp(b + n)))
        return out

    return row


def picture_rings(w, h):
    grain = Grain(4, w, 5)
    cx, cy = w * 0.4, h * 0.45
    dx2 = [(x - cx) ** 2 for x in range(w)]

    def row(y):
        g = grain.row(y)
        out = bytearray()
        dy2 = (y - cy) ** 2
        for x in range(w):
            d = math.sqrt(dx2[x] + dy2)
            ring = 0.5 + 0.5 * math.cos(d * 0.09)
            r, gg, b = hsv(d / 900.0, 0.65, 0.35 + 0.6 * ring)
            n = g[x]
            out += bytes((clamp(r + n), clamp(gg + n), clamp(b + n)))
        return out

    return row


def picture_tiles(w, h):
    """Coloured rectangles split recursively, in the spirit of a geometric painting."""
    rng = random.Random(5)
    rects = []

    def split(x0, y0, x1, y1, depth):
        if depth > 4 or (x1 - x0) < 160 or (y1 - y0) < 120 or (depth > 1 and rng.random() < 0.25):
            colour = rng.choice([(222, 52, 44), (245, 200, 40), (30, 70, 160), (245, 242, 232), (245, 242, 232),
                                 (245, 242, 232), (40, 150, 110)])
            rects.append((x0, y0, x1, y1, colour))
            return
        if (x1 - x0) > (y1 - y0):
            m = rng.randint(x0 + (x1 - x0) // 3, x1 - (x1 - x0) // 3)
            split(x0, y0, m, y1, depth + 1)
            split(m, y0, x1, y1, depth + 1)
        else:
            m = rng.randint(y0 + (y1 - y0) // 3, y1 - (y1 - y0) // 3)
            split(x0, y0, x1, m, depth + 1)
            split(x0, m, x1, y1, depth + 1)

    split(0, 0, w, h, 0)
    grain = Grain(6, w, 5)

    def row(y):
        line = [(20, 20, 24)] * w
        for x0, y0, x1, y1, colour in rects:
            if y0 + 6 <= y < y1 - 6:
                line[x0 + 6:x1 - 6] = [colour] * (x1 - x0 - 12)
        g = grain.row(y)
        out = bytearray()
        for x in range(w):
            r, gg, b = line[x]
            n = g[x]
            out += bytes((clamp(r + n), clamp(gg + n), clamp(b + n)))
        return out

    return row


PICTURES = [
    ("Aurora Over the Fjord.png", 1600, 1000, picture_aurora),
    ("Harbour Sunset.png", 1600, 1067, picture_sunset),
    ("Plasma Study.png", 1280, 960, picture_plasma),
    ("Ripples.png", 1280, 960, picture_rings),
    ("Composition in Primary Colours.png", 1200, 1200, picture_tiles),
]

# MARK: - WAV

RATE = 44100
NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name, octave):
    return NOTE[name] * 2 ** (octave - 4)


def chord(root, octave, kind):
    steps = {"maj": (0, 4, 7), "min": (0, 3, 7), "maj7": (0, 4, 7, 11), "min7": (0, 3, 7, 10), "sus2": (0, 2, 7)}[kind]
    base = freq(root, octave)
    return [base * 2 ** (s / 12) for s in steps]


def render_bar(notes, bass, seconds, arpeggio_steps):
    """One bar: a soft pad, a bass note and a plucked arpeggio. Returns (left, right) float lists."""
    n = int(RATE * seconds)
    left = [0.0] * n
    right = [0.0] * n
    two_pi = 2 * math.pi
    # Pad: every chord note, slow attack and release, panned across the field.
    for k, f in enumerate(notes):
        pan = 0.2 + 0.6 * k / max(1, len(notes) - 1)
        step = two_pi * f / RATE
        detune = two_pi * f * 1.003 / RATE
        for i in range(n):
            env = min(1.0, i / (0.25 * RATE)) * min(1.0, (n - i) / (0.3 * RATE))
            s = 0.07 * env * (math.sin(step * i) + 0.5 * math.sin(detune * i))
            left[i] += s * (1 - pan)
            right[i] += s * pan
    # Bass: a sine with its octave, centred.
    step = two_pi * bass / RATE
    for i in range(n):
        env = min(1.0, i / (0.02 * RATE)) * math.exp(-i / (1.2 * RATE))
        s = 0.22 * env * (math.sin(step * i) + 0.3 * math.sin(2 * step * i))
        left[i] += s
        right[i] += s
    # Arpeggio: plucked notes up the chord, alternating sides.
    if arpeggio_steps:
        length = n // arpeggio_steps
        for a in range(arpeggio_steps):
            f = notes[a % len(notes)] * 2
            step = two_pi * f / RATE
            start = a * length
            pan = 0.3 if a % 2 else 0.7
            for i in range(length):
                env = min(1.0, i / 80.0) * math.exp(-i / (0.18 * RATE))
                s = 0.12 * env * (math.sin(step * i) + 0.25 * math.sin(3 * step * i))
                left[start + i] += s * (1 - pan)
                right[start + i] += s * pan
    return left, right


def write_track(path, progression, bar_seconds, arpeggio_steps, total_seconds):
    bars = [render_bar(chord(*c), freq(c[0], 2), bar_seconds, arpeggio_steps) for c in progression]
    frames = int(total_seconds * RATE)
    bar_frames = len(bars[0][0])
    fade = int(3 * RATE)
    pcm = bytearray()
    pack = struct.Struct("<hh").pack
    for i in range(frames):
        left, right = bars[(i // bar_frames) % len(bars)]
        j = i % bar_frames
        gain = min(1.0, (frames - i) / fade) * min(1.0, i / 2000.0)
        pcm += pack(int(max(-1.0, min(1.0, left[j] * gain * 2.0)) * 32000),
                    int(max(-1.0, min(1.0, right[j] * gain * 2.0)) * 32000))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(pcm))


TRACKS = [
    ("01 Morning Light.wav", [("C", 3, "maj7"), ("A", 3, "min7"), ("F", 3, "maj7"), ("G", 3, "sus2")], 2.0, 8, 32),
    ("02 Slow Tide.wav", [("D", 3, "min"), ("A#", 2, "maj"), ("F", 3, "maj"), ("C", 3, "maj")], 3.0, 6, 36),
    ("03 Glass Garden.wav", [("E", 3, "min7"), ("C", 3, "maj7"), ("G", 3, "maj"), ("D", 3, "sus2")], 1.5, 12, 24),
    ("04 Night Drive.wav", [("A", 2, "min"), ("F", 3, "maj"), ("C", 3, "maj"), ("G", 3, "maj")], 2.0, 16, 28),
    ("05 Last Light.wav", [("F", 3, "maj7"), ("E", 3, "min7"), ("D", 3, "min7"), ("C", 3, "maj")], 4.0, 4, 40),
]

# MARK: - Documents


ABOUT = """# Krouton Demo Files

Sample content for showing Krouton without bringing your own files. Every file here was generated
by `Scripts/demo/make-demo-files.py` in the Krouton repository: the pictures are drawn by code
and the music is synthesised, so there is nothing to license and nothing private.

| Folder | What's in it | Try it as |
|---|---|---|
| `Photos/` | {pictures} PNG pictures | a data disc or a photo backup |
| `Music/` | {tracks} WAV tracks, 44.1 kHz 16-bit stereo, {minutes} | an audio CD project, or files on a data disc |
| `Documents/` | text, Markdown and a CSV | a data disc |
| `Projects/` | a few nested folders | showing that folder structure survives the burn |

The whole folder is about {size} MB, so it fits on a CD.
"""

TRACKLIST_HEADER = "Krouton Demo Files: Music\n\nAll tracks synthesised by make-demo-files.py; free to use.\n\n"

DOCUMENTS = {
    "Documents/Welcome.txt": (
        "Welcome!\n\nThis disc was burned with Krouton, a disc mastering app for the Mac.\n"
        "The files on it are generated samples, safe to share.\n"
    ),
    "Documents/Packing List.md": (
        "# Packing list\n\n- [x] Blank discs (or a demo server)\n- [x] Sharpie for the label\n"
        "- [ ] Spare USB cable\n- [ ] Snacks\n"
    ),
    "Documents/Burn Log.csv": (
        "date,disc,format,size_mb,verified\n"
        "2026-01-05,Holiday Photos,DVD+R,3120,yes\n"
        "2026-01-12,Band Practice,CD-DA,612,yes\n"
        "2026-02-02,Tax Archive 2025,BD-R,18450,yes\n"
        "2026-02-20,Mixtape for Sam,CD-DA,701,no\n"
    ),
    "Projects/Garden Plan/Notes.md": (
        "# Garden plan\n\nTomatoes along the south fence, herbs by the door,\n"
        "and the pumpkins wherever they want to go.\n"
    ),
    "Projects/Garden Plan/Seeds/Order.txt": "Basil x2\nCherry tomato x3\nSunflower (giant) x1\n",
    "Projects/Recipes/Bread.md": (
        "# Weekend bread\n\n500 g flour, 350 g water, 10 g salt, 5 g yeast.\n"
        "Mix, rest an hour, fold, rest overnight in the fridge, bake at 240 °C for 40 minutes.\n"
    ),
    "Projects/Archive/2025/Q4/Summary.txt": "Nothing to see here: just a folder four levels deep.\n",
}

# MARK: - Main


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(Path.home() / "Desktop" / "Krouton Demo Files"),
                        help="folder to write (default: ~/Desktop/Krouton Demo Files)")
    args = parser.parse_args()
    out = Path(args.out).expanduser()
    if out.exists() and any(out.iterdir()) and not (out / MARKER).exists():
        sys.exit(f"{out} already has other files in it; choose an empty folder with --out.")
    for sub in ("Photos", "Music"):
        (out / sub).mkdir(parents=True, exist_ok=True)

    for name, w, h, make in PICTURES:
        print(f"Photos/{name}", flush=True)
        write_png(out / "Photos" / name, w, h, make(w, h))

    tracklist = TRACKLIST_HEADER
    for number, (name, progression, bar, arp, seconds) in enumerate(TRACKS, 1):
        print(f"Music/{name}", flush=True)
        write_track(out / "Music" / name, progression, bar, arp, seconds)
        tracklist += f"{number:2d}. {name[3:-4]:<20} {seconds // 60}:{seconds % 60:02d}\n"
    (out / "Music" / "Track List.txt").write_text(tracklist, encoding="utf-8")

    for rel, text in DOCUMENTS.items():
        path = out / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    total = sum(p.stat().st_size for p in out.rglob("*") if p.is_file() and p.name != MARKER)
    seconds = sum(t[4] for t in TRACKS)
    (out / MARKER).write_text(ABOUT.format(
        pictures=len(PICTURES), tracks=len(TRACKS), minutes=f"{seconds // 60}:{seconds % 60:02d} in all",
        size=max(1, round(total / 1_000_000))), encoding="utf-8")

    for path in sorted(out.rglob("*"), reverse=True):
        os.utime(path, (FIXED_MTIME, FIXED_MTIME))
    os.utime(out, (FIXED_MTIME, FIXED_MTIME))
    print(f"\nWrote {out} ({total / 1_000_000:.1f} MB)")


if __name__ == "__main__":
    main()
