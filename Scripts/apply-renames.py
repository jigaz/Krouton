#!/usr/bin/env python3
"""Apply the renames planned in dev-notes/naming-and-structure.md, in one go, from a table.

The table is Scripts/renames.tsv (tab-separated, `#` starts a comment line):

  tier  module  kind  old  new  allow  why

  tier    1 = names that hide what a thing is, 2 = files and suffixes, 3 = spelling,
          4 = the mechanical "Krouton" prefix drop
  module  the target the old name is declared in (for --module)
  kind    type | member | case   a whole-word identifier rename
          file                   old and new are paths from the repository root
  allow   comma-separated hazards the row has been checked for and accepts, or `-`:
            string        also rewrite the name inside Swift string literals
            keep-strings  rename the code but leave string literals alone
            persisted     a member or case of a Codable type, or an enum case whose implicit
                          raw value is the name: only once the stored key is pinned
            objc          the Objective-C runtime sees the name
            intent        an App Intents, widget or Live Activity type, whose name the system stores
            catalog       the name appears in Localizable.xcstrings
            manual        the name appears in the user manual
            ci            also rewrite Scripts/, .github/ and .periphery.yml
            shared-name   (member and case rows) the new name is already used by an unrelated
                          member elsewhere; checked that nothing in the same scope clashes

What is rewritten: Sources/, Tests/, XcodeHost/, and the Markdown that names types
(PENDING_INTEGRATION.md, ARCHITECTURE.md, CLAUDE.md, CONTRIBUTING.md, README.md, dev-notes/).
History is never rewritten: CHANGELOG.md and the dated hand-off notes keep the names they used.
Member and case rows leave prose alone: in comments and Markdown they rewrite only a name in
`backticks`, so "the centre of the disc" stays when a variable `centre` becomes `center`.
A type row also renames the files named after the type (`Old.swift`, `Old+Role.swift`), and a
path in a string literal that names a renamed file is always rewritten with it.

A row is refused, and nothing is written, when the name turns up somewhere the row doesn't
allow: inside a string literal, in a persisted or Objective-C or App Intents declaration, in the
String Catalog, the manual or a CI script. A row whose new name is already in use is refused too.
A row whose old name is gone and whose new name is present counts as already applied, so running
the table again changes nothing.

  python3 -I Scripts/apply-renames.py --dry-run            # print every change, write nothing
  python3 -I Scripts/apply-renames.py --dry-run --module ImageKit
  python3 -I Scripts/apply-renames.py --report             # the hazards found for each row
  python3 -I Scripts/apply-renames.py --module ImageKit    # apply one module's rows
"""
import argparse
import bisect
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / "Scripts" / "renames.tsv"

REWRITE_GLOBS = ["Sources/**/*.swift", "Tests/**/*.swift", "XcodeHost/**/*.swift", "XcodeHost/**/*.yml",
                 "XcodeHost/**/*.plist", "PENDING_INTEGRATION.md", "ARCHITECTURE.md", "CLAUDE.md",
                 "CONTRIBUTING.md", "README.md", "dev-notes/*.md"]
# Records of what was, and this plan itself: never rewritten.
NEVER = {"CHANGELOG.md", "dev-notes/project_history.md", "dev-notes/AI_HANDOFF.md",
         "dev-notes/ABACUS_CODE_SWARM_HANDOFF.md", "dev-notes/original-specification.md",
         "dev-notes/naming-and-structure.md", "Scripts/renames.tsv", "Scripts/apply-renames.py"}
CATALOG = "Sources/KroutonApp/Resources/Localizable.xcstrings"
MANUAL_GLOB = "Sources/KroutonApp/Resources/Manual/*.md"
CI_GLOBS = ["Scripts/*.py", "Scripts/*.sh", ".github/workflows/*.yml", ".periphery.yml"]
RENAMED_FILE_ROOTS = ("Sources/", "Tests/", "XcodeHost/")

INTENT_PROTOCOLS = re.compile(r"\b(AppIntent|AppEntity|AppEnum|AppShortcutsProvider|AppIntentsPackage|EntityQuery|"
                              r"ActivityAttributes|Widget|WidgetBundle|TimelineProvider|TransientAppEntity)\b")
ALLOW_TOKENS = {"string", "keep-strings", "persisted", "objc", "intent", "catalog", "manual", "ci", "shared-name"}
KINDS = {"type", "member", "case", "file"}


# MARK: - Swift source: code, comments and string literals

RAW_STRING_START = re.compile(r"#+\"")


def swift_segments(src):
    """Splits Swift source into ('code'|'comment'|'string', start, end) runs. Code inside a string
    interpolation counts as code, so `"\\(Foo.bar)"` renames Foo."""
    out = []
    n = len(src)

    def emit(kind, s, e):
        if e <= s:
            return
        if out and out[-1][0] == kind and out[-1][2] == s:
            out[-1] = (kind, out[-1][1], e)
        else:
            out.append((kind, s, e))

    def block_comment_end(i):
        depth, i = 0, i
        while i < n:
            if src.startswith("/*", i):
                depth += 1
                i += 2
            elif src.startswith("*/", i):
                depth -= 1
                i += 2
                if depth == 0:
                    return i
            else:
                i += 1
        return n

    def code(i, in_interpolation):
        depth, start = 0, i
        while i < n:
            c = src[i]
            if src.startswith("//", i):
                emit("code", start, i)
                j = src.find("\n", i)
                j = n if j < 0 else j
                emit("comment", i, j)
                i = start = j
                continue
            if src.startswith("/*", i):
                emit("code", start, i)
                j = block_comment_end(i)
                emit("comment", i, j)
                i = start = j
                continue
            if c == '"' or (c == "#" and RAW_STRING_START.match(src, i)):
                emit("code", start, i)
                i = start = string(i)
                continue
            if in_interpolation:
                if c == "(":
                    depth += 1
                elif c == ")":
                    if depth == 0:
                        emit("code", start, i)
                        return i
                    depth -= 1
            i += 1
        emit("code", start, n)
        return n

    def string(i):
        j, hashes = i, 0
        while src[j] == "#":
            hashes += 1
            j += 1
        multi = src.startswith('"""', j)
        quote = '"""' if multi else '"'
        close = quote + "#" * hashes
        escape = "\\" + "#" * hashes
        k, s = j + len(quote), i
        while k < n:
            if src.startswith(escape, k):
                after = k + len(escape)
                if after < n and src[after] == "(":
                    emit("string", s, after + 1)
                    k = code(after + 1, True)
                    s = k
                    k += 1
                    continue
                k = after + 1
                continue
            if src.startswith(close, k):
                k += len(close)
                emit("string", s, k)
                return k
            if not multi and src[k] == "\n":
                emit("string", s, k)
                return k
            k += 1
        emit("string", s, n)
        return n

    code(0, False)
    return out


def masked_code(src, segments):
    """The source with comments and string literals blanked (offsets kept), for declaration scans."""
    chars = list(src)
    for kind, s, e in segments:
        if kind != "code":
            for i in range(s, e):
                if chars[i] != "\n":
                    chars[i] = " "
    return "".join(chars)


def enclosing_headers(code_text, pos):
    """The declaration headers of the braces that are open at `pos`, innermost last."""
    stack, last_break = [], 0
    for i, c in enumerate(code_text[:pos]):
        if c == "{":
            stack.append(code_text[last_break:i])
            last_break = i + 1
        elif c == "}":
            if stack:
                stack.pop()
            last_break = i + 1
    return stack


def header_of(text):
    """The last declaration in a brace header (`struct Foo: Codable` from `...\\nstruct Foo: Codable `)."""
    m = list(re.finditer(r"\b(struct|class|enum|actor|protocol|extension)\s+[^{]*$", text, re.S))
    return m[-1].group(0) if m else text.strip().splitlines()[-1] if text.strip() else ""


# MARK: - The tree, held in memory so a dry run can follow row after row

class Tree:
    def __init__(self, root):
        self.root = root
        self.files = {}          # relative path -> text (rewritable)
        self.detect = {}         # relative path -> (hazard, text), never rewritten unless allowed
        for pattern in REWRITE_GLOBS:
            for p in sorted(root.glob(pattern)):
                rel = p.relative_to(root).as_posix()
                if p.is_file() and rel not in NEVER:
                    self.files[rel] = p.read_text(encoding="utf-8")
        for rel, hazard in [(CATALOG, "catalog")]:
            if (root / rel).exists():
                self.detect[rel] = (hazard, (root / rel).read_text(encoding="utf-8"))
        for p in sorted(root.glob(MANUAL_GLOB)):
            self.detect[p.relative_to(root).as_posix()] = ("manual", p.read_text(encoding="utf-8"))
        for pattern in CI_GLOBS:
            for p in sorted(root.glob(pattern)):
                rel = p.relative_to(root).as_posix()
                if p.is_file() and rel not in NEVER:
                    self.detect[rel] = ("ci", p.read_text(encoding="utf-8"))
        self.renamed = {}        # old relative path -> new relative path
        self.changed = set()
        self._segments = {}

    def segments(self, rel):
        text = self.files[rel]
        key = (rel, hash(text))
        if key not in self._segments:
            segs = swift_segments(text) if rel.endswith(".swift") else [("doc", 0, len(text))]
            self._segments[key] = (segs, [s for _, s, _ in segs])
        return self._segments[key]

    def kind_at(self, rel, pos):
        segs, starts = self.segments(rel)
        i = bisect.bisect_right(starts, pos) - 1
        return segs[i] if i >= 0 else ("code", 0, 0)


def word(name):
    return re.compile(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])")


def in_backticks(text, pos):
    """True when `pos` sits inside a `code span` on its line: how prose names a member."""
    line_start = text.rfind("\n", 0, pos) + 1
    return text.count("`", line_start, pos) % 2 == 1


def is_path_literal(text):
    return ".swift" in text or "Sources/" in text or "Tests/" in text


# MARK: - Checking a row

class Row:
    def __init__(self, line_no, fields):
        self.line_no = line_no
        self.tier, self.module, self.kind, self.old, self.new, allow, self.why = fields
        self.allow = set() if allow.strip() in ("", "-") else {a.strip() for a in allow.split(",")}

    def __str__(self):
        return f"[tier {self.tier} {self.module} {self.kind}] {self.old} -> {self.new}"


def load_table(path):
    rows, errors = [], []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if fields[0] == "tier":
            continue
        if len(fields) != 7:
            errors.append(f"{path.name}:{n}: expected 7 tab-separated fields, found {len(fields)}")
            continue
        row = Row(n, fields)
        if row.kind not in KINDS:
            errors.append(f"{path.name}:{n}: unknown kind {row.kind!r}")
        if row.allow - ALLOW_TOKENS:
            errors.append(f"{path.name}:{n}: unknown allow {sorted(row.allow - ALLOW_TOKENS)}")
        if {"string", "keep-strings"} <= row.allow:
            errors.append(f"{path.name}:{n}: allow can't hold both string and keep-strings")
        rows.append(row)
    seen = Counter(r.old for r in rows if r.kind != "file")
    errors += [f"{path.name}: {old} is renamed by {count} rows" for old, count in seen.items() if count > 1]
    return rows, errors


def find_hits(tree, row):
    """Every occurrence of the old name: (rel, pos, where) with where in code/comment/doc/string/path."""
    pattern = word(row.old)
    hits = []
    for rel, text in tree.files.items():
        for m in pattern.finditer(text):
            kind, s, e = tree.kind_at(rel, m.start())
            where = kind
            if kind == "string":
                where = "path" if is_path_literal(text[s:e]) else "string"
            hits.append((rel, m.start(), where))
    return hits


def declaration_hazards(tree, row):
    """objc / intent / persisted, read from the declarations of the old name."""
    found = defaultdict(set)
    for rel, text in tree.files.items():
        if not rel.endswith(".swift") or row.old not in text:
            continue
        segs, _ = tree.segments(rel)
        code_text = masked_code(text, segs)
        if row.kind == "type":
            decl = re.compile(r"\b(struct|class|enum|actor|protocol|typealias)\s+" + re.escape(row.old) + r"\b([^{=\n]*)")
            for m in decl.finditer(code_text):
                line_start = code_text.rfind("\n", 0, m.start()) + 1
                prev_start = code_text.rfind("\n", 0, max(0, line_start - 1)) + 1
                attributes = code_text[prev_start:m.start()]
                conformances = m.group(2) or ""
                if INTENT_PROTOCOLS.search(conformances):
                    found["intent"].add(rel)
                if "@objc" in attributes or re.search(r"\bNSObject\b", conformances):
                    found["objc"].add(rel)
        else:
            decl = re.compile(r"\b(case|var|let|func)\s+(?:[A-Za-z_][\w]*\s*(?:\([^)]*\))?\s*,\s*)*"
                              + re.escape(row.old) + r"\b")
            for m in decl.finditer(code_text):
                headers = enclosing_headers(code_text, m.start())
                if not headers:
                    continue
                header = header_of(headers[-1])
                line_end = code_text.find("\n", m.end())
                rest = code_text[m.end(): line_end if line_end >= 0 else len(code_text)]
                prev = code_text[code_text.rfind("\n", 0, m.start()) + 1: m.start()]
                if "@objc" in prev:
                    found["objc"].add(rel)
                if re.search(r"\benum\s+CodingKeys\b", header):
                    found["persisted"].add(rel)
                elif m.group(1) == "case" and re.search(r"\benum\b", header):
                    raw_typed = re.search(r":\s*(String|Int|UInt8|Character)\b", header)
                    codable = re.search(r"\b(Codable|Encodable|Decodable)\b", header)
                    if (raw_typed and "=" not in rest.split(",")[0]) or (codable and not raw_typed):
                        found["persisted"].add(rel)
                elif m.group(1) in ("var", "let") and re.search(r"\b(Codable|Encodable|Decodable)\b", header):
                    computed = "{" in rest and "=" not in rest.split("{")[0]
                    if not computed and not prev.strip().startswith(("static", "private static", "public static")):
                        found["persisted"].add(rel)
    return found


def detect_hazards(tree, row):
    found = defaultdict(set)
    pattern = word(row.old)
    for rel, (hazard, text) in tree.detect.items():
        if pattern.search(text):
            found[hazard].add(rel)
    return found


# MARK: - Applying a row

def files_named_after(tree, name):
    out = {}
    for rel in list(tree.files):
        if not rel.startswith(RENAMED_FILE_ROOTS) or not rel.endswith(".swift"):
            continue
        folder, _, filename = rel.rpartition("/")
        stem = filename[:-len(".swift")]
        if stem == name or stem.startswith(name + "+"):
            out[rel] = f"{folder}/{stem.replace(name, name_placeholder(), 1)}.swift"
    return out


def name_placeholder():
    return "\0NEW\0"


def plan_identifier_row(tree, row):
    """Returns (status, hazards, edits, moves). edits: {rel: new_text}; moves: {old_rel: new_rel}."""
    hits = find_hits(tree, row)
    new_pattern = word(row.new)
    new_in_code = any(tree.kind_at(rel, m.start())[0] in ("code",)
                      for rel, text in tree.files.items() if rel.endswith(".swift")
                      for m in new_pattern.finditer(text))
    if not hits:
        new_anywhere = any(new_pattern.search(t) for t in tree.files.values())
        return ("already applied" if new_anywhere else "not found"), {}, {}, {}
    if new_in_code and not (row.kind in ("member", "case") and "shared-name" in row.allow):
        return "refused: new name already in use", {"collision": {row.new}}, {}, {}

    hazards = defaultdict(set)
    for rel, _, where in hits:
        if where in ("string", "path"):
            hazards[where].add(rel)
    for k, v in declaration_hazards(tree, row).items():
        hazards[k] |= v
    for k, v in detect_hazards(tree, row).items():
        hazards[k] |= v

    blocking = []
    for hazard in hazards:
        if hazard == "path":
            continue  # a path to a file this row renames: always rewritten with it
        if hazard == "string":
            if not ({"string", "keep-strings"} & row.allow):
                blocking.append(hazard)
        elif hazard not in row.allow:
            blocking.append(hazard)
    if blocking:
        return "refused: " + ", ".join(sorted(blocking)), hazards, {}, {}

    rename_strings = "string" in row.allow
    edits = {}
    by_file = defaultdict(list)
    for rel, pos, where in hits:
        if where == "string" and not rename_strings:
            continue
        by_file[rel].append(pos)
    for rel, positions in by_file.items():
        text = tree.files[rel]
        if row.kind in ("member", "case"):
            positions = [p for p in positions
                         if tree.kind_at(rel, p)[0] in ("code", "string") or in_backticks(text, p)]
        pieces, last = [], 0
        for pos in sorted(positions):
            pieces += [text[last:pos], row.new]
            last = pos + len(row.old)
        pieces.append(text[last:])
        edits[rel] = "".join(pieces)
    if "ci" in row.allow:
        pattern = word(row.old)
        for rel, (hazard, text) in tree.detect.items():
            if hazard == "ci" and pattern.search(text):
                edits[rel] = pattern.sub(row.new, text)
    moves = {}
    if row.kind == "type":
        moves = {old: new.replace(name_placeholder(), row.new) for old, new in files_named_after(tree, row.old).items()}
    edits = {rel: text for rel, text in edits.items()
             if text != tree.files.get(rel, tree.detect.get(rel, (None, None))[1])}
    if not edits and not moves:
        # What is left of the old name is what this row leaves alone (prose, kept strings).
        return "already applied", hazards, {}, {}
    return "ok", hazards, edits, moves


def plan_file_row(tree, row):
    old, new = row.old, row.new
    if old not in tree.files:
        return ("already applied" if new in tree.files else "not found"), {}, {}, {}
    if new in tree.files:
        return "refused: new path already exists", {"collision": {new}}, {}, {}
    hazards = defaultdict(set)
    forms = [old, old[len("Sources/"):] if old.startswith("Sources/") else None]
    old_base, new_base = old.rsplit("/", 1)[-1], new.rsplit("/", 1)[-1]
    unique_base = sum(1 for p in tree.files if p.rsplit("/", 1)[-1] == old_base) == 1
    edits = {}
    replacements = [(f, new if f == old else new[len("Sources/"):]) for f in forms if f]
    for rel, text in tree.files.items():
        updated = text
        for f, to in replacements:
            updated = updated.replace(f, to)
        if unique_base and old_base != new_base:
            updated = re.sub(r"(?<![A-Za-z0-9_+/])" + re.escape(old_base), new_base, updated)
        if updated != text:
            edits[rel] = updated
    for rel, (hazard, text) in tree.detect.items():
        if old in text or (unique_base and old_base in text):
            hazards[hazard].add(rel)
    blocking = [h for h in hazards if h not in row.allow]
    if blocking:
        return "refused: " + ", ".join(sorted(blocking)), hazards, {}, {}
    if "ci" in row.allow:
        for rel, (hazard, text) in tree.detect.items():
            if hazard == "ci":
                updated = text.replace(old, new)
                if unique_base:
                    updated = re.sub(r"(?<![A-Za-z0-9_+/])" + re.escape(old_base), new_base, updated)
                if updated != text:
                    edits[rel] = updated
    return "ok", hazards, edits, {old: new}


def commit(tree, edits, moves):
    for rel, text in edits.items():
        if rel in tree.files:
            tree.files[rel] = text
        else:
            hazard, _ = tree.detect[rel]
            tree.detect[rel] = (hazard, text)
        tree.changed.add(rel)
    for old, new in moves.items():
        tree.files[new] = tree.files.pop(old)
        origin = next((k for k, v in tree.renamed.items() if v == old), old)
        tree.renamed[origin] = new
        if old in tree.changed:
            tree.changed.discard(old)
            tree.changed.add(new)


def print_diff(before, after, rel):
    a, b = before.splitlines(), after.splitlines()
    count = 0
    for n, (x, y) in enumerate(zip(a, b), 1):
        if x != y:
            print(f"  {rel}:{n}")
            print(f"    - {x.strip()}")
            print(f"    + {y.strip()}")
            count += 1
    return count


# MARK: - Main

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="print every change and write nothing")
    parser.add_argument("--report", action="store_true", help="print each row's status and hazards, write nothing")
    parser.add_argument("--module", action="append", default=[], help="only rows of this module (repeatable)")
    parser.add_argument("--tier", action="append", default=[], help="only rows of this tier (repeatable)")
    parser.add_argument("--table", type=Path, default=TABLE)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)

    rows, errors = load_table(args.table)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 2
    if args.module:
        rows = [r for r in rows if r.module in args.module]
    if args.tier:
        rows = [r for r in rows if r.tier in args.tier]

    tree = Tree(args.root.resolve())
    status_counts, lines_changed = Counter(), 0
    refused = []
    for row in rows:
        planner = plan_file_row if row.kind == "file" else plan_identifier_row
        status, hazards, edits, moves = planner(tree, row)
        key = status.split(":")[0]
        status_counts[key] += 1
        hazard_text = "; ".join(f"{h}: {', '.join(sorted(v))}" for h, v in sorted(hazards.items())) or "-"
        if args.report:
            print(f"{row.line_no}\t{row.old}\t{row.new}\t{status}\t{hazard_text}")
        if key == "refused":
            refused.append(f"{args.table.name}:{row.line_no} {row}: {status} ({hazard_text})")
            continue
        if key != "ok":
            if args.dry_run:
                print(f"{row}: {status}")
            continue
        if args.dry_run:
            print(f"{row}")
            for rel in sorted(edits):
                before = tree.files.get(rel, tree.detect.get(rel, (None, ""))[1])
                lines_changed += print_diff(before, edits[rel], rel)
            for old, new in sorted(moves.items()):
                print(f"  rename {old} -> {new}")
        else:
            for rel in edits:
                before = tree.files.get(rel, tree.detect.get(rel, (None, ""))[1])
                lines_changed += sum(1 for x, y in zip(before.splitlines(), edits[rel].splitlines()) if x != y)
        commit(tree, edits, moves)

    if refused:
        print("\nRefused (fix the row, or add the hazard to its allow column once it's been handled):", file=sys.stderr)
        print("\n".join("  " + r for r in refused), file=sys.stderr)

    summary = (f"\n{len(rows)} rows: {status_counts['ok']} to apply, {status_counts['already applied']} already applied, "
               f"{status_counts['not found']} not found, {status_counts['refused']} refused. "
               f"{lines_changed} lines in {len(tree.changed)} files, {len(tree.renamed)} files renamed.")
    if args.dry_run or args.report:
        print(summary)
        return 0
    if refused:
        print(summary + "\nNothing written: a refused row would leave the tree half renamed.", file=sys.stderr)
        return 1
    for old in tree.renamed:
        (tree.root / old).unlink()
    for rel in tree.changed:
        path = tree.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        text = tree.files[rel] if rel in tree.files else tree.detect[rel][1]
        path.write_text(text, encoding="utf-8")
    for old, new in tree.renamed.items():
        if new not in tree.changed:
            path = tree.root / new
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(tree.files[new], encoding="utf-8")
    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
