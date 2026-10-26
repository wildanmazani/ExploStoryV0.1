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

Tanda seru **(!)** menunjukkan tugasan seterusnya, dan **anak panah emas** (di peta mini, peta penuh dan
di tepi skrin) menunjuk jalan ke misi aktif. Teka-teki: **Seret dan Padankan** dan
**Papan Siasatan**. Tiada pemasa, tiada penalti.

## Aliran permainan

Tajuk -> Log masuk / Daftar / Tetamu -> Prolog, ditonton sahaja dan boleh dilangkau (sembang
kumpulan kelas 11:47 malam, Alif melihat barang dalam biliknya, kata kunci masuk dan keluar dari
"Ingatan Alif" sambil huruf berselerak, mimpi: rakan sekelas saling lupa dalam Kabus Lupa, Nirbana
di Gua Warisan; teks dalam `data/prologue_room.json` dan `data/dialogue/prologue.json`) ->
Pau kejutkan Alif di **Bilik Alif** (Rumah Alif, Dunia Explo-Story): Pau terangkan artifak (4 Serpihan),
misi, tujuan dan cara bermain; tugasan pertama ambil beg sekolah (tanda "Tekan E" berkelip), Misi 1.1 bermula
(`scripts/world/bilik_alif.gd`, teks `bilik_*` dalam `data/dialogue/prologue.json`) -> Kampung Jejak -> Zon 1.1 Gerbang Masa -> Zon 1.2 Pelabuhan
Melaka -> Zon 1.3 Balai Penghadapan (dalam Istana) -> Zon 1.4 Bukit Siguntang -> Ringkasan
setiap zon -> Penutup (Bendera 1 berkibar, Nota Alif, teaser Bab 2).

Ciri baharu (pek 2): skrin **Arka & Zon** (Arka = Tingkatan, Zon = Bab, Misi 1.1-1.4 = subtopik),
**Profil & Kedai** (ID Pemain, 6 pakaian Alif dibeli dengan syiling), **Tetapan** bertab (fon, audio Muzik/Bunyi/Suara,
Bahasa menu BM/English), soalan **objektif** dan **suaikan** selain seret-padan dan papan siasatan, dan
**Bilik Pertarungan**: jawab betul untuk serang lawan pilihan, yang terakhir berdiri menang 20 syiling.
Lawan Bot berfungsi tanpa internet; main dengan rakan (tambah rakan guna ID) memerlukan Supabase:
jalankan `supabase/schema.sql` kemudian `supabase/multiplayer.sql` (belum diuji pada projek sebenar).

Maklum balas pusingan 1: pertarungan kini menunjukkan watak besar dengan HP di bawah (lawan bot ialah
4 rakan sekelas: Aisyah, Ravi, Mei Ling, Daniel), **Papan Markah** (Seluruh / Negeri / Rakan, ikut jumlah EXP;
dalam talian perlukan `supabase/leaderboard.sql`, luar talian tunjuk pemain contoh), gambar profil ikut
pakaian yang dipakai, butang **Menu** yang terbuka ke bawah, dan tab Kata Kunci di peta yang boleh dilipat
dan dicari (ketik kata kunci untuk tunjuk tempatnya di peta).

**Gelanggang Pesta Silat** (Bilik Pertarungan > Lawan Bot): pertarungan aksi sisi (macam Hobo / Streets of Rage)
dalam dewan sekolah, 1 lwn 1, 2 lwn 2, 1 lwn 2 atau 1 lwn 3, tahap Mudah / Biasa / Sukar. Setiap pusingan:
SOALAN (15 s, semua jawab) -> KEPUTUSAN (betul = Semangat, serangan penuh + senjata sekolah jatuh; paling cepat =
Jurus Kilat; salah = Lemah, 30%) -> AKSI (10 s bertarung bebas: tumbuk, sepak, kombo J-J-K, tendang terbang,
tangkis, ambil/baling pembaris, buku, penyapu, beg, bola, bantal). Kesan kartun sahaja (bintang, "PAK!", plaster,
lebam, "PENGSAN"), tiada darah. Kod: `scripts/brawl/`, data gerakan: `data/brawl/moves.json`.
Kekunci: WASD gerak, J tumbuk, K sepak, Space lompat, L ambil/baling, I tangkis, U jurus, Shift lari; telefon guna
joystick/D-pad + butang aksi. "Kuiz sahaja" masih ada untuk yang mahu soalan tanpa aksi.

**Dunia baharu yang lebih ceria**: rumput cerah, jalan tanah berliku (tiada lantai batu lagi), sungai dari mata air
Bukit Siguntang ke lagun di tepi pasar dengan 3 jambatan kayu, rumah kampung bertiang menghadap ke depan dengan pagar
dan bunga, pokok berwarna (bunga merah jambu, semarak api, rambutan), pelita, perigi, tong dan peti di pasar dan
pelabuhan, gudang. Hidup: ayam mematuk di halaman, itik di sungai, ikan melompat, asap dapur, rama-rama dan burung.
Susun atur dijana oleh `tools/gen_world.py` (semak sendiri: semua tempat boleh dicapai, tiada sambungan jubin yang salah).

**Bab 2: Kebangkitan Nasionalisme** (lengkap): selepas Bab 1, Pintu Kabus di barat Kampung Jejak terbuka ke
**Lembah Kebangkitan**, pekan tahun 1900-an hingga 1941 di pulau kedua. Kabus Lupa mengelabukan setiap kawasan
sehingga misinya selesai. 8 misi, satu bagi setiap subtopik: 2.1 Dewan Kedaulatan Rakyat (maksud nasionalisme),
2.2 Rumah Falsafah Sejagat (revolusi di Barat), 2.3 Dermaga Asia, 2.4 Balai Serantau (Asia Tenggara), 2.5 Tugu
Pahlawan (kesedaran di negara kita), 2.6 Kompleks Intelektual & Jelutong Press (faktor), 2.7 Maktab SITC
(perkembangan) dan 2.8 Menara Pentadbiran (kesan, lawan Gabenor Sekatan 1941). Tokoh: Za'ba, Syed Sheikh al-Hadi,
Ibu Zain, Ibrahim Haji Yaakob, Mohammad Eunos Abdullah, serta pemandu rekaan (Profesor Sejarawan, Nakhoda Warkah,
Ketua Pengarang). Data: `data/zon_2_*.json`, `data/nota_bab2.json`, `data/soalan/bab2.json` (bank soalan
pertarungan; pilih Bab 1 / Bab 2 / Campur di Bilik Pertarungan). Soalan bertanda `"semak": true` perlu disemak guru.

**Penceritaan (pek 3)**: prolog kini masuk ke mimpi (pelabuhan huru-hara, Gua Warisan) di mana **Nirbana**, Penghulu
Kabus Lupa, memecahkan Inskripsi Telaga Batu kepada 4 Serpihan: satu serpihan bagi setiap misi Bab 1. Kawasan misi Bab 1
bermula kelabu dan berwarna semula apabila misinya selesai. Setiap kawasan ada kad tajuk dan sebab datang pada lawatan
pertama (`data/area_intro.json`), dan pertukaran peta menunjukkan kad tajuk. **Ujian Bab** (`data/ujian.json`) di hujung
setiap bab: 3 nyawa, tumbangkan bos (Panglima Derhaka / Bayang Nirbana) dengan 7 jawapan betul, tiada had masa; mesti
lulus sebelum bab seterusnya dibuka (gagal = cuba lagi atau ulang kaji, bos menunggu di peta). Bilik cerita:
Jelutong Press dan Maktab SITC (`data/interiors/*.json`). Artifak yang dijumpai disimpan dalam **Beg Alif** (Menu > Beg Alif;
ketik artifak untuk dengar ceritanya, teks dalam `ganjaran.cerita` setiap `data/zon_*.json`). Potret Alif dalam dialog ikut pakaian yang
dipakai. Semua aset peta pandangan atas, menghadap ke bawah; pokok hijau sahaja.

**Lembah Kebangkitan dilukis semula (pek 4)**: pekan kolonial 1920-an yang tersusun: Jalan Besar, jalan batu kelikir
kelabu (tileset PixelLab `grass_jalan`), padang dengan wakaf dan menara jam, deretan rumah kedai, kapal wap di Dermaga.
Misi 2.1 hingga 2.8 mengikut satu laluan, dengan papan bernombor di depan setiap tempat. Susun atur dalam
`data/world/lembah_layout.json` (dikarang di PixelLab Map Workshop, dibaca oleh `tools/gen_world.py`). Kabus Lupa kini
kelabu dengan kabus putih nipis, dan peta mini serta peta penuh menunjukkan kabus yang sama. Nirbana mengejek setiap
2 misi; Gabenor Sekatan menjaga Menara semasa Misi 2.8. `python tools/asset_sheet.py` = helaian semua objek peta.

Ciri lain: peta mini dengan zum (dekat / sederhana / seluruh) dan peta penuh dengan legenda tempat, kata kunci dan simbol (`data/map_legend.json`), HUD (tahap, EXP, syiling), Nota Alif, Beg Alif + Kad Tokoh + Jalan Pintas (pindah terus ke tempat yang dah dibuka;
juga butang Pergi dalam peta penuh), Peta Jejak (tugu batu),
Arena Ulang Kaji di setiap pulau (Kampung Jejak dan tepi padang Lembah; lobi, pemain lain bertarung berpasangan,
patung latihan dan Papan Markah; Guru Jalal dengan tugasan sampingan Jurus Ingatan selepas Serpihan 1), Tetapan Mod Mudah Baca (Lexend / Atkinson / OpenDyslexic, saiz dan
kelajuan teks, bacaan suara), log petunjuk untuk guru, muzik interaktif dan bunyi.

Seni baharu dari PixelLab (latar tajuk berlapis, bilik Alif, perabot, watak silat): senarai fail, saiz dan
prompt dalam `docs/pixellab/PIXELLAB_ASSETS.md`. Permainan berjalan tanpa fail itu dan menukar sendiri bila fail ada.

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
   (prolog sahaja, lebih cepat: tambah `--only=prologue`)

## Versi web

GitHub Actions (`.github/workflows/web-export.yml`) menguji (autotest), membina versi web
dan menerbitkannya ke GitHub Pages pada setiap push. Sekali sahaja: Settings -> Pages ->
Source: **GitHub Actions** (repo awam, atau GitHub Pro untuk repo peribadi). Build juga boleh
dimuat turun dari tab Actions (artifact `explostory-web`).

Supabase (pilihan): tampal `supabase/schema.sql` dalam SQL Editor, kemudian isi
`config/backend.json` (`supabase_url`, `supabase_anon_key`).
