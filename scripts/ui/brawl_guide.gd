extends RefCounted
## "Cara Main" for the Gelanggang Pesta Silat: how a round works, the tips,
## and the controls for whatever the player is using (keyboard layout picked
## in the pause menu, or the on-screen fight buttons on a phone).
## Used by the pause menu, the first-match intro and the lobby.

const UI = preload("res://scripts/ui/ui.gd")

## [action, what it does]
const MOVES := [
	["attack_punch", "Tumbuk"],
	["attack_kick", "Sepak"],
	["jump", "Lompat (tekan Sepak masa di udara = tendangan terbang)"],
	["grab", "Ambil senjata / baling senjata"],
	["block", "Tangkis (tahan) - kurangkan kesakitan"],
	["special", "Jurus Kilat (hanya bila dapat JURUS!)"],
	["run", "Lari (tahan sambil bergerak)"],
]
## the on-screen buttons, same names as touch_controls.gd
const TOUCH := [
	["Tumbuk", "Butang kuning paling besar"],
	["Sepak", "Butang oren"],
	["Lompat", "Butang biru"],
	["Ambil", "Butang hijau: ambil / baling senjata"],
	["Tangkis", "Butang kelabu: tahan untuk menangkis"],
	["Jurus", "Butang ungu: Jurus Kilat (bila dapat JURUS!)"],
]


static func on_touch() -> bool:
	return Game.controls_on_screen()


## the whole guide; scroll it if the space is short
static func build() -> Control:
	var col := UI.vbox(10)
	col.add_child(_heading("Setiap pusingan ada 3 langkah"))
	for s in [
		["1. SOALAN (15 saat)", "Semua orang jawab soalan yang sama. Gelanggang berhenti masa ni. Tekan 1, 2, 3 atau 4, atau ketik jawapan."],
		["2. KEPUTUSAN", "Jawapan betul = SEMANGAT: serangan penuh dan sebuah senjata sekolah jatuh dekat kau. Salah = LEMAH: serangan kau tinggal 30% sahaja. Paling cepat betul = JURUS KILAT."],
		["3. AKSI! (10 saat)", "Bertarung! Pasukan yang semua ahlinya pengsan, kalah. Selepas 8 pusingan, pasukan dengan nyawa paling banyak menang."],
	]:
		col.add_child(_point(s[0], s[1]))
	col.add_child(_heading("Kawalan skrin sentuh" if on_touch() else "Kawalan papan kekunci"))
	if on_touch():
		col.add_child(_point("Bergerak", "D-pad atau joystick di sebelah kiri"))
		for t in TOUCH:
			col.add_child(_point(t[0], t[1]))
	else:
		col.add_child(_point(Game.brawl_key_names("move_up") + " " + Game.brawl_key_names("move_left") + " " + Game.brawl_key_names("move_down") + " " + Game.brawl_key_names("move_right"), "Bergerak"))
		for m in MOVES:
			col.add_child(_point(Game.brawl_key_names(m[0]), m[1]))
		col.add_child(_point("Esc / P", "Jeda permainan"))
	col.add_child(_heading("Tip"))
	for t in [
		"Jawab dengan betul dulu. Semangat buat serangan kau 3 kali lebih kuat.",
		"Kutip senjata yang jatuh (Ambil). Pukul dengan senjata atau baling ke arah lawan.",
		"Lawan menyerang? Tahan Tangkis. Kau hanya rasa sedikit sakit.",
		"Kombo: Tumbuk, Tumbuk, Sepak dengan cepat.",
		"Baru main? Pilih tahap lawan Mudah dan pasukan 1 lwn 1.",
	]:
		var l := UI.label("•  " + _t(t), "Ink", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(l)
	return col


static func _heading(t: String) -> Label:
	var h := UI.label(_t(t), "InkHeading")
	h.add_theme_color_override("font_color", Color("8a4b14"))
	return h


## a key chip (or step name) on the left, what it does on the right
static func _point(key: String, what: String) -> Control:
	var row := UI.hbox(12)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.sb(Color("3a2a1c"), Color("c99a4a"), 2, 6, 6))
	chip.custom_minimum_size.x = 230
	var k := UI.label(_t(key), "Small", true)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_color_override("font_color", Color("ffe7a8"))
	chip.add_child(k)
	row.add_child(chip)
	var l := UI.label(_t(what), "Ink", true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


## a Paper card with the guide in a scroll box, a button named "Ok" for the
## caller to connect, and (on a keyboard) the layout switch. live = the fight
## keys are bound right now (in the Gelanggang), so a switch applies at once.
static func card(button_text: String, live := false) -> PanelContainer:
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(980, 0)
	var c := UI.vbox(12)
	var t := UI.label(_t("CARA MAIN: GELANGGANG PESTA SILAT"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var holder := UI.vbox(0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(build())
	scroll.add_child(holder)
	c.add_child(scroll)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not on_touch():
		row.add_child(UI.label(_t("Kekunci:"), "Ink"))
		for s in [["wasd", "W A S D + J K L"], ["panah", "Anak panah + Z X C"]]:
			var b := UI.button(s[1], "Primary" if Game.brawl_scheme() == s[0] else "", 230)
			b.pressed.connect(func():
				Game.set_setting("brawl_keys", s[0])
				if live:
					Game.use_brawl_keys(true)
				for x in row.get_children():
					if x is Button and x.has_meta("scheme"):
						x.theme_type_variation = "Primary" if x.get_meta("scheme") == s[0] else ""
				for ch in holder.get_children():
					ch.queue_free()
				holder.add_child(build()))
			b.set_meta("scheme", s[0])
			row.add_child(b)
	var ok := UI.button(_t(button_text), "Primary", 220)
	ok.name = "Ok"
	row.add_child(ok)
	c.add_child(row)
	card.add_child(c)
	return card


static func _t(s: String) -> String:
	return TranslationServer.translate(s)
