"""Pixel art for Pesta Warisan (the traditional games), drawn by code.

Run: python tools/gen_warisan_sprites.py   then   godot --headless --import --path .
Writes assets/warisan/*.png and assets/objects/papan_pesta.png. Same look as
the PixelLab art: small, flat colours with one highlight and one shade, and a
dark brown outline. Swap any file for PixelLab art of the same size later.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = (43, 28, 16, 255)        # outline
WOOD, WOOD_L, WOOD_D = (150, 98, 52, 255), (196, 140, 78, 255), (104, 64, 34, 255)
GOLD, GOLD_D = (255, 214, 77, 255), (214, 150, 40, 255)
RED, RED_D = (204, 62, 52, 255), (150, 38, 40, 255)
GREEN, GREEN_D = (88, 166, 76, 255), (52, 116, 60, 255)
BLUE, BLUE_D = (70, 130, 200, 255), (44, 86, 150, 255)
CREAM, CREAM_D = (246, 232, 196, 255), (214, 190, 140, 255)
ROTAN, ROTAN_D = (222, 180, 104, 255), (170, 122, 60, 255)
PINANG, PINANG_D, PINANG_L = (186, 150, 86, 255), (136, 100, 52, 255), (224, 196, 130, 255)
WHITE = (255, 255, 255, 255)


def canvas(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def outline(im):
    """a 1 px dark line round everything drawn so far"""
    src = im.copy().load()
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        px[x, y] = OUT
                        break
    return im


def save(im, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", rel, im.size)


def papan_pesta():
    """the festival gate board in Kampung Jejak: two posts, a gold board, bunting"""
    im, d = canvas(48, 48)
    for x in (5, 39):                       # posts
        d.rectangle([x, 12, x + 3, 45], fill=WOOD)
        d.line([x, 12, x, 45], fill=WOOD_L)
        d.line([x + 3, 14, x + 3, 45], fill=WOOD_D)
        d.rectangle([x - 1, 44, x + 4, 46], fill=WOOD_D)
    d.rectangle([3, 8, 44, 12], fill=WOOD_D)  # beam
    d.line([3, 8, 44, 8], fill=WOOD)
    d.rectangle([10, 14, 37, 27], fill=GOLD)  # board
    d.rectangle([10, 26, 37, 27], fill=GOLD_D)
    d.line([10, 14, 37, 14], fill=CREAM)
    # a wau and a gasing painted on the board
    d.polygon([(17, 16), (21, 20), (17, 25), (13, 20)], fill=RED)
    d.line([17, 16, 17, 25], fill=RED_D)
    d.ellipse([27, 17, 34, 22], fill=BLUE)
    d.polygon([(28, 22), (33, 22), (30, 25), (31, 25)], fill=BLUE_D)
    d.line([30, 15, 31, 16], fill=WOOD_D)
    # bunting under the beam
    cols = [RED, GREEN, BLUE, GOLD, RED, GREEN, BLUE]
    for i, c in enumerate(cols[:6]):
        x = 11 + i * 5
        d.polygon([(x, 30), (x + 2, 30), (x + 1, 33)], fill=c)
    d.line([9, 29, 38, 29], fill=CREAM_D)
    # a roof ornament: three little flags
    for x, c in ((12, RED), (23, GOLD), (34, GREEN)):
        d.line([x, 3, x, 7], fill=WOOD_D)
        d.polygon([(x + 1, 3), (x + 4, 4), (x + 1, 5)], fill=c)
    return outline(im)


def dam():
    """a draughts board from above, a few buah on it (Dam Haji)"""
    im, d = canvas(32, 32)
    d.rectangle([1, 1, 30, 30], fill=WOOD_D)
    for r in range(4):
        for c in range(4):
            dark = (r + c) % 2 == 1
            d.rectangle([4 + c * 6, 4 + r * 6, 9 + c * 6, 9 + r * 6], fill=WOOD if dark else CREAM)
    for (r, c, col, shade) in ((0, 1, RED, RED_D), (1, 2, RED, RED_D), (2, 1, GOLD, GOLD_D), (3, 2, GOLD, GOLD_D), (3, 0, GOLD, GOLD_D)):
        d.ellipse([4 + c * 6, 4 + r * 6, 9 + c * 6, 9 + r * 6], fill=shade)
        d.ellipse([5 + c * 6, 4 + r * 6, 8 + c * 6, 7 + r * 6], fill=col)
    return outline(im)


def gasing():
    """a wooden top: flat head, fat belly, an iron tip"""
    im, d = canvas(16, 20)
    d.rectangle([7, 0, 8, 3], fill=WOOD_D)                # tangkai
    d.ellipse([2, 3, 13, 12], fill=WOOD)
    d.ellipse([3, 3, 12, 8], fill=WOOD_L)
    d.line([3, 8, 12, 8], fill=RED)                        # painted band
    d.line([2, 9, 13, 9], fill=GOLD)
    d.polygon([(4, 12), (11, 12), (8, 17), (7, 17)], fill=WOOD_D)
    d.rectangle([7, 17, 8, 18], fill=(150, 156, 170, 255)) # paksi
    d.point((5, 5), fill=CREAM)
    return outline(im)


def bola_raga():
    """the woven rattan ball"""
    im, d = canvas(16, 16)
    d.ellipse([1, 1, 14, 14], fill=ROTAN)
    d.arc([1, 1, 14, 14], 20, 160, fill=ROTAN_D)
    for a in range(0, 180, 36):                            # the weave
        r = math.radians(a)
        x, y = 7.5 + 6 * math.cos(r), 7.5 + 6 * math.sin(r)
        d.line([x, y, 15 - x, 15 - y], fill=ROTAN_D)
    for x, y in ((5, 5), (10, 6), (7, 10), (4, 9), (10, 10)):  # the holes
        d.point((x, y), fill=WOOD_D)
    d.point((4, 3), fill=CREAM)
    d.point((5, 3), fill=CREAM)
    return outline(im)


def bola_bayang():
    """a soft round shadow (Sepak Raga)"""
    im, d = canvas(16, 8)
    d.ellipse([1, 1, 14, 6], fill=(0, 0, 0, 90))
    return im


def galah():
    """two bamboo poles crossed: the lines of the court"""
    im, d = canvas(32, 32)
    for (x0, y0, x1, y1) in ((3, 26, 27, 4), (4, 5, 28, 27)):
        d.line([x0, y0, x1, y1], fill=GREEN, width=3)
        d.line([x0, y0 - 1, x1, y1 - 1], fill=(150, 206, 110, 255))
        for t in (0.25, 0.5, 0.75):                        # the joints
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=GREEN_D)
    d.rectangle([13, 13, 18, 18], fill=ROTAN)              # the rattan binding
    d.line([13, 15, 18, 15], fill=ROTAN_D)
    return outline(im)


def hati():
    """a life"""
    im, d = canvas(12, 11)
    d.polygon([(1, 3), (3, 1), (5, 2), (6, 3), (7, 2), (9, 1), (10, 3), (10, 5), (6, 9), (5, 9), (1, 5)], fill=RED)
    d.point((3, 3), fill=WHITE)
    d.line([7, 7, 9, 5], fill=RED_D)
    return outline(im)


if __name__ == "__main__":
    save(papan_pesta(), "assets/objects/papan_pesta.png")
    for name, fn in (("dam", dam), ("gasing", gasing), ("bola_raga", bola_raga),
                     ("galah", galah), ("hati", hati),
                     ("bola_bayang", bola_bayang)):
        save(fn(), "assets/warisan/%s.png" % name)
