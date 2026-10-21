#!/usr/bin/env python3
"""Draws the placeholder icons of the demo: a green disc with a white "Z", the
same mark as the placeholder wordmark in the app. The final logo is made at the
very end of the project (step k) and replaces these files.

    python3 tool/brand/make_placeholder_icons.py

Needs Pillow (pip install pillow). Writes into app/web and app/android, so run
it from anywhere in the repository. It overwrites the icons that are there.
"""

import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
FONT = ROOT / "app/assets/fonts/Baloo2-ExtraBold.ttf"
GREEN = (0x2F, 0x7A, 0x3E, 255)  # AppColors.green700
WHITE = (255, 255, 255, 255)
SCALE = 4  # drawn four times larger and shrunk, for smooth edges


def mark(size, shape):
    """The icon at [size] px. shape: "disc" (transparent corners), "full" (the
    whole square green, for masks the system applies itself) or "rounded"."""
    big = size * SCALE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if shape == "disc":
        margin = round(big * 0.04)
        draw.ellipse((margin, margin, big - margin, big - margin), fill=GREEN)
        letter = 0.62
    elif shape == "rounded":
        draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=round(big * 0.22), fill=GREEN)
        letter = 0.62
    else:
        draw.rectangle((0, 0, big, big), fill=GREEN)
        # Inside the "safe zone" that a mask may not cut into.
        letter = 0.46
    font = ImageFont.truetype(str(FONT), round(big * letter))
    # The letter's own box, centred, so it sits in the middle of the mark.
    left, top, right, bottom = draw.textbbox((0, 0), "Z", font=font)
    draw.text(((big - (right - left)) / 2 - left, (big - (bottom - top)) / 2 - top), "Z", font=font, fill=WHITE)
    return image.resize((size, size), Image.LANCZOS)


def save(path, size, shape, flatten=False):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    image = mark(size, shape)
    if flatten:
        # No transparency (the iOS home screen would paint it black).
        background = Image.new("RGBA", image.size, GREEN)
        background.alpha_composite(image)
        image = background
    image.convert("RGBA" if not flatten else "RGB").save(path, optimize=True)
    print(f"wrote {path.relative_to(ROOT)} ({size} px, {shape})")


save("app/web/favicon.png", 48, "disc")
save("app/web/icons/Icon-192.png", 192, "disc")
save("app/web/icons/Icon-512.png", 512, "disc")
save("app/web/icons/Icon-maskable-192.png", 192, "full")
save("app/web/icons/Icon-maskable-512.png", 512, "full")
save("app/web/icons/apple-touch-icon.png", 180, "full", flatten=True)

for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(f"app/android/app/src/main/res/mipmap-{density}/ic_launcher.png", size, "rounded")
