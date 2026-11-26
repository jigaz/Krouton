#!/usr/bin/env python3
"""Render the user manual (Sources/KroutonApp/Resources/Manual/*.md) into docs/manual/.

The app shows the same Markdown files in Help > Krouton User Manual, so the two never drift.
Run it after editing a chapter:

    python3 Scripts/build-manual.py           # write docs/manual/
    python3 Scripts/build-manual.py --check   # fail if docs/manual/ is out of date (CI)

The Markdown subset matches KroutonManualDocument.parse in the app: "# " title, "## " sections,
paragraphs, "- " bullets, "1. " steps, and inline **bold**, `code` and [links](url).
Standard library only.
"""

import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Sources/KroutonApp/Resources/Manual"
OUTPUT = ROOT / "docs/manual"


def slug_of(path):
    # manual-03-audio-cds.md -> audio-cds
    return "-".join(path.stem.split("-")[2:])


def parse(text):
    title, blocks, para, items, kind = "", [], [], [], None

    def flush_para():
        nonlocal para
        if para:
            blocks.append(("p", " ".join(para)))
        para = []

    def flush_list():
        nonlocal items, kind
        if items:
            blocks.append((kind, items))
        items, kind = [], None

    for raw in text.splitlines():
        line = raw.strip()
        step = re.match(r"^(\d+)\. (.*)$", line)
        if not line:
            flush_para()
            flush_list()
        elif line.startswith("## "):
            flush_para()
            flush_list()
            blocks.append(("h2", line[3:]))
        elif line.startswith("# "):
            flush_para()
            flush_list()
            title = line[2:]
        elif line.startswith("- "):
            flush_para()
            if kind == "ol":
                flush_list()
            kind = "ul"
            items.append(line[2:])
        elif step:
            flush_para()
            if kind == "ul":
                flush_list()
            kind = "ol"
            items.append(step.group(2))
        elif items:
            items[-1] += " " + line
        else:
            para.append(line)
    flush_para()
    flush_list()
    return title, blocks


def inline(text):
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", r'<a href="\2">\1</a>', out)
    return out


def render_blocks(blocks):
    parts = []
    for kind, value in blocks:
        if kind == "h2":
            parts.append(f"    <h2>{inline(value)}</h2>")
        elif kind == "p":
            parts.append(f"    <p>{inline(value)}</p>")
        else:
            rows = "\n".join(f"      <li>{inline(item)}</li>" for item in value)
            parts.append(f"    <{kind}>\n{rows}\n    </{kind}>")
    return "\n".join(parts)


def page(title, description, body, current_slug, chapters):
    current = ' aria-current="page"'
    toc = "\n".join(
        f'        <li><a href="/manual/{slug}/"{current if slug == current_slug else ""}>{html.escape(t)}</a></li>'
        for slug, t, _ in chapters
    )
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description)}">
<link rel="stylesheet" href="/assets/site.css">
<link rel="icon" href="/assets/disc.svg" type="image/svg+xml">
</head>
<body>
<div class="site">
  <header class="masthead">
    <a class="name" href="/">Krouton</a>
    <nav aria-label="Site">
      <a href="/">The app</a>
      <a href="/manual/" aria-current="page">Manual</a>
      <a href="/server/">Krouton Server</a>
      <a href="https://archive.krouton.app/">Archive</a>
      <a href="/drives/">Report a drive</a>
      <a href="https://github.com/jigaz/Krouton">Source</a>
    </nav>
  </header>

  <main class="manual">
    <nav class="chapters" aria-label="Manual chapters">
      <ol>
{toc}
      </ol>
    </nav>
    <article>
{body}
    </article>
  </main>

  <footer class="colophon">
    <p>This manual is also built into Krouton: choose Help › Krouton User Manual, or press ⌘?. Corrections are welcome at <a href="https://github.com/jigaz/Krouton/tree/main/Sources/KroutonApp/Resources/Manual">github.com/jigaz/Krouton</a>.</p>
    <p>This site sets no cookies and loads nothing from anyone else. <a href="/privacy/">Privacy</a></p>
  </footer>
</div>
</body>
</html>
"""


def first_paragraph(blocks):
    for kind, value in blocks:
        if kind == "p":
            plain = re.sub(r"[*`]", "", value)
            return plain if len(plain) <= 200 else plain[:197].rsplit(" ", 1)[0] + "…"
    return ""


def build():
    files = sorted(SOURCE.glob("manual-*.md"))
    if not files:
        sys.exit(f"no chapters in {SOURCE}")
    chapters = []
    for path in files:
        title, blocks = parse(path.read_text(encoding="utf-8"))
        if not title:
            sys.exit(f"{path.name}: the first line must be a '# ' title")
        chapters.append((slug_of(path), title, blocks))

    pages = {}
    for index, (slug, title, blocks) in enumerate(chapters):
        pager = []
        if index > 0:
            prev_slug, prev_title, _ = chapters[index - 1]
            pager.append(f'<a href="/manual/{prev_slug}/" rel="prev">Previous: {html.escape(prev_title)}</a>')
        else:
            pager.append("<span></span>")
        if index + 1 < len(chapters):
            next_slug, next_title, _ = chapters[index + 1]
            pager.append(f'<a href="/manual/{next_slug}/" rel="next">Next: {html.escape(next_title)}</a>')
        body = (
            f"    <h1>{inline(title)}</h1>\n{render_blocks(blocks)}\n"
            f'    <nav class="pager" aria-label="Chapters">{"".join(pager)}</nav>'
        )
        pages[f"{slug}/index.html"] = page(
            f"{title} — Krouton manual", first_paragraph(blocks), body, slug, chapters
        )

    intro = "\n".join(
        f'      <li><a href="/manual/{slug}/">{html.escape(title)}</a>. {inline(first_paragraph(blocks))}</li>'
        for slug, title, blocks in chapters
    )
    index_body = (
        "    <h1>Krouton manual</h1>\n"
        '    <p class="lede">How to make data discs, audio CDs and labels with Krouton, burn on another computer, '
        "and fix what goes wrong. The same manual is inside the app under Help.</p>\n"
        f"    <ul>\n{intro}\n    </ul>"
    )
    pages["index.html"] = page(
        "Krouton manual",
        "The Krouton user manual: data discs, audio CDs, burners, Krouton Server, labels, the command line and troubleshooting.",
        index_body, None, chapters,
    )
    return pages


MENU_SOURCES = ROOT / "Sources/KroutonApp/Shell/App"
SHORTCUTS_CHAPTER = SOURCE / "manual-09-keyboard-shortcuts.md"


def menu_shortcuts():
    """Every keyboardShortcut in the menu commands, written the way the manual writes it (⌃⌥⇧⌘ order)."""
    symbols = {"control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"}
    keys = {".delete": "⌫", "-": "−"}
    found = set()
    pattern = re.compile(r'keyboardShortcut\((\.\w+|"[^"]+")(?:,\s*modifiers:\s*([^)]*))?\)')
    for path in sorted(MENU_SOURCES.glob("KroutonMenuCommands*.swift")):
        for key, mods in pattern.findall(path.read_text(encoding="utf-8")):
            key = key.strip('"')
            names = re.findall(r"control|option|shift|command", mods or "command")
            prefix = "".join(symbols[n] for n in ("control", "option", "shift", "command") if n in names)
            found.add(prefix + keys.get(key, key.upper()))
    return found


def check_shortcuts():
    text = SHORTCUTS_CHAPTER.read_text(encoding="utf-8")
    missing = sorted(s for s in menu_shortcuts() if s not in text)
    for combo in missing:
        print(f"menu shortcut not in {SHORTCUTS_CHAPTER.name}: {combo}")
    return not missing


def main():
    check = "--check" in sys.argv[1:]
    pages = build()
    if not check_shortcuts():
        sys.exit("Add the shortcuts above to the keyboard shortcuts chapter.")
    stale = []
    for relative, content in pages.items():
        target = OUTPUT / relative
        current = target.read_text(encoding="utf-8") if target.exists() else None
        if current == content:
            continue
        stale.append(relative)
        if not check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
    known = {OUTPUT / rel for rel in pages}
    extra = [p for p in OUTPUT.rglob("index.html") if p not in known] if OUTPUT.exists() else []
    if check:
        if stale or extra:
            for name in stale:
                print(f"out of date: docs/manual/{name}")
            for path in extra:
                print(f"no chapter for: {path.relative_to(ROOT)}")
            sys.exit("Run python3 Scripts/build-manual.py and commit docs/manual/.")
        print(f"docs/manual is up to date ({len(pages) - 1} chapters)")
    else:
        for path in extra:
            path.unlink()
            try:
                path.parent.rmdir()
            except OSError:
                pass
        print(f"wrote {len(stale)} page(s) to docs/manual ({len(pages) - 1} chapters)")


if __name__ == "__main__":
    main()
