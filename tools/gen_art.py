#!/usr/bin/env python3
"""Explo-Story placeholder pixel-art generator.

Draws every P1 placeholder asset at low resolution (the game scales them up
with nearest-neighbour filtering, so they stay crisp). Re-run any time:

    python3 tools/gen_art.py

Replace any PNG under assets/ with final art (PixelLab / Higgsfield) using the
same file name and canvas size, and the game picks it up with no code change.
See docs/ASSET_MANIFEST.md for the list, sizes and generation prompts.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets")

# ---------------------------------------------------------------- palette
P = {
    "outline": (34, 28, 40),
    "grass1": (92, 168, 72), "grass2": (110, 186, 82), "grass3": (76, 146, 62), "grass4": (132, 200, 96),
    "sand1": (226, 196, 134), "sand2": (210, 178, 118), "sand3": (238, 214, 160),
    "water1": (64, 140, 206), "water2": (88, 168, 226), "water3": (150, 210, 240), "water4": (44, 108, 176),
    "trunk": (110, 72, 44), "trunk2": (84, 54, 34),
    "leaf1": (52, 128, 64), "leaf2": (72, 156, 76), "leaf3": (110, 190, 92), "leaf4": (36, 98, 54),
    "pink1": (236, 128, 160), "pink2": (248, 168, 190), "pink3": (200, 92, 132),
    "orange1": (232, 140, 52), "orange2": (248, 180, 80), "orange3": (196, 104, 40),
    "wood1": (150, 96, 54), "wood2": (120, 74, 42), "wood3": (182, 124, 72), "wood4": (92, 56, 32),
    "roof1": (168, 66, 52), "roof2": (136, 48, 40), "roof3": (196, 92, 64),
    "stone1": (150, 150, 160), "stone2": (120, 120, 134), "stone3": (180, 182, 190),
    "cream": (246, 238, 214), "gold": (232, 186, 64), "gold2": (196, 148, 40), "gold3": (250, 220, 120),
    "red": (196, 52, 52), "red2": (150, 36, 40), "yellow": (240, 204, 64), "white": (250, 250, 246),
    "night1": (28, 32, 58), "night2": (40, 46, 82), "night3": (58, 66, 110),
    "grey1": (128, 128, 136), "grey2": (96, 96, 106), "grey3": (170, 170, 178),
    "skin1": (214, 160, 116), "skin2": (184, 128, 90), "skin3": (238, 190, 146),
    "navy": (30, 36, 51),
}

rng = random.Random(1957)


def new(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c if len(c) == 4 else c + (255,))


def rect(img, x, y, w, h, c):
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def ellipse(img, x, y, w, h, c):
    d = ImageDraw.Draw(img)
    d.ellipse([x, y, x + w - 1, y + h - 1], fill=c)


def poly(img, pts, c):
    ImageDraw.Draw(img).polygon(pts, fill=c)


def line(img, pts, c, w=1):
    ImageDraw.Draw(img).line(pts, fill=c, width=w)


def noise_fill(img, x0, y0, w, h, colors, weights=None):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            px(img, x, y, rng.choices(colors, weights)[0])


def outline_alpha(img, color=P["outline"]):
    """Add a 1px dark outline around opaque pixels (classic pixel-art look)."""
    src = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0:
                        img.putpixel((x, y), color + (255,))
                        break
    return img


# ---------------------------------------------------------------- scenery
def grass(img, x0=0, y0=0, w=None, h=None):
    w = w or img.width
    h = h or img.height
    noise_fill(img, x0, y0, w, h, [P["grass1"], P["grass2"], P["grass3"]], [6, 3, 2])
    for _ in range(w * h // 90):
        x, y = rng.randrange(x0, x0 + w), rng.randrange(y0, y0 + h)
        px(img, x, y, P["grass4"])
        px(img, x, y + 1, P["grass3"])


def flowers(img, n, area=None):
    x0, y0, w, h = area or (0, 0, img.width, img.height)
    for _ in range(n):
        x, y = rng.randrange(x0, x0 + w), rng.randrange(y0, y0 + h)
        c = rng.choice([P["white"], P["pink2"], P["yellow"]])
        px(img, x, y, c)
        px(img, x + 1, y, c)


def tree(img, x, y, kind="green", s=1.0):
    """x,y = base of trunk."""
    pal = {
        "green": (P["leaf4"], P["leaf1"], P["leaf2"], P["leaf3"]),
        "pink": (P["pink3"], P["pink1"], P["pink2"], (255, 210, 222)),
        "orange": (P["orange3"], P["orange1"], P["orange2"], (255, 214, 130)),
    }[kind]
    r = int(9 * s)
    rect(img, x - 1, y - int(6 * s), 3, int(6 * s), P["trunk"])
    px(img, x - 1, y - 1, P["trunk2"])
    cy = y - int(6 * s) - r + 2
    ellipse(img, x - r - 1, y - 3, 2 * r + 2, 5, (0, 0, 0, 60))
    for i, (ox, oy, rr) in enumerate([(0, 0, r), (-r // 2, 2, r - 2), (r // 2, 2, r - 2), (0, -r // 2, r - 3)]):
        ellipse(img, x + ox - rr, cy + oy - rr, 2 * rr, 2 * rr, pal[0])
    for ox, oy, rr in [(0, -1, r - 1), (-r // 2, 1, r - 3), (r // 2, 1, r - 3)]:
        ellipse(img, x + ox - rr, cy + oy - rr, 2 * rr, 2 * rr - 1, pal[1])
    ellipse(img, x - r // 2 - 1, cy - r // 2 - 1, r, r - 1, pal[2])
    for _ in range(int(6 * s)):
        px(img, x + rng.randint(-r // 2, r // 3), cy + rng.randint(-r // 2, 0), pal[3])


def palm(img, x, y):
    for i in range(14):
        px(img, x + (i // 5), y - i, P["trunk"])
        px(img, x + 1 + (i // 5), y - i, P["trunk2"])
    tx, ty = x + 2, y - 14
    for ang in range(0, 360, 50):
        a = math.radians(ang)
        for t in range(9):
            xx = tx + int(math.cos(a) * t)
            yy = ty + int(math.sin(a) * t * 0.6) + (t * t) // 18
            px(img, xx, yy, P["leaf1"] if t < 6 else P["leaf2"])
            px(img, xx, yy + 1, P["leaf4"])


def rock(img, x, y):
    ellipse(img, x, y, 7, 5, P["stone2"])
    ellipse(img, x + 1, y, 5, 3, P["stone1"])
    px(img, x + 2, y + 1, P["stone3"])


def path_blob(img, pts, width):
    d = ImageDraw.Draw(img)
    d.line(pts, fill=P["sand2"], width=width + 2, joint="curve")
    for p in pts:
        d.ellipse([p[0] - (width + 2) // 2, p[1] - (width + 2) // 2, p[0] + (width + 2) // 2, p[1] + (width + 2) // 2], fill=P["sand2"])
    d.line(pts, fill=P["sand1"], width=width, joint="curve")
    for p in pts:
        d.ellipse([p[0] - width // 2, p[1] - width // 2, p[0] + width // 2, p[1] + width // 2], fill=P["sand1"])
    # speckles
    for _ in range(len(pts) * width):
        p = rng.choice(pts)
        px(img, p[0] + rng.randint(-width // 3, width // 3), p[1] + rng.randint(-width // 3, width // 3), P["sand3"])


def water(img, x0, y0, w, h):
    rect(img, x0, y0, w, h, P["water1"])
    for _ in range(w * h // 40):
        x, y = rng.randrange(x0, x0 + w), rng.randrange(y0, y0 + h)
        line(img, [(x, y), (x + 3, y)], P["water2"])
    for _ in range(w * h // 160):
        x, y = rng.randrange(x0, x0 + w), rng.randrange(y0, y0 + h)
        line(img, [(x, y), (x + 2, y)], P["water3"])


def house(img, x, y, w, h, roof=P["roof1"], wall=P["wood3"], style="malay"):
    """x,y = top-left of whole house."""
    rh = h // 2
    ellipse(img, x - 2, y + h - 3, w + 4, 6, (0, 0, 0, 70))
    # stilts
    if style == "malay":
        for sx in range(x + 2, x + w - 1, max(4, w // 4)):
            rect(img, sx, y + h - 4, 2, 4, P["wood4"])
        bh = h - rh - 4
    else:
        bh = h - rh
    rect(img, x + 1, y + rh, w - 2, bh, wall)
    for yy in range(y + rh + 2, y + rh + bh, 3):
        line(img, [(x + 1, yy), (x + w - 2, yy)], P["wood1"])
    # door + windows
    dw = max(4, w // 6)
    rect(img, x + w // 2 - dw // 2, y + rh + bh - 8, dw, 8, P["wood4"])
    rect(img, x + 3, y + rh + 3, 4, 4, P["night2"])
    rect(img, x + w - 7, y + rh + 3, 4, 4, P["night2"])
    # roof (curved Malay style)
    poly(img, [(x - 3, y + rh + 1), (x + w // 2, y), (x + w + 2, y + rh + 1)], roof)
    poly(img, [(x + 2, y + rh - 1), (x + w // 2, y + 3), (x + w // 2, y + rh - 1)], P["roof3"])
    line(img, [(x - 3, y + rh + 1), (x + w + 2, y + rh + 1)], P["roof2"], 2)
    px(img, x - 4, y + rh - 1, roof)
    px(img, x + w + 3, y + rh - 1, roof)


def fort(img, x, y, w, h):
    ellipse(img, x - 2, y + h - 3, w + 4, 6, (0, 0, 0, 70))
    rect(img, x, y + 6, w, h - 6, P["wood1"])
    for yy in range(y + 8, y + h, 3):
        line(img, [(x, yy), (x + w - 1, yy)], P["wood2"])
    for tx in (x - 2, x + w - 8):
        rect(img, tx, y, 10, h, P["wood3"])
        for cx in range(tx, tx + 10, 3):
            rect(img, cx, y - 2, 2, 2, P["wood3"])
        rect(img, tx + 3, y + 5, 3, 4, P["wood4"])
    rect(img, x + w // 2 - 5, y + 2, 10, h - 2, P["wood3"])
    poly(img, [(x + w // 2 - 7, y + 3), (x + w // 2, y - 5), (x + w // 2 + 7, y + 3)], P["roof1"])
    rect(img, x + w // 2 - 3, y + h - 10, 6, 10, P["wood4"])
    ellipse(img, x + w // 2 - 3, y + h - 12, 6, 5, P["wood4"])


def flagpole(img, x, y, color, h=22, lowered=False):
    rect(img, x, y - h, 1, h, P["grey2"])
    px(img, x, y - h - 1, P["gold"])
    fy = y - h + (h - 8 if lowered else 1)
    poly(img, [(x + 1, fy), (x + 10, fy + 2), (x + 1, fy + 6)], color)


# ---------------------------------------------------------------- characters
def char_sheet(spec):
    """3 frames x 4 dirs (down, left, right, up), each 16x24."""
    W, H = 16, 24
    sheet = new(W * 3, H * 4)
    for row, d in enumerate(["down", "left", "right", "up"]):
        for f in range(3):
            fr = new(W, H)
            draw_char(fr, spec, d, f)
            outline_alpha(fr)
            sheet.alpha_composite(fr, (f * W, row * H))
    return sheet


def draw_char(img, s, d, f):
    skin, hair, shirt, shirt2, pants, shoes = s["skin"], s["hair"], s["shirt"], s["shirt2"], s["pants"], s["shoes"]
    leg = [0, 1, -1][f]
    bob = 0 if f == 0 else 1
    y0 = 1 + bob
    # legs
    if d in ("down", "up"):
        rect(img, 5, 17 + y0, 3, 5 - max(0, leg), pants)
        rect(img, 8, 17 + y0, 3, 5 - max(0, -leg), pants)
        rect(img, 5, 21 + y0 - max(0, leg), 3, 1, shoes)
        rect(img, 8, 21 + y0 - max(0, -leg), 3, 1, shoes)
    else:
        rect(img, 6 + leg, 17 + y0, 3, 4, pants)
        rect(img, 7 - leg, 17 + y0, 3, 4, pants)
        rect(img, 6 + leg, 21 + y0, 3, 1, shoes)
        rect(img, 7 - leg, 21 + y0, 3, 1, shoes)
    # sarong / samping
    if s.get("samping"):
        rect(img, 4, 15 + y0, 8, 4, s["samping"])
        line(img, [(4, 16 + y0), (11, 16 + y0)], s.get("samping2", s["samping"]))
    # body
    rect(img, 4, 10 + y0, 8, 8 if not s.get("robe") else 11, shirt)
    rect(img, 4, 10 + y0, 8, 1, shirt2)
    if s.get("collar") and d == "down":
        px(img, 7, 10 + y0, P["white"])
        px(img, 8, 10 + y0, P["white"])
    if s.get("tie") and d == "down":
        rect(img, 7, 11 + y0, 2, 4, s["tie"])
    # arms
    if d == "down" or d == "up":
        rect(img, 3, 11 + y0 + (leg if f else 0), 1, 5, shirt2)
        rect(img, 12, 11 + y0 - (leg if f else 0), 1, 5, shirt2)
        px(img, 3, 16 + y0 + (leg if f else 0), skin)
        px(img, 12, 16 + y0 - (leg if f else 0), skin)
    else:
        ax = 7 + (leg if f else 0)
        rect(img, ax, 11 + y0, 2, 5, shirt2)
        px(img, ax, 16 + y0, skin)
    # backpack
    if s.get("bag"):
        if d == "up":
            rect(img, 4, 11 + y0, 8, 6, s["bag"])
            line(img, [(5, 13 + y0), (10, 13 + y0)], P["wood4"])
        elif d == "left":
            rect(img, 10, 11 + y0, 3, 6, s["bag"])
        elif d == "right":
            rect(img, 3, 11 + y0, 3, 6, s["bag"])
        else:
            px(img, 4, 11 + y0, s["bag"])
            px(img, 11, 11 + y0, s["bag"])
    # head
    rect(img, 4, 2 + y0, 8, 8, skin)
    if d == "up":
        rect(img, 4, 1 + y0, 8, 8, hair)
    else:
        rect(img, 4, 1 + y0, 8, 3, hair)
        if d == "left":
            rect(img, 9, 1 + y0, 3, 6, hair)
        elif d == "right":
            rect(img, 4, 1 + y0, 3, 6, hair)
        else:
            px(img, 4, 4 + y0, hair)
            px(img, 11, 4 + y0, hair)
        # eyes
        ey = 5 + y0
        if d == "down":
            px(img, 6, ey, P["outline"])
            px(img, 9, ey, P["outline"])
            if s.get("glasses"):
                rect(img, 5, ey - 1, 3, 3, (60, 60, 70))
                rect(img, 8, ey - 1, 3, 3, (60, 60, 70))
                px(img, 6, ey, P["water3"])
                px(img, 9, ey, P["water3"])
                px(img, 6, ey, P["outline"])
                px(img, 9, ey, P["outline"])
            px(img, 7, 8 + y0, skin[:3] if not s.get("beard") else s["beard"])
            if s.get("beard"):
                rect(img, 5, 8 + y0, 6, 2, s["beard"])
            else:
                px(img, 7, 8 + y0, (170, 100, 80))
                px(img, 8, 8 + y0, (170, 100, 80))
        elif d == "left":
            px(img, 5, ey, P["outline"])
            if s.get("glasses"):
                rect(img, 4, ey - 1, 3, 3, (60, 60, 70))
                px(img, 5, ey, P["outline"])
            if s.get("beard"):
                rect(img, 4, 8 + y0, 4, 2, s["beard"])
        else:
            px(img, 10, ey, P["outline"])
            if s.get("glasses"):
                rect(img, 9, ey - 1, 3, 3, (60, 60, 70))
                px(img, 10, ey, P["outline"])
            if s.get("beard"):
                rect(img, 8, 8 + y0, 4, 2, s["beard"])
    # headwear
    hw = s.get("hat")
    if hw == "tengkolok":
        rect(img, 3, 0 + y0, 10, 3, s["hatc"])
        poly(img, [(9, 0 + y0), (13, -2 + y0 + 2), (12, 0 + y0)], s["hatc"])
        line(img, [(3, 2 + y0), (12, 2 + y0)], P["gold"])
    elif hw == "songkok":
        rect(img, 4, 0 + y0, 8, 3, (30, 30, 34))
    elif hw == "ming":
        rect(img, 3, 0 + y0, 10, 3, (40, 40, 48))
        rect(img, 1, 1 + y0, 2, 1, (40, 40, 48))
        rect(img, 13, 1 + y0, 2, 1, (40, 40, 48))
    elif hw == "crown":
        rect(img, 4, 0 + y0, 8, 2, P["gold"])
        for cx in (4, 7, 10):
            px(img, cx, -1 + y0 + 1, P["gold3"])
    elif hw == "turban":
        rect(img, 3, 0 + y0, 10, 3, s["hatc"])
        line(img, [(3, 1 + y0), (12, 1 + y0)], P["cream"])
    elif hw == "tudung":
        rect(img, 3, 0 + y0, 10, 4, s["hatc"])
        if d == "up":
            rect(img, 3, 0 + y0, 10, 12, s["hatc"])
        else:
            rect(img, 3, 3 + y0, 2, 8, s["hatc"])
            rect(img, 11, 3 + y0, 2, 8, s["hatc"])
            rect(img, 4, 9 + y0, 8, 3, s["hatc"])
            if d == "left":
                rect(img, 9, 3 + y0, 4, 8, s["hatc"])
            elif d == "right":
                rect(img, 3, 3 + y0, 4, 8, s["hatc"])
    elif hw == "ponytail" and d != "down":
        rect(img, 11 if d != "right" else 3, 4 + y0, 2, 5, s["hair"]) if d != "up" else rect(img, 7, 8 + y0, 2, 4, s["hair"])


SPECS = {
    "alif": dict(skin=P["skin1"], hair=(40, 30, 28), shirt=P["white"], shirt2=(220, 224, 230), pants=(46, 74, 120),
                 shoes=(30, 30, 30), bag=(214, 92, 60), glasses=True, collar=True),
    "penjaga": dict(skin=P["skin2"], hair=(220, 220, 228), shirt=(110, 70, 150), shirt2=(84, 50, 120), pants=(70, 48, 30),
                    shoes=(60, 40, 30), samping=P["gold"], samping2=P["gold2"], beard=(230, 230, 236), hat="turban", hatc=(70, 140, 150), robe=True),
    "syahbandar": dict(skin=P["skin1"], hair=(30, 24, 22), shirt=(40, 120, 110), shirt2=(30, 96, 88), pants=(60, 50, 40),
                       shoes=(50, 34, 24), samping=(168, 66, 52), samping2=(136, 48, 40), hat="songkok"),
    "tunperak": dict(skin=P["skin2"], hair=(36, 30, 28), shirt=(30, 60, 100), shirt2=(22, 44, 78), pants=(36, 36, 44),
                     shoes=(30, 24, 20), samping=P["gold"], samping2=P["gold2"], beard=(80, 70, 66), hat="tengkolok", hatc=(130, 30, 40), robe=True),
    "sapurba": dict(skin=P["skin3"], hair=(36, 30, 28), shirt=(234, 196, 70), shirt2=(204, 160, 50), pants=(150, 40, 40),
                    shoes=(110, 70, 40), samping=(150, 40, 40), samping2=(120, 30, 30), hat="crown", robe=True),
    "demang": dict(skin=P["skin2"], hair=(50, 40, 34), shirt=(90, 120, 60), shirt2=(70, 96, 46), pants=(70, 50, 34),
                   shoes=(60, 40, 30), samping=(120, 74, 42), samping2=(92, 56, 32), beard=(70, 60, 52), hat="tengkolok", hatc=(60, 90, 50)),
    "chengho": dict(skin=P["skin3"], hair=(20, 20, 24), shirt=(176, 40, 40), shirt2=(140, 30, 30), pants=(60, 30, 30),
                    shoes=(30, 30, 30), samping=P["gold"], samping2=P["gold2"], hat="ming", robe=True),
    "pelajar_1": dict(skin=P["skin1"], hair=(40, 30, 28), shirt=P["white"], shirt2=(220, 224, 230), pants=(46, 74, 120),
                      shoes=(30, 30, 30), bag=(60, 120, 200), collar=True, hat="songkok"),
    "pelajar_2": dict(skin=P["skin3"], hair=(40, 30, 28), shirt=(70, 110, 180), shirt2=(56, 90, 156), pants=(70, 110, 180),
                      shoes=(30, 30, 30), bag=(230, 120, 160), hat="tudung", hatc=(248, 248, 244), robe=True),
    "pelajar_3": dict(skin=P["skin3"], hair=(24, 20, 20), shirt=(70, 110, 180), shirt2=(56, 90, 156), pants=(70, 110, 180),
                      shoes=(30, 30, 30), bag=(240, 190, 70), hat="ponytail", robe=True),
    "pelajar_4": dict(skin=(150, 100, 70), hair=(20, 18, 18), shirt=P["white"], shirt2=(220, 224, 230), pants=(40, 60, 50),
                      shoes=(30, 30, 30), bag=(90, 160, 90), collar=True, tie=(40, 60, 120)),
    "pedagang": dict(skin=P["skin1"], hair=(40, 30, 28), shirt=(200, 140, 60), shirt2=(170, 110, 40), pants=(70, 60, 50),
                     shoes=(50, 34, 24), hat="songkok"),
}


def pau_sheet():
    """4 frames 16x16: idle, squash, stretch, happy."""
    sheet = new(64, 16)
    for i, (w, h) in enumerate([(12, 10), (14, 8), (10, 12), (12, 10)]):
        fr = new(16, 16)
        x = (16 - w) // 2
        y = 15 - h
        ellipse(fr, x, y, w, h, (250, 244, 228))
        ellipse(fr, x + 1, y + 1, w - 3, h - 4, (255, 252, 242))
        # pleats on top
        px(fr, 8, y, (226, 214, 190))
        px(fr, 7, y + 1, (226, 214, 190))
        px(fr, 9, y + 1, (226, 214, 190))
        ey = y + h // 2
        if i == 3:
            px(fr, x + 3, ey, P["outline"]); px(fr, x + 4, ey - 1, P["outline"]); px(fr, x + 5, ey, P["outline"])
            px(fr, x + w - 6, ey, P["outline"]); px(fr, x + w - 5, ey - 1, P["outline"]); px(fr, x + w - 4, ey, P["outline"])
        else:
            px(fr, x + 4, ey, P["outline"])
            px(fr, x + w - 5, ey, P["outline"])
        px(fr, x + 2, ey + 1, (246, 150, 170))
        px(fr, x + w - 3, ey + 1, (246, 150, 170))
        px(fr, x + w // 2 - 1, ey + 2, (190, 90, 90))
        outline_alpha(fr)
        sheet.alpha_composite(fr, (i * 16, 0))
    return sheet


def portrait(spec_key, expr="neutral"):
    s = SPECS.get(spec_key)
    img = new(48, 48)
    rect(img, 0, 0, 48, 48, (0, 0, 0, 0))
    if spec_key == "pau":
        ellipse(img, 6, 12, 36, 30, (250, 244, 228))
        ellipse(img, 9, 14, 28, 20, (255, 252, 242))
        for dx in (-4, 0, 4):
            line(img, [(24 + dx, 12), (24, 18)], (226, 214, 190))
        if expr == "happy":
            line(img, [(15, 27), (17, 25), (19, 27)], P["outline"], 1)
            line(img, [(29, 27), (31, 25), (33, 27)], P["outline"], 1)
        elif expr == "scared":
            rect(img, 16, 24, 3, 4, P["outline"])
            rect(img, 29, 24, 3, 4, P["outline"])
            px(img, 33, 20, P["water3"]); px(img, 33, 21, P["water3"])
        else:
            rect(img, 16, 25, 3, 3, P["outline"])
            rect(img, 29, 25, 3, 3, P["outline"])
            px(img, 16, 25, P["white"]); px(img, 29, 25, P["white"])
        ellipse(img, 11, 29, 6, 4, (246, 150, 170))
        ellipse(img, 31, 29, 6, 4, (246, 150, 170))
        if expr == "scared":
            ellipse(img, 22, 31, 4, 4, (150, 60, 60))
        else:
            line(img, [(21, 32), (24, 34), (27, 32)], (150, 60, 60), 1)
        return outline_alpha(img)
    if spec_key == "sultan":
        # silhouette from behind on the throne
        rect(img, 8, 6, 32, 42, (120, 40, 40))
        rect(img, 10, 4, 28, 4, P["gold"])
        ellipse(img, 16, 10, 16, 16, (24, 20, 30))
        rect(img, 12, 24, 24, 24, (24, 20, 30))
        rect(img, 15, 8, 18, 4, (40, 34, 44))
        return outline_alpha(img)
    skin, hair, shirt, shirt2 = s["skin"], s["hair"], s["shirt"], s["shirt2"]
    # shoulders
    ellipse(img, 6, 34, 36, 24, shirt)
    rect(img, 6, 44, 36, 4, shirt2)
    if s.get("collar"):
        poly(img, [(18, 34), (24, 40), (30, 34)], P["white"])
        poly(img, [(20, 34), (24, 38), (28, 34)], (220, 224, 230))
    if s.get("samping"):
        rect(img, 6, 44, 36, 4, s["samping"])
    if s.get("bag"):
        rect(img, 8, 36, 3, 12, s["bag"])
        rect(img, 37, 36, 3, 12, s["bag"])
    if s.get("hat") == "tudung":
        ellipse(img, 8, 2, 32, 36, s["hatc"])
        poly(img, [(8, 30), (24, 46), (40, 30), (42, 46), (6, 46)], s["hatc"])
    # neck + head
    rect(img, 20, 28, 8, 8, skin)
    ellipse(img, 13, 8, 22, 26, skin)
    # hair
    if s.get("hat") in (None, "songkok", "tie"):
        ellipse(img, 12, 6, 24, 12, hair)
        rect(img, 12, 12, 3, 8, hair)
        rect(img, 33, 12, 3, 8, hair)
    # ears
    rect(img, 11, 19, 3, 5, skin)
    rect(img, 34, 19, 3, 5, skin)
    # eyes
    ey = 20
    brow = {"neutral": 0, "worried": 1, "confused": 2, "happy": 0, "confident": -1}.get(expr, 0)
    if expr == "happy":
        line(img, [(17, ey + 1), (19, ey - 1), (21, ey + 1)], P["outline"])
        line(img, [(27, ey + 1), (29, ey - 1), (31, ey + 1)], P["outline"])
    else:
        rect(img, 18, ey - 1, 3, 3, P["outline"])
        rect(img, 27, ey - 1, 3, 3, P["outline"])
        px(img, 18, ey - 1, P["white"])
        px(img, 27, ey - 1, P["white"])
    # brows
    if brow == 1:
        line(img, [(16, ey - 4), (21, ey - 5)], hair)
        line(img, [(27, ey - 5), (32, ey - 4)], hair)
    elif brow == 2:
        line(img, [(16, ey - 4), (21, ey - 4)], hair)
        line(img, [(27, ey - 6), (32, ey - 4)], hair)
    elif brow == -1:
        line(img, [(16, ey - 5), (21, ey - 4)], hair)
        line(img, [(27, ey - 4), (32, ey - 5)], hair)
    else:
        line(img, [(16, ey - 4), (21, ey - 4)], hair)
        line(img, [(27, ey - 4), (32, ey - 4)], hair)
    if s.get("glasses"):
        for gx in (15, 25):
            ImageDraw.Draw(img).rectangle([gx, ey - 3, gx + 8, ey + 3], outline=(50, 50, 60))
        line(img, [(23, ey - 1), (25, ey - 1)], (50, 50, 60))
    # nose + mouth
    px(img, 24, 24, s["skin"] if not True else (180, 120, 90))
    if s.get("beard"):
        ellipse(img, 15, 26, 18, 10, s["beard"])
    mouth = {"happy": "smile", "confident": "smile", "worried": "flat", "confused": "wavy"}.get(expr, "flat")
    if mouth == "smile":
        line(img, [(20, 28), (24, 30), (28, 28)], (150, 70, 60))
    elif mouth == "wavy":
        line(img, [(20, 29), (22, 28), (24, 29), (26, 28), (28, 29)], (150, 70, 60))
    else:
        line(img, [(21, 29), (27, 29)], (150, 70, 60))
    if expr == "worried":
        px(img, 33, 14, P["water3"]); px(img, 33, 15, P["water3"]); px(img, 32, 16, P["water2"])
    # headwear
    hw = s.get("hat")
    if hw == "tengkolok":
        poly(img, [(11, 14), (14, 4), (34, 4), (37, 14)], s["hatc"])
        poly(img, [(30, 4), (38, 0), (36, 8)], s["hatc"])
        line(img, [(11, 13), (37, 13)], P["gold"], 2)
    elif hw == "songkok":
        rect(img, 13, 3, 22, 9, (30, 30, 34))
        line(img, [(13, 11), (34, 11)], (60, 60, 66))
    elif hw == "ming":
        rect(img, 12, 3, 24, 10, (40, 40, 48))
        rect(img, 4, 8, 8, 3, (40, 40, 48))
        rect(img, 36, 8, 8, 3, (40, 40, 48))
    elif hw == "crown":
        rect(img, 13, 6, 22, 6, P["gold"])
        for cx in (14, 22, 30):
            poly(img, [(cx, 6), (cx + 2, 0), (cx + 4, 6)], P["gold"])
        px(img, 24, 8, P["red"])
    elif hw == "turban":
        ellipse(img, 11, 1, 26, 14, s["hatc"])
        line(img, [(13, 8), (35, 6)], P["cream"], 2)
    elif hw == "tudung":
        ellipse(img, 11, 3, 26, 14, s["hatc"])
        rect(img, 10, 10, 4, 22, s["hatc"])
        rect(img, 34, 10, 4, 22, s["hatc"])
        poly(img, [(12, 30), (24, 38), (36, 30), (36, 36), (12, 36)], s["hatc"])
        line(img, [(14, 13), (34, 13)], (226, 226, 222))
    elif hw == "ponytail":
        ellipse(img, 12, 5, 24, 13, hair)
        rect(img, 12, 12, 3, 12, hair)
        rect(img, 33, 12, 3, 12, hair)
        ellipse(img, 34, 6, 8, 16, hair)
    return outline_alpha(img)


# ---------------------------------------------------------------- icons 24x24
def icon(name):
    i = new(24, 24)
    if name == "siva":
        rect(i, 8, 19, 8, 4, P["stone2"])
        rect(i, 9, 8, 6, 11, P["stone1"])
        ellipse(i, 8, 2, 8, 8, P["stone1"])
        rect(i, 5, 10, 3, 6, P["stone1"]); rect(i, 16, 10, 3, 6, P["stone1"])
        px(i, 11, 5, P["outline"]); px(i, 13, 5, P["outline"]); px(i, 12, 3, P["gold"])
        line(i, [(10, 12), (14, 12)], P["stone3"])
    elif name == "kitab":
        rect(i, 4, 5, 16, 15, P["roof2"]); rect(i, 5, 6, 14, 13, P["roof1"])
        rect(i, 6, 7, 1, 11, P["gold"]); rect(i, 9, 10, 7, 1, P["gold3"]); rect(i, 9, 13, 7, 1, P["gold3"])
        rect(i, 19, 6, 1, 13, P["cream"])
    elif name == "peta":
        poly(i, [(2, 5), (8, 3), (15, 5), (22, 3), (22, 19), (15, 21), (8, 19), (2, 21)], P["sand3"])
        line(i, [(8, 3), (8, 19)], P["sand2"]); line(i, [(15, 5), (15, 21)], P["sand2"])
        ellipse(i, 5, 8, 7, 6, P["leaf2"]); ellipse(i, 12, 11, 7, 5, P["leaf2"])
        line(i, [(4, 16), (11, 13), (18, 15)], P["water1"])
        px(i, 14, 12, P["red"]); px(i, 15, 12, P["red"])
    elif name == "prasasti":
        poly(i, [(5, 21), (5, 8), (12, 2), (19, 8), (19, 21)], P["stone2"])
        poly(i, [(6, 20), (6, 9), (12, 4), (18, 9), (18, 20)], P["stone1"])
        for yy in range(9, 19, 3):
            line(i, [(8, yy), (16, yy)], P["stone2"])
        ellipse(i, 9, 4, 6, 4, P["stone3"])
    elif name == "nobat":
        ellipse(i, 4, 6, 16, 6, P["gold"])
        rect(i, 4, 9, 16, 9, P["roof1"])
        ellipse(i, 4, 15, 16, 6, P["roof2"])
        ellipse(i, 5, 7, 14, 4, P["cream"])
        for xx in range(6, 19, 4):
            line(i, [(xx, 11), (xx + 2, 17)], P["gold"])
        line(i, [(18, 2), (14, 7)], P["wood2"], 2)
    elif name == "capmohor":
        rect(i, 9, 3, 6, 10, P["wood1"]); ellipse(i, 8, 1, 8, 5, P["wood3"])
        ellipse(i, 4, 12, 16, 10, P["gold2"]); ellipse(i, 5, 12, 14, 8, P["gold"])
        ellipse(i, 8, 14, 8, 4, P["red"])
    elif name == "gulungan":
        rect(i, 5, 6, 14, 12, P["cream"])
        rect(i, 3, 4, 3, 16, P["wood2"]); rect(i, 18, 4, 3, 16, P["wood2"])
        for yy in range(8, 17, 3):
            line(i, [(8, yy), (16, yy)], P["grey1"])
        rect(i, 11, 15, 3, 3, P["red"])
    elif name == "regalia":
        line(i, [(12, 6), (12, 22)], P["wood2"], 1)
        poly(i, [(2, 9), (12, 2), (22, 9)], P["yellow"])
        line(i, [(2, 9), (22, 9)], P["gold2"])
        for xx in range(4, 21, 4):
            px(i, xx, 10, P["gold2"])
    elif name == "kain":
        poly(i, [(3, 6), (21, 4), (20, 18), (4, 20)], P["yellow"])
        line(i, [(4, 10), (20, 9)], P["gold2"]); line(i, [(4, 15), (20, 14)], P["gold2"])
    elif name == "bendera":
        rect(i, 4, 2, 2, 20, P["grey2"])
        poly(i, [(6, 3), (21, 6), (6, 12)], P["red"])
        line(i, [(6, 7), (17, 7)], P["white"])
    elif name == "pohon":
        tmp = new(24, 24)
        tree(tmp, 12, 22, "green", 0.9)
        i = tmp
    elif name == "kapal":
        poly(i, [(2, 15), (22, 15), (19, 20), (5, 20)], P["wood2"])
        rect(i, 11, 3, 1, 12, P["wood4"])
        poly(i, [(12, 4), (20, 13), (12, 13)], P["cream"])
        poly(i, [(11, 5), (4, 13), (11, 13)], P["red"])
    elif name == "mahkota":
        rect(i, 4, 12, 16, 7, P["gold"])
        for cx in (4, 10, 16):
            poly(i, [(cx, 12), (cx + 2, 5), (cx + 4, 12)], P["gold"])
        px(i, 12, 15, P["red"]); px(i, 7, 15, P["water2"]); px(i, 17, 15, P["water2"])
    elif name == "timbangan":
        line(i, [(12, 4), (12, 20)], P["wood2"], 2)
        line(i, [(4, 7), (20, 7)], P["gold2"], 1)
        poly(i, [(2, 13), (8, 13), (5, 8)], P["gold"])
        poly(i, [(16, 13), (22, 13), (19, 8)], P["gold"])
        rect(i, 8, 20, 8, 2, P["wood2"])
    elif name == "orang":
        ellipse(i, 8, 2, 8, 8, P["skin1"])
        ellipse(i, 5, 11, 14, 12, P["water1"])
    elif name == "kunci":
        ellipse(i, 6, 3, 12, 11, P["grey2"]); ellipse(i, 9, 6, 6, 6, (0, 0, 0, 0))
        rect(i, 4, 10, 16, 11, P["gold2"]); rect(i, 5, 11, 14, 9, P["gold"])
        rect(i, 11, 13, 2, 4, P["outline"])
    elif name == "nota":
        rect(i, 4, 3, 16, 19, P["cream"]); rect(i, 4, 3, 3, 19, P["water1"])
        for yy in range(7, 19, 3):
            line(i, [(9, yy), (17, yy)], P["grey1"])
    elif name == "muzium":
        poly(i, [(2, 9), (12, 2), (22, 9)], P["stone1"])
        for xx in (4, 9, 14, 19):
            rect(i, xx, 10, 2, 9, P["stone3"])
        rect(i, 2, 19, 20, 3, P["stone2"])
    elif name == "tetapan":
        ellipse(i, 4, 4, 16, 16, P["grey2"])
        for a in range(0, 360, 45):
            r = math.radians(a)
            rect(i, 11 + int(math.cos(r) * 9), 11 + int(math.sin(r) * 9), 3, 3, P["grey2"])
        ellipse(i, 8, 8, 8, 8, P["grey3"]); ellipse(i, 10, 10, 4, 4, P["grey2"])
    elif name == "suara":
        poly(i, [(3, 9), (8, 9), (13, 4), (13, 20), (8, 15), (3, 15)], P["cream"])
        for r in (4, 7):
            ImageDraw.Draw(i).arc([13 - r, 12 - r, 13 + r + 2, 12 + r], -50, 50, fill=P["cream"])
    elif name == "syiling":
        ellipse(i, 3, 3, 18, 18, P["gold2"]); ellipse(i, 4, 4, 16, 16, P["gold"])
        ellipse(i, 7, 7, 10, 10, P["gold3"]); rect(i, 11, 8, 2, 8, P["gold2"])
    elif name == "bintang":
        pts = []
        for k in range(10):
            r = 10 if k % 2 == 0 else 4
            a = math.radians(-90 + k * 36)
            pts.append((12 + math.cos(a) * r, 12 + math.sin(a) * r))
        poly(i, pts, P["gold"])
    elif name == "pedang":
        line(i, [(5, 19), (19, 5)], P["grey3"], 2)
        line(i, [(4, 14), (10, 20)], P["gold2"], 2)
        line(i, [(3, 21), (6, 18)], P["wood2"], 2)
    elif name == "kumpulan":
        for cx, col in ((6, P["water1"]), (12, P["red"]), (18, P["leaf2"])):
            ellipse(i, cx - 3, 4, 6, 6, P["skin1"])
            ellipse(i, cx - 4, 11, 8, 10, col)
    elif name == "rakan":
        for cx, col in ((7, P["orange1"]), (17, P["water2"])):
            ellipse(i, cx - 3, 4, 7, 7, P["skin2"] if cx == 7 else P["skin3"])
            ellipse(i, cx - 4, 12, 9, 10, col)
        line(i, [(10, 15), (14, 15)], P["skin1"], 2)
    elif name == "sekolah":
        poly(i, [(2, 10), (12, 3), (22, 10)], P["roof1"])
        rect(i, 4, 10, 16, 11, P["cream"])
        rect(i, 10, 14, 4, 7, P["wood2"])
        rect(i, 6, 12, 3, 3, P["water2"]); rect(i, 15, 12, 3, 3, P["water2"])
    return outline_alpha(i) if name not in ("pohon",) else i


ICONS = ["siva", "kitab", "peta", "prasasti", "nobat", "capmohor", "gulungan", "regalia", "kain", "bendera", "pohon",
         "kapal", "mahkota", "timbangan", "orang", "kunci", "nota", "muzium", "tetapan", "suara", "syiling", "bintang",
         "pedang", "kumpulan", "rakan", "sekolah"]


# ---------------------------------------------------------------- backgrounds (320x180 unless noted)
def bg_bilik():
    img = new(320, 180, P["night2"] + (255,))
    # wall stripes
    for x in range(0, 320, 16):
        rect(img, x, 0, 1, 120, P["night1"])
    rect(img, 0, 120, 320, 60, (70, 52, 46))
    for y in range(124, 180, 8):
        line(img, [(0, y), (320, y)], (58, 42, 38))
    # window with moon
    rect(img, 30, 18, 70, 56, P["wood2"])
    rect(img, 34, 22, 62, 48, (16, 20, 44))
    for _ in range(25):
        px(img, rng.randrange(36, 94), rng.randrange(24, 68), P["white"])
    ellipse(img, 70, 28, 14, 14, (240, 236, 200))
    ellipse(img, 74, 27, 12, 12, (16, 20, 44))
    line(img, [(65, 22), (65, 70)], P["wood2"], 2)
    line(img, [(34, 46), (96, 46)], P["wood2"], 2)
    # bed
    rect(img, 230, 96, 86, 40, P["wood2"])
    rect(img, 232, 92, 82, 20, (90, 120, 170))
    rect(img, 290, 86, 22, 12, P["cream"])
    # calendar
    rect(img, 130, 24, 34, 38, P["cream"])
    rect(img, 130, 24, 34, 9, P["red"])
    for yy in range(37, 60, 6):
        for xx in range(134, 160, 6):
            rect(img, xx, yy, 4, 3, P["grey3"])
    ImageDraw.Draw(img).ellipse([145, 48, 155, 58], outline=P["red"])
    # desk
    rect(img, 100, 104, 120, 8, P["wood3"])
    rect(img, 104, 112, 6, 40, P["wood2"]); rect(img, 210, 112, 6, 40, P["wood2"])
    # books & papers
    rect(img, 118, 88, 22, 16, P["roof1"]); rect(img, 120, 84, 20, 4, (60, 110, 160)); rect(img, 116, 80, 22, 4, P["leaf1"])
    poly(img, [(150, 102), (190, 100), (194, 104), (152, 106)], P["white"])
    poly(img, [(160, 98), (196, 96), (198, 100), (162, 102)], P["cream"])
    for xx in range(164, 194, 4):
        px(img, xx, 99, P["red"])
    # lamp
    rect(img, 200, 84, 3, 20, P["grey2"])
    poly(img, [(192, 84), (210, 84), (206, 74), (196, 74)], P["yellow"])
    ImageDraw.Draw(img).polygon([(180, 104), (226, 104), (208, 84), (194, 84)], fill=(255, 230, 140, 60))
    # clock
    ellipse(img, 186, 20, 22, 22, P["cream"]); ImageDraw.Draw(img).ellipse([186, 20, 207, 41], outline=P["wood2"])
    line(img, [(197, 31), (197, 24)], P["outline"]); line(img, [(197, 31), (202, 33)], P["outline"])
    return img


def bg_bukit():
    img = new(320, 180)
    for y in range(110):
        t = y / 110
        c = (int(250 - 60 * t), int(190 - 20 * t + 30 * t), int(150 + 80 * t))
        line(img, [(0, y), (320, y)], c)
    ellipse(img, 240, 30, 36, 36, (255, 236, 170))
    for cx, cy in ((60, 30), (150, 18), (280, 60)):
        ellipse(img, cx, cy, 40, 10, (255, 240, 236))
        ellipse(img, cx + 10, cy - 5, 24, 10, (255, 248, 244))
    # distant hills
    for i, col in enumerate([(120, 170, 140), (96, 156, 100)]):
        pts = [(0, 110)] + [(x, 92 + i * 10 + int(8 * math.sin(x / 30 + i))) for x in range(0, 321, 10)] + [(320, 180), (0, 180)]
        poly(img, pts, col)
    pts = [(0, 140)] + [(x, 124 + int(10 * math.sin(x / 50))) for x in range(0, 321, 8)] + [(320, 180), (0, 180)]
    poly(img, pts, P["grass1"])
    grass(img, 0, 140, 320, 40)
    flowers(img, 40, (0, 140, 320, 40))
    # giant map board
    rect(img, 96, 52, 4, 76, P["wood4"]); rect(img, 220, 52, 4, 76, P["wood4"])
    rect(img, 88, 34, 144, 66, P["wood2"])
    rect(img, 92, 38, 136, 58, P["sand3"])
    pts = [(100, 88), (120, 70), (140, 84), (160, 62), (180, 78), (200, 56), (220, 70)]
    line(img, pts, P["sand2"], 3)
    for k, p in enumerate(pts[:7]):
        flagpole(img, p[0], p[1], P["red"] if k == 0 else P["grey1"], h=10)
    tree(img, 40, 150, "pink", 1.2)
    tree(img, 280, 156, "green", 1.3)
    palm(img, 20, 140)
    return img


FLAG_POS = [(120, 270), (215, 232), (300, 262), (352, 200), (300, 150), (370, 110), (512, 118), (580, 160), (604, 96), (560, 44)]
ZONE_POS = {"1_1": (40, 200), "1_2": (60, 312), "1_3": (150, 196), "1_4": (190, 318)}
SPECIAL_POS = {"muzium": (270, 318), "arena": (398, 240), "t5": (470, 34), "spawn": (96, 330)}


def bg_peta():
    W, H = 640, 360
    img = new(W, H)
    grass(img)
    # river
    pts = [(470, 0), (458, 40), (472, 80), (466, 116), (440, 170), (452, 230), (430, 290), (440, 340)]
    for i in range(len(pts) - 1):
        line(img, [pts[i], pts[i + 1]], P["water4"], 16)
        line(img, [pts[i], pts[i + 1]], P["water1"], 12)
    for _ in range(80):
        t = rng.random()
        k = rng.randrange(len(pts) - 1)
        x = pts[k][0] + (pts[k + 1][0] - pts[k][0]) * t
        y = pts[k][1] + (pts[k + 1][1] - pts[k][1]) * t
        px(img, x + rng.randint(-3, 3), y, P["water3"])
    def river_x(y):
        for a, b in zip(pts, pts[1:]):
            if a[1] <= y <= b[1]:
                return a[0] + (b[0] - a[0]) * (y - a[1]) / float(b[1] - a[1])
        return -100
    # sea at bottom
    water(img, 0, 340, 640, 20)
    for x in range(0, 640):
        px(img, x, 339, P["sand1"]); px(img, x, 338, P["sand1"]); px(img, x, 337, P["sand3"])
    # main path through all flags
    path_pts = [SPECIAL_POS["spawn"]] + FLAG_POS
    path_blob(img, path_pts, 9)
    # side paths to zones / buildings
    for key, zp in ZONE_POS.items():
        path_blob(img, [FLAG_POS[0], (zp[0], zp[1] + 10)], 6)
    path_blob(img, [FLAG_POS[2], (SPECIAL_POS["muzium"][0], SPECIAL_POS["muzium"][1] + 8)], 6)
    path_blob(img, [FLAG_POS[3], (SPECIAL_POS["arena"][0], SPECIAL_POS["arena"][1] + 8)], 6)
    path_blob(img, [FLAG_POS[9], SPECIAL_POS["t5"]], 6)
    # bridge over river on main path (between flag 6 and 7)
    rect(img, 446, 106, 40, 16, P["wood1"])
    for x in range(446, 486, 3):
        line(img, [(x, 106), (x, 121)], P["wood2"])
    line(img, [(446, 106), (485, 106)], P["wood4"])
    line(img, [(446, 121), (485, 121)], P["wood4"])
    # trees scattered avoiding paths
    segs = list(zip(path_pts, path_pts[1:]))
    segs += [(FLAG_POS[0], zp) for zp in ZONE_POS.values()]
    segs += [(FLAG_POS[2], SPECIAL_POS["muzium"]), (FLAG_POS[3], SPECIAL_POS["arena"]), (FLAG_POS[9], SPECIAL_POS["t5"])]

    def seg_d(x, y, a, b):
        ax, ay = a; bx, by = b
        dx, dy = bx - ax, by - ay
        t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / float(dx * dx + dy * dy or 1)))
        return math.hypot(x - (ax + t * dx), y - (ay + t * dy))

    def near_path(x, y):
        pts = list(ZONE_POS.values()) + list(SPECIAL_POS.values()) + FLAG_POS
        if any(abs(x - p[0]) < 30 and -6 < (p[1] - y) < 40 for p in pts):
            return True
        return any(seg_d(x, y, a, b) < 16 for a, b in segs)
    placed = 0
    tries = 0
    while placed < 120 and tries < 4000:
        tries += 1
        x, y = rng.randrange(8, W - 8), rng.randrange(20, 332)
        if near_path(x, y) or abs(x - river_x(y)) < 14:
            continue
        tree(img, x, y, rng.choices(["green", "pink", "orange"], [6, 2, 2])[0], rng.uniform(0.8, 1.2))
        placed += 1
    for _ in range(30):
        x, y = rng.randrange(8, W - 8), rng.randrange(20, 330)
        if not near_path(x, y):
            rock(img, x, y)
    flowers(img, 260)
    for x in range(10, 640, 70):
        palm(img, x + rng.randint(0, 20), 336)
    return img


def bg_zone(kind):
    img = new(320, 180)
    if kind == "1_1":
        # misty corridor of time
        for y in range(180):
            t = y / 180
            line(img, [(0, y), (320, y)], (int(70 + 50 * t), int(60 + 40 * t), int(110 + 30 * t)))
        for _ in range(60):
            x, y = rng.randrange(320), rng.randrange(90)
            px(img, x, y, (230, 220, 255))
        rect(img, 0, 100, 320, 80, (120, 104, 140))
        noise_fill(img, 0, 100, 320, 80, [(126, 110, 146), (116, 100, 136), (134, 118, 152)])
        poly(img, [(110, 100), (210, 100), (290, 180), (30, 180)], (170, 150, 120))
        noise_fill(img, 0, 0, 0, 0, [P["sand1"]])
        for i in range(6):
            yy = 104 + i * 13
            line(img, [(110 - i * 13, yy), (210 + i * 13, yy)], (150, 132, 104))
        for x in (20, 290):
            for y in range(60, 110, 12):
                rect(img, x, y, 10, 10, (90, 80, 110))
        # floating gold thread
        for x in range(0, 320, 2):
            px(img, x, 52 + int(4 * math.sin(x / 15)), P["gold"] + (120,))
    elif kind == "1_2":
        # port of Melaka
        for y in range(60):
            line(img, [(0, y), (320, y)], (150 + y, 200 + y // 2, 240))
        ellipse(img, 30, 10, 40, 10, P["white"])
        water(img, 0, 30, 320, 60)
        # distant ship
        poly(img, [(240, 50), (290, 50), (284, 58), (246, 58)], P["wood2"])
        rect(img, 264, 26, 2, 24, P["wood4"]); poly(img, [(266, 28), (282, 46), (266, 46)], P["cream"])
        # dock
        rect(img, 0, 88, 320, 92, P["sand1"])
        noise_fill(img, 0, 92, 320, 88, [P["sand1"], P["sand2"], P["sand3"]], [6, 2, 2])
        rect(img, 120, 60, 80, 30, P["wood1"])
        for x in range(120, 200, 4):
            line(img, [(x, 60), (x, 89)], P["wood2"])
        for x in (122, 196):
            rect(img, x, 56, 3, 36, P["wood4"])
        # stalls
        for sx, col in ((14, P["red"]), (60, P["water2"]), (250, P["yellow"])):
            rect(img, sx, 108, 40, 22, P["wood3"])
            poly(img, [(sx - 3, 108), (sx + 43, 108), (sx + 38, 98), (sx + 2, 98)], col)
            for k in range(4):
                rect(img, sx + 4 + k * 9, 102, 4, 6, P["white"] if k % 2 else col)
        # warehouse
        house(img, 262, 136, 50, 40, roof=P["roof2"], wall=P["wood1"], style="flat")
        for _ in range(8):
            x, y = rng.randrange(140, 240), rng.randrange(150, 175)
            rect(img, x, y, 6, 5, P["wood2"]); rect(img, x + 1, y + 1, 4, 1, P["wood3"])
        palm(img, 230, 120)
        palm(img, 8, 170)
    elif kind == "1_3":
        # Balai Penghadapan interior
        rect(img, 0, 0, 320, 180, (120, 62, 44))
        for x in range(0, 320, 12):
            line(img, [(x, 0), (x, 90)], (104, 52, 38))
        rect(img, 0, 90, 320, 90, (170, 120, 70))
        for y in range(94, 180, 8):
            line(img, [(0, y), (320, y)], (150, 104, 60))
        for x in range(0, 320, 24):
            line(img, [(x, 90), (x - 40, 180)], (150, 104, 60))
        # carpet
        poly(img, [(140, 50), (180, 50), (220, 180), (100, 180)], P["red2"])
        poly(img, [(146, 50), (174, 50), (210, 180), (110, 180)], P["red"])
        # throne dais
        rect(img, 120, 28, 80, 26, P["gold2"])
        rect(img, 126, 32, 68, 18, (140, 40, 40))
        poly(img, [(116, 30), (160, 6), (204, 30)], P["gold"])
        # pillars
        for x in (30, 80, 236, 286):
            rect(img, x, 10, 10, 120, P["wood3"])
            rect(img, x + 2, 10, 2, 120, P["wood1"])
            rect(img, x - 2, 8, 14, 4, P["gold2"])
            rect(img, x - 2, 126, 14, 4, P["gold2"])
        # court area (right)
        rect(img, 244, 120, 70, 50, (130, 86, 50))
        rect(img, 248, 124, 62, 6, P["gold2"])
        # lanterns
        for x in (60, 260):
            rect(img, x, 0, 1, 20, P["gold2"])
            ellipse(img, x - 4, 20, 9, 10, P["orange2"])
    elif kind == "1_4":
        # Bukit Siguntang summit
        for y in range(120):
            t = y / 120
            line(img, [(0, y), (320, y)], (int(120 + 90 * t), int(170 + 40 * t), int(230 - 20 * t)))
        for cx, cy in ((40, 20), (200, 30), (270, 14)):
            ellipse(img, cx, cy, 44, 12, (250, 250, 255))
        for i, col in enumerate([(130, 170, 160), (110, 160, 130)]):
            pts = [(0, 120)] + [(x, 100 + i * 12 + int(6 * math.sin(x / 25 + i * 2))) for x in range(0, 321, 10)] + [(320, 180), (0, 180)]
            poly(img, pts, col)
        poly(img, [(0, 180), (0, 130), (60, 112), (160, 100), (260, 112), (320, 130), (320, 180)], P["grass1"])
        grass(img, 0, 128, 320, 52)
        ImageDraw.Draw(img).polygon([(40, 128), (160, 102), (280, 128), (320, 180), (0, 180)], fill=None)
        flowers(img, 50, (0, 130, 320, 50))
        # stone platform for the Waadat
        ellipse(img, 70, 140, 80, 20, P["stone2"])
        ellipse(img, 72, 140, 76, 16, P["stone1"])
        for x in (10, 300):
            tree(img, x, 176, "green", 1.1)
    return img


def tree_stage(stage):
    """64x72 big tree in 3 states: 0 layu, 1 sederhana, 2 subur."""
    img = new(64, 72)
    trunk = P["trunk"]
    rect(img, 28, 36, 8, 30, trunk)
    rect(img, 30, 36, 2, 30, P["trunk2"])
    # roots (akar = rakyat)
    root_col = [(120, 90, 60), (160, 120, 70), P["gold"]][stage]
    for dx in (-14, -8, 8, 14):
        line(img, [(32, 64), (32 + dx, 70)], root_col, 2)
    line(img, [(24, 66), (40, 66)], root_col, 2)
    if stage == 0:
        pal = [(130, 110, 60), (150, 130, 70), (170, 150, 90)]
        blobs = [(32, 26, 16), (20, 32, 9), (44, 32, 9)]
        line(img, [(32, 40), (14, 22)], trunk, 2)
        line(img, [(32, 38), (50, 20)], trunk, 2)
    elif stage == 1:
        pal = [(70, 120, 60), (90, 146, 70), (120, 170, 90)]
        blobs = [(32, 24, 19), (16, 30, 12), (48, 30, 12)]
    else:
        pal = [P["leaf4"], P["leaf1"], P["leaf2"]]
        blobs = [(32, 22, 22), (12, 28, 14), (52, 28, 14), (32, 8, 14)]
    for (x, y, r) in blobs:
        ellipse(img, x - r, y - r, 2 * r, 2 * r, pal[0])
    for (x, y, r) in blobs:
        ellipse(img, x - r + 2, y - r + 1, 2 * r - 4, 2 * r - 5, pal[1])
    for (x, y, r) in blobs:
        ellipse(img, x - r // 2, y - r // 2 - 2, r, r - 2, pal[2])
    if stage == 0:
        for _ in range(16):
            px(img, rng.randrange(14, 50), rng.randrange(10, 40), (0, 0, 0, 0))
    if stage == 2:
        for _ in range(10):
            x, y = rng.randrange(14, 50), rng.randrange(6, 36)
            px(img, x, y, P["pink2"]); px(img, x + 1, y, P["pink1"])
    return outline_alpha(img)


def building(kind):
    """Map buildings, ~48x44."""
    img = new(56, 50)
    if kind == "1_1":
        # time gate arch
        rect(img, 8, 12, 8, 36, (110, 96, 130)); rect(img, 40, 12, 8, 36, (110, 96, 130))
        poly(img, [(4, 14), (28, 0), (52, 14)], (140, 120, 160))
        rect(img, 16, 16, 24, 32, (60, 50, 90))
        for k in range(5):
            px(img, 20 + k * 4, 22 + (k % 2) * 3, P["gold3"])
        line(img, [(16, 30), (40, 30)], P["gold"])
    elif kind == "1_2":
        fort(img, 6, 14, 44, 34)
    elif kind == "1_3":
        house(img, 4, 4, 48, 44, roof=P["roof1"], wall=P["wood3"])
    elif kind == "1_4":
        poly(img, [(0, 50), (28, 10), (56, 50)], P["leaf1"])
        poly(img, [(8, 50), (28, 18), (48, 50)], P["leaf2"])
        tree(img, 28, 20, "green", 0.7)
        rect(img, 24, 40, 8, 4, P["stone1"])
    elif kind == "muzium":
        poly(img, [(2, 18), (28, 4), (54, 18)], P["stone1"])
        rect(img, 4, 18, 48, 4, P["stone3"])
        for xx in (8, 18, 34, 44):
            rect(img, xx, 22, 4, 22, P["stone3"]); rect(img, xx + 1, 22, 1, 22, P["stone2"])
        rect(img, 4, 44, 48, 5, P["stone2"])
        rect(img, 24, 30, 8, 14, P["wood4"])
    elif kind == "arena":
        ellipse(img, 2, 18, 52, 30, P["stone2"])
        ellipse(img, 6, 14, 44, 26, P["stone1"])
        ellipse(img, 14, 20, 28, 14, P["sand1"])
        for xx in (8, 46):
            rect(img, xx, 4, 2, 16, P["wood4"])
            poly(img, [(xx + 2, 4), (xx + 10, 7), (xx + 2, 10)], P["red"])
    elif kind == "t5":
        rect(img, 6, 10, 8, 38, P["stone2"]); rect(img, 42, 10, 8, 38, P["stone2"])
        rect(img, 4, 6, 48, 8, P["stone1"])
        for xx in range(14, 42, 4):
            rect(img, xx, 14, 2, 34, P["grey2"])
        rect(img, 22, 24, 12, 12, P["gold2"]); rect(img, 26, 27, 4, 5, P["outline"])
    return outline_alpha(img) if kind not in ("1_4",) else img


def gate(kind):
    """32x40 kingdom gates for Zon 1.1 puzzle & area."""
    img = new(32, 40)
    cols = {
        "funan": ((120, 150, 90), (90, 120, 70)),
        "champa": ((190, 110, 70), (160, 80, 50)),
        "srivijaya": ((210, 170, 80), (170, 130, 50)),
        "melaka": ((170, 60, 50), (130, 40, 36)),
        "johor": ((70, 100, 160), (50, 76, 130)),
    }[kind]
    rect(img, 3, 8, 6, 32, cols[0]); rect(img, 23, 8, 6, 32, cols[0])
    rect(img, 4, 8, 2, 32, cols[1]); rect(img, 24, 8, 2, 32, cols[1])
    if kind == "funan":
        poly(img, [(0, 10), (16, 0), (32, 10)], cols[1])
    elif kind == "champa":
        for k in range(3):
            poly(img, [(6 + k * 2, 10 - k * 3), (16, 0 - k), (26 - k * 2, 10 - k * 3)], cols[1] if k % 2 else cols[0])
    elif kind == "srivijaya":
        rect(img, 0, 4, 32, 6, cols[1]); poly(img, [(8, 4), (16, 0), (24, 4)], P["gold"])
    elif kind == "melaka":
        poly(img, [(-2, 12), (16, 0), (34, 12)], cols[1]); line(img, [(0, 12), (32, 12)], P["gold"])
    else:
        poly(img, [(0, 10), (16, 2), (32, 10)], cols[1]); rect(img, 14, 0, 4, 4, P["gold"])
    rect(img, 9, 14, 14, 26, (40, 30, 60, 180))
    return outline_alpha(img)


def panji(color, raised):
    img = new(16, 48)
    rect(img, 7, 4, 2, 44, P["wood4"])
    ellipse(img, 6, 1, 4, 4, P["gold"])
    fy = 6 if raised else 34
    poly(img, [(9, fy), (16, fy + 4), (9, fy + 10)], color)
    rect(img, 4, 44, 8, 4, P["stone2"])
    return outline_alpha(img)


def board_bg():
    """Papan Siasatan cork board 320x160."""
    img = new(320, 160)
    rect(img, 0, 0, 320, 160, P["wood2"])
    rect(img, 4, 4, 312, 152, (190, 140, 90))
    noise_fill(img, 4, 4, 312, 152, [(190, 140, 90), (176, 128, 80), (204, 154, 100)], [5, 3, 2])
    return img


def ship_utusan():
    img = new(64, 48)
    poly(img, [(4, 30), (60, 30), (52, 42), (12, 42)], P["wood2"])
    rect(img, 6, 30, 52, 3, P["wood3"])
    for mx, h in ((24, 26), (40, 22)):
        rect(img, mx, 30 - h, 2, h, P["wood4"])
        poly(img, [(mx - 10, 30 - h + 2), (mx + 12, 30 - h + 2), (mx + 10, 26), (mx - 8, 26)], P["red"])
        line(img, [(mx - 9, 30 - h + 8), (mx + 11, 30 - h + 8)], P["gold"])
    poly(img, [(58, 30), (64, 24), (62, 32)], P["wood2"])
    return outline_alpha(img)


def marker():
    img = new(16, 20)
    ellipse(img, 1, 1, 14, 14, P["gold3"])
    ellipse(img, 2, 2, 12, 12, P["yellow"])
    poly(img, [(6, 13), (10, 13), (8, 18)], P["yellow"])
    rect(img, 7, 4, 2, 6, P["outline"])
    rect(img, 7, 11, 2, 2, P["outline"])
    return outline_alpha(img)


def app_icon():
    img = new(64, 64)
    rect(img, 0, 0, 64, 64, P["navy"] + (255,))
    rect(img, 3, 3, 58, 58, P["wood2"])
    rect(img, 6, 6, 52, 52, P["night2"])
    p = pau_sheet().crop((48, 0, 64, 16)).resize((40, 40), Image.NEAREST)
    img.alpha_composite(p, (12, 16))
    f = new(16, 32)
    flagpole(f, 4, 31, P["red"], h=26)
    img.alpha_composite(f.resize((16, 32), Image.NEAREST), (42, 4))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    # characters
    for k, spec in SPECS.items():
        save(char_sheet(spec), f"sprites/{k}.png")
    save(pau_sheet(), "sprites/pau.png")
    # portraits
    for expr in ("neutral", "worried", "confused", "happy", "confident"):
        save(portrait("alif", expr), f"portraits/alif_{expr}.png")
    for expr in ("neutral", "happy", "scared"):
        save(portrait("pau", expr), f"portraits/pau_{expr}.png")
    for k in ("penjaga", "syahbandar", "tunperak", "sapurba", "demang", "chengho", "pedagang",
              "pelajar_1", "pelajar_2", "pelajar_3", "pelajar_4"):
        save(portrait(k), f"portraits/{k}.png")
    save(portrait("sultan"), "portraits/sultan.png")
    # icons
    for n in ICONS:
        save(icon(n), f"icons/{n}.png")
    # backgrounds
    save(bg_bilik(), "bg/bilik_alif.png")
    save(bg_bukit(), "bg/bukit_peta.png")
    save(bg_peta(), "bg/peta_jejak.png")
    for z in ("1_1", "1_2", "1_3", "1_4"):
        save(bg_zone(z), f"bg/zon_{z}.png")
    save(board_bg(), "bg/papan_siasatan.png")
    # objects
    for s in range(3):
        save(tree_stage(s), f"objects/pokok_{s}.png")
    for b in ("1_1", "1_2", "1_3", "1_4", "muzium", "arena", "t5"):
        save(building(b), f"objects/bangunan_{b}.png")
    for g in ("funan", "champa", "srivijaya", "melaka", "johor"):
        save(gate(g), f"objects/gerbang_{g}.png")
    save(panji(P["red"], True), "objects/panji_naik.png")
    save(panji(P["grey1"], False), "objects/panji_turun.png")
    save(ship_utusan(), "objects/kapal_utusan.png")
    save(marker(), "objects/penanda.png")
    save(app_icon(), "icon_src.png")
    for i in range(2):
        f = new(16, 32)
        flagpole(f, 4, 31, P["grey1"] if i == 0 else P["red"], h=26, lowered=(i == 0))
        save(outline_alpha(f), f"objects/bendera_{'kunci' if i == 0 else 'aktif'}.png")
    # positions used by the map, exported for the game (in game pixels = x4)
    layout = {
        "scale": 4,
        "flags": [[x * 4, y * 4] for x, y in FLAG_POS],
        "zones": {k: [v[0] * 4, v[1] * 4] for k, v in ZONE_POS.items()},
        "special": {k: [v[0] * 4, v[1] * 4] for k, v in SPECIAL_POS.items()},
    }
    with open(os.path.join(ROOT, "data", "peta_layout.json"), "w") as fh:
        json.dump(layout, fh, indent=2)
    print("art generated in", OUT)


if __name__ == "__main__":
    main()
