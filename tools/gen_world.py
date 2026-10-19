"""Generate the Dunia Explo-Story overworld layout.

Writes data/world/terrain.txt (one char per 16px cell), data/world/objects.txt
(object anchors, same grid) and data/world/entities.json (NPCs, signs, gates,
spawn). The game builds the TileMap from these at runtime (scripts/world/).

Terrain chars: ~ sea, s sand, . grass, = dirt path, # stone plaza
Object chars (anchor = bottom-left cell of the footprint):
  P palm  T tree  B bush  R rocks  F flowers  f fence  H house  M market stall
  K Peta Jejak monument  Y banyan  G open flag gate  L locked flag gate  S sign
  U muzium  I istana  J jetty (walkable over sea)  X Ming ship  b perahu
  1-5 the five kingdom gates of Misi 1.1 (Funan, Champa, Srivijaya, Melaka, Johor-Riau)
  A Empat Tiang (Misi 1.1)  Q panji pole (Misi 1.2)  W Arena Ulang Kaji  Z Batu Renungan (Misi 1.4)
"spots" in entities.json names the puzzle locations used by data/zon_1_x.json steps.

Run: python tools/gen_world.py   (deterministic; edit shapes below and re-run)
"""
import json
import math
import os
import random

W, H = 80, 60
random.seed(7)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "world")

terrain = [["~"] * W for _ in range(H)]
objects = [[" "] * W for _ in range(H)]
blocked = [[False] * W for _ in range(H)]  # object footprints (for scatter)


def inside(x, y):
    return 0 <= x < W and 0 <= y < H


# --- landmass: wobbly ellipses ------------------------------------------
def blob(cx, cy, rx, ry, wobble=0.12, seed=0.0):
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(dy, dx)
            r = 1 + wobble * (math.sin(a * 3 + seed) + 0.6 * math.sin(a * 7 + seed * 2))
            if dx * dx + dy * dy <= r * r:
                terrain[y][x] = "."


blob(38, 32, 33, 23, seed=1.0)   # main island
blob(58, 13, 15, 9, seed=2.3)    # north-east lobe (Bukit Siguntang)
blob(19, 47, 12, 9, seed=0.4)    # south-west lobe (Bukit Permulaan)
blob(14, 26, 9, 10, seed=3.1)    # west lobe (mist road)


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if inside(x, y):
                terrain[y][x] = ch


def path(points, ch="=", width=2):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2 + 1
        for i in range(steps + 1):
            t = i / steps
            x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
            for oy in range(width):
                for ox in range(width):
                    if inside(x + ox, y + oy):
                        terrain[y + oy][x + ox] = ch


# --- plazas and roads ---------------------------------------------------
rect(26, 13, 41, 18, "#")    # Misi 1.1 Gerbang Masa ruins
rect(49, 24, 62, 33, "#")    # Kota Melaka (Balai / Istana square)
rect(33, 29, 37, 32, "#")    # monument square in Kampung Jejak

path([(19, 47), (24, 43), (30, 38), (34, 34)])          # start hill -> hub
path([(35, 28), (34, 23), (33, 19)])                     # hub -> ruins
path([(42, 16), (48, 14), (52, 14)])                     # ruins -> Siguntang
path([(38, 31), (44, 30), (48, 29)])                     # hub -> Kota Melaka
path([(57, 34), (60, 38), (64, 41)])                     # Melaka -> port
path([(32, 31), (24, 30), (16, 28), (10, 27)])           # hub -> west mist gate
path([(60, 12), (63, 10), (64, 9)])                       # Siguntang -> NE mist gate


# --- legality pass (Wang pairs: sea-sand, sand-grass, grass-path, grass-stone)
def near(x, y, chars, r):
    for yy in range(y - r, y + r + 1):
        for xx in range(x - r, x + r + 1):
            if inside(xx, yy) and terrain[yy][xx] in chars:
                return True
    return False


# beaches: land within 2 cells of sea becomes sand
for y in range(H):
    for x in range(W):
        if terrain[y][x] != "~" and near(x, y, "~", 2):
            terrain[y][x] = "s"
# paths/plazas never touch sand; paths never within 2 of stone
for y in range(H):
    for x in range(W):
        if terrain[y][x] in "=#" and near(x, y, "s~", 1):
            terrain[y][x] = "."
snapshot = [row[:] for row in terrain]
for y in range(H):
    for x in range(W):
        if snapshot[y][x] == "=":
            for yy in range(y - 2, y + 3):
                for xx in range(x - 2, x + 3):
                    if inside(xx, yy) and snapshot[yy][xx] == "#":
                        terrain[y][x] = "#"


# --- objects ------------------------------------------------------------
FOOT = {  # footprint (w, h) in cells; anchored at bottom-left
    "P": (1, 1), "T": (2, 1), "B": (2, 1), "R": (2, 1), "F": (2, 1), "f": (2, 1),
    "H": (6, 3), "U": (6, 3), "M": (4, 2), "I": (10, 4), "J": (2, 6), "X": (6, 4), "b": (3, 1),
    "1": (3, 1), "2": (3, 1), "3": (3, 1), "4": (3, 1), "5": (3, 1),
    "A": (4, 1), "Q": (1, 1), "W": (6, 2), "Z": (2, 1), "K": (4, 2), "Y": (6, 2), "G": (4, 1), "L": (4, 1), "S": (1, 1),
}


def can_place(ch, x, y, ground=".", margin=0):
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


def place(ch, x, y, ground=".#=s", force=False):
    if not force and not can_place(ch, x, y, ground):
        return False
    w, h = FOOT[ch]
    objects[y][x] = ch
    for yy in range(y - h + 1, y + 1):
        for xx in range(x, x + w):
            blocked[yy][xx] = True
    return True


entities = {"spawn": [19, 50], "npcs": [], "signs": [], "gates": [], "areas": [], "spots": {}}


def place_near(ch, x, y, ground=".s", radius=6):
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

# keep a clearing around the spawn so the opening shot is clean
sx, sy = entities["spawn"]
for yy in range(sy - 3, sy + 5):
    for xx in range(sx - 4, sx + 5):
        if inside(xx, yy):
            blocked[yy][xx] = True

# hand-placed landmarks
place("S", 23, 49, force=True)
entities["signs"].append({"pos": [23, 49], "id": "sign_start"})
place("K", 33, 30, force=True)
entities["signs"].append({"pos": [33, 30], "id": "monument", "size": [4, 2]})
for hx, hy in [(25, 27), (40, 27)]:
    place("H", hx, hy, force=True)
place("U", 25, 39, force=True)
entities["signs"].append({"pos": [25, 39], "id": "muzium", "size": [6, 3]})
# five kingdom gates start in a jumble; the Misi 1.1 puzzle puts them in order
# (1 Funan, 2 Champa, 3 Srivijaya, 4 Melaka, 5 Johor-Riau)
GATE_SLOTS = [27, 30, 33, 36, 39]
for slot, kingdom in zip(GATE_SLOTS, ["5", "1", "3", "4", "2"]):
    place(kingdom, slot, 15, force=True)
entities["kingdom_gates"] = {"row": 15, "slots": GATE_SLOTS, "start": ["johor", "funan", "srivijaya", "melaka", "champa"],
    "order": ["funan", "champa", "srivijaya", "melaka", "johor"]}
spot("tiang", place_near("A", 37, 18, ".#"), "A")
place("I", 51, 28, force=True)
entities["signs"].append({"pos": [51, 28], "id": "istana", "size": [10, 4]})
place("J", 66, 47, force=True)
for name, (px, py) in zip(["p_kerajaan", "p_rakyat", "p_kedaulatan", "p_wilayah", "p_undang", "p_lambang"],
                          [(58, 38), (60, 36), (64, 38), (57, 42), (59, 44), (63, 46)]):
    spot(name, place_near("Q", px, py), "Q")
spot("arena", place_near("W", 44, 33, ".=#"), "W")
spot("batu", place_near("Z", 50, 13), "Z")
place("S", 69, 30, force=True)
entities["signs"].append({"pos": [69, 30], "id": "t5"})
entities["spots"]["pokok"] = {"pos": [54, 11], "size": [6, 2]}
entities["spots"]["kapal"] = {"pos": [70, 49], "size": [6, 4]}
place("X", 70, 49, force=True)
place("b", 62, 51, force=True)
place("b", 72, 42, force=True)
place("M", 40, 37, force=True)
place("M", 45, 37, force=True)
place("Y", 54, 11, force=True)
place("G", 32, 22, force=True)
entities["gates"].append({"pos": [32, 22], "chapter": 1, "open": True})
place("L", 9, 26, force=True)
entities["gates"].append({"pos": [9, 26], "chapter": 2, "open": False})
place("L", 61, 9, force=True)
entities["gates"].append({"pos": [61, 9], "chapter": 5, "open": False})
place("S", 14, 54, force=True)
entities["signs"].append({"pos": [14, 54], "id": "sign_sea"})

entities["npcs"] += [
    {"id": "makcik", "pos": [31, 35], "facing": "south"},
    {"id": "nelayan", "pos": [63, 43], "facing": "east"},
    {"id": "penjaga", "pos": [34, 17], "facing": "south"},
    {"id": "syahbandar", "pos": [61, 40], "facing": "south"},
    {"id": "chengho", "pos": [65, 44], "facing": "south"},
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

entities["areas"] = [  # name, rect x0,y0,x1,y1 (used for music + area titles)
    {"id": "permulaan", "name": "Bukit Permulaan", "rect": [6, 40, 30, 58]},
    {"id": "kampung", "name": "Kampung Jejak", "rect": [20, 22, 47, 40]},
    {"id": "gerbang", "name": "Misi 1.1: Gerbang Masa", "rect": [24, 4, 44, 21]},
    {"id": "siguntang", "name": "Misi 1.4: Bukit Siguntang", "rect": [45, 2, 74, 20]},
    {"id": "melaka", "name": "Misi 1.3: Kota Melaka", "rect": [48, 21, 66, 35]},
    {"id": "pelabuhan", "name": "Misi 1.2: Pelabuhan Melaka", "rect": [56, 36, 79, 52]},
    {"id": "kabus", "name": "Kabus Masa", "rect": [0, 15, 13, 35]},
]


def dist_to(x, y, chars, rmax):
    for r in range(rmax + 1):
        if near(x, y, chars, r):
            return r
    return rmax + 1


# scatter nature (skip roads, plazas, village core)
village = (24, 24, 46, 41)
cells = [(x, y) for y in range(2, H - 1) for x in range(1, W - 2)]
random.shuffle(cells)
for x, y in cells:
    t = terrain[y][x]
    in_village = village[0] <= x <= village[2] and village[1] <= y <= village[3]
    if any((x + dx, y - dy) in reserved for dx in range(2) for dy in range(2)):
        continue
    if t == "." and dist_to(x, y, "=#", 2) >= 2:
        d_sand = dist_to(x, y, "s", 4)
        r = random.random()
        if d_sand <= 2 and r < 0.10:
            place("P", x, y)
        elif not in_village and r < (0.16 if d_sand <= 6 else 0.075):
            place("T", x, y) if can_place("T", x, y, ".", margin=0) else None
        elif r < 0.095:
            place("B", x, y)
        elif r < 0.115:
            place("F", x, y)
        elif r < 0.122:
            place("R", x, y)
    elif t == "s" and dist_to(x, y, "~", 3) >= 1 and random.random() < 0.025:
        place("P", x, y, ground="s")

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "terrain.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in terrain) + "\n")
with open(os.path.join(OUT, "objects.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in objects) + "\n")
with open(os.path.join(OUT, "entities.json"), "w") as f:
    json.dump(entities, f, indent=1)
print("world", W, "x", H, "objects:", sum(c != " " for r in objects for c in r))
