#!/usr/bin/env python3
"""Keep Sources/KroutonApp/Resources/Localizable.xcstrings in step with the code.

Collects the interface text in Sources/KroutonApp: string literals passed to KroutonL10n.tr
and to SwiftUI's localizable initialisers and modifiers (Text, Button, Label, Toggle, .help,
.accessibilityLabel and the like). Literals with interpolation are left out: they stay English
until written with String(localized:) or as format strings.

  python3 Scripts/extract-strings.py           # add new strings to the catalog
  python3 Scripts/extract-strings.py --check   # fail if the catalog is missing any (CI)

Existing entries and their translations are kept. A string no longer in the code is dropped,
unless it has translations, in which case it is kept and marked stale for a translator to
review. Xcode's String Catalog editor reads and writes the same file.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources" / "KroutonApp"
CATALOG = SOURCES / "Resources" / "Localizable.xcstrings"

CALLS = (r"KroutonL10n\.tr|Text|Button|Label|Toggle|Picker|Section|Menu|ColorPicker|Stepper|"
         r"DisclosureGroup|TextField|SecureField|LabeledContent|GroupBox|Link|"
         r"\.help|\.navigationTitle|\.accessibilityLabel|\.accessibilityHint|\.badge")
PATTERN = re.compile(r"(?<![\w.])(?:" + CALLS + r")\(\s*\"((?:[^\"\\\n]|\\.)*)\"")
LITERAL = re.compile(r"\"((?:[^\"\\\n]|\\.)*)\"")
UNESCAPE = {'"': '"', "\\": "\\", "n": "\n", "t": "\t", "'": "'"}


def unescape(raw):
    return re.sub(r"\\(.)", lambda m: UNESCAPE.get(m.group(1), m.group(0)), raw)


def strings_in_code():
    found = {}
    for path in sorted(SOURCES.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in PATTERN.finditer(text):
            raw = match.group(1)
            if "\\(" in raw or not raw.strip():
                continue
            key = unescape(raw)
            if not any(c.isalpha() for c in key):
                continue
            found.setdefault(key, path.relative_to(ROOT).as_posix())
        # Every literal inside KroutonL10n.tr(...), so tr(flag ? "A" : "B") gives both.
        for start in (m.end() for m in re.finditer(r"KroutonL10n\.tr\(", text)):
            depth, end = 1, start
            while end < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[end], 0)
                end += 1
            for raw in LITERAL.findall(text[start:end - 1]):
                if "\\(" not in raw and any(c.isalpha() for c in raw):
                    found.setdefault(unescape(raw), path.relative_to(ROOT).as_posix())
    return found


def load_catalog():
    if CATALOG.exists():
        return json.loads(CATALOG.read_text(encoding="utf-8"))
    return {"sourceLanguage": "en", "strings": {}, "version": "1.0"}


def merged(catalog, found):
    old = catalog.get("strings", {})
    strings = {}
    for key in found:
        entry = dict(old.get(key, {}))
        entry.pop("extractionState", None)
        strings[key] = entry
    for key, entry in old.items():
        if key not in found and entry.get("localizations"):
            strings[key] = dict(entry, extractionState="stale")
    catalog["strings"] = dict(sorted(strings.items(), key=lambda kv: kv[0].lower()))
    return catalog


def dump(catalog):
    return json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=False) + "\n"


def main():
    found = strings_in_code()
    catalog = load_catalog()
    if "--check" in sys.argv:
        missing = sorted(k for k in found if k not in catalog.get("strings", {}))
        if missing:
            print(f"Localizable.xcstrings is missing {len(missing)} strings, e.g.:")
            for key in missing[:10]:
                print(f"  {key!r}  ({found[key]})")
            print("Run python3 Scripts/extract-strings.py and commit the catalog.")
            sys.exit(1)
        print(f"Localizable.xcstrings has all {len(found)} interface strings")
        return
    CATALOG.write_text(dump(merged(catalog, found)), encoding="utf-8")
    translated = sum(1 for e in catalog["strings"].values() if e.get("localizations"))
    print(f"{len(catalog['strings'])} strings in the catalog, {translated} with translations")


if __name__ == "__main__":
    main()
