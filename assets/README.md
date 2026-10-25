# Aset Bab 1 (PixelLab)

Semua aset dijana dengan PixelLab. Latar 320x180 — skala 4x ke 1280x720 (guna penapis `Nearest` dalam Godot).

## Watak (`characters32/`)
Sprite 36x36, 4 arah, pandangan low top-down, gaya sama dengan Alif. Panduan penuh, prompt
dan ID PixelLab: `docs/CONTENT_CONSISTENT_DESIGN.md` dan `tools/asset_manifest.json`.
Import watak baharu: `python tools/import_characters.py <id>=<uuid>`.

`characters/pau.png` (64x64) masih dipakai di skrin tajuk dan prolog.

## Latar (`backgrounds/`)
`bg_skrin_tajuk`, `bg_bilik_alif_malam`, `bg_peta_jejak_pembelajaran`, `bg_zon1_1_gerbang_masa`, `bg_zon1_2_pelabuhan_melaka`, `bg_zon1_3_balai_penghadapan`, `bg_zon1_4_bukit_siguntang`.

## Artifak (`items/`)
Ikon 64x64, dipotong daripada `sheet_*.png`.
- Zon 1.1: `item_patung_dewa_siva`, `item_kitab_kutara_manawa`, `item_peta_funan`, `item_prasasti_telaga_batu`
- Zon 1.2/1.3: `item_nobat`, `item_cap_mohor`, `item_gulungan_undang_undang`, `item_kain_kuning_diraja`

## UI (`ui/`)
`bendera_berkunci`, `bendera_berkibar` (48x64), `bg_papan_siasatan` (320x180).
