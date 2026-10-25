# Content Consistent Design: characters

Every character in Explo-Story must look like it belongs next to **Alif**. Alif is the standard. If a new sprite doesn't sit right beside Alif on the contact sheet (`python tools/asset_sheet.py --characters`), redo it.

## 1. The standard: Alif

| Setting | Value |
|---|---|
| PixelLab character | `Alif HD`, `c94f966a-677f-4df7-a53a-786b2b84d92d` (6 outfit states) |
| Style reference | `Alif HD B36`, `09c32366-5aa6-4780-8aa3-d07fcf662b05` (the same Alif with 8 directions, used as `style_character_id`) |
| Canvas | **36 × 36 px** |
| View | **low top-down** (about 20°, classic 3/4 RPG) |
| Look | 16-bit, clean single-colour dark outline, soft 2–3 step shading, warm Malaysian palette, transparent background |
| Proportions | slightly chibi teen: big head (about 1/3 of the height), short legs, feet on the bottom 2 rows of the canvas |
| Directions in game | south, east, north, west. West is **mirrored from east** (`tools/mirror_west.gd`) |
| Walk | template `walking-6-frames`, south/east/north (west mirrored), 6 frames |

## 2. How to make a new character

1. `create_character` with:
   - `mode: "pro"`
   - `style_character_id: "09c32366-5aa6-4780-8aa3-d07fcf662b05"`
   - `size: 36`
   - `view: "low top-down"`
   - `name: "<Name> 36"`
2. Write `description` with the template in §3.
3. `animate_character` with `template_animation_id: "walking-6-frames"` and `directions: ["south","east","north"]`, `animation_name: "walk"`.
4. Add the id to `tools/asset_manifest.json`:
   - `characters.<id>`
   - `animations.<id>_walk`
   - `mirror_west`
5. Run:
   - `python tools/fetch_assets.py`
   - `godot --headless --path . -s tools/mirror_west.gd`
   - `python tools/make_portraits.py <id>`
6. Check the contact sheet beside Alif.

**Files**
- `assets/characters32/<id>/<id>_<dir>.png` holds the idle rotations.
- `assets/characters32/<id>_walk/<id>_walk_<dir>_<i>.png` holds the walk frames.
- `assets/portraits/<id>.png` is the 48 × 48 portrait, cropped from the south sprite's head and shoulders (nearest-neighbour scaling). Portraits are never drawn separately, so they always match the sprite.

## 3. Prompt template

```
<age> <gender> <role>, <era> Malay world, wearing <clothing with colours>,
<headwear>, <one prop or detail>, <expression/attitude>,
same art style as a Malaysian school RPG, simple readable shapes
```

Rules:
- **One** strong colour idea per character, so it can be recognised from far away on the map.
- At most **one prop**. At 36 px a second prop turns into noise.
- Use real clothing from the right period:
  - Melaka 15th century: baju kurung or baju Melayu teluk belanga, tengkolok/tanjak, samping, keris at the waist.
  - Srivijaya / early kingdoms: draped sarong and selendang, gold arm bands, bare feet or sandals.
  - Ming China: hanfu robes and an official's hat.
  - 1900–1940 (Bab 2): baju Melayu with songkok, Western jacket over sarong, round spectacles, kebaya with tudung/selendang, white colonial suit and pith helmet for British officials.
- Never name real brands, films or characters in a prompt. Describe the look instead.

## 4. Cast

| id | Who | Description core |
|---|---|---|
| penjaga | Penjaga Gerbang Masa (fictional) | old guardian, robe mixing five eras, glowing thread spool |
| syahbandar | Syahbandar of Melaka | port master, baju Melayu, tengkolok, ledger scroll |
| chengho | Laksamana Cheng Ho | Ming admiral, red and gold robe, black official hat |
| tunperak | Bendahara Tun Perak | elderly wise minister, maroon baju Melayu, gold tengkolok, white beard |
| sapurba | Sang Sapurba | royal prince, gold and white royal dress, gold crown |
| demang | Demang Lebar Daun | ruler of Palembang, deep green baju, tanjak, calm elder |
| makcik | Mak Som | village auntie, floral baju kurung, tudung |
| nelayan | Pak Mat | fisherman, faded singlet and sarong, straw hat |
| pencetak | Pak Hamid | 1930s printer, rolled sleeves, ink apron, songkok |
| pelatih | Pelatih SITC | teacher trainee, white shirt, songkok, books |
| profesor | Profesor Sejarawan | old historian, brown jacket, round glasses, book |
| nakhoda | Nakhoda Warkah | sea captain, navy coat, letter satchel |
| pengarang | Ketua Pengarang | 1930s newspaper editor, white shirt, vest, songkok, pen |
| syed_sheikh | Syed Sheikh al-Hadi | reformist scholar, white jubah, white serban, short beard |
| zaba | Za'ba | Malay scholar, white baju Melayu, black songkok, spectacles |
| eunos | Mohammad Eunos Abdullah | 1920s gentleman, dark Western suit, songkok, moustache |
| ibrahim | Ibrahim Haji Yaakob | young 1930s activist, white shirt, dark trousers, songkok |
| ibu_zain | Ibu Zain | 1930s woman educator, kebaya, selendang over the head, books |
| panglima | Panglima Derhaka (fictional) | rebel warrior, dark armour vest, red sash, keris |
| gabenor | Gabenor Sekatan (fictional) | British colonial governor, white suit, pith helmet |
| nirbana | Nirbana (villain, fictional) | see §5 |

## 5. Nirbana: villain spec

Nirbana is the Penghulu Kabus Lupa. He wants everyone to forget history. He must read as **mysterious and dark** while still keeping Alif's style.

- **Cape:** dark red / crimson flowing cloak with a tall stiff collar standing up behind the head, sorcerer-style.
- **Hood:** deep hood pulled low. The face is **hidden in shadow**: pure black, with at most two faint glowing eyes. No visible mouth or nose.
- **Under the cape:** near-black robes with thin dark-purple trim.
- **Symbol of darkness:** wisps of black-purple smoke at the hem, plus one cracked rune or broken-inscription mark on the chest (it echoes the broken Telaga Batu).
- **Pose:** upright and still, hands hidden in the sleeves. He floats a little (no visible feet).
- **Animation:** hovering idle (`animation_name: "hover"`, south): slow bob with the cape hem swaying.
- **Palette:** crimson `#8b1a1a`, deep red `#5a0f12`, black `#120a10`, purple smoke `#3b1f4a`, eye glow `#ff5a3c`.
- Avoid: skulls, blood, weapons, or anything gory. Keep it scary for 16-year-olds, not horror.
