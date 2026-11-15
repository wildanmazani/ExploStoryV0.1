"""The upih of Tarik Upih, from the artist's sheet of eight directions.

Run: python tools/make_upih_sprites.py <sheet.png>   then   godot --headless --import --path .
Takes the upih pulled to the right (top row, third), shrinks it to game pixels
and writes assets/warisan/upih.png (whole, for the fair's card),
upih_belakang.png (whole: the rider sits on it) and upih_depan.png (the near
wall of the scoop, drawn over the rider).
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIDTH = 58          # game pixels across; shown at scale 3
REGION = (880, 130, 1330, 380)   # the third upih of the top row, on a 1774 x 887 sheet


def main(sheet):
    im = Image.open(sheet).convert("RGBA")
    if im.size != (1774, 887):
        sys.exit("unexpected sheet size %s" % (im.size,))
    reg = im.crop(REGION)
    reg = reg.crop(reg.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox())
    h = round(reg.size[1] * WIDTH / reg.size[0])
    small = reg.resize((WIDTH, h), Image.LANCZOS)
    alpha = small.getchannel("A").point(lambda a: 255 if a > 110 else 0)
    rgb = small.convert("RGB").quantize(14, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    whole = Image.merge("RGBA", (*rgb.split(), alpha))
    # the near wall: in the scoop (the left part), the lower half of every column
    front = Image.new("RGBA", whole.size, (0, 0, 0, 0))
    a = alpha.load()
    src, dst = whole.load(), front.load()
    for x in range(int(WIDTH * 0.62)):
        ys = [y for y in range(h) if a[x, y]]
        if len(ys) < 5:
            continue
        cut = ys[0] + int(len(ys) * 0.5)
        for y in ys:
            if y >= cut:
                dst[x, y] = src[x, y]
    out = os.path.join(ROOT, "assets", "warisan")
    for name, pic in (("upih", whole), ("upih_belakang", whole), ("upih_depan", front)):
        pic.save(os.path.join(out, name + ".png"))
    xs = [x for x in range(WIDTH) for y in range(h) if a[x, y]]
    tip = max(xs)
    tip_y = [y for y in range(h) if a[tip, y]]
    print("size", whole.size, "stalk tip", (tip, sum(tip_y) // len(tip_y)), "scoop middle x", int(WIDTH * 0.31))


if __name__ == "__main__":
    main(sys.argv[1])
