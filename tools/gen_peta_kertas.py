"""The paper map Mak Som gives Alif (assets/ui/peta_kertas.png, 320x180).

Old folded paper in pixel art: warm parchment with grain, darker toasted
edges, a ragged outline, two fold creases and a small tea stain. The middle
stays plain because scripts/ui/peta_kertas.gd draws the island on it.

    python tools/gen_peta_kertas.py
"""
import math
import pathlib
import random

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/ui/peta_kertas.png"
W, H = 320, 180
PAPER = (236, 219, 172)
EDGE = (176, 128, 74)
INK = (92, 60, 32)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main() -> None:
    rnd = random.Random(7)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    # a ragged outline: each side wanders in by 0..4 px
    top = [2 + int(2 * math.sin(x * 0.21) + rnd.random() * 2) for x in range(W)]
    bot = [H - 3 - int(2 * math.sin(x * 0.17 + 1) + rnd.random() * 2) for x in range(W)]
    left = [2 + int(2 * math.sin(y * 0.3) + rnd.random() * 2) for y in range(H)]
    right = [W - 3 - int(2 * math.sin(y * 0.27 + 2) + rnd.random() * 2) for y in range(H)]
    for y in range(H):
        for x in range(W):
            if y < top[x] or y > bot[x] or x < left[y] or x > right[y]:
                continue
            d = min(y - top[x], bot[x] - y, x - left[y], right[y] - x)
            c = PAPER
            # toasted edges, a little uneven
            burn = max(0.0, 1.0 - d / (9.0 + 3 * math.sin(x * 0.07 + y * 0.05)))
            c = mix(c, EDGE, burn * 0.85)
            # grain, in 2x2 blocks so it reads as pixel art
            g = ((x // 2 * 73856093) ^ (y // 2 * 19349663)) % 7
            c = mix(c, (0, 0, 0), g * 0.008)
            # fold creases: thirds across, half down
            for fx in (W // 3, 2 * W // 3):
                if x == fx:
                    c = mix(c, EDGE, 0.35)
                elif x == fx + 1:
                    c = mix(c, (255, 248, 225), 0.35)
            if y == H // 2:
                c = mix(c, EDGE, 0.3)
            elif y == H // 2 + 1:
                c = mix(c, (255, 248, 225), 0.3)
            # a tea stain near the bottom right corner
            r = math.hypot(x - 302, y - 165)
            if 9 <= r <= 11:
                c = mix(c, EDGE, 0.35)
            elif r < 9:
                c = mix(c, EDGE, 0.1)
            px[x, y] = (*c, 255)
            if d == 0:
                px[x, y] = (*INK, 255)
    # a compass rose, top right
    cx, cy = 304, 20
    for i in range(-9, 10):
        for (x, y) in ((cx + i, cy), (cx, cy + i)):
            px[x, y] = (*INK, 255)
    for (x, y) in ((cx, cy - 10), (cx - 1, cy - 9), (cx + 1, cy - 9)):
        px[x, y] = (170, 40, 30, 255)  # north
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
