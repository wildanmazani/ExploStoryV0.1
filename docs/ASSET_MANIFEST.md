# Senarai Aset (Asset Manifest)

Semua aset sekarang ialah seni sementara yang dijana oleh `tools/gen_art.py`.
Gantikan fail dengan **nama dan saiz kanvas yang sama** (seni dilukis kecil dan dibesarkan 4x dalam permainan dengan penapis nearest).

**Gaya asas untuk setiap prompt (PixelLab / Higgsfield):** 16-bit pixel art, top-down RPG, warm Malaysian palette, clean 1px dark outline, transparent background.

Sprite watak ialah helaian 3 lajur x 4 baris (16x24 setiap bingkai): baris 1 bawah, 2 kiri, 3 kanan, 4 atas; lajur 1 diam, 2-3 langkah.
Potret dialog 48x48 (dibesarkan 3x). Ikon 24x24. Latar zon 320x180 (dibesarkan 4x ke 1280x720).

Peraturan sensitiviti: Sultan hanya siluet dari belakang; tiada visual ganas; tokoh sejarah dilukis dengan hormat.

| Fail | Saiz (px) | Prompt / catatan |
| --- | --- | --- |
| `assets/bg/bilik_alif.png` | 320x180 | student bedroom at night, desk full of notes and red-marked papers, open history textbook, desk lamp glow, calendar 'SPM 3 hari lagi', moon in window |
| `assets/bg/bukit_peta.png` | 320x180 | sunrise hilltop in a dream world, giant wooden map board with a winding path and 10 small flags |
| `assets/bg/papan_siasatan.png` | 320x160 | cork investigation board texture with wooden frame |
| `assets/bg/peta_jejak.png` | 640x360 | large overworld map, grass, winding sand road with 10 flag spots, river with wooden bridge, coast at bottom, colourful trees |
| `assets/bg/zon_1_1.png` | 320x180 | mystic corridor of time, misty purple sky, stone floor, faint golden thread |
| `assets/bg/zon_1_2.png` | 320x180 | busy 15th-century Melaka port, sea at top, wooden pier, market stalls, warehouse, palm trees |
| `assets/bg/zon_1_3.png` | 320x180 | Balai Penghadapan interior, Malay palace audience hall, red carpet to golden throne dais, wooden pillars, court area at right |
| `assets/bg/zon_1_4.png` | 320x180 | summit of Bukit Siguntang, soft sky, rolling hills, stone platform for an oath ceremony |
| `assets/icon_src.png` | 64x64 |  |
| `assets/icons/bendera.png` | 24x24 | UI/artifact icon: bendera |
| `assets/icons/bintang.png` | 24x24 | UI/artifact icon: bintang |
| `assets/icons/capmohor.png` | 24x24 | UI/artifact icon: capmohor |
| `assets/icons/gulungan.png` | 24x24 | UI/artifact icon: gulungan |
| `assets/icons/kain.png` | 24x24 | UI/artifact icon: kain |
| `assets/icons/kapal.png` | 24x24 | UI/artifact icon: kapal |
| `assets/icons/kitab.png` | 24x24 | UI/artifact icon: kitab |
| `assets/icons/kumpulan.png` | 24x24 | UI/artifact icon: kumpulan |
| `assets/icons/kunci.png` | 24x24 | UI/artifact icon: kunci |
| `assets/icons/mahkota.png` | 24x24 | UI/artifact icon: mahkota |
| `assets/icons/muzium.png` | 24x24 | UI/artifact icon: muzium |
| `assets/icons/nobat.png` | 24x24 | UI/artifact icon: nobat |
| `assets/icons/nota.png` | 24x24 | UI/artifact icon: nota |
| `assets/icons/orang.png` | 24x24 | UI/artifact icon: orang |
| `assets/icons/pedang.png` | 24x24 | UI/artifact icon: pedang |
| `assets/icons/peta.png` | 24x24 | UI/artifact icon: peta |
| `assets/icons/pohon.png` | 24x24 | UI/artifact icon: pohon |
| `assets/icons/prasasti.png` | 24x24 | UI/artifact icon: prasasti |
| `assets/icons/rakan.png` | 24x24 | UI/artifact icon: rakan |
| `assets/icons/regalia.png` | 24x24 | UI/artifact icon: regalia |
| `assets/icons/sekolah.png` | 24x24 | UI/artifact icon: sekolah |
| `assets/icons/siva.png` | 24x24 | UI/artifact icon: siva |
| `assets/icons/suara.png` | 24x24 | UI/artifact icon: suara |
| `assets/icons/syiling.png` | 24x24 | UI/artifact icon: syiling |
| `assets/icons/tetapan.png` | 24x24 | UI/artifact icon: tetapan |
| `assets/icons/timbangan.png` | 24x24 | UI/artifact icon: timbangan |
| `assets/objects/bangunan_1_1.png` | 56x50 | world object: bangunan 1 1 |
| `assets/objects/bangunan_1_2.png` | 56x50 | world object: bangunan 1 2 |
| `assets/objects/bangunan_1_3.png` | 56x50 | world object: bangunan 1 3 |
| `assets/objects/bangunan_1_4.png` | 56x50 | world object: bangunan 1 4 |
| `assets/objects/bangunan_arena.png` | 56x50 | world object: bangunan arena |
| `assets/objects/bangunan_muzium.png` | 56x50 | world object: bangunan muzium |
| `assets/objects/bangunan_t5.png` | 56x50 | world object: bangunan t5 |
| `assets/objects/bendera_aktif.png` | 16x32 | world object: bendera aktif |
| `assets/objects/bendera_kunci.png` | 16x32 | world object: bendera kunci |
| `assets/objects/gerbang_champa.png` | 32x40 | world object: gerbang champa |
| `assets/objects/gerbang_funan.png` | 32x40 | world object: gerbang funan |
| `assets/objects/gerbang_johor.png` | 32x40 | world object: gerbang johor |
| `assets/objects/gerbang_melaka.png` | 32x40 | world object: gerbang melaka |
| `assets/objects/gerbang_srivijaya.png` | 32x40 | world object: gerbang srivijaya |
| `assets/objects/kapal_utusan.png` | 64x48 | world object: kapal utusan |
| `assets/objects/panji_naik.png` | 16x48 | world object: panji naik |
| `assets/objects/panji_turun.png` | 16x48 | world object: panji turun |
| `assets/objects/penanda.png` | 16x20 | world object: penanda |
| `assets/objects/pokok_0.png` | 64x72 | world object: pokok 0 |
| `assets/objects/pokok_1.png` | 64x72 | world object: pokok 1 |
| `assets/objects/pokok_2.png` | 64x72 | world object: pokok 2 |
| `assets/portraits/alif_confident.png` | 48x48 | dialogue portrait bust of alif confident, same character design as sprite |
| `assets/portraits/alif_confused.png` | 48x48 | dialogue portrait bust of alif confused, same character design as sprite |
| `assets/portraits/alif_happy.png` | 48x48 | dialogue portrait bust of alif happy, same character design as sprite |
| `assets/portraits/alif_neutral.png` | 48x48 | dialogue portrait bust of alif neutral, same character design as sprite |
| `assets/portraits/alif_worried.png` | 48x48 | dialogue portrait bust of alif worried, same character design as sprite |
| `assets/portraits/chengho.png` | 48x48 | dialogue portrait bust of chengho, same character design as sprite |
| `assets/portraits/demang.png` | 48x48 | dialogue portrait bust of demang, same character design as sprite |
| `assets/portraits/pau_happy.png` | 48x48 | dialogue portrait bust of pau happy, same character design as sprite |
| `assets/portraits/pau_neutral.png` | 48x48 | dialogue portrait bust of pau neutral, same character design as sprite |
| `assets/portraits/pau_scared.png` | 48x48 | dialogue portrait bust of pau scared, same character design as sprite |
| `assets/portraits/pedagang.png` | 48x48 | dialogue portrait bust of pedagang, same character design as sprite |
| `assets/portraits/pelajar_1.png` | 48x48 | dialogue portrait bust of pelajar 1, same character design as sprite |
| `assets/portraits/pelajar_2.png` | 48x48 | dialogue portrait bust of pelajar 2, same character design as sprite |
| `assets/portraits/pelajar_3.png` | 48x48 | dialogue portrait bust of pelajar 3, same character design as sprite |
| `assets/portraits/pelajar_4.png` | 48x48 | dialogue portrait bust of pelajar 4, same character design as sprite |
| `assets/portraits/penjaga.png` | 48x48 | dialogue portrait bust of penjaga, same character design as sprite |
| `assets/portraits/sapurba.png` | 48x48 | dialogue portrait bust of sapurba, same character design as sprite |
| `assets/portraits/sultan.png` | 48x48 | dialogue portrait bust of sultan, same character design as sprite |
| `assets/portraits/syahbandar.png` | 48x48 | dialogue portrait bust of syahbandar, same character design as sprite |
| `assets/portraits/tunperak.png` | 48x48 | dialogue portrait bust of tunperak, same character design as sprite |
| `assets/sprites/alif.png` | 48x96 | Malaysian Form 5 schoolboy, white school shirt, navy trousers, glasses, orange backpack, anxious but kind. Walk sheet: 3 frames x 4 directions (down, left, right, up) |
| `assets/sprites/chengho.png` | 48x96 | Admiral Cheng Ho, Ming dynasty envoy, red robe, black official hat |
| `assets/sprites/demang.png` | 48x96 | Demang Lebar Daun, Malay chief representing the people, green baju, tengkolok |
| `assets/sprites/pau.png` | 64x16 | tiny cream-white steamed bun (pau) mascot, pink cheeks, cheerful; 4 frames: idle, squash, stretch, happy |
| `assets/sprites/pedagang.png` | 48x96 | 15th-century port trader, songkok, orange baju |
| `assets/sprites/pelajar_1.png` | 48x96 | Malaysian schoolboy avatar, songkok, white uniform |
| `assets/sprites/pelajar_2.png` | 48x96 | Malaysian schoolgirl avatar, white tudung, blue pinafore |
| `assets/sprites/pelajar_3.png` | 48x96 | Malaysian Chinese schoolgirl avatar, ponytail, blue pinafore |
| `assets/sprites/pelajar_4.png` | 48x96 | Malaysian Indian schoolboy avatar, white shirt, tie |
| `assets/sprites/penjaga.png` | 48x96 | old mystical gatekeeper wearing a blend of five eras, turban, purple robe, gold samping, white beard |
| `assets/sprites/sapurba.png` | 48x96 | Sang Sapurba, legendary Malay ruler, gold crown, yellow royal robe |
| `assets/sprites/syahbandar.png` | 48x96 | busy 15th-century Melaka harbour master, songkok, teal baju, red samping |
| `assets/sprites/tunperak.png` | 48x96 | Bendahara Tun Perak, wise calm Malay statesman, red tengkolok, dark blue robe, gold samping (respectful) |

## Audio (slot kosong, untuk Suno AI / ElevenLabs)

| Slot | Catatan |
| --- | --- |
| Muzik bilik Alif | lembut, sedikit cemas, malam |
| Muzik peta | ceria, pengembaraan |
| Muzik Zon 1.1 - 1.4 | `"music"` dalam `data/zon_1_x.json` (misteri, pelabuhan, istana, bukit) |
| Bunyi | kertas, seret kad, sambungan sah, sambungan putus, bendera berkibar, nobat |
| Suara | bacaan dialog utama (P1); kini guna bacaan suara pelayar |
