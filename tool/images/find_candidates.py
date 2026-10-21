#!/usr/bin/env python3
"""Finds candidate photos for the demo products on Wikimedia Commons and writes
one contact sheet per product, so a person can choose by eye.

    pip install pillow
    python -I tool/images/find_candidates.py --out /tmp/zaba-candidates [product-id ...]

Writes <out>/<product-id>.jpg (numbered candidates) and <out>/candidates.json.
The choice is then written into tool/images/selection.json and built by
build_images.py.
"""

import argparse
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import commons  # noqa: E402

# Search phrases per product, most specific first. Hungarian names often find
# the right dish; the English ones find more photos.
QUERIES = {
    "carbonara": ["spaghetti carbonara", "pasta carbonara plate"],
    "bolognese": ["spaghetti bolognese", "pasta bolognese plate"],
    "arrabbiata": ["penne arrabbiata", "penne tomato sauce chili"],
    "four-cheese": ["penne quattro formaggi", "pasta cheese sauce", "penne cheese sauce", "pasta gorgonzola", "macaroni and cheese"],
    "pesto": ["tagliatelle pesto", "pasta pesto basil", "trofie pesto"],
    "mushroom-tagliatelle": ["tagliatelle funghi", "pasta mushroom cream sauce", "tagliatelle mushrooms"],
    "tuna-fusilli": ["fusilli tuna", "pasta tuna tomato", "pasta al tonno"],
    "lasagne": ["lasagne", "lasagna plate"],
    "caesar": ["caesar salad chicken", "caesar salad plate"],
    "greek": ["greek salad", "horiatiki salad"],
    "tuna-salad": ["tuna salad plate", "salade niçoise", "tuna salad bowl"],
    "goat-cheese-beet": ["beetroot goat cheese salad", "beet salad goat cheese", "beetroot salad"],
    "quinoa": ["quinoa salad", "quinoa avocado salad bowl"],
    "caprese": ["insalata caprese", "caprese salad"],
    "goulash-soup": ["gulyásleves", "goulash soup Hungary", "goulash soup bowl"],
    "chicken-soup": ["húsleves", "chicken noodle soup", "chicken soup bowl"],
    "tomato-cream-soup": ["tomato cream soup", "tomato soup bowl", "paradicsomleves"],
    "mushroom-cream-soup": ["mushroom cream soup", "cream of mushroom soup", "gombaleves"],
    "vegetable-cream-soup": ["vegetable cream soup", "pumpkin cream soup", "zöldségkrémleves"],
    "fried-chicken": ["rántott csirkemell", "schnitzel", "Wiener Schnitzel plate", "chicken cutlet breaded", "rántott hús"],
    "chicken-paprikash": ["csirkepaprikás nokedli", "paprikás csirke", "chicken paprikash", "paprikash dumplings", "nokedli galuska"],
    "beef-stew": ["marhapörkölt nokedli", "pörkölt", "Hungarian beef stew", "goulash with dumplings", "beef goulash"],
    "stuffed-cabbage": ["töltött káposzta", "stuffed cabbage rolls", "cabbage rolls plate"],
    "squash-stew": ["tökfőzelék", "főzelék", "zucchini stew", "pumpkin stew dill", "vegetable stew meatballs"],
    "lecso": ["lecsó", "lecso kolbász", "lecho peppers tomato stew"],
    "layered-potato": ["rakott krumpli", "layered potato casserole", "potato casserole sausage egg"],
    "brasso": ["brassói aprópecsenye", "brassói", "pork fried potatoes garlic", "roast pork cubes potatoes plate"],
    "cheeseburger": ["cheeseburger", "hamburger cheese plate"],
    "chicken-burger": ["chicken burger", "crispy chicken burger", "chicken sandwich burger"],
    "veggie-burger": ["falafel burger", "veggie burger", "vegetarian burger"],
    "club-sandwich": ["club sandwich", "club sandwich plate"],
    "chicken-wrap": ["chicken wrap", "tortilla wrap chicken", "wrap sandwich"],
    "veggie-wrap": ["vegetable wrap hummus", "veggie wrap", "falafel wrap"],
    "curd-dumplings": ["túrógombóc", "túrógombóc tejföl", "cottage cheese dumplings"],
    "somloi": ["somlói galuska", "somloi sponge cake", "Somlói"],
    "cocoa-pancake": ["palacsinta", "pancakes chocolate", "crepes chocolate"],
    "tiramisu": ["tiramisu", "tiramisù dessert"],
    "gundel-pancake": ["gundel palacsinta", "palacsinta csokoládé dió", "crêpes chocolate sauce walnuts", "crepe chocolate sauce plate"],
    "brownie": ["chocolate brownie", "brownie walnut"],
    "water": ["glass of water", "mineral water bottle glass", "sparkling water bottle", "water glass table"],
    "lemonade": ["lemonade glass mint", "lemonade", "limonádé"],
    "cola": ["cola glass ice", "coca cola glass", "cola can glass"],
    "orange-juice": ["orange juice glass", "fresh orange juice"],
    "apple-juice": ["apple juice glass", "apple juice bottle"],
    "iced-tea": ["iced tea glass", "peach iced tea", "ice tea"],
}

SHEET_THUMB = (360, 270)


def contact_sheet(product_id, candidates):
    cols = 2
    rows = (len(candidates) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * SHEET_THUMB[0], rows * SHEET_THUMB[1]), "white")
    draw = ImageDraw.Draw(sheet)
    for index, item in enumerate(candidates):
        try:
            image = Image.open(io.BytesIO(commons.fetch_bytes(item["thumb_url"]))).convert("RGB")
        except Exception as error:  # a broken thumbnail should not stop the run
            print(f"  ! {product_id} #{index + 1}: {error}")
            continue
        image.thumbnail(SHEET_THUMB)
        x = (index % cols) * SHEET_THUMB[0]
        y = (index // cols) * SHEET_THUMB[1]
        sheet.paste(image, (x, y))
        draw.rectangle([x, y, x + 30, y + 24], fill="black")
        draw.text((x + 9, y + 6), str(index + 1), fill="white")
    return sheet


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("products", nargs="*")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    wanted = args.products or list(QUERIES)
    result = {}
    for product_id in wanted:
        seen, candidates = set(), []
        for query in QUERIES[product_id]:
            for item in commons.search(query):
                if item["title"] not in seen:
                    seen.add(item["title"])
                    candidates.append(item)
            if len(candidates) >= 6:
                break
        candidates = candidates[:6]
        result[product_id] = candidates
        print(f"{product_id}: {len(candidates)} candidates")
        if candidates:
            contact_sheet(product_id, candidates).save(args.out / f"{product_id}.jpg", quality=80)

    (args.out / "candidates.json").write_text(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
