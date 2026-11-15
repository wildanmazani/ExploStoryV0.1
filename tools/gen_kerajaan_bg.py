"""Pixel pictures of the five kingdoms of Misi 1.1, drawn by code.

Run: python tools/gen_kerajaan_bg.py   then   godot --headless --import --path .
Writes assets/puzzle_bg/kerajaan_<id>.png (80 x 130). The drag-and-match puzzle
shows one behind a slot when its card lands there ("bg" on the item, see
scripts/puzzles/drag_match.gd). Swap any file for PixelLab art of the same
shape later.
"""
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 80, 130
INK = (38, 26, 20)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def canvas():
    im = Image.new("RGB", (W, H))
    return im, ImageDraw.Draw(im)


def sky(d, top, low, horizon, bands=9):
    for i in range(bands):
        y0 = int(horizon * i / bands)
        d.rectangle([0, y0, W, int(horizon * (i + 1) / bands)], fill=mix(top, low, i / (bands - 1)))


def sun(d, x, y, r, col, glow):
    d.ellipse([x - r - 3, y - r - 3, x + r + 3, y + r + 3], fill=glow)
    d.ellipse([x - r, y - r, x + r, y + r], fill=col)


def clouds(d, rnd, col, y0, y1, n=4):
    for _ in range(n):
        x, y, w = rnd.randint(-6, W - 10), rnd.randint(y0, y1), rnd.randint(10, 20)
        d.rectangle([x, y, x + w, y + 1], fill=col)
        d.rectangle([x + 3, y - 1, x + w - 4, y - 1], fill=col)


def hills(d, rnd, base, col, height, step=7):
    y = base - rnd.randint(height // 2, height)
    for x in range(0, W + step, step):
        y = max(base - height, min(base - 2, y + rnd.randint(-3, 3)))
        d.rectangle([x, y, x + step, base], fill=col)


def water(d, rnd, y0, y1, deep, light, glint):
    for y in range(y0, y1):
        d.line([0, y, W, y], fill=mix(light, deep, (y - y0) / max(1, y1 - y0)))
    for _ in range(26):
        x, y = rnd.randint(0, W - 6), rnd.randint(y0 + 1, y1 - 1)
        d.line([x, y, x + rnd.randint(2, 6), y], fill=glint)


def land(d, rnd, y0, y1, col, dark):
    d.rectangle([0, y0, W, y1], fill=col)
    for _ in range(40):
        x, y = rnd.randint(0, W - 2), rnd.randint(y0 + 1, y1)
        d.point((x, y), fill=dark)
    d.line([0, y0, W, y0], fill=dark)


def palm(d, x, y, h, trunk=(104, 72, 44), leaf=(46, 120, 62), leaf_d=(30, 84, 48)):
    for i in range(h):
        d.point((x + (i * i) // (h * 3), y - i), fill=trunk)
        d.point((x + 1 + (i * i) // (h * 3), y - i), fill=mix(trunk, INK, 0.3))
    tx, ty = x + h // 3, y - h
    for dx, dy in ((-7, 1), (-5, -3), (0, -5), (5, -3), (7, 1), (-4, 3), (4, 3)):
        d.line([tx, ty, tx + dx, ty + dy], fill=leaf)
        d.line([tx, ty + 1, tx + dx, ty + dy + 1], fill=leaf_d)


def stilt_house(d, x, y, w, wall=(150, 100, 58), roof=(92, 60, 38), roof_l=(190, 150, 84)):
    """a wooden house on posts with a steep thatch roof; (x, y) = left, ground"""
    for px in (x + 1, x + w - 2):
        d.line([px, y - 5, px, y], fill=INK)
    d.rectangle([x, y - 12, x + w - 1, y - 5], fill=wall)
    d.line([x, y - 5, x + w - 1, y - 5], fill=mix(wall, INK, 0.5))
    d.rectangle([x + w // 2 - 1, y - 10, x + w // 2, y - 6], fill=INK)
    d.polygon([(x - 2, y - 12), (x + w + 1, y - 12), (x + w // 2 + 2, y - 20), (x + w // 2 - 3, y - 20)], fill=roof)
    d.line([x - 2, y - 12, x + w + 1, y - 12], fill=roof_l)
    d.line([x + w // 2 - 3, y - 20, x + w // 2 + 2, y - 20], fill=roof_l)


def boat(d, x, y, w, hull=(96, 60, 36), sail=(238, 224, 190), mast=True):
    d.polygon([(x, y), (x + w, y), (x + w - 3, y + 3), (x + 3, y + 3)], fill=hull)
    d.line([x - 1, y - 1, x + 2, y], fill=hull)
    d.line([x + w - 2, y, x + w + 1, y - 1], fill=hull)
    if mast:
        m = x + w // 2
        d.line([m, y - w + 2, m, y], fill=INK)
        d.polygon([(m + 1, y - w + 3), (m + 1, y - 2), (m + w // 2 + 1, y - 2)], fill=sail)
        d.polygon([(m - 1, y - w + 5), (m - 1, y - 2), (m - w // 3, y - 2)], fill=mix(sail, INK, 0.2))


def frame(im):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W - 1, H - 1], outline=INK)
    return im


def funan():
    """the Mekong delta, first century: canals, houses on stilts, a brick shrine, rice"""
    rnd = random.Random(1)
    im, d = canvas()
    sky(d, (250, 196, 120), (252, 232, 170), 52)
    sun(d, 58, 30, 7, (255, 244, 200), (254, 220, 150))
    clouds(d, rnd, (255, 240, 205), 8, 34)
    hills(d, rnd, 54, (120, 150, 110), 12)
    land(d, rnd, 52, 74, (112, 156, 78), (84, 126, 62))
    # a brick shrine (prasat) on the far bank
    for i, (wd, hh) in enumerate(((16, 8), (12, 6), (8, 5), (4, 4))):
        y = 62 - sum(h for _, h in ((16, 8), (12, 6), (8, 5), (4, 4))[:i])
        d.rectangle([20 - wd // 2, y - hh, 20 + wd // 2, y], fill=(178, 98, 62) if i % 2 == 0 else (150, 78, 50))
        d.line([20 - wd // 2, y - hh, 20 + wd // 2, y - hh], fill=(214, 140, 96))
    d.rectangle([19, 57, 21, 62], fill=INK)
    palm(d, 40, 66, 16)
    palm(d, 70, 70, 13)
    stilt_house(d, 48, 72, 14)
    # the canal, and rice fields in squares on the near bank
    water(d, rnd, 74, 100, (58, 120, 136), (150, 200, 190), (230, 244, 226))
    boat(d, 12, 84, 16)
    boat(d, 50, 93, 12, mast=False)
    land(d, rnd, 100, H, (146, 176, 76), (100, 140, 60))
    for x in range(0, W, 13):
        d.line([x, 100, x + 6, H], fill=(96, 132, 58))
    for y in (108, 118):
        d.line([0, y, W, y], fill=(96, 132, 58))
    for _ in range(50):
        x, y = rnd.randint(0, W - 1), rnd.randint(102, H - 2)
        d.line([x, y, x, y - 2], fill=(210, 220, 110))
    return frame(im)


def champa():
    """the coast of central Vietnam, second century: red brick towers (kalan) above the sea"""
    rnd = random.Random(2)
    im, d = canvas()
    sky(d, (96, 170, 226), (206, 232, 244), 60)
    clouds(d, rnd, (255, 255, 255), 6, 30, 5)
    hills(d, rnd, 62, (98, 140, 150), 22, 9)
    water(d, rnd, 60, 100, (40, 110, 170), (120, 190, 220), (236, 248, 252))
    boat(d, 8, 70, 13)
    boat(d, 56, 78, 10)
    # the headland
    d.polygon([(0, 96), (20, 86), (52, 84), (80, 90), (80, H), (0, H)], fill=(120, 158, 84))
    d.line([0, 96, 20, 86, 52, 84, 80, 90], fill=(88, 124, 66))
    for _ in range(60):
        d.point((rnd.randint(0, W - 1), rnd.randint(92, H - 2)), fill=(92, 130, 66))
    # three kalan: square brick towers with stepped tops
    for cx, base, s in ((24, 100, 1.0), (46, 104, 1.35), (66, 99, 0.85)):
        w = int(12 * s)
        hh = int(20 * s)
        d.rectangle([cx - w // 2, base - hh, cx + w // 2, base], fill=(186, 92, 60))
        d.rectangle([cx + w // 4, base - hh, cx + w // 2, base], fill=(150, 68, 48))
        for k in range(1, 4):
            ww = w - k * int(3 * s)
            y = base - hh - k * int(4 * s)
            d.rectangle([cx - ww // 2, y, cx + ww // 2, y + int(4 * s)], fill=(196, 104, 68) if k % 2 else (166, 80, 54))
            d.line([cx - ww // 2, y, cx + ww // 2, y], fill=(226, 150, 104))
        d.line([cx, base - hh - int(15 * s), cx, base - hh - int(12 * s)], fill=(226, 150, 104))
        d.rectangle([cx - 1, base - int(8 * s), cx + 1, base], fill=INK)
        d.line([cx - w // 2, base - hh, cx + w // 2, base - hh], fill=(226, 150, 104))
    palm(d, 6, 112, 15)
    palm(d, 74, 120, 12)
    return frame(im)


def srivijaya():
    """the Musi at Palembang, seventh century: big trading ships, a stupa, houses over the river"""
    rnd = random.Random(3)
    im, d = canvas()
    sky(d, (250, 150, 96), (252, 214, 140), 56)
    sun(d, 20, 40, 8, (255, 236, 170), (252, 190, 120))
    clouds(d, rnd, (255, 214, 170), 8, 30)
    hills(d, rnd, 58, (110, 104, 110), 10)
    land(d, rnd, 54, 68, (96, 136, 82), (70, 106, 64))
    # a bell-shaped stupa on a stepped base
    d.rectangle([50, 60, 72, 64], fill=(170, 160, 150))
    d.rectangle([53, 56, 69, 60], fill=(190, 180, 168))
    d.ellipse([54, 42, 68, 60], fill=(206, 196, 182))
    d.rectangle([54, 52, 68, 58], fill=(206, 196, 182))
    d.rectangle([59, 38, 63, 43], fill=(190, 180, 168))
    d.line([61, 30, 61, 38], fill=(232, 196, 96))
    d.line([56, 46, 58, 58], fill=(232, 224, 210))
    palm(d, 40, 64, 14)
    stilt_house(d, 6, 67, 13)
    stilt_house(d, 24, 66, 11)
    water(d, rnd, 68, H, (120, 96, 70), (214, 170, 110), (255, 232, 180))
    # a great ship with two masts and an outrigger
    d.polygon([(10, 96), (64, 96), (58, 104), (16, 104)], fill=(88, 54, 34))
    d.polygon([(64, 96), (70, 90), (66, 98)], fill=(88, 54, 34))
    d.polygon([(10, 96), (5, 91), (9, 98)], fill=(88, 54, 34))
    d.line([10, 96, 64, 96], fill=(160, 110, 64))
    d.rectangle([28, 90, 44, 95], fill=(150, 100, 58))
    for m, h in ((24, 26), (46, 30)):
        d.line([m, 96 - h, m, 96], fill=INK)
        d.polygon([(m - 8, 96 - h + 3), (m + 9, 96 - h + 1), (m + 8, 92 - h // 3), (m - 9, 94 - h // 3)], fill=(236, 214, 170))
        d.line([m - 8, 96 - h + 8, m + 8, 96 - h + 6], fill=(196, 168, 120))
    d.line([8, 108, 66, 108], fill=(88, 54, 34))
    d.line([20, 104, 20, 108], fill=(88, 54, 34))
    d.line([54, 104, 54, 108], fill=(88, 54, 34))
    boat(d, 60, 118, 11, mast=False)
    boat(d, 4, 122, 10, mast=False)
    return frame(im)


def melaka():
    """Melaka, fifteenth century: the Sultan's wooden palace on the hill, the busy harbour"""
    rnd = random.Random(4)
    im, d = canvas()
    sky(d, (86, 160, 224), (196, 228, 244), 58)
    clouds(d, rnd, (255, 255, 255), 6, 26, 5)
    # Bukit Melaka
    d.polygon([(0, 70), (10, 52), (32, 42), (58, 44), (80, 58), (80, 76), (0, 76)], fill=(92, 144, 80))
    d.line([0, 70, 10, 52, 32, 42, 58, 44, 80, 58], fill=(68, 112, 62))
    for _ in range(50):
        d.point((rnd.randint(2, W - 2), rnd.randint(50, 74)), fill=(70, 116, 64))
    # the istana: a long wooden hall, roofs in tiers, gold on the ridges
    d.rectangle([20, 34, 60, 44], fill=(140, 84, 48))
    for x in range(22, 60, 5):
        d.line([x, 36, x, 43], fill=(96, 56, 34))
    d.line([20, 44, 60, 44], fill=(232, 196, 96))
    for i, (x0, x1, y) in enumerate(((16, 64, 34), (24, 56, 27), (32, 48, 21))):
        d.polygon([(x0, y), (x1, y), (x1 - 5, y - 6), (x0 + 5, y - 6)], fill=(120, 44, 36) if i % 2 == 0 else (150, 58, 42))
        d.line([x0, y, x1, y], fill=(232, 196, 96))
    d.line([40, 10, 40, 15], fill=(232, 196, 96))
    d.polygon([(41, 10), (46, 12), (41, 14)], fill=(232, 196, 96))
    for px in (22, 34, 46, 58):
        d.line([px, 44, px, 49], fill=(96, 56, 34))
    palm(d, 8, 62, 13)
    palm(d, 72, 66, 12)
    for x in (2, 15, 54, 66):
        stilt_house(d, x, 78, 10)
    water(d, rnd, 78, H, (36, 104, 160), (120, 190, 216), (236, 248, 252))
    d.rectangle([30, 78, 34, 92], fill=(120, 80, 48))   # the jetty
    d.line([30, 78, 30, 92], fill=(170, 124, 76))
    # a junk with ribbed red sails, and small boats
    d.polygon([(40, 104), (72, 104), (68, 110), (44, 110)], fill=(92, 56, 36))
    d.rectangle([62, 99, 72, 104], fill=(120, 76, 46))
    d.line([40, 104, 72, 104], fill=(170, 124, 76))
    for m, h, w2 in ((50, 20, 7), (62, 15, 5)):
        d.line([m, 104 - h, m, 104], fill=INK)
        d.rectangle([m - w2, 104 - h + 2, m + w2, 100], fill=(190, 64, 46))
        for y in range(104 - h + 4, 100, 3):
            d.line([m - w2, y, m + w2, y], fill=(132, 40, 34))
    boat(d, 6, 100, 13)
    boat(d, 18, 120, 11, mast=False)
    boat(d, 58, 122, 10, mast=False)
    return frame(im)


def johor():
    """the Johor river, sixteenth century: a fort of earth and timber, mangroves, dusk"""
    rnd = random.Random(5)
    im, d = canvas()
    sky(d, (96, 84, 150), (250, 170, 110), 58)
    sun(d, 56, 52, 8, (255, 220, 140), (250, 150, 96))
    clouds(d, rnd, (236, 150, 130), 10, 36, 5)
    hills(d, rnd, 60, (70, 78, 104), 14, 8)
    water(d, rnd, 58, 96, (86, 74, 120), (240, 170, 120), (255, 226, 170))
    boat(d, 50, 68, 11)
    boat(d, 8, 76, 13)
    # the bank and the kota: an earth wall, a timber palisade, a watchtower, cannon
    d.polygon([(0, 92), (30, 84), (80, 86), (80, H), (0, H)], fill=(94, 122, 76))
    d.line([0, 92, 30, 84, 80, 86], fill=(68, 92, 60))
    d.polygon([(8, 104), (72, 100), (76, 112), (4, 116)], fill=(136, 104, 70))
    d.line([8, 104, 72, 100], fill=(176, 140, 96))
    for x in range(10, 72, 3):
        top = 96 - (x % 2)
        d.line([x, top, x, 104 - (x - 8) // 16], fill=(112, 76, 46))
        d.point((x, top), fill=(190, 150, 100))
    d.rectangle([34, 76, 46, 96], fill=(124, 84, 50))
    d.line([34, 76, 34, 96], fill=(170, 124, 76))
    d.polygon([(30, 76), (50, 76), (44, 68), (36, 68)], fill=(96, 52, 40))
    d.line([30, 76, 50, 76], fill=(232, 196, 96))
    d.rectangle([38, 82, 42, 88], fill=INK)
    d.line([40, 60, 40, 68], fill=INK)
    d.polygon([(41, 60), (47, 62), (41, 64)], fill=(206, 60, 50))
    for cx in (20, 60):
        d.line([cx - 3, 99, cx + 3, 98], fill=INK)
        d.point((cx - 3, 100), fill=INK)
    stilt_house(d, 56, 96, 12)
    # mangrove in front
    for x in (4, 12, 68, 76):
        for k in (-3, 0, 3):
            d.line([x + k, 124, x, 116], fill=(64, 48, 40))
        d.ellipse([x - 6, 106, x + 6, 118], fill=(48, 92, 62))
        d.ellipse([x - 4, 104, x + 3, 112], fill=(66, 118, 76))
    d.rectangle([0, 124, W, H], fill=(70, 66, 96))
    for _ in range(14):
        x = rnd.randint(0, W - 5)
        d.line([x, rnd.randint(125, H - 2), x + 4, rnd.randint(125, H - 2)], fill=(200, 150, 130))
    return frame(im)


if __name__ == "__main__":
    out = os.path.join(ROOT, "assets", "puzzle_bg")
    os.makedirs(out, exist_ok=True)
    for name, fn in (("funan", funan), ("champa", champa), ("srivijaya", srivijaya), ("melaka", melaka), ("johor", johor)):
        fn().save(os.path.join(out, "kerajaan_%s.png" % name))
        print("wrote assets/puzzle_bg/kerajaan_%s.png" % name)
