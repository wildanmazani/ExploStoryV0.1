# Codex brief: puzzle background pictures (39 images)

Generate 39 pixel-art pictures for the drag-and-match puzzles of Explo-Story, a
Malaysian history learning game (Form 4 Sejarah). Each picture appears behind a
slot when the student drops the right card on it. Five pictures of the same
kind already exist and set the style: look at
`assets/puzzle_bg/kerajaan_funan.png`, `kerajaan_champa.png`,
`kerajaan_srivijaya.png`, `kerajaan_melaka.png`, `kerajaan_johor.png` and match
them.

## Rules for every picture

- Save as PNG in `assets/puzzle_bg/` with **exactly** the file name given below.
  The game already points at these paths; do not change any code or JSON.
- True pixel art, 16-bit RPG style: hard pixel edges, no anti-aliasing, no blur,
  about 24 to 32 colours per image. Opaque, no transparency, no border.
- **No text of any kind**: no letters, numbers, signs with writing, captions,
  watermarks or signatures. Flags and banners carry shapes and colours only.
- Wide scenic view from slightly above, horizon at about 40% from the top.
- **Keep the top 25% of the image to sky or plain background.** A label and a
  name card cover that part in the game. Put the subject between 30% and 80% of
  the height.
- People are small figures inside a scene, not close-up portraits. No real
  photographs as a base. No gore, no blood, no dead bodies: conflict is shown
  by stance, flags, smoke and distance.
- Period-correct buildings, clothes, ships and tools. No modern objects.
- One consistent style across all 39, warm and inviting like the existing five.

Sizes differ by puzzle because the slots differ in width:

| Slots in the puzzle | Size (px) |
| --- | --- |
| 5 | 320 x 520 |
| 4 | 360 x 520 |
| 3 | 440 x 520 |

## 1. Tiga Revolusi (Misi 2.2) - 3 slots - 440 x 520

| File | Scene |
| --- | --- |
| `tiga_revolusi_eng.png` | Glorious Revolution, England, 1688. A peaceful change of power: the old Palace of Westminster by the Thames, members of Parliament in 17th-century coats and wigs presenting a rolled document (the Bill of Rights) to the new king and queen. Calm grey-blue English sky, no fighting. |
| `tiga_revolusi_ame.png` | American Revolution, 1776. A red-brick Georgian assembly hall (like Independence Hall) with delegates in 18th-century coats gathered round a table with a parchment and a quill. Outside, a flag of red and white stripes with a circle of stars, colonists cheering. |
| `tiga_revolusi_fra.png` | French Revolution, 1789. A crowd of Parisians with blue-white-red tricolour flags storming the Bastille, a grey stone fortress with round towers. Smoke from cannon, dramatic sky. No bodies. |

## 2. Tugu Pahlawan (Misi 2.5) - 3 slots - 440 x 520

Malay and Bornean leaders who resisted British rule. Show each leader standing
firm in the foreground of his own land, small enough to be part of the scene.

| File | Scene |
| --- | --- |
| `pahlawan_dol.png` | Penghulu Dol Said, Naning (near Melaka), 1831. A village chief in baju Melayu, sampin and tengkolok with a keris, before a timber stockade and Minangkabau-style houses with upswept roofs among rice fields. A column of redcoat soldiers far off on the road. |
| `pahlawan_lela.png` | Dato' Maharaja Lela, Pasir Salak, Perak, 1875. A Malay chief with his followers on the bank of the wide Perak river, a riverside village of stilt houses and a wooden fort behind, a British steam launch in the distance. |
| `pahlawan_bahaman.png` | Dato' Bahaman, Pahang, 1890s. A chief and a few warriors in the deep rainforest of Semantan: giant trees, a jungle river, a hidden hill stockade, mist. |
| `pahlawan_janggut.png` | Tok Janggut, Pasir Puteh, Kelantan, 1915. An elderly leader with a long white beard, white robe and turban, leading villagers with keris and parang past rice fields toward a small wooden town. |
| `pahlawan_limbong.png` | Haji Abdul Rahman Limbong, Terengganu, 1928. A religious teacher in a white robe and turban speaking to a gathering of farmers by the Terengganu river, hill farms and forest behind. A peaceful assembly. |
| `pahlawan_rentap.png` | Rentap, Sarawak, 1850s. An Iban war leader with a hornbill-feather headdress, a wooden shield and a parang ilang, on Bukit Sadok: a hill fort of timber above the jungle, a longhouse below, a river winding away. |
| `pahlawan_salleh.png` | Mat Salleh, Sabah, 1890s. A leader in Bajau-Suluk dress with a flag, before his bamboo-and-earth fort at Tambunan, with Mount Kinabalu's jagged peak behind. |

## 3. Madrasah Moden (Misi 2.6) - 3 slots - 440 x 520

Three early modern Islamic schools. Each shows the school building with pupils
in white shirts, sarong and songkok carrying books; make the settings differ.

| File | Scene |
| --- | --- |
| `madrasah_attas.png` | Madrasah al-Attas, Johor Bahru, 1914. A two-storey colonial-Malay school building with arched verandas, near the Johor Strait waterfront, palms. |
| `madrasah_masyhur.png` | Madrasah al-Masyhur, Pulau Pinang, 1916. A school with a small dome and arches among George Town shophouses, Penang Hill in the distance. |
| `madrasah_idrisiyah.png` | Madrasah al-Idrisiyah, Kuala Kangsar, 1926. A school building on a green rise by the Perak river, a golden-domed royal mosque far behind. |

## 4. Garis Masa Persatuan (Misi 2.7) - 4 slots - 360 x 520

Associations in Malaya before the war.

| File | Scene |
| --- | --- |
| `garis_persatuan_khalsa.png` | Khalsa Diwan Malaya, Taiping, 1902. Sikh men in turbans gathered before a gurdwara with a small dome and an orange triangular flag, the rain trees and lake of Taiping behind. |
| `garis_persatuan_kms.png` | Kesatuan Melayu Singapura, 1926. Malay men in baju Melayu and songkok at a meeting in a hall with tall shuttered windows, the Singapore waterfront with sailing boats and godowns outside. |
| `garis_persatuan_paspam.png` | Persaudaraan Sahabat Pena, Pulau Pinang, 1934. A pen-friends' club: young men and women writing letters at wooden desks, stacks of envelopes, fountain pens, a red pillar postbox, a colonial post office and clock tower outside. |
| `garis_persatuan_kmm.png` | Kesatuan Melayu Muda, Kuala Lumpur, 1937. Young Malay men in white shirts and songkok talking over newspapers at a coffee-shop table, a Moorish-style government building with a clock tower and copper domes behind. |

## 5. Perahu Serantau (Misi 2.4) - 5 slots - 320 x 520

Nationalist movements in Southeast Asia.

| File | Scene |
| --- | --- |
| `perahu_serantau_kat.png` | Katipunan, Philippines, 1896. Revolutionaries in white shirts and straw hats raising bolo knives under a red flag with a white sun, nipa huts and a hand printing press with sheets of a newspaper. |
| `perahu_serantau_kasut.png` | The "shoe question", Burma, 1906. A great golden pagoda; at the foot of its stairway rows of shoes left behind, monks and Burmese laymen barefoot, a few British officials in boots stopped at the entrance. |
| `perahu_serantau_thakin.png` | The Thakin movement, Burma, 1930s. Young Burmese students in longyi and jackets marching with a tricolour flag bearing a peacock, a university building of red brick behind. |
| `perahu_serantau_trib.png` | Vietnamese nationalist newspapers, Saigon, 1920s. A small printing shop: a press, bundles of newspapers, writers at desks, a cracked bell as an emblem on the wall, a French-colonial street outside. |
| `perahu_serantau_sumpah.png` | Sumpah Pemuda, Batavia, 1928. A youth congress in a colonial hall: young delegates in suits and peci standing together, a red-and-white flag, a violinist playing at the front. |
| `perahu_serantau_mongkut.png` | Siam under Mongkut and Chulalongkorn. The Grand Palace of Bangkok with gilded spires; the king receiving Western advisers in frock coats, a steamboat on the Chao Phraya, telegraph poles. |

## 6. Kapal-kapal Asia (Misi 2.3) - 4 slots - 360 x 520

Nationalist and reform movements in Asia.

| File | Scene |
| --- | --- |
| `kapal_asia_satya.png` | Satyagraha, India. Mahatma Gandhi with a walking stick leading followers in white homespun on the Salt March, along a dusty road to the sea. Peaceful. |
| `kapal_asia_samaj.png` | Brahmo Samaj and Arya Samaj, 19th-century India. Reformers and teachers in a meeting hall with books, a small sacred fire on a square altar in the courtyard, a school with pupils beyond. |
| `kapal_asia_sanmin.png` | The Three Principles of the People, China. Dr Sun Yat-sen in a high-collared suit speaking from a platform to a crowd, three plain banners in different colours behind him, a Chinese hall with tiled roofs. |
| `kapal_asia_manchu.png` | The 1911 Revolution, China. Revolutionary soldiers raising a flag of five coloured stripes on a city gate and wall, citizens cutting off their queues in celebration, smoke far away. |
| `kapal_asia_islah.png` | The Islah movement, Egypt. Scholars in robes and turbans teaching students in the courtyard of a great mosque-university in Cairo: arcades, minarets, a hand press printing a journal. |
| `kapal_asia_meiji.png` | The Meiji Restoration, Japan, 1868. A steam locomotive on a bridge, factory chimneys, soldiers in Western uniforms beside a samurai, cherry blossom, Mount Fuji behind. |

## 7. Hari Sibuk di Balai (Misi 1.3) - 5 slots - 320 x 520

Five problems in 15th-century Melaka, each the duty of one minister. Malay
dress and ships of the Melaka Sultanate.

| File | Scene |
| --- | --- |
| `hari_sibuk_m_lanun.png` | Pirates in the Strait: fast pirate boats closing on a merchant ship, and the Laksamana's war fleet of lancaran with oars and red pennants sailing out from Melaka to drive them off. |
| `hari_sibuk_m_berangkat.png` | The Sultan leaves the city: a royal procession with a yellow umbrella boarding a royal ship at the jetty, while the Bendahara stands on the palace steps holding the staff of office, left in charge. |
| `hari_sibuk_m_cukai_kapal.png` | The port: foreign ships (Chinese junk, Gujarati dhow, Javanese jong) at anchor, the Syahbandar and his clerks at a customs shed on the jetty with scales and bales of goods, a captain paying duty in coins. |
| `hari_sibuk_m_curi.png` | Night in the town of Melaka: a thief running over wooden rooftops with a bundle, the Temenggung and his guards with torches and spears giving chase in the lane below, a full moon. |
| `hari_sibuk_m_perbendaharaan.png` | The treasury: a strongroom of timber with open chests of tin ingots, gold and coins, ledgers and scales on a low table, the Penghulu Bendahari checking the count with two clerks. |

## 8. Panji Kerajaan (Misi 1.2) - 5 slots - 320 x 520

The layers of government of the Melaka Sultanate, from the top down. Each
picture shows the audience hall (balairung) of a timber palace; the lower the
layer, the larger and plainer the group.

| File | Scene |
| --- | --- |
| `kerajaan_sultan.png` | The Sultan alone on a raised golden throne under a yellow royal umbrella, in songket and a tengkolok, bearers of regalia at his sides. |
| `kerajaan_p4.png` | The four chief ministers (Pembesar Berempat) seated in a row on a raised dais in rich dress: one with a staff of office, one with a treasure chest, one with a keris and guard, one in a sea-captain's dress. |
| `kerajaan_p8.png` | Eight nobles (Pembesar Berlapan) seated in two rows of four on mats, one step lower, in fine but simpler dress. |
| `kerajaan_p16.png` | Sixteen lesser nobles (Pembesar Enam Belas) seated in rows on the hall floor, seen from a little further back. |
| `kerajaan_p32.png` | Thirty-two minor chiefs (Pembesar Tiga Puluh Dua) filling the hall in many rows, seen from the back of the hall so the whole assembly shows. |

## When done

Make a preview sheet of all 39 and a zip that keeps the `assets/puzzle_bg/`
folder structure, as for the first five. Do not edit code, JSON or `.import`
files.
