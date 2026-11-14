"""Dialogue portraits cut straight from each character's in-game south sprite,
so the face in the dialogue box is the face walking on the map.

Run: python tools/make_portraits.py --all       (every character with a sprite)
     python tools/make_portraits.py tunperak ...  (just these)

Each portrait is a 24 x 24 head-and-shoulders crop of the 36 x 36 sprite,
doubled to 48 x 48 (whole pixels, so it scales cleanly in the dialogue box).
Characters with feelings get <base>neutral.png; the other feelings
(<base>happy.png, ...) are made from that one (PixelLab edit_image) and
Game.portrait_path falls back to neutral for any feeling not drawn yet.

Alif has one set per outfit: alif_<feeling>.png for the school uniform,
alif_<skin>_<feeling>.png for the others (data/skins.json).
Kept as they are: Pau (a drawn bun, not a person sprite), and characters with
no sprite of their own or a portrait that differs on purpose (the possessed
villager, Kapten John set free).
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CROP = 24
SCALE = 2
KEEP = {"pau", "orang_awam_nirbana", "kapten_john_sedar"}


def bust(folder: str) -> Image.Image | None:
    src = os.path.join(ROOT, "assets", "characters32", folder, f"{folder}_south.png")
    if not os.path.exists(src):
        return None
    img = Image.open(src).convert("RGBA")
    box = img.getchannel("A").getbbox()
    if box is None:
        return None
    x0, y0, x1, _ = box
    left = round((x0 + x1) / 2 - CROP / 2)
    top = y0 - 1
    crop = Image.new("RGBA", (CROP, CROP), (0, 0, 0, 0))
    crop.paste(img.crop((left, top, left + CROP, top + CROP)), (0, 0))
    return crop.resize((CROP * SCALE, CROP * SCALE), Image.NEAREST)


def save(img: Image.Image, name: str) -> str:
    img.save(os.path.join(ROOT, "assets", "portraits", f"{name}.png"))
    return f"ok   {name}"


def make(cid: str, c: dict) -> list:
    if cid in KEEP:
        return [f"keep {cid}"]
    if cid == "alif":
        out = []
        skins = json.load(open(os.path.join(ROOT, "data", "skins.json"), encoding="utf-8"))["skins"]
        for s in skins:
            img = bust(str(s["folder"]))
            name = "alif_neutral" if s["id"] == "sekolah" else f"alif_{s['id']}_neutral"
            out.append(save(img, name) if img else f"skip {name}: no sprite")
        return out
    base = str(c.get("portrait", ""))
    img = bust(str(c.get("sprite", "")))
    if base == "" or img is None:
        return [f"skip {cid}: no sprite of its own"]
    return [save(img, base + "neutral" if base.endswith("_") else base)]


if __name__ == "__main__":
    chars = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
    ids = list(chars) if sys.argv[1:] == ["--all"] else sys.argv[1:]
    for cid in ids:
        for line in make(cid, chars.get(cid, {})):
            print(line)
