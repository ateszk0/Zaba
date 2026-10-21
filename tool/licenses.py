#!/usr/bin/env python3
"""Lists the licences of the Dart packages the app is built from, read from the
LICENSE files in the local pub cache, and writes the table into docs/licenses.md
between the two marker comments.

    python3 tool/licenses.py            # prints the table
    python3 tool/licenses.py --write    # replaces the table in docs/licenses.md

The licence is recognised from the text of the LICENSE file (a few well-known
licences, by their standard wording). Anything it cannot place is listed as
"UNKNOWN" and has to be read by a person. This is an inventory, not legal advice.

Needs `dart pub get` to have been run in app/ (it reads the pub cache).
"""

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys

repo = pathlib.Path(__file__).resolve().parent.parent
app = repo / "app"
doc = repo / "docs" / "licenses.md"
START, END = "<!-- dart-licences:start -->", "<!-- dart-licences:end -->"


def pub_cache() -> pathlib.Path:
    return pathlib.Path(os.environ.get("PUB_CACHE") or pathlib.Path.home() / ".pub-cache")


def flutter_root() -> pathlib.Path:
    flutter = shutil.which("flutter")
    if not flutter:
        sys.exit("flutter is not on the PATH")
    return pathlib.Path(flutter).resolve().parent.parent


def listed(heading: str, lines: list[str]) -> list[tuple[str, str]]:
    """The `- name version` entries (not their sub-dependencies) of a section."""
    found, inside = [], False
    for line in lines:
        if re.match(r"^[a-z ]+:$", line):
            inside = line == heading
        elif inside:
            match = re.match(r"^- (\S+) (\S+)$", line)
            if match:
                found.append((match[1], match[2]))
    return found


def shipped_packages() -> dict[str, tuple[str, bool]]:
    """name -> (version, direct), for what goes into the release build."""
    out = subprocess.run(
        ["dart", "pub", "deps", "--no-dev", "--style=list"],
        cwd=app, check=True, capture_output=True, text=True,
    ).stdout.splitlines()
    packages = {name: (version, True) for name, version in listed("dependencies:", out)}
    for name, version in listed("transitive dependencies:", out):
        packages.setdefault(name, (version, False))
    return packages


def lock_sources() -> dict[str, str]:
    """name -> where it comes from (hosted, sdk, ...), from pubspec.lock."""
    sources, name = {}, None
    for line in (app / "pubspec.lock").read_text().splitlines():
        if re.match(r"^  [A-Za-z0-9_]+:$", line):
            name = line.strip().rstrip(":")
        elif name and (m := re.match(r"^    source: (\S+)", line)):
            sources[name] = m[1]
    return sources


def classify(text: str) -> str:
    flat = re.sub(r"\s+", " ", text)
    if "Apache License" in flat and "Version 2.0" in flat:
        return "Apache-2.0"
    if "Mozilla Public License" in flat:
        return "MPL-2.0"
    if "Permission is hereby granted, free of charge" in flat:
        return "MIT"
    if "Redistribution and use in source and binary forms" in flat:
        if "Neither the name" in flat or "may be used to endorse" in flat:
            return "BSD-3-Clause"
        return "BSD-2-Clause"
    if "Permission to use, copy, modify, and/or distribute" in flat:
        return "ISC"
    return "UNKNOWN"


def licence_of(name: str, version: str, source: str) -> str:
    if source == "sdk":
        folder = flutter_root()
    else:
        folder = pub_cache() / "hosted" / "pub.dev" / f"{name}-{version}"
    files = sorted(folder.glob("LICENSE*")) + sorted(folder.glob("LICENCE*"))
    if not files:
        return "NO LICENSE FILE"
    kinds = sorted({classify(f.read_text(errors="replace")) for f in files})
    return " + ".join(kinds)


def table() -> str:
    sources = lock_sources()
    rows = []
    for name, (version, direct) in sorted(shipped_packages().items()):
        source = sources.get(name, "hosted")
        rows.append((name, version, "közvetlen" if direct else "átvitt", source, licence_of(name, version, source)))
    counts: dict[str, int] = {}
    for *_, kind in rows:
        counts[kind] = counts.get(kind, 0) + 1
    lines = [
        "Az összesítés: " + ", ".join(f"{kind}: {n}" for kind, n in sorted(counts.items())) + f" (összesen {len(rows)} csomag).",
        "",
        "| Csomag | Verzió | Függőség | Forrás | Licenc |",
        "|---|---|---|---|---|",
    ]
    lines += [f"| `{n}` | {v} | {d} | {s} | {k} |" for n, v, d, s, k in rows]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="put the table into docs/licenses.md")
    args = parser.parse_args()
    result = table()
    if not args.write:
        print(result)
        return
    text = doc.read_text()
    if START not in text or END not in text:
        sys.exit(f"{doc} has no {START} / {END} markers")
    head, rest = text.split(START, 1)
    _, tail = rest.split(END, 1)
    doc.write_text(f"{head}{START}\n{result}\n{END}{tail}")
    print(f"wrote {doc}")


main()
