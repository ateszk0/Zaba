#!/usr/bin/env python3
"""Lists what the Dart code of the app declares, and checks that docs/development.md
describes all of it.

    python3 tool/dev_inventory.py                 # prints the inventory (file, type, member)
    python3 tool/dev_inventory.py --check         # fails if development.md leaves a name out
    python3 tool/dev_inventory.py --check --list  # ... and lists what is missing

The Dart sources are read with patterns, not a parser: they are formatted by `dart format`,
so a declaration of a class starts in column 0 and a member of a class in column 2. That is
all this relies on, and it is enough to catch a class, a field or a function that was added
or renamed without the guide being touched.

How the check works: development.md has one section per source file (a heading that holds the
file's path; one heading may name several files). Every name the inventory finds in a Dart
file has to appear, as a whole word, in that file's section. The usual overrides (`build`,
`dispose`, `==` and the like) are not required: they do what their name says and are described
with their class.

The other kinds of file (SQL, TypeScript, Python, shell, workflows, configuration) are checked
more loosely: every file has to be named in the guide, every object a migration creates
(table, view, function, type, index, trigger, policy), every export of a function and every
function of a script has to be mentioned somewhere in it.
"""

import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "development.md"
SOURCES = [("app/lib", "*.dart"), ("app/test", "*.dart"), ("app/tool", "*.dart")]
SKIP_DIRS = {"generated"}
COMMON = {
    "build", "dispose", "initState", "createState", "didUpdateWidget", "didChangeDependencies", "hashCode", "toString",
    "==", "main", "key", "context", "ref", "state", "call", "Function", "testExecutable",
}

TYPE_RE = re.compile(
    r"^(?:(?:abstract|final|base|sealed|interface|mixin)\s+)*"
    r"(class|enum|mixin|extension type|extension|typedef)\s+(?:const\s+)?([A-Za-z_]\w*)"
)
TOP_VALUE_RE = re.compile(r"^(?:final|const|var|late)\s+(?:[\w<>\?\[\], \.\(\)]+\s+)?([A-Za-z_]\w*)\s*=")
TOP_FUNCTION_RE = re.compile(r"^(?!class |enum |mixin |extension |typedef |import |export |part |abstract |final |const |var |late |//|@)"
                             r"[\w<>\?\[\], \.\(\)]+?\s+([A-Za-z_]\w*)\s*(?:<[^>]*>)?\(")
MEMBER_GETTER_RE = re.compile(r"^  (?:static\s+)?(?:[\w<>\?\[\], \.\(\)]+\s+)?get\s+([A-Za-z_]\w*)")
MEMBER_SETTER_RE = re.compile(r"^  (?:static\s+)?set\s+([A-Za-z_]\w*)")
MEMBER_FIELD_RE = re.compile(
    r"^  (?:static\s+)?(?:late\s+)?(?:final\s+|const\s+|var\s+)?(?:[\w<>\?\[\], \.\(\)]+\s+)?([A-Za-z_]\w*)\s*(?:=|;)"
)
MEMBER_METHOD_RE = re.compile(r"^  (?:static\s+)?(?:[\w<>\?\[\], \.\(\)]+?\s+)?([A-Za-z_]\w*)\s*(?:<[^>]*>)?\(")
ENUM_VALUE_RE = re.compile(r"^  ([a-z_]\w*)(?:\(.*\))?\s*[,;]?\s*$")


def source_files():
    for base, pattern in SOURCES:
        for path in sorted((ROOT / base).rglob(pattern)):
            if not SKIP_DIRS.intersection(path.parts):
                yield path


def inventory(path: pathlib.Path):
    """[(kind, owner, name)] for one Dart file."""
    found = []
    owner = None
    owner_kind = None
    lines = path.read_text().splitlines()
    for index, line in enumerate(lines):
        if not line or line.startswith(("//", "import ", "export ", "part ", "library ", "@", "}", ")", "]")):
            if line.startswith("}"):
                owner = owner_kind = None
            continue
        if not line.startswith(" "):
            match = TYPE_RE.match(line)
            if match:
                kind, name = match.groups()
                found.append((kind, None, name))
                owner, owner_kind = (name, kind) if "{" in line or line.rstrip().endswith(("{", "(")) or kind != "typedef" else (None, None)
                if kind == "typedef" or line.rstrip().endswith(";"):
                    owner = owner_kind = None
                continue
            match = TOP_VALUE_RE.match(line)
            if match:
                found.append(("value", None, match.group(1)))
                continue
            match = TOP_FUNCTION_RE.match(line)
            if match and not line.rstrip().endswith(";") or (match and "(" in line):
                found.append(("function", None, match.group(1)))
            continue
        if owner is None or not line.startswith("  ") or line.startswith("   "):
            continue
        stripped = line.strip()
        if stripped.startswith(("//", "@", "}", ")", "]", ".", "?", ":", "=", "&&", "||", "+", "-", "*", "/", "<", ">")):
            continue
        if owner_kind == "enum" and ENUM_VALUE_RE.match(line) and not re.match(r"^  (static|final|const|factory|late|bool|int|String|double|Future|Stream|List|Map|Set|void)\b", line):
            found.append(("enum value", owner, ENUM_VALUE_RE.match(line).group(1)))
            continue
        ctor = re.match(rf"^  (?:const\s+|factory\s+)?{re.escape(owner)}(?:\.(\w+))?\(", line)
        if ctor:
            if ctor.group(1):
                found.append(("constructor", owner, f"{owner}.{ctor.group(1)}"))
            continue
        match = MEMBER_GETTER_RE.match(line)
        if match:
            found.append(("getter", owner, match.group(1)))
            continue
        match = MEMBER_SETTER_RE.match(line)
        if match:
            found.append(("setter", owner, match.group(1)))
            continue
        if "operator" in stripped.split("(")[0]:
            continue
        # a method (has a parameter list before any '=' ) or a field
        head = stripped.split("=")[0]
        if "(" in head and not head.startswith(("return", "if ", "for ", "while ", "switch ")):
            match = MEMBER_METHOD_RE.match(line)
            if match and match.group(1) not in {"if", "for", "while", "switch", "return"}:
                found.append(("method", owner, match.group(1)))
            continue
        match = MEMBER_FIELD_RE.match(line)
        if match and match.group(1) not in {"return", "else", "case", "default", "super", "this"}:
            found.append(("field", owner, match.group(1)))
    return found


def doc_sections():
    """{source path: text of its section in development.md}"""
    if not DOC.exists():
        sys.exit(f"{DOC} does not exist")
    text = DOC.read_text()
    sections = {}
    current = []
    for line in text.splitlines():
        if re.match(r"^#{2,4}\s", line):
            # A heading that starts with a path (or a list of paths) opens a section for each.
            head = re.match(r"^#{2,4}\s+((?:`?(?:app|supabase|tool|deploy|\.github)/[^`\s,]+`?,?\s*)+)", line)
            current = re.findall(r"(?:app|supabase|tool|deploy|\.github)/[^`\s,]+", head.group(1)) if head else []
            for path in current:
                sections.setdefault(path, [])
        else:
            for path in current:
                sections[path].append(line)
    return {path: "\n".join(lines) for path, lines in sections.items()}


OTHER_FILES = [
    "supabase/migrations/*.sql", "supabase/seed/*.sql", "supabase/tests/database/*.sql", "supabase/tests/*.py",
    "supabase/functions/**/*.ts", "supabase/config.toml", "supabase/.env.example",
    "tool/**/*.py", "tool/**/*.sh", "tool/images/*.json",
    "deploy/**/*", ".github/workflows/*.yml", "config/*.example.json",
    "package.json", ".gitignore", "README.md",
]
SQL_CREATE_RE = re.compile(
    r"^\s*create\s+(?:or\s+replace\s+)?(?:unique\s+)?(table|view|materialized\s+view|function|type|index|trigger|policy)\s+"
    r"(?:if\s+not\s+exists\s+)?([\w.\"]+)", re.IGNORECASE | re.MULTILINE)
TS_EXPORT_RE = re.compile(r"^export\s+(?:async\s+)?(?:function|const|class|interface|type)\s+(\w+)", re.MULTILINE)
PY_DEF_RE = re.compile(r"^(?:def|class)\s+(\w+)", re.MULTILINE)
SH_FUNCTION_RE = re.compile(r"^\s*([A-Za-z_]\w*)\(\)\s*\{", re.MULTILINE)


def other_files():
    """The files of OTHER_FILES that git knows (or would add): ignored files and caches do not count."""
    listed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    wanted = {path for pattern in OTHER_FILES for path in ROOT.glob(pattern) if path.is_file()}
    return sorted(path for path in (ROOT / name for name in listed) if path in wanted)


def word_in(name, text):
    return re.search(rf"(?<![\w]){re.escape(name)}(?![\w])", text) is not None


def check_other(doc_text):
    """Files and names of everything that is not Dart: [(file, what)] that the guide leaves out."""
    files = other_files()
    base_count = {}
    for path in files:
        base_count[path.name] = base_count.get(path.name, 0) + 1
    chapter_two = doc_text.split("\n## 2.", 1)[-1].split("\n## 3.", 1)[0] if "\n## 2." in doc_text else doc_text
    sections = doc_sections()
    missing = []
    for path in files:
        rel = str(path.relative_to(ROOT))
        named = rel in doc_text or (base_count[path.name] == 1 and word_in(path.name, doc_text))
        if not named:
            missing.append((rel, "file"))
            continue
        if path.suffix == ".sql" and "migrations" in path.parts:
            for kind, name in SQL_CREATE_RE.findall(path.read_text()):
                short = name.strip('"').split(".")[-1]
                if not word_in(short, chapter_two):
                    missing.append((rel, f"{kind.lower()} {name}"))
        elif path.suffix == ".ts" and not path.name.endswith(".test.ts"):
            text = sections.get(rel, doc_text)
            for name in TS_EXPORT_RE.findall(path.read_text()):
                if not word_in(name, text):
                    missing.append((rel, f"export {name}"))
        elif path.suffix == ".py":
            for name in PY_DEF_RE.findall(path.read_text()):
                if not word_in(name, doc_text):
                    missing.append((rel, f"def {name}"))
        elif path.suffix == ".sh":
            for name in SH_FUNCTION_RE.findall(path.read_text()):
                if not word_in(name, doc_text):
                    missing.append((rel, f"function {name}"))
    return len(files), missing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--list", action="store_true", help="with --check: list every missing name")
    args = parser.parse_args()

    total = 0
    if not args.check:
        for path in source_files():
            rel = path.relative_to(ROOT)
            print(rel)
            for kind, owner, name in inventory(path):
                total += 1
                print(f"  {kind:11} {owner + '.' if owner else ''}{name}")
        print(f"\n{total} declarations in the Dart sources", file=sys.stderr)
        return

    sections = doc_sections()
    missing_files, missing_names, checked = [], [], 0
    for path in source_files():
        rel = str(path.relative_to(ROOT))
        text = sections.get(rel)
        if text is None:
            missing_files.append(rel)
            continue
        for kind, owner, name in inventory(path):
            short = name.split(".")[-1]
            if short in COMMON or (kind == "constructor" and False):
                continue
            checked += 1
            if not re.search(rf"(?<![\w]){re.escape(short)}(?![\w])", text):
                missing_names.append((rel, kind, f"{owner + '.' if owner else ''}{name}"))
    stale = [p for p in sections if not (ROOT / p).exists()]
    other_count, other_missing = check_other(DOC.read_text())
    print(f"{checked} Dart names checked in {len(sections)} documented sections; {other_count} other files checked")
    if missing_files:
        print(f"\n{len(missing_files)} source file(s) have no section in development.md:")
        for rel in missing_files:
            print(f"  {rel}")
    if stale:
        print(f"\n{len(stale)} section(s) describe a file that no longer exists:")
        for rel in stale:
            print(f"  {rel}")
    if missing_names:
        print(f"\n{len(missing_names)} name(s) are not mentioned in their file's section" + ("" if args.list else " (use --list)"))
        if args.list:
            for rel, kind, name in missing_names:
                print(f"  {rel}: {kind} {name}")
    if other_missing:
        print(f"\n{len(other_missing)} file(s) or name(s) outside the Dart code are not in development.md" + ("" if args.list else " (use --list)"))
        if args.list:
            for rel, what in other_missing:
                print(f"  {rel}: {what}")
    if missing_files or stale or missing_names or other_missing:
        sys.exit(1)
    print("development.md describes everything the sources declare.")


main()
