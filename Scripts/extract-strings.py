#!/usr/bin/env python3
"""Keep Sources/KroutonApp/Resources/Localizable.xcstrings in step with the code.

Collects the interface text in Sources/KroutonApp: string literals passed to KroutonL10n.tr
and to SwiftUI's localizable initialisers and modifiers (Text, Button, Label, Toggle, .help,
.accessibilityLabel and the like).

A SwiftUI literal with interpolation, such as Text("STEP \\(n) OF \\(count)"), is looked up
under a format key: "STEP %lld OF %lld". The specifier depends on the value's type (%lld for
Int, %lf for Double, %@ for String and Text), which this script infers from the code: an
explicit `specifier:`, `Int(...)` or `.count`, or the declared type of the property named
last. KroutonL10n.tr with interpolation can never match a key and is skipped. CI compiles the
app with `-emit-localized-strings` and passes the result to --compiler-strings, so a wrong
guess fails the build instead of leaving a label in English.

  python3 Scripts/extract-strings.py           # add new strings to the catalog
  python3 Scripts/extract-strings.py --check   # fail if the catalog is missing any (CI)
  python3 Scripts/extract-strings.py --check --compiler-strings DIR
                                               # also every format key swiftc wrote to DIR

Existing entries and their translations are kept. A string no longer in the code is dropped,
unless it has translations, in which case it is kept and marked stale for a translator to
review. Xcode's String Catalog editor reads and writes the same file.
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources" / "KroutonApp"
CATALOG = SOURCES / "Resources" / "Localizable.xcstrings"

CALLS = (r"KroutonL10n\.tr|Text|Button|Label|Toggle|Picker|Section|Menu|ColorPicker|Stepper|"
         r"DisclosureGroup|TextField|SecureField|LabeledContent|GroupBox|Link|"
         r"\.help|\.navigationTitle|\.accessibilityLabel|\.accessibilityHint|\.accessibilityValue|\.badge")
CALL_START = re.compile(r"(?<![\w.])(" + CALLS + r")\(")
SPECIFIER = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|L|q|j|z|t)?[@dDiuUxXoOfFeEgGcCsSpaA]")
LITERAL = re.compile(r"\"((?:[^\"\\\n]|\\.)*)\"")
UNESCAPE = {'"': '"', "\\": "\\", "n": "\n", "t": "\t", "'": "'"}
REPO_SOURCES = ROOT / "Sources"


def unescape(raw):
    return re.sub(r"\\(.)", lambda m: UNESCAPE.get(m.group(1), m.group(0)), raw)


# MARK: - Swift string literals

def scan_literal(text, i):
    """Reads the string literal whose opening quote is at text[i]. Returns (parts, end), where
    parts alternates ("text", raw) and ("expr", source), or None for a literal that runs past
    the line (a multi-line literal, or code this scanner doesn't follow)."""
    assert text[i] == '"'
    parts, buf, i = [], [], i + 1
    while i < len(text):
        c = text[i]
        if c == "\n":
            return None
        if c == '"':
            parts.append(("text", "".join(buf)))
            return parts, i + 1
        if c == "\\" and i + 1 < len(text) and text[i + 1] == "(":
            parts.append(("text", "".join(buf)))
            buf = []
            end = skip_interpolation(text, i + 2)
            if end is None:
                return None
            parts.append(("expr", text[i + 2:end - 1]))
            i = end
            continue
        if c == "\\":
            buf.append(text[i:i + 2])
            i += 2
            continue
        buf.append(c)
        i += 1
    return None


def skip_interpolation(text, i):
    """From just after "\\(", returns the index after the matching ")", stepping over nested
    parentheses and nested string literals."""
    depth = 1
    while i < len(text) and depth:
        c = text[i]
        if c == '"':
            inner = scan_literal(text, i)
            if inner is None:
                return None
            i = inner[1]
            continue
        if c == "\n":
            return None
        depth += {"(": 1, ")": -1}.get(c, 0)
        i += 1
    return i if depth == 0 else None


# MARK: - Format specifiers

SPECIFIERS = {
    "Int": "%lld", "Int64": "%lld", "Int32": "%d", "Int16": "%d", "Int8": "%d",
    "UInt": "%llu", "UInt64": "%llu", "UInt32": "%u", "UInt16": "%u", "UInt8": "%u",
    "Double": "%lf", "CGFloat": "%lf", "TimeInterval": "%lf", "Float": "%f",
}
STRING_TAILS = re.compile(
    r"\.(?:lowercased|uppercased|capitalized|joined|formatted|description|rawValue|path|"
    r"lastPathComponent|name|title|displayName|trimmingCharacters|replacingOccurrences)\b[^.]*$")


def declared_types():
    """Names mapped to the types they most likely have, per file and for the whole package:
    from a type annotation, a function's return type, a loop or closure over integers, or the
    expression a `let` or `var` is initialised with. A name is looked up in its own file first,
    since the same name can mean different things in different files."""
    decl = re.compile(r"\b(?:let|var)\s+(\w+)\s*:\s*([A-Z]\w*)\??(?![\w.<\[!])")
    func = re.compile(r"\bfunc\s+(\w+)\s*\([^)]*\)\s*(?:throws\s*)?->\s*([A-Z]\w*)\b(?![\w.<\[?!])")
    init = re.compile(r"\b(?:let|var)\s+(\w+)\s*=\s*([^\n]+?)\s*(?:\{|else\s*\{)?\s*$", re.M)
    # A parameter such as `index: Int,` in a function or initializer signature.
    parameter = re.compile(r"(?:^|[(,])\s*(?:\w+\s+)?(\w+)\s*:\s*([A-Z]\w*)\??\s*(?=[,)=]|$)", re.M)
    integer_loops = [
        re.compile(r"\bfor\s+(\w+)\s+in\s+\(?[\w.]*\d*\s*(?:\.\.\.|\.\.<)"),
        re.compile(r"\bfor\s+\((\w+),\s*\w+\)\s+in\s+[^\n{]*\.enumerated\(\)"),
        re.compile(r"\bfor\s+(\w+)\s+in\s+[^\n{]*\.indices\b"),
        re.compile(r"ForEach\(\s*\(?[\w.]*\s*(?:\.\.\.|\.\.<)[^\n{]*\{\s*(\w+)\s+in"),
        re.compile(r"ForEach\([^\n{]*\.indices[^\n{]*\{\s*(\w+)\s+in"),
        re.compile(r"\.enumerated\(\)[^\n{]*\{\s*\(?(\w+),\s*\w+\)?\s+in"),
    ]
    package, per_file, initialisers = {}, {}, {}
    for path in REPO_SOURCES.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        local = per_file.setdefault(path, {})
        found = decl.findall(text) + func.findall(text) + parameter.findall(text)
        found += [(name, "Int") for pattern in integer_loops for name in pattern.findall(text)]
        for name, kind in found:
            local.setdefault(name, Counter())[kind] += 1
            package.setdefault(name, Counter())[kind] += 1
        initialisers[path] = init.findall(text)
    package_types = {name: most_likely(kinds) for name, kinds in package.items()}
    file_types = {}
    for path, local in per_file.items():
        types = dict(package_types)
        types.update({name: most_likely(kinds) for name, kinds in local.items()})
        guesses = {}
        for name, expression in initialisers[path]:
            if name not in local:
                guesses.setdefault(name, Counter())[value_type(expression, types, {name})] += 1
        types.update({name: most_likely(kinds) for name, kinds in guesses.items()})
        file_types[path] = types
    return file_types


def most_likely(kinds):
    """The commonest type; a name declared as a number in one place and as text in another
    (`badge`, `id`) is shown as text, which SwiftUI accepts for any value."""
    numeric = sum(n for kind, n in kinds.items() if kind in SPECIFIERS)
    if numeric and numeric < sum(kinds.values()):
        return "String"
    return kinds.most_common(1)[0][0]


def top_level_split(expr, token):
    """Splits expr at the first `token` outside parentheses, brackets and strings."""
    depth, i, quote = 0, 0, False
    while i < len(expr):
        c = expr[i]
        if c == '"':
            quote = not quote
        elif not quote:
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            elif depth == 0 and expr.startswith(token, i):
                return expr[:i], expr[i + len(token):]
        i += 1
    return None


# Expressions whose type the rules below can't see; each was checked against swiftc.
TYPE_HINTS = {
    "disc.id": "Int",
    "preset.id": "Int",
    "heroMeta.badge": "String",
    "item.seconds": "Int",
}


def value_type(expr, types, resolving=frozenset()):
    """The Swift type an interpolated expression most likely has: a key of SPECIFIERS, or
    "String" for anything shown as text."""
    expr = expr.strip()
    if expr in TYPE_HINTS:
        return TYPE_HINTS[expr]
    ternary = top_level_split(expr, " ? ")
    if ternary:
        branches = top_level_split(ternary[1], " : ")
        return value_type(branches[0] if branches else ternary[1], types, resolving)
    split = top_level_split(expr, " ?? ")
    if split:
        return value_type(split[0], types, resolving)
    for op in (" + ", " - ", " * ", " / ", " % "):
        split = top_level_split(expr, op)
        if split:
            left = value_type(split[0], types, resolving)
            right = value_type(split[1], types, resolving)
            if left in SPECIFIERS:
                return left
            if re.fullmatch(r"\d+", split[1].strip()) or re.fullmatch(r"\d+", split[0].strip()):
                return "Int"
            return right if right in SPECIFIERS else left
    if expr.startswith("(") and expr.endswith(")") and top_level_split(expr[1:-1], ",") is None:
        return value_type(expr[1:-1], types, resolving)
    if expr.startswith('"') or STRING_TAILS.search(expr):
        return "String"
    minmax = re.match(r"^(?:max|min|abs)\((.*)\)$", expr)
    if minmax:
        first = top_level_split(minmax.group(1), ",")
        return value_type(first[0] if first else minmax.group(1), types, resolving)
    call = re.match(r"^([A-Z]\w*)\(", expr)
    if call:
        return call.group(1) if call.group(1) in SPECIFIERS else "String"
    if re.search(r"\.count$", expr) or re.match(r"^-?\d+$", expr):
        return "Int"
    if re.match(r"^-?\d+\.\d+$", expr):
        return "Double"
    last = re.findall(r"(\w+)[?!]?(?:\(\))?$", expr)
    if not last or last[0] in resolving:
        return "String"
    return types.get(last[0], "String")


def specifier(expr, types):
    explicit = re.search(r",\s*specifier:\s*\"([^\"]+)\"\s*$", expr)
    if explicit:
        return explicit.group(1)
    if re.search(r",\s*(?:format|formatter|style):", expr):
        return "%@"
    return SPECIFIERS.get(value_type(expr, types), "%@")


def format_key(parts, types):
    """The key SwiftUI builds for an interpolated literal: the text, with % doubled, and a
    specifier for each value."""
    key = []
    for kind, raw in parts:
        key.append(unescape(raw).replace("%", "%%") if kind == "text" else specifier(raw, types))
    return "".join(key)


# MARK: - Collecting

def first_argument_literals(text, open_paren):
    """The string literals SwiftUI treats as localizable keys in a call's first argument: a
    literal itself, either side of a ternary or ??, inside grouping parentheses, or returned by
    a closure (`.map { "…" }`). Literals passed to another call, such as String(format:), are
    plain strings and are skipped."""
    literals, i, depth = [], open_paren + 1, 0
    while i < len(text):
        c = text[i]
        if c == '"':
            if text.startswith('"""', i):
                return literals
            scanned = scan_literal(text, i)
            if scanned is None:
                return literals
            if depth == 0:
                literals.append(scanned[0])
            i = scanned[1]
            continue
        if c == "(":
            before = text[:i].rstrip()[-1:]
            is_call = bool(before) and (before.isalnum() or before in "_)]?!>")
            depth += 1 if is_call or depth else 0
            if not is_call and not depth:
                grouping_end = skip_interpolation(text, i + 1)
                if grouping_end is None:
                    return literals
                literals.extend(first_argument_literals(text, i))
                i = grouping_end
                continue
        elif c == ")":
            if depth == 0:
                return literals
            depth -= 1
        elif c == "," and depth == 0:
            return literals
        i += 1
    return literals


def strings_in_code():
    found = {}
    file_types = declared_types()
    for path in sorted(SOURCES.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        types = file_types.get(path, {})
        where = path.relative_to(ROOT).as_posix()
        for match in CALL_START.finditer(text):
            if match.group(1) == "KroutonL10n.tr":
                continue
            for parts in first_argument_literals(text, match.end() - 1):
                if len(parts) == 1:
                    key = unescape(parts[0][1])
                    if not any(c.isalpha() for c in key):
                        continue
                else:
                    key = format_key(parts, types)
                    plain = "".join(raw for kind, raw in parts if kind == "text")
                    if not (any(c.isalpha() for c in plain) or SPECIFIER.search(key)):
                        continue
                found.setdefault(key, where)
        # Every literal inside KroutonL10n.tr(...), so tr(flag ? "A" : "B") gives both.
        for start in (m.end() for m in re.finditer(r"KroutonL10n\.tr\(", text)):
            depth, end = 1, start
            while end < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[end], 0)
                end += 1
            for raw in LITERAL.findall(text[start:end - 1]):
                if "\\(" not in raw and any(c.isalpha() for c in raw):
                    found.setdefault(unescape(raw), where)
    return found


def compiler_format_keys(folder):
    """Format keys swiftc's -emit-localized-strings wrote for the app's sources."""
    keys = {}
    for path in Path(folder).rglob("*.stringsdata"):
        data = json.loads(path.read_text(encoding="utf-8"))
        source = data.get("source", "")
        if "/Sources/KroutonApp/" not in source:
            continue
        for table, entries in data.get("tables", {}).items():
            for entry in entries:
                key = entry.get("key", "")
                if table == "Localizable" and SPECIFIER.search(key.replace("%%", "")):
                    keys.setdefault(key, source.split("/Sources/", 1)[-1])
    return keys


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
        if "--compiler-strings" in sys.argv:
            folder = sys.argv[sys.argv.index("--compiler-strings") + 1]
            compiled = compiler_format_keys(folder)
            wrong = sorted(k for k in compiled if k not in catalog.get("strings", {}))
            if not compiled:
                print(f"No .stringsdata for Sources/KroutonApp in {folder}; was the app built with -emit-localized-strings?")
                sys.exit(1)
            if wrong:
                print(f"swiftc looks up {len(wrong)} format keys the catalog doesn't have:")
                for key in wrong:
                    print(f"  {key!r}  ({compiled[key]})")
                print("The script guessed a different specifier; fix value_type() or SPECIFIERS in Scripts/extract-strings.py.")
                sys.exit(1)
            print(f"and all {len(compiled)} format keys swiftc looks up")
        return
    CATALOG.write_text(dump(merged(catalog, found)), encoding="utf-8")
    translated = sum(1 for e in catalog["strings"].values() if e.get("localizations"))
    print(f"{len(catalog['strings'])} strings in the catalog, {translated} with translations")


if __name__ == "__main__":
    main()
