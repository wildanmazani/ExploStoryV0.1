"""The SPM timetable on the wall of Alif's desk (bg_meja_pov.png, top left).

The painted one had made-up letters ("HUS 3a 5a"). This repaints its paper
with a real exam timetable in a 3x5 pixel font: subject and date, Sejarah
circled in red (Alif: "SPM Sejarah. Tiga hari lagi." - the Kalendar in
data/prologue_room.json). The left of the frame runs off the picture, so
everything sits inside the visible paper, x 0-56, y 17-84.

    python tools/gen_jadual.py
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
BG = ROOT / "assets/backgrounds/bg_meja_pov.png"
PAPER = (0, 17, 57, 85)        # x0, y0, x1, y1 (exclusive) of the visible paper
PAPER_C = (43, 55, 86)
INK = (12, 20, 42)
LINE = (22, 33, 62)
RED = (196, 58, 58)

ROWS = [("BM", "2/11"), ("BI", "4/11"), ("MATE", "5/11"), ("SEJARAH", "9/11"), ("SAINS", "11/11")]
MARK = "SEJARAH"

F = {  # 3x5 glyphs, rows top to bottom
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "110", "100", "110", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["10001", "11011", "10101", "10001", "10001"], "N": ["1001", "1101", "1011", "1001", "1001"],
    "P": ["110", "101", "110", "100", "100"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    "/": ["001", "001", "010", "100", "100"], " ": ["000"] * 5,
}


def text(px, x: int, y: int, s: str, c) -> int:
    for ch in s:
        for r, row in enumerate(F[ch]):
            for k, bit in enumerate(row):
                if bit == "1":
                    px[x + k, y + r] = c
        x += len(F[ch][0]) + 1
    return x


def width(s: str) -> int:
    return sum(len(F[ch][0]) + 1 for ch in s) - 1


def main() -> None:
    im = Image.open(BG).convert("RGBA")
    px = im.load()
    x0, y0, x1, y1 = PAPER
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = PAPER_C + (255,)
    split = 31  # subject | date
    # title
    title = "JADUAL SPM"
    text(px, x0 + (x1 - x0 - width(title)) // 2, y0 + 2, title, INK + (255,))
    top = y0 + 9
    for x in range(x0, x1):
        px[x, top] = INK + (255,)
    row_h = 11  # text at +3..+7, the red ring at +1 and +9
    for i, (subj, date) in enumerate(ROWS):
        ry = top + 1 + i * row_h
        ink = (RED if subj == MARK else INK) + (255,)
        text(px, x0 + 3, ry + 3, subj, ink)
        text(px, x1 - 4 - width(date), ry + 3, date, ink)
        if i < len(ROWS) - 1:
            for x in range(x0, x1):
                px[x, ry + row_h - 1] = LINE + (255,)
        if subj == MARK:  # a red ring drawn round the row, by hand
            for x in range(x0 + 1, x1 - 1):
                px[x, ry + 1] = RED + (255,)
                px[x, ry + row_h - 2] = RED + (255,)
            for y in range(ry + 2, ry + row_h - 2):
                px[x0 + 1 if x0 > 0 else x0, y] = RED + (255,)
                px[x1 - 2, y] = RED + (255,)
    for y in range(top + 1, top + row_h * len(ROWS) - 1):
        if px[split, y][:3] != RED:
            px[split, y] = LINE + (255,)
    im.save(BG)
    print("jadual:", BG)


if __name__ == "__main__":
    main()
