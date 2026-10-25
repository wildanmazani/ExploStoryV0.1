# PixelLab assets to generate

Every file below is optional. The game already runs without it and switches to
the new art as soon as the file exists at the exact path. Nothing here is a
placeholder image: until a file is dropped in, the game uses the old picture
(title, prologue) or code-drawn pixel art (bedroom, bag icon), or a "stand-in"
sprite named in `data/characters.json` (silat group).

After adding files, open the project in the Godot editor once (or run
`godot --headless --import`) so they get imported. Nearest filtering is already
the project default; the new code also forces it on these textures.

## Already generated (25 Oct 2026)

| File | How |
| --- | --- |
| `assets/backgrounds/tajuk/tajuk_penuh.png` | Pro, 320x180: the whole title scene in one piece (used when the 4 parallax layers below don't exist) |
| `assets/backgrounds/bg_bilik_alif_malam_v2.png` | Pro edit of the old night room (layout kept) |
| `assets/backgrounds/bg_int_bilik_alif.png` | Pro edit of `bilik_alif_dengan_perabot.png`: the whole furnished room; the guide's door arrow was painted out by hand |
| `assets/icons/beg.png`, `assets/objects/bilik/beg.png` | Pro 24x24, candidate 3 (the floor bag is the same sprite trimmed) |

Still open: the 4 parallax title layers (A), separate furniture sprites (C2,
only needed without the painted room), `rumah_alif.png` and the silat characters.

## Art specs of this game (match these)

| Thing | Spec |
| --- | --- |
| Screen | 1280x720. Full-screen art is **320x180 drawn at 4x** (dream scenes 640x360 at 2x) |
| Map grid | 16x16 px tiles, top-down 3/4 view, everything faces the camera (south) |
| Characters | 36x36 canvas, 4 directions (south, east, north, west), "Alif style" chibi (big head, 1px dark outline) |
| Portraits | 48x48, cut from the south sprite by `tools/make_portraits.py` |
| Outline / palette | 1px dark brown or navy outline (never pure black), warm saturated colours, 3-4 shades per material, no dithering noise, no anti-aliasing |
| Style words that match | "clean pixel art, Stardew Valley / Pokemon HGSS interior style, cozy, warm, Malaysian" |

Use **PixFlux** (or Pro) for the backgrounds and **Create character** for the people.
Where a prompt says *init image*, load that file as the init/reference image
(strength about 0.4-0.55) so the layout still matches the game's collision grid
and glow areas.

---

## A. Game start: title / login / register backdrop (parallax)

Folder: `assets/backgrounds/tajuk/`. All four files are needed before the
layered backdrop turns on (`scripts/ui/title_backdrop.gd`). Layers 0-2 are
352 px wide so they can drift sideways; layer 3 is the fixed foreground.

Keep clear: the title text sits on art rows 8-52 (top centre), "Ketik untuk
mula" on rows 150-170 (bottom centre), and the animated Pau mascot on art
x 262-310, y 136-176 (bottom right). Leave those areas calm (sky or plain grass).

| File | Size | Transparent | Prompt |
| --- | --- | --- | --- |
| `tajuk_0_langit.png` | 352x180 | No | Pixel art sky background, golden hour morning over a Malaysian coast, soft peach and gold gradient to light turquoise at the top, a large warm sun low in the centre with gentle rings of light, big fluffy cream and orange cumulus clouds on the sides, a few birds, calm and hopeful mood, clean pixel art, limited palette, no ground, no buildings, no text |
| `tajuk_1_jauh.png` | 352x180 | Yes (everything above the skyline) | Pixel art far background layer, transparent sky, distant hazy silhouettes on the lower half: a 15th century Melaka Sultanate wooden palace with tall layered Malay roofs, an ancient stone candi temple, a slim mosque minaret, tall ship masts and sails on a misty sea to the right, soft blue-violet atmospheric haze, low contrast, clean pixel art, no people, no text |
| `tajuk_2_tengah.png` | 352x180 | Yes (top 55%) | Pixel art middle layer, transparent top, rolling green hills along the bottom 45% of the image, Malay kampung houses on stilts with red and brown roofs, coconut trees, a winding river catching golden light, small paddy terraces, warm morning light from the centre, clean pixel art, no people, no text |
| `tajuk_3_depan.png` | 320x180 | Yes (centre and sky) | Pixel art foreground layer, transparent centre: a big leafy rain tree framing the top-left corner with dark green leaves, its trunk on the far left, tall grass and wild flowers along the bottom edge, on a grassy hill on the left third a Malaysian teenage boy seen from behind three-quarters (black hair, glasses, white school shirt, navy trousers, blue backpack) looking toward the distant palace, bottom-right corner plain grass, centre and top centre empty, warm rim light, clean pixel art, no text |

## B. Prologue: Alif's real bedroom at night (story scene)

| File | Size | Transparent |
| --- | --- | --- |
| `assets/backgrounds/bg_bilik_alif_malam_v2.png` | 320x180 | No |

*Init image:* `assets/backgrounds/bg_bilik_alif_malam.png` (keeps the layout:
the prologue makes these areas glow in turn, in art pixels x, y, w, h:
calendar 237,16,28,43 · trial paper on the left wall 6,76,26,40 · desk top
75,104,24,15 · window 107,21,120,70 · Pau plush on the bed 260,85,43,44 ·
textbook at the bottom 176,138,77,26). The game draws the glowing phone on the
desk and the Pau plush on the bed itself, so leave both out of the picture.

Prompt: Pixel art side-view bedroom of a Malaysian secondary school boy at night, cozy and lived-in. Centre: louvred glass window (tingkap nako) with a white metal grille and floral pink curtains, crescent moon and night sky outside, a coconut tree silhouette. Left: wooden study table with a warm desk lamp glowing, open Sejarah textbook, pencil case, a trial exam paper pinned on the wall above. Top right: wall calendar with a date circled in red. Right: single bed with batik blanket and a bantal peluk (bolster), its right end left clear. A standing fan instead of a heater, a folded sejadah on the chair, school bag on the floor, white school shoes by the door, a Harimau Malaya football poster. Warm lamp light against cool blue moonlight, clean pixel art, no people, no text.

## C. Walkable dream bedroom (Bilik Alif, top-down)

The room's collision grid is fixed (`scripts/world/bilik_art.gd`), so match the guides:

* `docs/pixellab/bilik_alif_bilik_kosong.png`: the empty room (use as init image for the shell)
* `docs/pixellab/bilik_alif_dengan_perabot.png`: where every piece of furniture stands

The yellow arrow at the door in the guides is drawn by the game. Leave it out
of your art.

### C1. Room shell

| File | Size | Transparent |
| --- | --- | --- |
| `assets/backgrounds/bg_int_bilik_alif.png` | 320x180 | No |

Must keep: back wall at y 0-47 between x 48-271 (window x 132-188, curtains
either side), tiled floor y 48-159, side walls x 40-47 and 272-279, front wall
y 160-170 with the door gap at x 144-175, dark navy (#1c2130) outside the room.
The rug (x 132-188, y 84-124) and the sejadah (x 52-76, y 114-146) belong in the
shell because Alif walks on or around them.

Prompt: Top-down 3/4 view pixel art interior of an empty Malaysian bedroom, morning. Back wall painted pastel mint green with a wooden skirting, a louvred glass window with white grille and pink floral curtains in the middle of the back wall (coconut tree and blue sky outside), a gold khat calligraphy frame, a round wall clock, a wall calendar, a Harimau Malaya poster and a study timetable on the wall. Beige ceramic floor tiles. A red and gold songket-pattern rug in the middle, a green sejadah laid in the lower-left corner, a doormat at the door gap in the bottom wall. Soft sunbeam from the window. Dark navy outside the walls. No furniture, no people, clean pixel art, Stardew Valley interior style.

### C2. Furniture

Folder: `assets/objects/bilik/`. All transparent. Each sprite is placed by its
bottom-centre on its footprint, so draw it standing on the bottom edge. Same
top-down 3/4 view, same light (window at the top, morning).

| File | Size | Footprint (cells) | Prompt |
| --- | --- | --- | --- |
| `katil.png` | 48x64 | 3x3 | Top-down 3/4 pixel art single wooden bed, headboard at the top, white pillow, a cream bantal peluk bolster on the right side, blue batik-pattern blanket folded over the lower half, transparent background |
| `meja_sisi.png` | 16x24 | 1x1 | Tiny wooden bedside table, a small family photo frame and a red alarm clock on top, top-down 3/4 pixel art, transparent background |
| `rak_buku.png` | 32x32 | 2x1 | Low wooden bookshelf with two rows of colourful books and a small gold trophy on top, top-down 3/4 pixel art, transparent background |
| `kipas.png` | 16x40 | 1x1 | Standing electric fan, white and light blue, round grille head, thin pole and round base, top-down 3/4 pixel art, transparent background |
| `almari.png` | 32x60 | 2x2 | Tall wooden two-door wardrobe, a long mirror on the left door, small gold handles, a red suitcase on top, top-down 3/4 pixel art, transparent background |
| `meja_belajar.png` | 32x36 | 2x2 | Wooden study desk seen from above against a wall, open Sejarah textbook, a pile of books, red pencil case, a mug and a small blue desk lamp, top-down 3/4 pixel art, transparent background |
| `kerusi.png` | 16x20 | 1x1 | Small wooden study chair facing right, top-down 3/4 pixel art, transparent background |
| `beg.png` | 16x18 | 1x1 | Blue school backpack lying on the floor with a small white bun-shaped keychain, top-down 3/4 pixel art, transparent background |
| `kasut.png` | 16x16 | 1x1 | Pair of white canvas Malaysian school shoes on a tiny wooden shoe rack, top-down 3/4 pixel art, transparent background |

When `katil.png` exists, sleeping Alif is drawn on top of it without the
code-drawn blanket.

## D. World and UI

| File | Size | Transparent | Prompt |
| --- | --- | --- | --- |
| `assets/objects/rumah_alif.png` | 96x96 | Yes | Top-down 3/4 pixel art Malay kampung house on short stilts, wooden walls painted light blue, red zinc roof, small wooden stairs at the front door in the middle, potted plants, a white school shoe pair on the stairs, same scale and style as the other kampung houses, facing the camera, transparent background (replaces the blue house used for Rumah Alif in Kampung Jejak) |
| `assets/icons/beg.png` | 24x24 | Yes | Pixel art icon of a blue school backpack with a gold buckle, 1px dark navy outline, front view, transparent background (menu icon for Beg Alif) |

## E. Silat group at Arena Ulang Kaji (characters)

Use PixelLab **Create character**, 4 directions, 36x36, in the same style as
Alif (`assets/characters32/alif/alif_south.png` as the style reference).
Save as `assets/characters32/<id>/<id>_<dir>.png`, then run
`python tools/make_portraits.py guru_silat pesilat_amir pesilat_hafiz` for the
dialogue portraits. Until then the game uses the stand-ins listed in
`data/characters.json` ("stand_in").

| id | Who | Prompt |
| --- | --- | --- |
| `guru_silat` | Guru Jalal, the silat teacher | Malay silat master in his fifties, calm and kind, short grey beard, black baju silat with gold trim, red and gold songket samping, red tanjak headcloth, standing straight, chibi pixel art, 1px outline |
| `pesilat_amir` | Amir, a pesilat (teen) | Malay teenage boy practising silat, black baju silat, red samping at the waist, black tengkolok headcloth, energetic ready stance, chibi pixel art, 1px outline |
| `pesilat_hafiz` | Hafiz, a pesilat (teen) | Malay teenage boy practising silat, dark blue baju silat, gold samping at the waist, no headcloth, short neat hair, focused calm stance, chibi pixel art, 1px outline |
