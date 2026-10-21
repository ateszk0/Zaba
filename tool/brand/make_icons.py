#!/usr/bin/env python3
"""Draws every icon of the app, and the logo files, from the one source of the logo,
app/assets/brand/zaba-mark.svg (the Z with the scooter).

    python3 tool/brand/make_icons.py

Needs `rsvg-convert` (librsvg: `apt install librsvg2-bin`, `brew install librsvg`) and nothing
else. It overwrites the files it writes (listed below), so run it after the source changes
and commit the result. Run from anywhere in the repository.

Written:
  app/assets/brand/zaba-logo.svg      the logo as an icon: white mark on a rounded green square
  app/assets/brand/logo_mark.png      the mark in green, for inside the app (1x, 2x, 3x)
  app/web/favicon.svg, favicon.png    browser tab
  app/web/icons/                      web app icons (any and maskable), the iOS home screen icon,
                                      logo-mark.svg for the loading screen
  app/android/.../mipmap-*            Android launcher icons: the old square ones and the adaptive
                                      icon's foreground, plus the adaptive icon's definition
"""

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "app/assets/brand/zaba-mark.svg"
RES = ROOT / "app/android/app/src/main/res"

GREEN = "#28A956"   # the logo's green
WHITE = "#FFFFFF"

# The Z's own box in the source's coordinates (the stroke's extremes), and its middle.
BOX_W, BOX_H = 670.0, 726.0
MIDDLE = (777.0, 825.0)


def mark_path() -> str:
    match = re.search(r'<path[^>]* d="([^"]+)"', SOURCE.read_text())
    if not match:
        sys.exit(f"no path found in {SOURCE}")
    return match[1]


def composition(size: int, *, height: float, shape: str = "none", radius: float = 0.22) -> str:
    """A [size] x [size] picture: the mark in white, [height] being the Z's height as a fraction
    of the picture, on a green square ("full"), a rounded one ("rounded") or nothing ("none")."""
    k = height * size / BOX_H
    if shape == "full":
        ground = f'<rect width="{size}" height="{size}" fill="{GREEN}"/>'
    elif shape == "rounded":
        ground = f'<rect width="{size}" height="{size}" rx="{radius * size:g}" fill="{GREEN}"/>'
    else:
        ground = ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}">{ground}'
        f'<g transform="translate({size / 2:g} {size / 2:g}) scale({k:.6f}) translate({-MIDDLE[0]:g} {-MIDDLE[1]:g})">'
        f'<path fill="{WHITE}" d="{mark_path()}"/></g></svg>'
    )


def render(svg: str, out: pathlib.Path, *, width: int, height: int | None = None) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    command = ["rsvg-convert", "-w", str(width), "-h", str(height or width), "-o", str(out)]
    subprocess.run(command, input=svg.encode(), check=True)
    print(f"wrote {out.relative_to(ROOT)}")


def write(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print(f"wrote {path.relative_to(ROOT)}")


def main() -> None:
    try:
        subprocess.run(["rsvg-convert", "--version"], check=True, capture_output=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        sys.exit("rsvg-convert is not installed (apt install librsvg2-bin / brew install librsvg)")

    # The logo as an icon, a vector, and the same mark in green for the screens of the app.
    write(ROOT / "app/assets/brand/zaba-logo.svg", composition(1024, height=0.62, shape="rounded") + "\n")
    green_mark = SOURCE.read_text()
    for density, scale in (("", 1), ("2.0x/", 2), ("3.0x/", 3)):
        out = ROOT / f"app/assets/brand/{density}logo_mark.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["rsvg-convert", "-h", str(64 * scale), "-o", str(out)],
            input=green_mark.encode(), check=True,
        )
        print(f"wrote {out.relative_to(ROOT)}")

    # Web. "Any" icons are rounded squares; the maskable ones fill the square, with the
    # mark inside the central circle (80 % across) that a mask may not cut into.
    write(ROOT / "app/web/favicon.svg", composition(512, height=0.66, shape="rounded") + "\n")
    write(ROOT / "app/web/icons/logo-mark.svg", green_mark)
    render(composition(512, height=0.66, shape="rounded"), ROOT / "app/web/favicon.png", width=48)
    for size in (192, 512):
        render(composition(size, height=0.64, shape="rounded"), ROOT / f"app/web/icons/Icon-{size}.png", width=size)
        render(composition(size, height=0.56, shape="full"), ROOT / f"app/web/icons/Icon-maskable-{size}.png", width=size)
    # iOS rounds the corners itself and paints transparency black, so: full, opaque.
    render(composition(180, height=0.62, shape="full"), ROOT / "app/web/icons/apple-touch-icon.png", width=180)

    # Android. The old launchers show a square icon as it is; from Android 8 the adaptive icon
    # is a 108 dp foreground over a background colour, of which only the middle 66 dp circle
    # is sure to stay visible, hence the smaller mark.
    for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        legacy = round(48 * scale)
        render(
            composition(512, height=0.64, shape="rounded"),
            RES / f"mipmap-{density}/ic_launcher.png", width=legacy,
        )
        layer = round(108 * scale)
        render(
            composition(512, height=0.44),
            RES / f"mipmap-{density}/ic_launcher_foreground.png", width=layer,
        )
    write(
        RES / "mipmap-anydpi-v26/ic_launcher.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
    )
    write(
        RES / "values/ic_launcher_background.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="ic_launcher_background">{GREEN}</color>\n'
        "</resources>\n",
    )


main()
