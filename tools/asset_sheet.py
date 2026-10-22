"""Contact sheet of every map object, to check at a glance that they share one
view (top-down, facing down, nothing slanted) and one palette.

Run: python tools/asset_sheet.py [out.png]   (default: asset_sheet.png in the current folder)
Each object sits on a grass-green cell at 2x with its file name under it.
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "objects")
CELL, SCALE, COLS, LABEL = 136, 2, 8, 14


def main(out):
    names = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".png"))
    rows = (len(names) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * CELL, rows * (CELL + LABEL)), (60, 120, 60))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
        box = im.getbbox() or (0, 0, im.width, im.height)
        im = im.crop(box)
        k = min(SCALE, (CELL - 8) / max(im.width, im.height))
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.NEAREST)
        x0, y0 = (i % COLS) * CELL, (i // COLS) * (CELL + LABEL)
        draw.rectangle([x0 + 1, y0 + 1, x0 + CELL - 2, y0 + CELL - 2], fill=(92, 168, 80))
        sheet.paste(im, (x0 + (CELL - im.width) // 2, y0 + CELL - 4 - im.height), im)
        draw.text((x0 + 4, y0 + CELL), name[:22], fill=(255, 255, 255))
    sheet.save(out)
    print("%d objects -> %s" % (len(names), out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "asset_sheet.png")
