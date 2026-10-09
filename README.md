# Explo-Story (Prototaip v0.1)

Permainan cerita 2D pixel art untuk Sejarah KSSM. Arka 1: **Sejarah Tingkatan 4**.
Prototaip ini menyiapkan **Bab 1: Warisan Negara Bangsa** sepenuhnya (prolog, 4 zon,
penutup dan teaser Bab 2). Bab 2 hingga 10 dan Arka Tingkatan 5 berkunci.

- Enjin: **Godot 4.4.1** (GDScript, renderer GL Compatibility), eksport **HTML5**
- Backend: **Supabase** (log masuk + simpan kemajuan); permainan tetap berfungsi luar talian
- Hos: **itch.io** (dimuat naik automatik oleh GitHub Actions)

## Cara main (pemain)

| Tindakan | Papan kekunci | Sentuh / tetikus |
| --- | --- | --- |
| Berjalan | WASD / anak panah | Ketik di mana-mana pada peta |
| Bercakap / guna | E, Space, Enter | Ketik watak atau objek bertanda **!** |
| Petunjuk Pau | H | Ketik Pau (bucu kanan bawah) |
| Momen tenang | - | Tekan lama Pau |
| Tetapan | Esc | Butang gear |

Teka-teki: **Seret dan Padankan** (seret kad, atau ketik kad kemudian ketik tempatnya) dan
**Papan Siasatan** (ketik satu kad, kemudian ketik kad yang berkaitan). Tiada pemasa, tiada penalti.

## Struktur projek

```
project.godot, main.tscn       titik masuk (Main -> scripts/main.gd)
scripts/autoload/              Game (keadaan + simpanan), Backend (Supabase), Tts (bacaan suara)
scripts/screens/               title, login, register, prolog, peta, zone_prep, zone_area,
                               zone_summary, penutup, lobby
scripts/puzzles/               drag_match.gd (Seret dan Padankan), board.gd (Papan Siasatan), choice.gd
scripts/ui/                    tema, kotak dialog, butang Pau, HUD, Tetapan, Nota Alif, Muzium
scripts/world/                 kawasan berjalan + Alif
scripts/dev/autotest.gd        main penuh automatik (CI + tangkapan skrin)
data/                          SEMUA kandungan: story.json (dialog), zon_1_1..4.json (teka-teki),
                               characters.json, chapters.json, nota.json
assets/                        seni pixel sementara (dijana oleh tools/gen_art.py), fon
supabase/schema.sql            pangkalan data (dari ERD GDS v0.2)
docs/ASSET_MANIFEST.md         senarai aset + prompt untuk PixelLab / Higgsfield
```

Kandungan sejarah hanya di dalam `data/*.json`. Guru atau penulis boleh mengubah teks dan
jawapan tanpa menyentuh kod. Medan `"rekaan": true` menanda dialog rekaan, dan `"semak": true`
menanda fakta yang perlu disemak dengan buku teks.

## Menjalankan secara tempatan

1. Pasang Godot **4.4.1** (versi standard, bukan .NET) dari godotengine.org.
2. Buka `project.godot` dalam Godot, kemudian tekan F5.
3. Ujian automatik: `godot --path . -- --autotest --shots=/tmp/shots`

## Menyambung Supabase (log masuk dalam talian)

1. Cipta projek percuma di supabase.com.
2. SQL Editor -> tampal `supabase/schema.sql` -> Run.
3. Authentication -> Providers -> Email: hidupkan. Untuk ujian, matikan "Confirm email".
4. GitHub -> repo -> Settings -> Secrets and variables -> Actions -> **Secrets**:
   `SUPABASE_URL` dan `SUPABASE_ANON_KEY` (Project Settings -> API).
   CI akan menulis `config/backend.json` semasa build. Tanpa rahsia ini, permainan berjalan
   dalam mod luar talian (akaun disimpan pada peranti sahaja).

## Menerbitkan ke itch.io

1. Cipta halaman permainan di itch.io: Kind of project = **HTML**, viewport **1280 x 720**,
   tandakan "Mobile friendly" dan "Fullscreen button".
2. itch.io -> Settings -> API keys -> Generate.
3. GitHub -> repo -> Settings -> Secrets and variables -> Actions:
   - Secret `BUTLER_API_KEY` = kunci API itch.io
   - Variables `ITCH_USER` = nama pengguna itch.io, `ITCH_GAME` = nama halaman permainan
4. Setiap push akan menguji, membina dan memuat naik versi web baharu.

Build web tidak memerlukan SharedArrayBuffer (eksport tanpa thread), jadi ia berjalan di
itch.io tanpa tetapan tambahan.

## Seni dan audio sebenar

Semua imej dalam `assets/` ialah seni sementara. Gantikan mana-mana fail PNG dengan nama dan
saiz kanvas yang sama, dan permainan akan menggunakannya tanpa perubahan kod. Lihat
`docs/ASSET_MANIFEST.md` untuk saiz dan prompt penjanaan. Slot muzik setiap zon ada dalam
medan `"music"` dalam `data/zon_*.json`.
