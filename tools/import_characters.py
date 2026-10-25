"""Import finished PixelLab characters made to docs/CONTENT_CONSISTENT_DESIGN.md.

Run: python tools/import_characters.py tunperak=<character-uuid> pencetak=<uuid> ...
For each one it downloads the character zip and writes (overwriting):
  assets/characters32/<id>/<id>_<dir>.png              idle south/east/north
  assets/characters32/<id>_walk/<id>_walk_<dir>_<i>.png  walk south/east/north
plus west as a mirror of east (so left and right always match), any other
animation (e.g. Nirbana's "hover") as <id>_<anim>/<id>_<anim>_<dir>_<i>.png
cropped back onto the 36x36 idle canvas, then the
48x48 portrait (tools/make_portraits.py), and records the uuid in
tools/asset_manifest.json ("characters" + "mirror_west").
"""
import io
import json
import os
import sys
import urllib.request
import zipfile

from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_portraits import portrait  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "characters32")
DIRS = ["south", "east", "north"]


def save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def import_one(cid: str, uuid: str) -> str:
    url = f"https://api.pixellab.ai/mcp/characters/{uuid}/download"
    req = urllib.request.Request(url, headers={"User-Agent": "explostory-fetch"})
    with urllib.request.urlopen(req, timeout=120) as r:
        z = zipfile.ZipFile(io.BytesIO(r.read()))
    meta = json.loads(z.read("metadata.json"))
    frames = meta["states"][0]["frames"]
    rot = frames["rotations"]
    for d in DIRS:
        save(Image.open(z.open(rot[d])).convert("RGBA"), os.path.join(BASE, cid, f"{cid}_{d}.png"))
    save(ImageOps.mirror(Image.open(z.open(rot["east"])).convert("RGBA")), os.path.join(BASE, cid, f"{cid}_west.png"))
    walk = frames.get("animations", {}).get("walk", {})
    wdir = os.path.join(BASE, f"{cid}_walk")
    if walk and os.path.isdir(wdir):  # drop frames left over from an older, longer cycle
        for f in os.listdir(wdir):
            os.remove(os.path.join(wdir, f))
    n = 0
    for d in DIRS:
        for i, p in enumerate(walk.get(d, [])):
            img = Image.open(z.open(p)).convert("RGBA")
            save(img, os.path.join(wdir, f"{cid}_walk_{d}_{i}.png"))
            if d == "east":
                save(ImageOps.mirror(img), os.path.join(wdir, f"{cid}_walk_west_{i}.png"))
            n += 1
    extra = []
    for anim, dirs in frames.get("animations", {}).items():
        if anim == "walk":
            continue
        adir = os.path.join(BASE, f"{cid}_{anim}")
        for d, paths in dirs.items():
            ref = Image.open(z.open(rot[d])).convert("RGBA")
            imgs = [Image.open(z.open(p)).convert("RGBA") for p in paths]
            ox, oy = _align(ref, imgs[0])
            for i, img in enumerate(imgs):
                save(img.crop((ox, oy, ox + ref.width, oy + ref.height)), os.path.join(adir, f"{cid}_{anim}_{d}_{i}.png"))
            extra.append(f"{anim} {d} {len(imgs)}f")
    return f"ok   {cid}: 4 idle, {n} walk frames, {', '.join(extra) + ', ' if extra else ''}" + portrait(cid)


def _align(ref: Image.Image, big: Image.Image) -> tuple:
    """Where the idle sprite sits inside a bigger animation canvas (its first
    frame is the idle pose): the offset with the fewest differing pixels."""
    if big.size == ref.size:
        return 0, 0
    best, at = None, (0, 0)
    rp = ref.load()
    for oy in range(big.height - ref.height + 1):
        for ox in range(big.width - ref.width + 1):
            bp = big.crop((ox, oy, ox + ref.width, oy + ref.height)).load()
            diff = sum(1 for y in range(ref.height) for x in range(ref.width)
                       if (rp[x, y][3] > 0) != (bp[x, y][3] > 0))
            if best is None or diff < best:
                best, at = diff, (ox, oy)
    return at


if __name__ == "__main__":
    pairs = [a.split("=", 1) for a in sys.argv[1:]]
    mpath = os.path.join(ROOT, "tools", "asset_manifest.json")
    m = json.load(open(mpath, encoding="utf-8"))
    for cid, uuid in pairs:
        try:
            print(import_one(cid, uuid))
        except Exception as e:  # report and continue with the rest
            print(f"FAIL {cid}: {e}")
            continue
        m["characters"][cid] = uuid
        if cid not in m["mirror_west"]:
            m["mirror_west"].append(cid)
    with open(mpath, "w", encoding="utf-8") as f:  # same layout as the existing file
        json.dump(m, f, indent=1, ensure_ascii=False)
