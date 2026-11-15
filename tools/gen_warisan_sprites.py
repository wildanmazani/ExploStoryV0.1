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


def wau():
    """Wau Bulan: the crescent under a rounded wing, tassels on the tail"""
    im, d = canvas(32, 32)
    d.pieslice([3, 1, 28, 22], 180, 360, fill=RED)       # wings
    d.polygon([(3, 11), (28, 11), (16, 17)], fill=RED)
    d.pieslice([7, 4, 24, 18], 180, 360, fill=GOLD)
    d.polygon([(9, 11), (22, 11), (16, 15)], fill=GOLD)
    d.ellipse([13, 6, 18, 11], fill=RED_D)
    d.pieslice([8, 13, 23, 28], 0, 180, fill=BLUE)        # the moon
    d.pieslice([11, 12, 20, 23], 0, 180, fill=(0, 0, 0, 0))
    d.rectangle([15, 2, 16, 26], fill=WOOD_D)             # spine
    d.line([3, 11, 1, 14], fill=GREEN)
    d.line([28, 11, 30, 14], fill=GREEN)
    d.line([15, 27, 14, 31], fill=GOLD_D)
    d.line([16, 27, 17, 31], fill=GOLD_D)
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


HULL = [(1, 4), (3, 2), (24, 3), (27, 5), (25, 9), (21, 11), (6, 11), (2, 9)]


def upih_belakang():
    """the sheath of a pinang frond from the side, open on top like a little
    boat: the rider sits inside (upih_depan is drawn over his legs)"""
    im, d = canvas(28, 13)
    d.polygon(HULL, fill=PINANG_D)
    d.polygon([(3, 4), (23, 4), (25, 5), (22, 7), (5, 7)], fill=PINANG_L)   # the pale inside
    d.line([4, 3, 23, 3], fill=PINANG)                                       # the far rim
    return outline(im)


def upih_depan():
    """the near wall of the sheath"""
    im, d = canvas(28, 13)
    d.polygon([(2, 7), (25, 7), (25, 9), (21, 11), (6, 11), (2, 9)], fill=PINANG)
    d.line([2, 7, 25, 7], fill=PINANG_L)                                     # the near rim, curled
    for x in range(6, 23, 4):                                                # the grain
        d.line([x, 8, x - 1, 10], fill=PINANG_D)
    d.line([6, 11, 21, 11], fill=PINANG_D)
    im = outline(im)
    px = im.load()
    for x in range(28):                                                      # no outline along the top: it joins the back
        for y in range(0, 7):
            px[x, y] = (0, 0, 0, 0)
    return im


def upih():
    """the whole frond for the fair's card: the sheath and the stalk the puller holds"""
    im, d = canvas(40, 16)
    d.polygon([(x, y + 3) for x, y in HULL], fill=PINANG_D)
    d.polygon([(3, 7), (23, 7), (25, 8), (22, 10), (5, 10)], fill=PINANG_L)
    d.polygon([(2, 10), (25, 10), (25, 12), (21, 14), (6, 14), (2, 12)], fill=PINANG)
    for x in range(6, 23, 4):
        d.line([x, 11, x - 1, 13], fill=PINANG_D)
    d.line([26, 8, 38, 2], fill=GREEN_D, width=2)                            # the stalk
    d.line([26, 7, 38, 1], fill=GREEN)
    for x, y in ((31, 4), (35, 2)):                                          # stubs of the leaves cut off
        d.line([x, y, x + 1, y - 2], fill=GREEN)
        d.line([x, y + 1, x + 2, y + 3], fill=GREEN)
    return outline(im)


def congkak():
    """the boat-shaped board from above: 7 + 7 houses and the two stores"""
    im, d = canvas(64, 22)
    d.rounded_rectangle([1, 3, 62, 18], radius=7, fill=WOOD)
    d.rounded_rectangle([3, 4, 60, 9], radius=4, fill=WOOD_L)
    d.rounded_rectangle([2, 15, 61, 18], radius=3, fill=WOOD_D)
    for cx in (6, 57):                                     # rumah (stores)
        d.ellipse([cx - 4, 7, cx + 4, 15], fill=WOOD_D)
        d.ellipse([cx - 3, 8, cx + 3, 14], fill=(74, 44, 24, 255))
    for i in range(7):                                     # kampung (houses)
        cx = 14 + i * 6
        for cy in (7, 14):
            d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(74, 44, 24, 255))
    for i, c in enumerate((BLUE, RED, GOLD, GREEN, CREAM, BLUE, RED)):  # a few guli
        d.point((14 + i * 6, 7), fill=c)
        d.point((14 + (6 - i) * 6, 14), fill=c)
    return outline(im)


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
    for name, fn in (("wau", wau), ("gasing", gasing), ("bola_raga", bola_raga), ("upih", upih),
                     ("congkak", congkak), ("galah", galah), ("hati", hati),
                     ("upih_belakang", upih_belakang), ("upih_depan", upih_depan)):
        save(fn(), "assets/warisan/%s.png" % name)
