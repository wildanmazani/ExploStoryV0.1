"""Generate the Dunia Explo-Story overworld layout.

Writes data/world/terrain.txt (one char per 16px cell), data/world/objects.txt
(object anchors, same grid) and data/world/entities.json (NPCs, signs, gates,
spawn). The game builds the TileMap from these at runtime (scripts/world/).

Terrain chars: ~ sea, s sand, r river/pond, . grass, , meadow, = dirt path
Object chars (anchor = bottom-left cell of the footprint):
  P palm  T tree  B bush  R rocks  F flowers  f fence  H house  M market stall
  K Peta Jejak monument  Y banyan  G open flag gate  L locked flag gate  S sign
  U Rumah Alif (was the muzium)  I istana  J jetty (walkable over sea)  X Ming ship  b perahu
  D gudang  n bridge (walkable over the river)  l lamp  w well
  j tempayan  k barrel  c crates  g log  u stump  e bench  x firewood
  p lily pads  q reeds (flat, no collision)
  1-5 the five kingdom gates of Misi 1.1 (Funan, Champa, Srivijaya, Melaka, Johor-Riau)
  Lembah Kebangkitan (Bab 2): O dewan  V rumah falsafah  E balai serantau  N madrasah
  C Jelutong Press  h kedai (shophouses)  m Maktab SITC  t menara  y tugu pahlawan
  a papan notis  o rak buku  d meja pengarang  v pintu kabus (portal back to island 1)  z lampu kolonial
  A Empat Tiang (Misi 1.1)  Q panji pole (Misi 1.2)  W Arena Ulang Kaji (one per island)  Z Batu Renungan (Misi 1.4)
"spots" in entities.json names the puzzle locations used by data/zon_1_x.json steps.

Run: python tools/gen_world.py   (deterministic; edit shapes below and re-run)
"""
import json
import math
import os
import random
from collections import deque

W, H = 140, 60
W1 = 80          # the first island (Bab 1) lives in columns 0..79
X2 = 84          # Lembah Kebangkitan (Bab 2) lives in columns 84..139, reached by the portal
random.seed(7)
r2 = random.Random(21)   # island 2 has its own dice so island 1 never changes
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "world")

terrain = [["~"] * W for _ in range(H)]
objects = [[" "] * W for _ in range(H)]
blocked = [[False] * W for _ in range(H)]  # object footprints (for scatter)


def inside(x, y):
    return 0 <= x < W and 0 <= y < H


# --- landmass: wobbly ellipses ------------------------------------------
def blob(cx, cy, rx, ry, wobble=0.12, seed=0.0, ch="."):
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(dy, dx)
            r = 1 + wobble * (math.sin(a * 3 + seed) + 0.6 * math.sin(a * 7 + seed * 2))
            if dx * dx + dy * dy <= r * r:
                terrain[y][x] = ch


blob(38, 32, 33, 23, seed=1.0)   # main island
blob(58, 13, 15, 9, seed=2.3)    # north-east lobe (Bukit Siguntang)
blob(19, 47, 12, 9, seed=0.4)    # south-west lobe (Bukit Permulaan)
blob(14, 26, 9, 10, seed=3.1)    # west lobe (mist road)
blob(46, 13, 7, 5, seed=1.7)     # saddle joining the village to Siguntang (spring pond)


def catmull(points, samples=8):
    """Smooth curve through the points (Catmull-Rom), as a dense list of (x, y)."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        n = max(abs(p2[0] - p1[0]), abs(p2[1] - p1[1])) * samples + 1
        for s in range(n):
            t = s / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t
                                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(2)))
    out.append(points[-1])
    return out


def stroke(points, ch, width, only=None):
    """Paint a smooth road / river of the given width through the points."""
    for fx, fy in catmull(points):
        x0, y0 = int(round(fx - (width - 1) / 2)), int(round(fy - (width - 1) / 2))
        for oy in range(width):
            for ox in range(width):
                x, y = x0 + ox, y0 + oy
                if inside(x, y) and (only is None or terrain[y][x] in only):
                    terrain[y][x] = ch


def ellipse(cx, cy, rx, ry, ch, only=".,="):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if inside(x, y) and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and terrain[y][x] in only:
                terrain[y][x] = ch


# --- river: spring pond under Bukit Siguntang, down past the village to a
# lagoon behind the beach by the pasar
ellipse(49, 12, 2.6, 2.1, "r", only=".")
RIVER = [(49, 13), (48, 16), (47, 21), (47, 26), (47, 30), (48, 35), (49, 40), (49, 44)]
stroke(RIVER, "r", 3, only=".")
ellipse(49.5, 44.8, 2.8, 1.4, "r", only=".")
# where a road crosses, the river runs straight and exactly 3 wide under the bridge
BRIDGES = [(48, 16), (47, 30), (49, 41)]  # (river centre x, road top row)
for bx, by in BRIDGES:
    for y in range(by - 2, by + 4):
        for x in range(bx - 4, bx + 5):
            if terrain[y][x] == "r":
                terrain[y][x] = "."
        for x in range(bx - 1, bx + 2):
            terrain[y][x] = "r"

# --- roads and yards (rounded dirt clearings instead of stone plazas) -----
ROADS = [
    [(19, 47), (23, 45), (28, 42), (31, 38), (34, 35)],          # Bukit Permulaan -> Kampung Jejak
    [(35, 28), (35, 25), (35, 21), (34, 18)],                    # kampung -> Gerbang Masa (through the gate)
    [(40, 31), (44, 30), (51, 30), (55, 31)],                    # kampung -> Kota Melaka (bridge)
    [(42, 15), (45, 16), (51, 16), (54, 14)],                    # Gerbang Masa -> Bukit Siguntang (bridge)
    [(60, 33), (61, 37), (62, 41)],                              # Kota Melaka -> Pelabuhan
    [(35, 37), (38, 40), (43, 41), (52, 41), (57, 42), (61, 43)],  # kampung -> pasar -> Pelabuhan (bridge)
    [(30, 31), (24, 30), (16, 28), (10, 27)],                    # kampung -> Kabus Masa gate
    [(58, 13), (61, 11), (63, 10)],                              # Siguntang -> NE mist gate
]
MAIN_ROADS = (0, 2)  # the rest are narrow footpaths
for i, r in enumerate(ROADS):
    stroke(r, "=", 2 if i in MAIN_ROADS else 1, only=".=,")
YARDS = [
    (35, 31.5, 4.2, 2.6),  # Kampung Jejak square
    (34, 15.5, 7.5, 2.4),  # Gerbang Masa clearing
    (56, 30.5, 4, 1.6),    # istana courtyard
    (61, 42, 3.5, 2.2),    # port square
    (56, 13, 2.5, 1.5),    # under the banyan
]
for cx, cy, rx, ry in YARDS:
    ellipse(cx, cy, rx, ry, "=")
# doorstep paths for the village buildings
STUBS = [[(27, 28), (28, 30)], [(43, 28), (43, 30)], [(23, 37), (26, 40)], [(22, 43), (25, 44)]]
for s in STUBS:
    stroke(s, "=", 1, only=".=,")


# --- Lembah Kebangkitan (Bab 2): a planned 1920s colonial town, reached only by
# the portal. The layout (roads, padang, river, landmarks) lives in
# data/world/lembah_layout.json, composed in PixelLab Map Workshop.
LAYOUT = json.load(open(os.path.join(ROOT, "data", "world", "lembah_layout.json"), encoding="utf-8"))
for kind, ch, x0, y0, w, h, *_ in LAYOUT["terrain"]:
    for yy in range(y0, y0 + h):
        for xx in range(x0, x0 + w):
            if inside(xx, yy):
                terrain[yy][xx] = ch
BRIDGES2 = [tuple(b) for b in LAYOUT["bridges"]]   # bridge anchors (bottom-left)


# --- legality pass (Wang pairs: sea-sand, sand-grass, river-grass, grass-meadow, grass-path, grass-jalan)
def near(x, y, chars, r):
    for yy in range(y - r, y + r + 1):
        for xx in range(x - r, x + r + 1):
            if inside(xx, yy) and terrain[yy][xx] in chars:
                return True
    return False


# beaches: land within 2 cells of sea becomes sand
snapshot = [row[:] for row in terrain]
for y in range(H):
    for x in range(W):
        if snapshot[y][x] in ".=,j" and any(
                inside(xx, yy) and snapshot[yy][xx] == "~"
                for yy in range(y - 2, y + 3) for xx in range(x - 2, x + 3)):
            terrain[y][x] = "s"
# water never touches sand: keep a grass bank between the lagoon and the beach
for y in range(H):
    for x in range(W):
        if terrain[y][x] == "r" and near(x, y, "s~", 1):
            terrain[y][x] = "."
# roads keep a grass verge next to sand and river
for y in range(H):
    for x in range(W):
        if terrain[y][x] in "=j" and near(x, y, "s~r", 1):
            terrain[y][x] = "."

# meadow patches: soft darker grass, at least 2 cells from roads/water/sand
def meadow(cx, cy, rx, ry, rnd):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not inside(x, y) or terrain[y][x] != ".":
                continue
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1 + rnd.uniform(-0.2, 0.2):
                continue
            if not near(x, y, "=sr~", 2):
                terrain[y][x] = ","


for i in range(26):
    cx, cy = random.randint(4, W1 - 5), random.randint(4, H - 5)
    rx, ry = random.uniform(2.5, 5.5), random.uniform(2, 4)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not inside(x, y) or terrain[y][x] != ".":
                continue
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1 + random.uniform(-0.2, 0.2):
                continue
            if not near(x, y, "=sr~", 2):
                terrain[y][x] = ","


# --- objects ------------------------------------------------------------
FOOT = {  # footprint (w, h) in cells; anchored at bottom-left
    "P": (1, 1), "T": (2, 1), "B": (2, 1), "R": (2, 1), "F": (2, 1), "f": (1, 1),
    "H": (6, 3), "U": (6, 3), "M": (4, 2), "I": (10, 4), "J": (2, 6), "X": (6, 4), "b": (3, 1),
    "1": (3, 1), "2": (3, 1), "3": (3, 1), "4": (3, 1), "5": (3, 1),
    "A": (4, 1), "Q": (1, 1), "W": (6, 2), "Z": (2, 1), "K": (4, 2), "Y": (6, 2), "G": (4, 1), "L": (4, 1), "S": (1, 1),
    "D": (6, 3), "n": (5, 2), "l": (1, 1), "w": (2, 1), "j": (1, 1), "k": (1, 1), "c": (2, 1),
    "g": (2, 1), "u": (1, 1), "e": (2, 1), "x": (2, 1), "p": (1, 1), "q": (1, 1),
    "O": (8, 4), "V": (6, 3), "E": (6, 3), "N": (6, 3), "C": (6, 3), "h": (6, 3), "m": (10, 4),
    "t": (6, 4), "y": (3, 2), "a": (2, 1), "o": (2, 1), "d": (2, 1), "v": (4, 1), "z": (1, 1),
    # 1920s town (Lembah): 6/7 shophouse rows, 8 clock tower, 9 bandstand, @ steamship, $ newspaper stand,
    # ! mission signpost, % angsana, & rubber tree, + telegraph pole, 0 bicycle, # iron railing
    "6": (8, 3), "7": (8, 3), "8": (3, 2), "9": (5, 3), "@": (8, 3), "$": (2, 1), "!": (2, 1),
    "%": (2, 1), "&": (2, 1), "+": (1, 1), "0": (2, 1), "#": (2, 1),
}
FLAT = set("FpqnJ")      # drawn under characters, no collision
WALK_OVER = set("nJ")      # walkable even over water
GATE_OPEN_COLS = {"G": (1, 2), "v": (1, 2)}


def can_place(ch, x, y, ground=".,", margin=0):
    w, h = FOOT[ch]
    for yy in range(y - h + 1 - margin, y + 1 + margin):
        for xx in range(x - margin, x + w + margin):
            if not inside(xx, yy) or blocked[yy][xx]:
                return False
    for yy in range(y - h + 1, y + 1):
        for xx in range(x, x + w):
            if terrain[yy][xx] not in ground:
                return False
    return True


def place(ch, x, y, ground=".,=s", force=False):
    if not force and not can_place(ch, x, y, ground):
        return False
    w, h = FOOT[ch]
    for yy in range(y - h + 1, y + 1):
        for xx in range(x, x + w):
            if force and blocked[yy][xx]:
                print("warning: %s at %d,%d overlaps another object" % (ch, x, y))
                force = False
            blocked[yy][xx] = True
    objects[y][x] = ch
    return True


entities = {"spawn": [19, 50], "npcs": [], "signs": [], "gates": [], "areas": [], "spots": {}}


def place_near(ch, x, y, ground=".,=s", radius=6):
    """Place at (x, y) or the nearest legal cell; returns the anchor used."""
    for r in range(radius + 1):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r:
                    continue
                if can_place(ch, x + dx, y + dy, ground):
                    place(ch, x + dx, y + dy, ground)
                    return [x + dx, y + dy]
    raise SystemExit("no room for %s near %d,%d" % (ch, x, y))


def spot(name, at, ch):
    w, h = FOOT[ch]
    entities["spots"][name] = {"pos": at, "size": [w, h]}


def keep_clear(x0, y0, x1, y1):
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            if inside(xx, yy):
                blocked[yy][xx] = True


# bridges first (they sit on the river)
for bx, by in BRIDGES:
    place("n", bx - 2, by + 1, force=True)

# --- landmarks ------------------------------------------------------------
place("S", 23, 49, force=True)
entities["signs"].append({"pos": [23, 49], "id": "sign_start"})
# keep a clearing around the spawn so the opening shot is clean
sx, sy = entities["spawn"]
keep_clear(sx - 4, sy - 3, sx + 3, sy + 4)
place("K", 33, 30, force=True)
entities["signs"].append({"pos": [33, 30], "id": "monument", "size": [4, 2]})
HOUSES = [(25, 27), (40, 27), (20, 36)]
for hx, hy in HOUSES:
    place("H", hx, hy, force=True)
place("U", 19, 42, force=True)
entities["signs"].append({"pos": [19, 42], "id": "rumah_alif", "size": [6, 3]})
# five kingdom gates start in a jumble; the Misi 1.1 puzzle puts them in order
# (1 Funan, 2 Champa, 3 Srivijaya, 4 Melaka, 5 Johor-Riau)
GATE_SLOTS = [27, 30, 33, 36, 39]
for slot, kingdom in zip(GATE_SLOTS, ["5", "1", "3", "4", "2"]):
    place(kingdom, slot, 14, force=True)
entities["kingdom_gates"] = {"row": 14, "slots": GATE_SLOTS, "start": ["johor", "funan", "srivijaya", "melaka", "champa"],
    "order": ["funan", "champa", "srivijaya", "melaka", "johor"]}
spot("tiang", place_near("A", 37, 17, ".,="), "A")
place("I", 51, 28, force=True)
entities["signs"].append({"pos": [51, 28], "id": "istana", "size": [10, 4]})
place("J", 66, 47, force=True)
for name, (px, py) in zip(["p_kerajaan", "p_rakyat", "p_kedaulatan", "p_wilayah", "p_undang", "p_lambang"],
                          [(58, 38), (60, 36), (64, 38), (57, 42), (59, 46), (63, 46)]):
    spot(name, place_near("Q", px, py), "Q")
spot("arena", place_near("W", 38, 37, ".,="), "W")
place("Y", 54, 11, force=True)
spot("batu", place_near("Z", 58, 16), "Z")
place("S", 69, 30, force=True)
entities["signs"].append({"pos": [69, 30], "id": "t5"})
entities["spots"]["pokok"] = {"pos": [54, 11], "size": [6, 2]}
entities["spots"]["kapal"] = {"pos": [70, 49], "size": [6, 4]}
place("X", 70, 49, force=True)
place("b", 62, 51, force=True)
place("b", 72, 42, force=True)
place("M", 39, 45, force=True)
place("M", 43, 45, force=True)
place("D", 52, 47, force=True)            # gudang by the port
place("G", 34, 22, force=True)
entities["gates"].append({"pos": [34, 22], "chapter": 1, "open": True})
place("L", 9, 26, force=True)
entities["gates"].append({"pos": [9, 26], "chapter": 2, "open": False})
place("L", 62, 9, force=True)
entities["gates"].append({"pos": [62, 9], "chapter": 5, "open": False})
place("S", 14, 54, force=True)
entities["signs"].append({"pos": [14, 54], "id": "sign_sea"})

entities["npcs"] += [
    {"id": "makcik", "pos": [31, 33], "facing": "south"},
    {"id": "nelayan", "pos": [64, 43], "facing": "east"},
    {"id": "penjaga", "pos": [34, 17], "facing": "south"},
    {"id": "syahbandar", "pos": [61, 40], "facing": "south"},
    {"id": "chengho", "pos": [65, 45], "facing": "south"},
    {"id": "sapurba", "pos": [53, 14], "facing": "east"},
    {"id": "demang", "pos": [61, 14], "facing": "west"},
]
reserved = set()


def reserve(x0, y0, w, h, r=2):
    for yy in range(y0 - h + 1 - r, y0 + 1 + r):
        for xx in range(x0 - r, x0 + w + r):
            reserved.add((xx, yy))


for n in entities["npcs"]:
    x, y = n["pos"]
    blocked[y][x] = True
    reserve(x, y, 1, 1)
for name, sp in entities["spots"].items():
    if name not in ("kapal",):
        reserve(sp["pos"][0], sp["pos"][1], sp["size"][0], sp["size"][1])
# Arena Ulang Kaji, a training and multiplayer yard: other players spar in
# pairs, Guru Jalal stands by the training dummies, a Papan Markah by the
# door (all inside the arena's reserved ring, so nothing else moves)
entities["npcs"].append({"id": "guru_silat", "pos": [43, 39], "facing": "east", "wander": False})
blocked[39][43] = True
entities["arenas"] = []


def arena_yard(spot_id, pairs, dummies, board):
    """Sparring pairs ([left fighter, right fighter]), dummies and a score board."""
    entities["arenas"].append({"spot": spot_id, "pairs": pairs, "dummies": dummies, "board": board})
    for x, y in [c for p in pairs for c in p] + dummies:
        blocked[y][x] = True
    place("a", board[0], board[1], force=True)
    entities["signs"].append({"pos": board, "id": "papan_markah", "size": [2, 1]})


arena_yard("arena", [[[37, 39], [38, 39]], [[40, 39], [41, 39]]], [[44, 39], [45, 38]], [36, 37])
# the istana door and the gate passage stay open
keep_clear(55, 29, 56, 30)
reserve(55, 29, 2, 1)
reserve(34, 22, 4, 1, r=1)

# --- Lembah Kebangkitan landmarks (Bab 2) ------------------------------------
ARRIVE = [90, 31]                       # where the portal from island 1 drops you
entities["arrive2"] = ARRIVE
entities["portals"] = [                 # stepping into the open columns warps
    {"cells": [[10, 26], [11, 26]], "to": ARRIVE, "facing": "south", "chapter": 2},
    {"cells": [[89, 30], [90, 30]], "to": [11, 27], "facing": "south", "chapter": 2},
]
for bx, by in BRIDGES2:
    place("n", bx, by, force=True)
place("v", 88, 30, force=True)
entities["signs"].append({"pos": [88, 30], "id": "portal_balik", "size": [1, 1]})
entities["signs"].append({"pos": [91, 30], "id": "portal_balik", "size": [1, 1]})
place("S", 93, 33, force=True)
entities["signs"].append({"pos": [93, 33], "id": "sign_lembah"})
keep_clear(ARRIVE[0] - 2, ARRIVE[1], ARRIVE[0] + 2, ARRIVE[1] + 2)


def landmark(name, ch, x, y, spot_name=None, sign=None):
    at = place_near(ch, x, y, ".,=s", radius=4)
    if spot_name:
        spot(spot_name, at, ch)
    if sign:
        entities["signs"].append({"pos": at, "id": sign, "size": list(FOOT[ch])})
    print("  %-16s %s at %s" % (name, ch, at))
    return at


print("Lembah Kebangkitan:")
for name, ch, x, y, opt in LAYOUT["landmarks"]:
    if not place(ch, x, y, ground=opt.get("ground", ".,=sj")):
        raise SystemExit("no room for %s (%s) at %d,%d" % (name, ch, x, y))
    if "spot" in opt:
        spot(opt["spot"], [x, y], ch)
    if "sign" in opt:
        entities["signs"].append({"pos": [x, y], "id": opt["sign"], "size": list(FOOT[ch])})
    reserve(x, y, FOOT[ch][0], FOOT[ch][1], r=1)
    print("  %-16s %s at %s" % (name, ch, [x, y]))
entities["misi_signs"] = []
for no, x, y in LAYOUT["misi_signs"]:
    if not place("!", x, y, ground=".,=sj"):
        raise SystemExit("no room for signpost %s at %d,%d" % (no, x, y))
    entities["misi_signs"].append({"no": no, "pos": [x, y]})
    reserve(x, y, 2, 1, r=1)
for n in LAYOUT["npcs"]:
    x, y = n["pos"]
    if blocked[y][x] or terrain[y][x] in "~r":
        raise SystemExit("NPC %s on a blocked cell %d,%d" % (n["id"], x, y))
    entities["npcs"].append(n)
    blocked[y][x] = True
    reserve(x, y, 1, 1)
reserve(88, 30, 4, 1, r=1)
reserve(ARRIVE[0], ARRIVE[1], 1, 1)
# the Lembah arena sits by the padang (its landmark comes from the layout)
arena_yard("arena_lembah", [[[128, 19], [129, 19]], [[131, 19], [132, 19]]], [[126, 19], [133, 20]], [126, 17])
reserve(126, 20, 8, 6, r=1)
DECOR = LAYOUT["decor"]
for y in DECOR["lamps_y"]:
    for x in DECOR["lamps_x"]:
        if (x, y) not in reserved and can_place("z", x, y, ".,"):
            place("z", x, y, ".,")
for key, ch in (("angsana", "%"), ("getah", "&"), ("telegraf", "+"), ("basikal", "0"), ("pagar", "#")):
    for x, y in DECOR[key]:
        if not place(ch, x, y, ground=".,s"):
            print("  (skipped %s at %d,%d)" % (key, x, y))


# --- village dressing -----------------------------------------------------
def try_place(ch, x, y, ground=".,"):
    if (x, y) not in reserved and can_place(ch, x, y, ground):
        place(ch, x, y, ground)
        return True
    return False


# each house gets a picket fence along its yard, a gap at the door, and flowers
for hx, hy in HOUSES:
    for fx in list(range(hx - 2, hx + 1)) + list(range(hx + 5, hx + 8)):
        try_place("f", fx, hy + 2)
    try_place("F", hx - 2, hy)
    try_place("F", hx + 6, hy)
    try_place("j", hx - 1, hy - 1)
try_place("w", 31, 29, ".,=")           # well on the square
try_place("e", 38, 34, ".,=")           # benches and a water jar by the square
try_place("e", 29, 35, ".,=")
try_place("j", 31, 35, ".,=")
try_place("x", 18, 36)                  # firewood behind the house
for x, y in [(52, 33), (59, 33), (49, 28), (61, 28)]:   # istana lamps
    try_place("l", x, y, ".,=")
for x, y in [(38, 45), (47, 45), (42, 44)]:              # pasar barrels and crates
    try_place("k", x, y, ".,=")
for x, y in [(52, 47), (60, 47), (63, 41), (64, 47)]:    # port cargo
    try_place("c", x, y, ".,=s") or try_place("k", x, y, ".,=s")
# lamps along the main roads, every few steps, on the verge
for road in (ROADS[0], ROADS[2], ROADS[5]):
    for i, (fx, fy) in enumerate(catmull(road, samples=2)):
        if i % 9 != 4:
            continue
        x, y = int(round(fx)), int(round(fy))
        for d in (3, -2, 2, -3):
            if try_place("l", x + d, y):
                break


# --- nature -----------------------------------------------------------------
def dist_to(x, y, chars, rmax):
    for r in range(rmax + 1):
        if near(x, y, chars, r):
            return r
    return rmax + 1


# water plants: reeds on the banks, lily pads on the pond and wide river
def water_plants(x0, x1, rnd):
    for y in range(H):
        for x in range(x0, x1):
            if (x, y) in reserved:
                continue
            t = terrain[y][x]
            if t in ".," and near(x, y, "r", 1) and rnd.random() < 0.22:
                try_place("q", x, y)
            elif t == "r" and not near(x, y, ".,=s", 1) and rnd.random() < 0.18:
                place("p", x, y, ground="r")


water_plants(0, W1, random)

GROVES = [(12, 38, 5), (11, 47, 4), (30, 49, 4), (40, 53, 4), (22, 20, 5), (42, 22, 3), (58, 21, 4),
          (67, 24, 5), (70, 36, 4), (53, 38, 3), (26, 8, 4), (66, 16, 4), (16, 30, 3), (31, 24, 2),
          (56, 21, 4), (66, 31, 3), (25, 52, 3), (44, 50, 3), (8, 33, 3), (41, 8, 2), (71, 15, 3)]
def scatter(cells, rnd, groves, village):
    """Trees in groves, bushes, flowers, rocks and logs; palms on the beach."""
    rnd.shuffle(cells)
    for x, y in cells:
        t = terrain[y][x]
        in_village = village[0] <= x <= village[2] and village[1] <= y <= village[3]
        if any((x + dx, y - dy) in reserved for dx in range(2) for dy in range(2)):
            continue
        grove = max((1.0 - math.hypot(x - gx, y - gy) / gr for gx, gy, gr in groves), default=0)
        if t in ".," and dist_to(x, y, "=", 1) >= 1:
            d_sand = dist_to(x, y, "s", 4)
            r = rnd.random()
            if d_sand <= 2 and r < 0.10:
                place("P", x, y)
            elif grove > 0 and r < 0.75 * grove + 0.1:
                if can_place("T", x, y, ".,") and dist_to(x, y, "=r", 2) >= 2:
                    place("T", x, y)
                elif r < 0.2:
                    try_place("u", x, y)
            elif not in_village and r < (0.12 if d_sand <= 6 else 0.07):
                if dist_to(x, y, "=r", 2) >= 2:
                    try_place("T", x, y)
            elif r < 0.03:
                try_place("B", x, y)
            elif r < 0.05:
                try_place("F", x, y)
            elif r < 0.054 and not in_village:
                try_place("R", x, y)
            elif r < 0.058 and not in_village:
                try_place("g", x, y)
        elif t == "s" and dist_to(x, y, "~", 3) >= 1 and rnd.random() < 0.025:
            place("P", x, y, ground="s")


scatter([(x, y) for y in range(2, H - 1) for x in range(1, W1 - 2)], random, GROVES, (17, 24, 46, 41))
water_plants(X2, W, r2)
for y in range(2, H - 1):
    for x in range(X2, W - 1):
        if terrain[y][x] == "s" and (x * 7 + y * 3) % DECOR["palms_every"] == 0 and dist_to(x, y, "~", 3) >= 1:
            if (x, y) not in reserved:
                place("P", x, y, ground="s")


entities["areas"] = [  # name, rect x0,y0,x1,y1 (used for music + area titles)
    {"id": "permulaan", "name": "Bukit Permulaan", "rect": [6, 42, 30, 58]},
    {"id": "kampung", "name": "Kampung Jejak", "rect": [17, 22, 46, 41]},
    {"id": "gerbang", "name": "Misi 1.1: Gerbang Masa", "rect": [22, 4, 45, 21]},
    {"id": "siguntang", "name": "Misi 1.4: Bukit Siguntang", "rect": [46, 2, 74, 20]},
    {"id": "melaka", "name": "Misi 1.3: Kota Melaka", "rect": [47, 21, 66, 35]},
    {"id": "pelabuhan", "name": "Misi 1.2: Pelabuhan Melaka", "rect": [50, 36, 79, 56]},
    {"id": "kabus", "name": "Kabus Masa", "rect": [0, 15, 13, 35]},
    # Lembah Kebangkitan (Bab 2): from the layout ("zone" links an area to its mission)
] + LAYOUT["areas"]


# --- checks -----------------------------------------------------------------
LEGAL = {frozenset("~s"), frozenset("s."), frozenset("r."), frozenset(".,"), frozenset(".="), frozenset(".j")}
ORDER = "~sr.,=j"
vert = [[max((terrain[min(max(y + dy, 0), H - 1)][min(max(x + dx, 0), W - 1)]
             for dx, dy in [(-1, -1), (0, -1), (-1, 0), (0, 0)]), key=ORDER.index)
         for x in range(W + 1)] for y in range(H + 1)]   # same rule as TerrainBuilder.paint
bad = []
for y in range(H):
    for x in range(W):
        cs = {vert[y][x], vert[y][x + 1], vert[y + 1][x], vert[y + 1][x + 1]}
        if len(cs) > 2 or (len(cs) == 2 and frozenset(cs) not in LEGAL):
            bad.append((x, y))
print("cells without a matching tile:", len(bad), bad[:12])

walk = [[terrain[y][x] not in "~r" for x in range(W)] for y in range(H)]
for y in range(H):
    for x in range(W):
        ch = objects[y][x]
        if ch == " ":
            continue
        w, h = FOOT[ch]
        for dy in range(h):
            for dx in range(w):
                cx, cy = x + dx, y - dy
                if ch in WALK_OVER:
                    walk[cy][cx] = True
                elif ch not in FLAT and dx not in GATE_OPEN_COLS.get(ch, ()):
                    walk[cy][cx] = False
for n in entities["npcs"]:
    walk[n["pos"][1]][n["pos"][0]] = False
for a in entities["arenas"]:
    for x, y in [c for p in a["pairs"] for c in p] + a["dummies"]:
        walk[y][x] = False
seen = {tuple(entities["spawn"]), tuple(entities["arrive2"])}
todo = deque(seen)
while todo:
    x, y = todo.popleft()
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        c = (x + dx, y + dy)
        if inside(*c) and walk[c[1]][c[0]] and c not in seen:
            seen.add(c)
            todo.append(c)


def reachable(cells):
    return any((cx + dx, cy + dy) in seen for cx, cy in cells for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])


def foot_cells(pos, size):
    return [(pos[0] + dx, pos[1] - dy) for dy in range(size[1]) for dx in range(size[0])]


lost = []
for name, sp in entities["spots"].items():
    if name != "kapal" and not reachable(foot_cells(sp["pos"], sp["size"])):
        lost.append(name)
for n in entities["npcs"]:
    if not reachable([tuple(n["pos"])]):
        lost.append(n["id"])
for s in entities["signs"]:
    if not reachable(foot_cells(s["pos"], s.get("size", [1, 1]))):
        lost.append(s["id"])
for g in entities["gates"]:
    if not reachable(foot_cells(g["pos"], [4, 1])):
        lost.append("gate %d" % g["chapter"])
for pt in entities["portals"]:
    if not reachable([tuple(c) for c in pt["cells"]]):   # the Bab 2 gate opens later
        lost.append("portal %s" % pt["cells"])
if (56, 29) not in seen:
    lost.append("istana door (56,29)")
os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "terrain.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in terrain) + "\n")
with open(os.path.join(OUT, "objects.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in objects) + "\n")
with open(os.path.join(OUT, "entities.json"), "w") as f:
    json.dump(entities, f, indent=1)
print("world", W, "x", H, "objects:", sum(c != " " for r in objects for c in r), "reachable cells:", len(seen))
if lost:
    raise SystemExit("unreachable from spawn: " + ", ".join(lost))
