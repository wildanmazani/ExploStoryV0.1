"""Cut the EXPLO-STORY wordmark (with the keris and the book) out of the app
icon, onto a transparent background: assets/ui/logo_explostory.png.

The wordmark sits inside a white outline. Everything that can be reached from
the edge of the crop without crossing that outline is background.

    python tools/gen_logo.py "path/to/EXPLO-STORY ICON APP.png"
"""
import pathlib
import sys
from collections import deque

from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/ui/logo_explostory.png"
CROP = (20, 290, 1004, 604)  # the wordmark in the 1024 x 1024 icon, tagline left out
WIDTH = 720                  # saved width


def is_outline(p) -> bool:
    r, g, b = p[:3]
    return min(r, g, b) > 200 and max(r, g, b) - min(r, g, b) < 45


def main(src: str) -> None:
    im = Image.open(src).convert("RGBA")
    im = im.resize((1024, 1024), Image.LANCZOS) if im.size != (1024, 1024) else im
    im = im.crop(CROP)
    w, h = im.size
    px = im.load()
    wall = [[is_outline(px[x, y]) for x in range(w)] for y in range(h)]
    outside = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or outside[y][x] or wall[y][x]:
            continue
        outside[y][x] = True
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    mask = Image.new("L", (w, h))
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            mp[x, y] = 0 if outside[y][x] else 255
    # drop specks, soften the edge a little
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    im.putalpha(mask)
    im = im.crop(im.getbbox())
    im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, optimize=True)
    print("logo:", OUT, im.size)


CAVAN_OUT = ROOT / "assets/ui/logo_cavan_tech.png"


def cavan(src: str) -> None:
    """The studio logo for the title screen: cropped to the mark, on a small
    white card with round corners (the logo is drawn for a white page)."""
    from PIL import ImageDraw, ImageOps
    im = Image.open(src).convert("RGB")
    ink = ImageOps.invert(im.convert("L")).point(lambda v: 255 if v > 18 else 0)
    x0, y0, x1, y1 = ink.getbbox()
    pad = 60
    im = im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))
    h = 160
    im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=18, fill=235)
    im.putalpha(mask)
    im.save(CAVAN_OUT, optimize=True)
    print("cavan:", CAVAN_OUT, im.size)


if __name__ == "__main__":
    # python tools/gen_logo.py <EXPLO-STORY ICON APP.png> [<CAVAN TECH LOGO.png>]
    main(sys.argv[1])
    if len(sys.argv) > 2:
        cavan(sys.argv[2])
