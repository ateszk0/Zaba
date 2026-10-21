#!/usr/bin/env python3
"""Builds the static, Latin/Latin-Extended-subset fonts bundled in app/assets/fonts.

Why: the upstream Google variable fonts are 0.7-0.9 MB each (many scripts, many
axes). The app is Hungarian-only for now, so we instance a few static weights
and keep only the glyphs we need. That keeps the web download small and avoids
variable-font quirks. Both fonts are SIL OFL 1.1 and declare no Reserved Font
Name, so redistributing modified instances is allowed (licence texts are
shipped next to the fonts).

Usage (needs `pip install fonttools brotli`, run in isolated mode):
    python -I tool/fonts/subset_fonts.py \
        --baloo path/to/Baloo2[wght].ttf --inter path/to/Inter[opsz,wght].ttf \
        --out app/assets/fonts

Upstream: https://github.com/google/fonts/tree/main/ofl/baloo2
          https://github.com/google/fonts/tree/main/ofl/inter
"""

import argparse
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

# Basic Latin, Latin-1, Latin Extended-A (covers Hungarian ő/ű/Ő/Ű), general
# punctuation (Hungarian quotes, dashes, ellipsis), euro sign, minus sign.
UNICODES = [
    *range(0x0020, 0x007F),
    *range(0x00A0, 0x0100),
    *range(0x0100, 0x0180),
    *range(0x2010, 0x2016),
    *range(0x2018, 0x201F),
    0x2020, 0x2021, 0x2022, 0x2026, 0x2030, 0x2039, 0x203A,
    0x20AC, 0x2122, 0x2212,
]
REQUIRED_HUNGARIAN = (0x0150, 0x0151, 0x0170, 0x0171)  # Ő ő Ű ű

# (output name, axis location)
BALOO_INSTANCES = [
    ("Baloo2-SemiBold", {"wght": 600}),
    ("Baloo2-Bold", {"wght": 700}),
    ("Baloo2-ExtraBold", {"wght": 800}),
]
# opsz 14 = the text optical size; tnum is kept for aligned prices.
INTER_INSTANCES = [
    ("Inter-Regular", {"wght": 400, "opsz": 14}),
    ("Inter-Medium", {"wght": 500, "opsz": 14}),
    ("Inter-SemiBold", {"wght": 600, "opsz": 14}),
    ("Inter-Bold", {"wght": 700, "opsz": 14}),
]
LAYOUT_FEATURES = ["kern", "liga", "ccmp", "locl", "mark", "mkmk", "tnum", "case"]


def build(source: Path, instances, out_dir: Path) -> None:
    for name, location in instances:
        font = TTFont(source)
        limits = {tag: location[tag] for tag in location if tag in {a.axisTag for a in font["fvar"].axes}}
        static = instancer.instantiateVariableFont(font, limits)

        options = subset.Options()
        options.layout_features = LAYOUT_FEATURES
        options.name_IDs = [1, 2, 3, 4, 6, 13, 14]
        options.notdef_outline = True
        options.hinting = False
        options.flavor = None
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(static)

        cmap = static.getBestCmap()
        missing = [hex(c) for c in REQUIRED_HUNGARIAN if c not in cmap]
        if missing:
            raise SystemExit(f"{name}: missing Hungarian glyphs {missing}")

        target = out_dir / f"{name}.ttf"
        static.save(target)
        print(f"{target.name}: {target.stat().st_size / 1024:.1f} KB")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baloo", type=Path, required=True)
    parser.add_argument("--inter", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    build(args.baloo, BALOO_INSTANCES, args.out)
    build(args.inter, INTER_INSTANCES, args.out)


if __name__ == "__main__":
    main()
