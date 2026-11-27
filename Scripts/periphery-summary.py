#!/usr/bin/env python3
"""Summarise Periphery's CSV (periphery scan --format csv) as Markdown, by module.

  python3 Scripts/periphery-summary.py periphery.csv >> "$GITHUB_STEP_SUMMARY"

Results in KroutonVerify and Tests are left out: they are test code. A declaration used only
by them still counts as used, which Suite 28's ratchet covers for public library types.
"""
import csv
import re
import sys
from collections import defaultdict

def module_of(path):
    m = re.search(r"Sources/([^/]+)/", path)
    return m.group(1) if m else "other"

def main():
    reader = csv.DictReader(open(sys.argv[1], encoding="utf-8"))
    print(f"<!-- columns: {reader.fieldnames} -->", file=sys.stderr)
    # Column names differ in case between Periphery versions.
    rows = [{(k or "").strip().lower(): (v or "") for k, v in row.items()} for row in reader]
    by_module = defaultdict(list)
    for row in rows:
        location = row.get("location", "")
        path = location.split(":")[0]
        if "/KroutonVerify/" in path or "/Tests/" in path:
            continue
        rel = path[path.find("Sources/"):] if "Sources/" in path else path
        line = location.split(":")[1] if location.count(":") >= 1 else ""
        what = row.get("hints") or "unused"
        by_module[module_of(path)].append((rel, line, row.get("kind", ""), row.get("name", ""), what))
    total = sum(len(v) for v in by_module.values())
    print(f"## Unused code (Periphery): {total} findings\n")
    print("A report, not a gate: some findings are reached in ways the index can't see. Sort them "
          "before deleting anything.\n")
    print("| Module | Findings |\n|---|---|")
    for module, items in sorted(by_module.items(), key=lambda kv: -len(kv[1])):
        print(f"| {module} | {len(items)} |")
    for module, items in sorted(by_module.items()):
        print(f"\n<details><summary>{module} ({len(items)})</summary>\n")
        for rel, line, kind, name, what in sorted(items):
            print(f"- `{rel}:{line}` {kind} `{name}`: {what}")
        print("\n</details>")

if __name__ == "__main__":
    main()
