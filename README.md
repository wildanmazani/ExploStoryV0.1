# Explo-Story (Prototaip v0.2)

Permainan RPG 2D pixel art gaya Pokémon untuk Sejarah KSSM Tingkatan 4.
**Bab 1: Warisan Negara Bangsa** lengkap: prolog sinematik, dunia terbuka untuk
diterokai, 4 zon dengan 13 teka-teki, penutup dan teaser Bab 2.

- Enjin: **Godot 4.7.2** (GDScript, renderer GL Compatibility), eksport **HTML5**
- Seni: PixelLab (watak, jubin, prop), muzik gamelan dijana oleh `tools/gen_music.py`
- Backend: Supabase pilihan (log masuk + simpan awan); tanpa Supabase permainan berjalan luar talian

## Cara main

| Tindakan | Papan kekunci | Telefon / tetikus |
| --- | --- | --- |
| Berjalan (satu petak) | WASD / anak panah, Shift = lari | D-pad, atau ketik ke mana-mana |
| Bercakap / guna | E, Space, Enter | Butang A, atau ketik watak / objek |
| Petunjuk Pau | H | Ketik Pau (di dunia: Pau yang mengikut Alif) |
| Momen tenang | Butang Pau di bar menu | Tekan lama Pau |
| Peta penuh + legenda | M | Ketik peta mini (bucu kanan) |
| Tetapan | Esc | Butang gear |

Tanda seru **(!)** menunjukkan tugasan seterusnya. Teka-teki: **Seret dan Padankan** dan
**Papan Siasatan**. Tiada pemasa, tiada penalti.

## Aliran permainan

Tajuk -> Log masuk / Daftar / Tetamu -> Prolog (bilik Alif, huruf berselerak) ->
bangun di Dunia Explo-Story -> Kampung Jejak -> Zon 1.1 Gerbang Masa -> Zon 1.2 Pelabuhan
Melaka -> Zon 1.3 Balai Penghadapan (dalam Istana) -> Zon 1.4 Bukit Siguntang -> Ringkasan
setiap zon -> Penutup (Bendera 1 berkibar, Nota Alif, teaser Bab 2).

Ciri baharu (pek 2): skrin **Arka & Zon** (Arka = Tingkatan, Zon = Bab, Misi 1.1-1.4 = subtopik),
**Profil & Kedai** (ID Pemain, 6 pakaian Alif dibeli dengan syiling), **Tetapan** bertab (fon, audio Muzik/Bunyi/Suara,
Bahasa menu BM/English), soalan **objektif** dan **suaikan** selain seret-padan dan papan siasatan, dan
**Bilik Pertarungan**: jawab betul untuk serang lawan pilihan, yang terakhir berdiri menang 20 syiling.
Lawan Bot berfungsi tanpa internet; main dengan rakan (tambah rakan guna ID) memerlukan Supabase:
jalankan `supabase/schema.sql` kemudian `supabase/multiplayer.sql` (belum diuji pada projek sebenar).

Ciri lain: peta mini dengan zum (dekat / sederhana / seluruh) dan peta penuh dengan legenda tempat, kata kunci dan simbol (`data/map_legend.json`), HUD (tahap, EXP, syiling), Nota Alif, Muzium + Kad Tokoh, Peta Jejak (tugu batu),
Arena Ulang Kaji (lobi), Tetapan Mod Mudah Baca (Lexend / Atkinson / OpenDyslexic, saiz dan
kelajuan teks, bacaan suara), log petunjuk untuk guru, muzik interaktif dan bunyi.

## Struktur projek

```
scenes/                 title, prologue, world/world, interior/balai, ui/peta_jejak, screen_host
scripts/main.gd         autoload "Main": lapisan dialog, butang Pau, panel, toast
scripts/autoload/       Game (data, simpanan, kemajuan), Backend (Supabase), Tts
scripts/world/          dunia: jubin, pemain grid, Pau, NPC, ZoneRunner (zon + teka-teki), interior
scripts/puzzles/        drag_match, board, choice
scripts/screens/        login, register, zone_prep, zone_summary, penutup, lobby
scripts/audio/          MusicDirector (muzik interaktif), Sfx (bunyi dijana kod)
scripts/dev/autotest.gd main penuh automatik (CI + tangkapan skrin)
data/zon_1_*.json       SEMUA kandungan teka-teki, fakta dan ganjaran
data/story.json         dialog zon;  data/dialogue/*.json dialog dunia (bahasa harian)
data/world/             susun atur dunia (dijana oleh tools/gen_world.py)
tools/                  gen_world.py, gen_music.py, fetch_assets.py (muat turun PixelLab)
```

Kandungan sejarah hanya di `data/*.json`; guru boleh ubah teks dan jawapan tanpa kod.
`"rekaan": true` menanda dialog rekaan, `"semak": true` menanda fakta untuk disemak.

## Menjalankan secara tempatan

1. Pasang Godot **4.7.2** (standard), buka `project.godot`, tekan **F5**.
2. Ujian automatik: `godot --path . -- --autotest --shots=C:/tmp/shots`

## Versi web

GitHub Actions (`.github/workflows/web-export.yml`) menguji (autotest), membina versi web
dan menerbitkannya ke GitHub Pages pada setiap push. Sekali sahaja: Settings -> Pages ->
Source: **GitHub Actions** (repo awam, atau GitHub Pro untuk repo peribadi). Build juga boleh
dimuat turun dari tab Actions (artifact `explostory-web`).

Supabase (pilihan): tampal `supabase/schema.sql` dalam SQL Editor, kemudian isi
`config/backend.json` (`supabase_url`, `supabase_anon_key`).
