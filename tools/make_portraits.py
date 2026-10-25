"""Dialogue portraits cut straight from each character's south sprite, so the
face in the dialogue box always matches the one walking on the map
(docs/CONTENT_CONSISTENT_DESIGN.md).

Run: python tools/make_portraits.py tunperak pencetak ...   (or --all)
Writes assets/portraits/<id>.png at 48x48 (head and shoulders, nearest-neighbour).
The 64x64 PixelLab portraits (drawn from these sprites, Oct 2026) are better than
a crop, so they are skipped unless --force is given.
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = 48


def portrait(cid: str) -> str:
    src = os.path.join(ROOT, "assets", "characters32", cid, f"{cid}_south.png")
    img = Image.open(src).convert("RGBA")
    box = img.getchannel("A").getbbox()
    if box is None:
        return f"skip {cid}: empty sprite"
    out = os.path.join(ROOT, "assets", "portraits", f"{cid}.png")
    if os.path.exists(out) and Image.open(out).size == (64, 64) and "--force" not in sys.argv:
        return f"skip {cid}: has a PixelLab portrait (use --force to replace it)"
    x0, y0, x1, y1 = box
    # head and shoulders: a square from just above the head, about 70% of the body tall
    side = max(x1 - x0, round((y1 - y0) * 0.7))
    cx = (x0 + x1) / 2
    left = round(cx - side / 2)
    top = y0 - 1
    crop = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    crop.paste(img.crop((left, top, left + side, top + side)), (0, 0))
    crop.resize((OUT, OUT), Image.NEAREST).save(os.path.join(ROOT, "assets", "portraits", f"{cid}.png"))
    return f"ok   {cid} ({side}px crop)"


if __name__ == "__main__":
    ids = [a for a in sys.argv[1:] if a != "--force"]
    if ids == ["--all"]:
        chars = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
        ids = [k for k, v in chars.items() if v.get("sprite") == k and v.get("portrait") == k]
    for cid in ids:
        print(portrait(cid))
