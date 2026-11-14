"""Pau has no hands: rub out the two little arm lines at the bottom corners of
the dialogue portraits (assets/portraits/pau_*.png), so the bun is one round
shape like the Pau that follows Alif in game.

The arms are drawn as mid-brown lines (darker than the bun's shading, lighter
than the black outline) near the left and right edges of the lower half.
Each such pixel takes the colour of the bun next to it, towards the middle.

    python tools/pau_no_hands.py
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
FILES = sorted((ROOT / "assets/portraits").glob("pau_*.png"))
ROWS = range(32, 42)      # lower half of the 48 px bun
EDGE = 13                 # how far in from each side the arms reach


def lum(p) -> float:
    return (p[0] + p[1] + p[2]) / 3


def is_arm(p) -> bool:
    return p[3] >= 128 and 60 <= lum(p) < 140


def fix(path: pathlib.Path) -> int:
    im = Image.open(path).convert("RGBA")
    w = im.width
    px = im.load()
    n = 0
    for y in ROWS:
        for x in list(range(0, EDGE)) + list(range(w - EDGE, w)):
            if not is_arm(px[x, y]):
                continue
            step = 1 if x < w // 2 else -1  # look towards the middle
            k = x + step
            while 0 <= k < w and (is_arm(px[k, y]) or lum(px[k, y]) < 60):
                k += step
            if 0 <= k < w:
                px[x, y] = px[k, y]
                n += 1
    n += round_sides(px, w)
    n += thin_outline(px, w)
    im.save(path)
    return n


## the arm's underside is a short run of outline next to the real outline:
## keep one outline pixel and give the rest the bun's colour
def thin_outline(px, w) -> int:
    n = 0
    for y in range(34, 42):
        for side in (-1, 1):
            x = edge(px, w, y, side)
            if x is None:
                continue
            k = x - side
            run = []
            while 0 <= k < w and px[k, y][3] >= 128 and lum(px[k, y]) < 60:
                run.append(k)
                k -= side
            if run and 0 <= k < w:
                for r in run:
                    px[r, y] = px[k, y]
                    n += 1
    return n


def edge(px, w, y, side):
    xs = range(w) if side < 0 else range(w - 1, -1, -1)
    for x in xs:
        if px[x, y][3] >= 128:
            return x
    return None


## The arms also leave a little step in the outline at the bottom corners.
## Make each side's outline bulge evenly (each row steps in at least as much
## as the row above it) by filling the step: the new edge pixel takes the
## outline colour and the old outline pixel becomes the bun's shading.
def round_sides(px, w) -> int:
    n = 0
    top, bottom = 30, 44
    for side in (-1, 1):
        e = {y: edge(px, w, y, side) for y in range(top, bottom + 1)}
        inward = {y: (e[y] if side < 0 else w - 1 - e[y]) for y in e if e[y] is not None}
        ys = sorted(inward)
        # convex: the step inwards per row never shrinks going down
        want = dict(inward)
        changed = True
        while changed:
            changed = False
            for i in range(1, len(ys) - 1):
                a, b, c = want[ys[i - 1]], want[ys[i]], want[ys[i + 1]]
                if b - a > c - b and b > a:  # this row sits too far in: bring it out
                    want[ys[i]] = b - 1
                    changed = True
        for y in ys:
            d = inward[y] - want[y]
            if d <= 0:
                continue
            old = e[y]
            line = px[old, y]
            shade = px[old - side, y]  # the bun just inside the old outline
            for k in range(d):
                x = old + side * (k + 1)
                px[x, y] = line if k == d - 1 else shade
                n += 1
            px[old, y] = shade
    return n


if __name__ == "__main__":
    for f in FILES:
        print(f.name, fix(f), "px")
