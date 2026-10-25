"""Contact sheet of every map object, to check at a glance that they share one
view (top-down, facing down, nothing slanted) and one palette.

Run: python tools/asset_sheet.py [out.png]   (default: asset_sheet.png in the current folder)
Each object sits on a grass-green cell at 2x with its file name under it.

     python tools/asset_sheet.py --characters [out.png]
every character's south sprite at its real size (4x, NOT fitted), Alif first,
plus its portrait: anyone drawn at a different scale or style stands out
(docs/CONTENT_CONSISTENT_DESIGN.md).
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


def characters(out):
    base = os.path.join(ROOT, "assets", "characters32")
    names = sorted(d for d in os.listdir(base)
                   if os.path.isfile(os.path.join(base, d, d + "_south.png")))
    names.sort(key=lambda n: n != "alif")
    cell, k = 36 * 4 + 8, 4
    rows = (len(names) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * cell, rows * (cell + 48 * 2 + LABEL)), (60, 120, 60))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        im = Image.open(os.path.join(base, name, name + "_south.png")).convert("RGBA")
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        x0, y0 = (i % COLS) * cell, (i // COLS) * (cell + 96 + LABEL)
        draw.rectangle([x0 + 1, y0 + 1, x0 + cell - 2, y0 + cell - 2], fill=(92, 168, 80))
        sheet.paste(im, (x0 + (cell - im.width) // 2, y0 + cell - 4 - im.height), im)
        por = os.path.join(ROOT, "assets", "portraits", name + ".png")
        if os.path.exists(por):
            p = Image.open(por).convert("RGBA").resize((96, 96), Image.NEAREST)
            sheet.paste(p, (x0 + (cell - 96) // 2, y0 + cell), p)
        draw.text((x0 + 4, y0 + cell + 96), name[:22], fill=(255, 255, 255))
    sheet.save(out)
    print("%d characters -> %s" % (len(names), out))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--characters":
        characters(sys.argv[2] if len(sys.argv) > 2 else "character_sheet.png")
    else:
        main(sys.argv[1] if len(sys.argv) > 1 else "asset_sheet.png")
