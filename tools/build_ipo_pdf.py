"""Build the Explo-Story work compilation PDF (game design, code and assets).

    python tools/build_ipo_pdf.py [--owner "Name"] [--out export/ExploStory_Compilation.pdf]

Owner and authors come from docs/ipo/meta.json; chapter text comes from docs/ipo/*.md ({{PLACEHOLDERS}} are filled from data/).
Code, scenes, data and assets are read straight from the repo, unmodified.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import tempfile
import wave
from pathlib import Path

from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Flowable, Frame, Image, KeepTogether,
                                NextPageTemplate, PageBreak, PageTemplate, Paragraph, Spacer, Table,
                                TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

ROOT = Path(__file__).resolve().parent.parent
SKIP_EXT = {".import", ".uid"}

INK = colors.HexColor("#1f2933")
MUTED = colors.HexColor("#616e7c")
ACCENT = colors.HexColor("#0f5e6b")
GOLD = colors.HexColor("#c9a227")
RULE = colors.HexColor("#d9dee3")
TINT = colors.HexColor("#f3f5f7")

PAGE_W, PAGE_H = A4
MARGIN = 18 * mm
CONTENT_W = PAGE_W - 2 * MARGIN


# --- fonts -----------------------------------------------------------------

def register_fonts():
    win = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"
    faces = {
        "Body": "segoeui.ttf", "Body-Bold": "segoeuib.ttf", "Body-Italic": "segoeuii.ttf",
        "Semi": "seguisb.ttf", "Head": "georgia.ttf", "Head-Bold": "georgiab.ttf",
        "Mono": "consola.ttf", "Mono-Bold": "consolab.ttf",
    }
    fallback = {"Body": "Helvetica", "Body-Bold": "Helvetica-Bold", "Body-Italic": "Helvetica-Oblique",
                "Semi": "Helvetica-Bold", "Head": "Times-Roman", "Head-Bold": "Times-Bold",
                "Mono": "Courier", "Mono-Bold": "Courier-Bold"}
    names = {}
    for key, fname in faces.items():
        path = win / fname
        if path.exists():
            pdfmetrics.registerFont(TTFont(key, str(path)))
            names[key] = key
        else:
            names[key] = fallback[key]
    if names["Body"] == "Body":
        from reportlab.pdfbase.pdfmetrics import registerFontFamily
        registerFontFamily("Body", normal="Body", bold="Body-Bold", italic="Body-Italic", boldItalic="Body-Bold")
    return names


F = register_fonts()

ST = {
    "body": ParagraphStyle("body", fontName=F["Body"], fontSize=9.6, leading=14, textColor=INK, spaceAfter=6),
    "small": ParagraphStyle("small", fontName=F["Body"], fontSize=8, leading=10.5, textColor=INK),
    "cell": ParagraphStyle("cell", fontName=F["Body"], fontSize=8.4, leading=11, textColor=INK),
    "cellh": ParagraphStyle("cellh", fontName=F["Semi"], fontSize=8.4, leading=11, textColor=colors.white),
    "cap": ParagraphStyle("cap", fontName=F["Body"], fontSize=6.6, leading=8, textColor=INK, alignment=TA_CENTER),
    "capm": ParagraphStyle("capm", fontName=F["Body"], fontSize=6, leading=7.5, textColor=MUTED, alignment=TA_CENTER),
    "bullet": ParagraphStyle("bullet", fontName=F["Body"], fontSize=9.6, leading=14, textColor=INK,
                             leftIndent=14, bulletIndent=3, spaceAfter=2),
    "h1": ParagraphStyle("h1", fontName=F["Head-Bold"], fontSize=24, leading=29, textColor=ACCENT, spaceAfter=4),
    "h2": ParagraphStyle("h2", fontName=F["Head-Bold"], fontSize=14, leading=18, textColor=INK,
                         spaceBefore=12, spaceAfter=5),
    "h3": ParagraphStyle("h3", fontName=F["Semi"], fontSize=10.5, leading=14, textColor=ACCENT,
                         spaceBefore=8, spaceAfter=3),
    "kicker": ParagraphStyle("kicker", fontName=F["Semi"], fontSize=8.5, leading=11, textColor=GOLD, spaceAfter=2),
    "toc1": ParagraphStyle("toc1", fontName=F["Semi"], fontSize=10.5, leading=15, textColor=INK, leftIndent=0),
    "toc2": ParagraphStyle("toc2", fontName=F["Body"], fontSize=9, leading=12.5, textColor=MUTED, leftIndent=14),
}


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(s):
    s = esc(s)
    s = re.sub(r"`([^`]+)`", lambda m: f'<font name="{F["Mono"]}" color="#0f5e6b">{m.group(1)}</font>', s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(?<![\w*])\*([^*]+)\*(?![\w*])", r"<i>\1</i>", s)
    return s


def rel(p):
    return Path(p).relative_to(ROOT).as_posix()


def load(p):
    with open(ROOT / p, encoding="utf-8") as f:
        return json.load(f)


# --- document --------------------------------------------------------------

class Doc(BaseDocTemplate):
    def __init__(self, path, meta):
        super().__init__(str(path), pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN,
                         topMargin=MARGIN + 6 * mm, bottomMargin=MARGIN,
                         title=f"{meta['title']}: Work Compilation", author=meta["owner"],
                         subject="Game design, source code and asset compilation", creator="")
        self.meta = meta
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="f", leftPadding=0,
                      rightPadding=0, topPadding=0, bottomPadding=0)
        self.addPageTemplates([PageTemplate("cover", [frame], onPage=self.cover_page),
                               PageTemplate("main", [frame], onPage=self.main_page)])
        self._bm = 0

    def cover_page(self, c, d):
        c.saveState()
        c.setFillColor(ACCENT)
        c.rect(0, PAGE_H - 92 * mm, PAGE_W, 92 * mm, stroke=0, fill=1)
        c.setFillColor(GOLD)
        c.rect(0, PAGE_H - 94 * mm, PAGE_W, 2 * mm, stroke=0, fill=1)
        c.restoreState()

    def main_page(self, c, d):
        c.saveState()
        c.setStrokeColor(RULE)
        c.setLineWidth(0.6)
        y = PAGE_H - MARGIN
        c.line(MARGIN, y, PAGE_W - MARGIN, y)
        c.setFont(F["Semi"], 7.5)
        c.setFillColor(ACCENT)
        c.drawString(MARGIN, y + 3, self.meta["title"].upper())
        c.setFont(F["Body"], 7.5)
        c.setFillColor(MUTED)
        c.drawRightString(PAGE_W - MARGIN, y + 3, f"Work compilation · version {self.meta['version']}")
        c.line(MARGIN, MARGIN - 5, PAGE_W - MARGIN, MARGIN - 5)
        c.drawString(MARGIN, MARGIN - 13, self.meta["owner"])
        c.drawRightString(PAGE_W - MARGIN, MARGIN - 13, f"Page {d.page}")
        c.restoreState()

    def beforeDocument(self):
        self._bm = 0

    def afterFlowable(self, fl):
        if isinstance(fl, Paragraph) and getattr(fl, "toc_level", None) is not None:
            text = fl.getPlainText()
            self._bm += 1
            key = f"bm{self._bm}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=fl.toc_level, closed=fl.toc_level > 0)
            self.notify("TOCEntry", (fl.toc_level, text, self.page, key))


def heading(text, level, kicker=None):
    out = []
    if level == 0:
        out.append(PageBreak())
        if kicker:
            out.append(Paragraph(esc(kicker).upper(), ST["kicker"]))
        p = Paragraph(inline(text), ST["h1"])
        p.toc_level = 0
        out += [p, Rule(GOLD, 1.4, 40 * mm), Spacer(1, 10)]
    elif level == 1:
        out.append(CondPageBreak(40 * mm))
        p = Paragraph(inline(text), ST["h2"])
        p.toc_level = 1
        out.append(p)
    else:
        out += [CondPageBreak(25 * mm), Paragraph(inline(text), ST["h3"])]
    return out


class Rule(Flowable):
    def __init__(self, color=RULE, width=0.6, length=None):
        super().__init__()
        self.color, self.lw, self.length = color, width, length

    def wrap(self, aw, ah):
        self.aw = aw
        return aw, self.lw + 2

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(self.lw)
        self.canv.line(0, 1, self.length or self.aw, 1)


def table(rows, widths=None, header=True, zebra=True):
    if not rows:
        return Spacer(1, 0)
    ncol = len(rows[0])
    widths = widths or [CONTENT_W / ncol] * ncol
    data = []
    for i, r in enumerate(rows):
        style = ST["cellh"] if header and i == 0 else ST["cell"]
        data.append([c if isinstance(c, Flowable) else Paragraph(inline(c), style) for c in r])
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    cmds = [("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 5),
            ("RIGHTPADDING", (0, 0), (-1, -1), 5), ("TOPPADDING", (0, 0), (-1, -1), 3.5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5), ("LINEBELOW", (0, 0), (-1, -1), 0.4, RULE)]
    if header:
        cmds.append(("BACKGROUND", (0, 0), (-1, 0), ACCENT))
    if zebra:
        for i in range(1 if header else 0, len(data)):
            if i % 2 == 0:
                cmds.append(("BACKGROUND", (0, i), (-1, i), TINT))
    t.setStyle(TableStyle(cmds))
    return t


# --- markdown chapters ----------------------------------------------------

def render_md(path, placeholders, kicker):
    out, para, bullets = [], [], []

    def flush():
        if para:
            out.append(Paragraph(inline(" ".join(para)), ST["body"]))
            para.clear()
        if bullets:
            for b, mark in bullets:
                out.append(Paragraph(inline(b), ST["bullet"], bulletText=mark))
            out.append(Spacer(1, 4))
            bullets.clear()

    lines = Path(path).read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i].rstrip()
        if not ln.strip():
            flush()
        elif ln.startswith("#"):
            flush()
            level = len(ln) - len(ln.lstrip("#")) - 1
            out += heading(ln.lstrip("#").strip(), level, kicker if level == 0 else None)
        elif ln.startswith("|"):
            flush()
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            out += [table(rows), Spacer(1, 8)]
            continue
        elif re.match(r"^\{\{(\w+)\}\}$", ln.strip()):
            flush()
            out += placeholders.get(ln.strip()[2:-2], [])
        elif re.match(r"^(- |\d+\. )", ln.lstrip()):
            if para:
                flush()
            m = re.match(r"^(- |(\d+)\. )(.*)", ln.lstrip())
            bullets.append((m.group(3), "•" if m.group(1) == "- " else f"{m.group(2)}."))
        else:
            if bullets:
                flush()
            para.append(ln.strip())
        i += 1
    flush()
    return out


# --- data-driven sections ---------------------------------------------------

def chars():
    return load("data/characters.json")


def zones_table(bab):
    ch = chars()
    rows = [["Misi", "Place", "Subtopic and guiding question", "Guide", "Puzzles", "Reward"]]
    for p in sorted((ROOT / "data").glob(f"zon_{bab}_*.json")):
        d = load(rel(p))
        pz = d["puzzles"]
        types = [v.get("type", "?") for v in pz.values()] if isinstance(pz, dict) else list(pz)
        guide = ch.get(d.get("pemandu"), {}).get("name", d.get("pemandu", ""))
        rows.append([d["no"], d["title"], f"**{d['subtopik']}**<br/>*{d.get('persoalan', '')}*".replace("<br/>", "\n"),
                     guide, ", ".join(t.replace("_", " ") for t in types), (d.get("ganjaran") or {}).get("nama", "")])
    rows = [[r[0], r[1], r[2], r[3], r[4], r[5]] for r in rows]
    w = [11 * mm, 30 * mm, 58 * mm, 27 * mm, 22 * mm, CONTENT_W - 148 * mm]
    t_rows = []
    for i, r in enumerate(rows):
        if i == 0:
            t_rows.append(r)
            continue
        sub, q = r[2].split("\n")
        t_rows.append([r[0], r[1], Paragraph(inline(sub) + "<br/>" + inline(q), ST["cell"]), r[3], r[4], r[5]])
    return [table(t_rows, w), Spacer(1, 8)]


def cast_table():
    rows = [["Character", "Role", "Description"]]
    for key, c in chars().items():
        if not c.get("name") or key in ("papan",):
            continue
        role = c.get("gelaran") or ("Fictional" if c.get("rekaan") else "")
        if key == "alif":
            role, lore = "Main character", "Form 4 student; the player."
        elif key == "pau":
            role, lore = "Companion", "Follows Alif, explains missions and gives hints."
        else:
            lore = c.get("lore", "")
        if c.get("zon"):
            role = f"{role} (Misi {c['zon'].replace('_', '.')})" if role else f"Misi {c['zon'].replace('_', '.')}"
        rows.append([f"**{c['name']}**", role, lore])
    return [table(rows, [40 * mm, 45 * mm, CONTENT_W - 85 * mm])]


def moves_table():
    m = load("data/brawl/moves.json")["moves"]
    rows = [["Move", "Duration (s)", "Damage", "Effect"]]
    for k, v in m.items():
        if "dmg" not in v:
            continue
        eff = []
        if v.get("down"):
            eff.append("knock-down")
        if v.get("lunge"):
            eff.append("lunge")
        if v.get("radius"):
            eff.append(f"hits all round ({v['radius']} px)")
        if v.get("word"):
            eff.append(f"“{v['word']}”")
        rows.append([k, v["time"], v["dmg"], ", ".join(eff)])
    return [Paragraph("<b>Move data</b> (damage × 1.0 with Semangat, × 0.3 when Lemah)", ST["body"]),
            table(rows, [35 * mm, 28 * mm, 22 * mm, CONTENT_W - 85 * mm]), Spacer(1, 8)]


def weapons_table():
    w = load("data/brawl/moves.json")["weapons"]
    rows = [["School item", "Damage", "Reach", "Uses", "Thrown damage"]]
    for v in w.values():
        rows.append([v["name"], v["dmg"], v["reach"], v["uses"], v["throw_dmg"]])
    return [Paragraph("<b>Pick-up items</b>", ST["body"]), table(rows), Spacer(1, 8)]


def skins_table():
    s = load("data/skins.json")["skins"]
    rows = [["Outfit", "Price (coins)", "Description"]]
    for v in s:
        rows.append([v["name"], "Free" if not v.get("price") else v["price"], v.get("info", "")])
    return [table(rows, [40 * mm, 28 * mm, CONTENT_W - 68 * mm]), Spacer(1, 8)]


def learning_section():
    out = heading("Learning Content", 0, "Chapter 4")
    out.append(Paragraph("Each mission adds a page to <b>Nota Alif</b>, and each chapter has a question bank "
                         "used by the Ujian Bab and the Bilik Pertarungan (Bab 1, Bab 2 or Campur).", ST["body"]))
    for bab, nota in ((1, "data/nota.json"), (2, "data/nota_bab2.json")):
        n = load(nota)
        q = load(f"data/soalan/bab{bab}.json")
        out += heading(f"Bab {bab}: {n['title'].split(':')[-1].strip()}", 1)
        out.append(Paragraph(f"<b>Nota Alif pages</b> ({len(n['pages'])})", ST["body"]))
        rows = [["Misi", "Page title", "Key points"]]
        for pg in n["pages"]:
            items = pg.get("items") or []
            pts = "; ".join(f"{it.get('text', '')}" + (f": {it['sub']}" if it.get("sub") else "")
                            for it in items[:4] if isinstance(it, dict))
            rows.append([str(pg.get("zone", "")).replace("_", "."), pg.get("title", ""), pts])
        out += [table(rows, [14 * mm, 45 * mm, CONTENT_W - 59 * mm]), Spacer(1, 8)]
        qs = q["questions"]
        by = {}
        for x in qs:
            by[x.get("sub") or str(x.get("zon", "")).replace("_", ".")] = by.get(
                x.get("sub") or str(x.get("zon", "")).replace("_", "."), 0) + 1
        out.append(Paragraph(f"<b>Question bank:</b> {len(qs)} questions. By subtopic: "
                             + ", ".join(f"{k} ({v})" for k, v in sorted(by.items())), ST["body"]))
        out.append(Paragraph("<b>Sample questions</b>", ST["body"]))
        for x in qs[:: max(1, len(qs) // 3)][:3]:
            opts = "".join(f"<br/>&nbsp;&nbsp;{'ABCD'[i]}. " + (f"<b>{esc(o)}</b> (answer)" if i == x.get("answer")
                                                                  else esc(o))
                           for i, o in enumerate(x.get("options", [])))
            out.append(KeepTogether([Paragraph(f"<b>{esc(x.get('sub', ''))}</b> {esc(x['q'])}{opts}", ST["cell"]),
                                     Spacer(1, 6)]))
    return out


# --- world map ---------------------------------------------------------------

TERRAIN_COL = {"~": (88, 152, 196), ".": (126, 186, 96), ",": (104, 164, 82), "s": (226, 208, 150),
               "j": (162, 160, 152), "=": (196, 156, 102), "r": (98, 170, 214)}


class MapFlow(Flowable):
    def __init__(self, img, gw, gh, areas, width):
        super().__init__()
        self.img, self.gw, self.gh, self.areas = img, gw, gh, areas
        self.w = width
        self.h = width * gh / gw

    def wrap(self, aw, ah):
        return self.w, self.h

    def draw(self):
        c = self.canv
        c.drawImage(self.img, 0, 0, self.w, self.h)
        sx, sy = self.w / self.gw, self.h / self.gh
        for n, a in enumerate(self.areas, 1):
            x0, y0, x1, y1 = a["rect"]
            c.setStrokeColor(colors.white)
            c.setLineWidth(0.8)
            c.setDash(2, 1.5)
            c.rect(x0 * sx, self.h - (y1 + 1) * sy, (x1 - x0 + 1) * sx, (y1 - y0 + 1) * sy, stroke=1, fill=0)
            c.setDash()
            cx, cy = (x0 + x1 + 1) / 2 * sx, self.h - (y0 + y1 + 1) / 2 * sy
            c.setFillColor(ACCENT)
            c.circle(cx, cy, 5.2, stroke=0, fill=1)
            c.setFillColor(colors.white)
            c.setFont(F["Semi"], 6.5)
            c.drawCentredString(cx, cy - 2.3, str(n))


def world_section(tmp):
    out = heading("World Map", 0, "Chapter 5")
    t = (ROOT / "data/world/terrain.txt").read_text(encoding="utf-8").splitlines()
    gh, gw = len(t), max(len(r) for r in t)
    im = PILImage.new("RGB", (gw, gh), TERRAIN_COL["~"])
    px = im.load()
    for y, row in enumerate(t):
        for x, ch in enumerate(row):
            px[x, y] = TERRAIN_COL.get(ch, (126, 186, 96))
    im = im.resize((gw * 8, gh * 8), PILImage.NEAREST)
    path = tmp / "world_map.png"
    im.save(path)
    areas = load("data/world/entities.json")["areas"]
    out.append(Paragraph(f"The world is a {gw} × {gh} tile grid with two islands. Bab 1 is on the left island "
                         "(Kampung Jejak and its four mission areas). Bab 2, Lembah Kebangkitan, is on the right "
                         "island, reached through the Pintu Kabus portal. Numbered boxes mark the named areas.",
                         ST["body"]))
    out += [MapFlow(str(path), gw, gh, areas, CONTENT_W), Spacer(1, 8)]
    key = [("Sea", "~"), ("Grass", "."), ("Meadow", ","), ("Sand", "s"), ("Gravel road (Bab 2)", "j"),
           ("Dirt road", "="), ("River", "r")]
    sw, cmds = [], []
    for i, (name, ch) in enumerate(key):
        sw += ["", Paragraph(name, ST["small"])]
        cmds.append(("BACKGROUND", (2 * i, 0), (2 * i, 0), colors.Color(*[v / 255 for v in TERRAIN_COL[ch]])))
    lt = Table([sw], colWidths=[4 * mm, CONTENT_W / len(key) - 4 * mm] * len(key), rowHeights=[4 * mm])
    lt.setStyle(TableStyle(cmds + [("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (0, 0), (-1, -1), 3)]))
    out += [lt, Spacer(1, 6)]
    rows = [["#", "Area", "Tiles (x0, y0 – x1, y1)"]]
    for n, a in enumerate(areas, 1):
        r = a["rect"]
        rows.append([n, a["name"], f"{r[0]}, {r[1]} – {r[2]}, {r[3]}"])
    out.append(table(rows, [10 * mm, 90 * mm, CONTENT_W - 100 * mm]))
    return out


# --- project structure, code and data -----------------------------------------

def walk(base, exts):
    return sorted((p for p in (ROOT / base).rglob("*") if p.is_file() and p.suffix in exts), key=lambda p: rel(p))


def structure_section():
    out = heading("Project Structure", 0, "Chapter 6")
    groups = [("scripts", "GDScript game code"), ("scenes", "Godot scenes"), ("shaders", "Shaders"),
              ("data", "Game content (JSON)"), ("assets", "Art, audio and fonts")]
    rows = [["Folder", "Contents", "Files"]]
    for g, desc in groups:
        n = sum(1 for p in (ROOT / g).rglob("*") if p.is_file() and p.suffix not in SKIP_EXT)
        rows.append([f"`{g}/`", desc, n])
    out += [table(rows, [40 * mm, 100 * mm, CONTENT_W - 140 * mm]), Spacer(1, 8)]

    out += heading("Autoloads", 1)
    al = []
    in_al = False
    for ln in (ROOT / "project.godot").read_text(encoding="utf-8").splitlines():
        if ln.startswith("["):
            in_al = ln.strip() == "[autoload]"
            continue
        if in_al and "=" in ln:
            k, v = ln.split("=", 1)
            al.append([k, f"`{v.strip().strip('\"').lstrip('*')}`"])
    out.append(table([["Singleton", "Script"]] + al, [45 * mm, CONTENT_W - 45 * mm]))

    out += heading("Code modules", 1)
    rows = [["Module", "Files", "Lines"]]
    mods = {}
    for p in walk("scripts", {".gd"}):
        m = rel(p).split("/")
        key = "/".join(m[:2]) + "/" if len(m) > 2 else "scripts/ (root)"
        n = len(p.read_text(encoding="utf-8", errors="replace").splitlines())
        f, l = mods.get(key, (0, 0))
        mods[key] = (f + 1, l + n)
    for k, (f, l) in sorted(mods.items()):
        rows.append([f"`{k}`", f, f"{l:,}"])
    rows.append(["**Total**", sum(v[0] for v in mods.values()), f"**{sum(v[1] for v in mods.values()):,}**"])
    out.append(table(rows, [90 * mm, 30 * mm, CONTENT_W - 120 * mm]))

    out += heading("Scenes", 1)
    rows = [["Scene", "Root node", "Nodes"]]
    for p in walk("scenes", {".tscn"}):
        txt = p.read_text(encoding="utf-8", errors="replace")
        nodes = re.findall(r'^\[node name="([^"]+)" type="([^"]+)"', txt, re.M)
        root = f"{nodes[0][0]} ({nodes[0][1]})" if nodes else ""
        rows.append([f"`{rel(p)}`", root, txt.count("[node ")])
    out.append(table(rows, [90 * mm, 60 * mm, CONTENT_W - 150 * mm]))
    return out


class CodeBlock(Flowable):
    """Monospace listing with line numbers that splits across pages and wraps long lines."""

    FS, LEAD = 6.9, 8.4

    def __init__(self, lines, start=1, wrapped=None):
        super().__init__()
        self.lines = lines
        self.start = start
        self.wrapped = wrapped

    def _wrap_lines(self, aw):
        cw = pdfmetrics.stringWidth("M", F["Mono"], self.FS)
        num_w = 30
        cols = max(20, int((aw - num_w - 8) / cw))
        out = []
        for i, ln in enumerate(self.lines):
            ln = ln.replace("\t", "    ")
            parts = [ln[j:j + cols] for j in range(0, len(ln), cols)] or [""]
            for k, part in enumerate(parts):
                out.append((self.start + i if k == 0 else None, part))
        return out

    def wrap(self, aw, ah):
        self.aw = aw
        if self.wrapped is None:
            self.wrapped = self._wrap_lines(aw)
        self.h = len(self.wrapped) * self.LEAD + 6
        return aw, self.h

    def split(self, aw, ah):
        self.wrap(aw, ah)
        n = int((ah - 6) // self.LEAD)
        if n <= 0:
            return []
        if n >= len(self.wrapped):
            return [self]
        return [CodeBlock(self.lines, wrapped=self.wrapped[:n]), CodeBlock(self.lines, wrapped=self.wrapped[n:])]

    def draw(self):
        c = self.canv
        c.setFillColor(TINT)
        c.rect(0, 0, self.aw, self.h, stroke=0, fill=1)
        c.setStrokeColor(RULE)
        c.setLineWidth(0.4)
        c.line(30, 0, 30, self.h)
        y = self.h - 3 - self.FS
        for num, text in self.wrapped:
            if num is not None:
                c.setFont(F["Mono"], self.FS - 0.8)
                c.setFillColor(MUTED)
                c.drawRightString(26, y, str(num))
            c.setFont(F["Mono"], self.FS)
            c.setFillColor(INK)
            c.drawString(34, y, text)
            y -= self.LEAD


def code_section():
    out = heading("Source Code", 0, "Appendix A")
    files = walk("scripts", {".gd"}) + walk("shaders", {".gdshader"})
    out.append(Paragraph(f"Complete, unmodified listings of all {len(files)} source files "
                         "(GDScript and shaders), grouped by folder, with line numbers.", ST["body"]))
    rows = [["File", "Lines"]]
    texts = []
    for p in files:
        t = p.read_text(encoding="utf-8", errors="replace").splitlines()
        texts.append((p, t))
        rows.append([f"`{rel(p)}`", len(t)])
    out.append(table(rows, [CONTENT_W - 25 * mm, 25 * mm]))
    current = None
    for p, t in texts:
        folder = str(Path(rel(p)).parent.as_posix())
        if folder != current:
            current = folder
            out += heading(f"{folder}/", 1)
        out += [CondPageBreak(30 * mm),
                Paragraph(f'<font name="{F["Mono-Bold"]}">{esc(p.name)}</font>'
                          f'<font color="#616e7c">  ·  {esc(rel(p))}  ·  {len(t)} lines</font>', ST["h3"]),
                CodeBlock(t), Spacer(1, 10)]
    return out


def data_section():
    out = heading("Game Data", 0, "Appendix B")
    files = walk("data", {".json", ".txt"})
    out.append(Paragraph("All story text, dialogue, puzzles, questions and world layout are stored as data files "
                         "read by the game at runtime. Files up to 4 KB are listed in full; larger files show "
                         "their first 70 lines.", ST["body"]))
    rows = [["File", "Size", "Top-level content"]]
    for p in files:
        top = ""
        if p.suffix == ".json":
            try:
                d = json.loads(p.read_text(encoding="utf-8"))
                top = ", ".join(list(d.keys())[:8]) + (" …" if len(d) > 8 else "") if isinstance(d, dict) \
                    else f"list of {len(d)}"
            except Exception:
                top = ""
        rows.append([f"`{rel(p)}`", f"{p.stat().st_size / 1024:.1f} KB", top])
    out.append(table(rows, [62 * mm, 18 * mm, CONTENT_W - 80 * mm]))
    for p in files:
        t = p.read_text(encoding="utf-8", errors="replace").splitlines()
        full = p.stat().st_size <= 4096
        shown = t if full else t[:70]
        out += [CondPageBreak(30 * mm),
                Paragraph(f'<font name="{F["Mono-Bold"]}">{esc(rel(p))}</font>'
                          f'<font color="#616e7c">  ·  {len(t)} lines'
                          f'{"" if full else f" (first {len(shown)} shown)"}</font>', ST["h3"]),
                CodeBlock(shown), Spacer(1, 10)]
    return out


# --- assets ----------------------------------------------------------------------

def bab_tag(name):
    n = name.lower()
    if re.search(r"zon_?1|bab_?1|telaga|melaka|siguntang|gerbang|kampung", n):
        return "Bab 1"
    if re.search(r"zon_?2|bab_?2|lembah|sitc|jelutong|menara|dermaga", n):
        return "Bab 2"
    return ""


def char_tags():
    tags = {}
    for c in chars().values():
        z = c.get("zon")
        if z and c.get("sprite"):
            tags[c["sprite"]] = f"Bab {z[0]}"
    return tags


def thumb(src, tmp, box=300):
    im = PILImage.open(src)
    im.load()
    w, h = im.size
    scale = min(box / w, box / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    im = im.convert("RGBA").resize((nw, nh), PILImage.NEAREST if scale >= 1 else PILImage.LANCZOS)
    dst = tmp / ("t_" + re.sub(r"[^\w.-]", "_", rel(src)))
    im.save(dst)
    return str(dst), (w, h), (nw, nh)


def grid(cells, cols=5):
    cw = CONTENT_W / cols
    rows = [cells[i:i + cols] for i in range(0, len(cells), cols)]
    if rows and len(rows[-1]) < cols:
        rows[-1] += [""] * (cols - len(rows[-1]))
    t = Table(rows, colWidths=[cw] * cols)
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "BOTTOM"), ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                           ("BOX", (0, 0), (-1, -1), 0.4, RULE), ("INNERGRID", (0, 0), (-1, -1), 0.4, RULE),
                           ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    return t


def cell(img_path, size_pt, caption, sub):
    w, h = size_pt
    return [Image(img_path, width=w, height=h, mask="auto"), Spacer(1, 3),
            Paragraph(esc(caption), ST["cap"]), Paragraph(esc(sub), ST["capm"])]


def asset_section(tmp):
    out = heading("Asset Catalogue", 0, "Appendix C")
    all_png = [p for p in (ROOT / "assets").rglob("*.png")]
    out.append(Paragraph(f"Every image in the game ({len(all_png)} PNG files), grouped by folder. Character "
                         "sprites are shown once per sprite set (first frame) with the number of frames in the "
                         "set. Captions give the file name and pixel size; a chapter tag is shown where the "
                         "asset belongs to one chapter.", ST["body"]))
    box_pt = CONTENT_W / 5 - 14
    folders = {}
    for p in all_png:
        parts = Path(rel(p)).parts
        if parts[1] == "characters32":
            continue
        folders.setdefault("/".join(parts[:-1]), []).append(p)
    ctags = char_tags()
    for folder in sorted(folders):
        files = sorted(folders[folder], key=lambda p: p.name)
        out += heading(f"{folder}/  ({len(files)})", 1)
        cells = []
        for p in files:
            tp, (w, h), (nw, nh) = thumb(p, tmp)
            s = min(box_pt / nw, box_pt / nh, 1.0)
            tag = bab_tag(p.name)
            cells.append(cell(tp, (nw * s, nh * s), p.name, f"{w}×{h}" + (f" · {tag}" if tag else "")))
        out.append(grid(cells))

    sets = sorted(d for d in (ROOT / "assets/characters32").iterdir() if d.is_dir())
    n_frames = sum(1 for d in sets for _ in d.glob("*.png"))
    out += heading(f"assets/characters32/  ({len(sets)} sprite sets, {n_frames} frames)", 1)
    cells = []
    for d in sets:
        frames = sorted(d.glob("*.png"))
        if not frames:
            continue
        first = next((f for f in frames if f.stem.endswith("_south")), None) or \
            next((f for f in frames if f.stem.endswith("east_0")), frames[0])
        tp, (w, h), (nw, nh) = thumb(first, tmp, 96)
        s = min(box_pt * 0.7 / nw, box_pt * 0.7 / nh)
        base = d.name.split("_")[0]
        tag = ctags.get(d.name) or ctags.get(base, "")
        cells.append(cell(tp, (nw * s, nh * s), d.name, f"{len(frames)} frames · {w}×{h}" + (f" · {tag}" if tag else "")))
    out.append(grid(cells, 6))

    wavs = sorted((ROOT / "assets").rglob("*.wav"), key=lambda p: rel(p))
    others = sorted(p for p in (ROOT / "assets").rglob("*") if p.is_file() and p.suffix in {".ogg", ".mp3", ".woff2", ".ttf", ".otf"})
    if wavs:
        out += heading(f"Audio  ({len(wavs)})", 1)
        rows = [["File", "Length", "Format"]]
        for p in wavs:
            try:
                with wave.open(str(p)) as w:
                    secs = w.getnframes() / w.getframerate()
                    fmt = f"WAV {w.getframerate()} Hz, {w.getnchannels()} ch"
            except Exception:
                secs, fmt = 0, "WAV"
            rows.append([f"`{rel(p)}`", f"{secs:.1f} s", fmt])
        out.append(table(rows, [100 * mm, 25 * mm, CONTENT_W - 125 * mm]))
    if others:
        out += heading(f"Fonts and other media  ({len(others)})", 1)
        out.append(table([["File", "Size"]] + [[f"`{rel(p)}`", f"{p.stat().st_size / 1024:.0f} KB"] for p in others],
                         [CONTENT_W - 30 * mm, 30 * mm]))
    return out


# --- cover and assembly -----------------------------------------------------------

def cover(meta):
    title = ParagraphStyle("ct", fontName=F["Head-Bold"], fontSize=40, leading=46, textColor=colors.white)
    sub = ParagraphStyle("cs", fontName=F["Body"], fontSize=13, leading=18, textColor=colors.HexColor("#d7ecef"))
    lab = ParagraphStyle("cl", fontName=F["Semi"], fontSize=8, leading=10, textColor=MUTED)
    val = ParagraphStyle("cv", fontName=F["Body"], fontSize=11, leading=15, textColor=INK)
    out = [Spacer(1, 22 * mm), Paragraph("EXPLO-STORY", title), Spacer(1, 4),
           Paragraph("A 2D adventure RPG for Sejarah KSSM Tingkatan 4", sub),
           Paragraph("Bab 1: Warisan Negara Bangsa · Bab 2: Kebangkitan Nasionalisme", sub),
           Spacer(1, 52 * mm),
           Paragraph("WORK COMPILATION", ParagraphStyle("k", parent=ST["kicker"], fontSize=11)),
           Paragraph("Game design, mechanics, story, source code and assets",
                     ParagraphStyle("x", parent=ST["h2"], spaceBefore=0)),
           Spacer(1, 14 * mm)]
    rows = [[Paragraph("OWNER", lab), Paragraph(esc(meta["owner"]), val)]]
    if meta.get("authors"):
        rows.append([Paragraph("AUTHORS", lab),
                     Paragraph("<br/>".join(f"{i}. {esc(a)}" for i, a in enumerate(meta["authors"], 1)), val)])
    rows += [[Paragraph("VERSION", lab), Paragraph(esc(meta["version"]), val)],
            [Paragraph("DATE", lab), Paragraph(esc(meta["date"]), val)],
            [Paragraph("ENGINE", lab), Paragraph("Godot Engine 4 (GDScript)", val)],
            [Paragraph("PLATFORM", lab), Paragraph("Web (HTML5), Windows", val)]]
    t = Table(rows, colWidths=[30 * mm, CONTENT_W - 30 * mm])
    t.setStyle(TableStyle([("LINEBELOW", (0, 0), (-1, -1), 0.4, RULE), ("TOPPADDING", (0, 0), (-1, -1), 6),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 6), ("VALIGN", (0, 0), (-1, -1), "MIDDLE")]))
    return out + [t, NextPageTemplate("main")]


def build(owner, out_path):
    try:
        version = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        version = "unversioned"
    meta = {"title": "Explo-Story", "owner": "[Owner name]", "authors": [], "version": version,
            "date": datetime.date.today().strftime("%d %B %Y")}
    meta_file = ROOT / "docs/ipo/meta.json"
    if meta_file.exists():
        meta.update(json.loads(meta_file.read_text(encoding="utf-8")))
    if owner:
        meta["owner"] = owner
    tmp = Path(tempfile.mkdtemp(prefix="ipo_pdf_"))

    story = cover(meta)
    toc = TableOfContents()
    toc.levelStyles = [ST["toc1"], ST["toc2"]]
    toc.dotsMinLevel = 0
    story += [PageBreak(), Paragraph("Contents", ST["h1"]), Rule(GOLD, 1.4, 40 * mm), Spacer(1, 10), toc]

    ph = {"MOVES_TABLE": moves_table(), "WEAPONS_TABLE": weapons_table(), "SKINS_TABLE": skins_table(),
          "ZONES_1": zones_table(1), "ZONES_2": zones_table(2), "CAST_TABLE": cast_table()}
    ipo = ROOT / "docs/ipo"
    for n, md in enumerate(sorted(ipo.glob("*.md")), 1):
        story += render_md(md, ph, f"Chapter {n}")
    story += learning_section()
    story += world_section(tmp)
    story += structure_section()
    story += code_section()
    story += data_section()
    story += asset_section(tmp)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    doc = Doc(out_path, meta)
    doc.multiBuild(story)
    print(f"wrote {out_path} ({out_path.stat().st_size / 1e6:.1f} MB, {doc.page} pages)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", default=None, help="overrides the owner in docs/ipo/meta.json")
    ap.add_argument("--out", default=str(ROOT / "export/ExploStory_Compilation.pdf"))
    a = ap.parse_args()
    build(a.owner, Path(a.out))
