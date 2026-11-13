extends RefCounted
## "Cara Main" for the Gelanggang Pesta Silat: how a round works, the tips,
## and the controls for whatever the player is using (keyboard layout picked
## in the pause menu, or the on-screen fight buttons on a phone).
## Used by the pause menu, the first-match intro and the lobby.

const UI = preload("res://scripts/ui/ui.gd")
const Pad = preload("res://scripts/ui/pad.gd")

## [action, what it does]
const MOVES := [
	["attack_punch", "Tumbuk"],
	["attack_kick", "Sepak"],
	["jump", "Lompat"],
	["grab", "Ambil / baling senjata"],
	["block", "Tangkis (tahan)"],
	["special", "Jurus Kilat"],
	["run", "Lari (tahan)"],
]
## the on-screen buttons, same names as touch_controls.gd
const TOUCH := [
	["Tumbuk", "Butang kuning besar"],
	["Sepak", "Butang oren"],
	["Lompat", "Butang biru"],
	["Ambil", "Butang hijau: ambil / baling"],
	["Tangkis", "Butang kelabu (tahan)"],
	["Jurus", "Butang ungu"],
]
## a controller: [button, what it does, the short name under the arena]
const PAD := [
	["square", "Tumbuk", "Tumbuk"],
	["triangle", "Sepak", "Sepak"],
	["cross", "Lompat", "Lompat"],
	["circle", "Ambil / baling senjata", "Ambil"],
	["l1", "Tangkis (tahan)", "Tangkis"],
	["r1", "Jurus Kilat", "Jurus"],
	["r2", "Lari (tahan)", "Lari"],
	["options", "Jeda", "Jeda"],
]


static func on_touch() -> bool:
	return Game.controls_on_screen()


## the whole guide, short on purpose: Cara main (3 steps), Tip, Kawalan
static func build() -> Control:
	var col := UI.vbox(10)
	col.add_child(_heading("Cara main"))
	var steps := UI.hbox(10)
	for s in [
		["1. SOALAN", "Jawab soalan."],
		["2. KEPUTUSAN", "Betul = SEMANGAT\nSalah = LEMAH"],
		["3. AKSI!", "Bertarung 10 saat."],
	]:
		steps.add_child(_step(s[0], s[1]))
	col.add_child(steps)
	var win := UI.label(_t("Menang: semua lawan pengsan, atau nyawa paling banyak selepas 8 pusingan."), "Ink", true)
	win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(win)
	col.add_child(_heading("Tip"))
	for t in [
		"Jawab betul = serangan 3 kali ganda.",
		"Paling cepat betul = JURUS KILAT.",
		"Kutip senjata, pukul atau baling.",
		"Diserang? Tahan Tangkis.",
	]:
		var l := UI.label("•  " + _t(t), "Ink", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(l)
	col.add_child(_heading("Kawalan"))
	if Game.pad_mode():
		var grid := GridContainer.new()  # two columns: the list stays short
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 26)
		grid.add_theme_constant_override("v_separation", 8)
		grid.add_child(_pad_point("stick", "Bergerak"))
		for m in PAD:
			grid.add_child(_pad_point(m[0], m[1]))
		grid.add_child(_pad_point("cross", "Jawab soalan (pilih dengan D-pad)"))
		col.add_child(grid)
	elif on_touch():
		col.add_child(_point("Bergerak", "Joystick di kiri"))
		for t in TOUCH:
			col.add_child(_point(t[0], t[1]))
	else:
		col.add_child(_point(Game.brawl_key_names("move_up") + " " + Game.brawl_key_names("move_left") + " " + Game.brawl_key_names("move_down") + " " + Game.brawl_key_names("move_right"), "Bergerak"))
		for m in MOVES:
			col.add_child(_point(Game.brawl_key_names(m[0]), m[1]))
		col.add_child(_point("1 2 3 4", "Jawab soalan"))
		col.add_child(_point("Esc / P", "Jeda"))
	return col


static func _heading(t: String) -> Label:
	var h := UI.label(_t(t), "InkHeading")
	h.add_theme_color_override("font_color", Color("8a4b14"))
	return h


## one of the three round steps: a small box, name on top, a few words under
static func _step(title: String, what: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.sb(Color("3a2a1c"), Color("c99a4a"), 2, 8, 10))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	var h := UI.label(_t(title), "")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_color_override("font_color", Color("ffe7a8"))
	v.add_child(h)
	var l := UI.label(_t(what), "Small", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(l)
	box.add_child(v)
	return box


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


## a controller button in the same dark chip, what it does on the right
static func _pad_point(kind: String, what: String) -> Control:
	var row := UI.hbox(12)
	row.custom_minimum_size.x = 430
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.sb(Color("3a2a1c"), Color("c99a4a"), 2, 6, 5))
	chip.custom_minimum_size.x = 120
	var cc := CenterContainer.new()
	cc.add_child(Pad.glyph(kind, 30))
	chip.add_child(cc)
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
	var t := UI.label(_t("CARA MAIN: GELANGGANG"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var holder := UI.vbox(0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(build())
	scroll.add_child(holder)
	c.add_child(scroll)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not on_touch() and not Game.pad_mode():
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
