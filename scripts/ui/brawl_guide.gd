extends RefCounted
## "Cara Main" for the Gelanggang Pesta Silat: how a round works, the tips,
## and the controls for whatever the player is using (keyboard layout picked
## in the pause menu, or the on-screen fight buttons on a phone).
## Used by the pause menu, the first-match intro and the lobby.

const UI = preload("res://scripts/ui/ui.gd")
const Pad = preload("res://scripts/ui/pad.gd")
const ControlHint = preload("res://scripts/ui/control_hint.gd")
const AnswerMark = preload("res://scripts/ui/answer_mark.gd")

## [action, what it does]
const MOVES := [
	["attack_punch", "Tumbuk"],
	["attack_kick", "Sepak"],
	["jump", "Lompat"],
	["grab", "Ambil / baling"],
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
	["circle", "Ambil / baling", "Ambil"],
	["l1", "Tangkis (tahan)", "Tangkis"],
	["r1", "Jurus Kilat", "Jurus"],
	["r2", "Lari (tahan)", "Lari"],
	["options", "Jeda", "Jeda"],
]


static func on_touch() -> bool:
	return Game.controls_on_screen()


## the whole guide, short on purpose: the round in 3 steps, 4 tips, the controls
static func build() -> Control:
	var col := UI.vbox(12)
	# the round: SOALAN > KEPUTUSAN > AKSI
	var steps := UI.hbox(8)
	steps.add_child(_step("res://assets/icons/kitab.png", "1  SOALAN", Color("3f7fc4"), _small("Jawab dulu")))
	steps.add_child(_arrow())
	var verdict := UI.vbox(2)
	verdict.add_child(_mark_line(true, "SEMANGAT"))
	verdict.add_child(_mark_line(false, "LEMAH"))
	steps.add_child(_step("res://assets/icons/timbangan.png", "2  KEPUTUSAN", Color("4f9a45"), verdict))
	steps.add_child(_arrow())
	steps.add_child(_step("res://assets/icons/pedang.png", "3  AKSI!", Color("c9673b"), _small("Lawan 10 saat")))
	col.add_child(steps)
	var win := UI.hbox(10)
	win.add_child(UI.icon("res://assets/icons/mahkota.png", 34))
	var wl := UI.label(_t("MENANG: semua lawan tumbang, atau nyawa paling banyak lepas 8 pusingan."), "Ink", true)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	win.add_child(wl)
	col.add_child(win)
	# tips: a big keyword, a few words under it
	var tips := GridContainer.new()
	tips.columns = 4
	tips.add_theme_constant_override("h_separation", 10)
	for t in [
		["x3", "Serangan bila jawab betul", Color("e0a526")],
		["JURUS", "Paling cepat jawab betul", Color("9a5cc4")],
		["SENJATA", "Kutip, pukul, baling", Color("c9673b")],
		["TANGKIS", "Tahan bila diserang", Color("6f7f94")],
	]:
		tips.add_child(_tip(t[0], t[1], t[2]))
	col.add_child(tips)
	col.add_child(_heading("Kawalan"))
	var grid := GridContainer.new()  # two columns: every control shows at once
	grid.columns = 6   # three (keys, what) pairs a line; each column as wide as it needs
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	if Game.pad_mode():
		_control(grid, [Pad.glyph("stick", 30)], "Bergerak")
		for m in PAD:
			_control(grid, [Pad.glyph(m[0], 30)], m[1])
		_control(grid, [Pad.glyph("dpad", 30), Pad.glyph("cross", 30)], "Jawab soalan")
	elif on_touch():
		_control(grid, [_dot(Color("8a8a96"), "")], "Joystick kiri: bergerak")
		for t in TOUCH:
			_control(grid, [_dot(TOUCH_COLOURS[t[0]], "")], {"Ambil": "Ambil / baling", "Tangkis": "Tangkis (tahan)"}.get(t[0], t[0]))
	else:
		var walk: Array = []
		for a in ["move_up", "move_left", "move_down", "move_right"]:
			walk.append(_cap(Game.brawl_key_names(a)))
		_control(grid, walk, "Bergerak")
		for m in MOVES:
			var caps: Array = []
			for k in Game.brawl_key_names(m[0]).split(" / "):
				caps.append(_cap(k))
			_control(grid, caps, m[1])
		_control(grid, [_cap("1"), _cap("2"), _cap("3"), _cap("4")], "Jawab soalan")
		_control(grid, [_cap("Esc"), _cap("P")], "Jeda")
	col.add_child(grid)
	return col


## the colours of the on-screen fight buttons (touch_controls.gd)
const TOUCH_COLOURS := {
	"Tumbuk": Color("e8b04a"), "Sepak": Color("e0805a"), "Lompat": Color("7aa7d9"),
	"Ambil": Color("8ac27a"), "Tangkis": Color("a8b0bc"), "Jurus": Color("c9a0ff"),
}


static func _heading(t: String) -> Label:
	var h := UI.label(_t(t), "InkHeading")
	h.add_theme_color_override("font_color", Color("8a4b14"))
	return h


static func _small(t: String) -> Label:
	var l := UI.label(_t(t), "")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color.WHITE)
	return l


## one step of a round: a coloured box, its picture, its name, what happens
static func _step(icon: String, title: String, col: Color, body: Control) -> Control:
	var box := PanelContainer.new()
	var sb := UI.sb(col, col.darkened(0.35), 3, 10, 10)
	sb.border_width_bottom = 6
	box.add_theme_stylebox_override("panel", sb)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	var top := UI.hbox(8)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(UI.icon(icon, 30))
	var h := UI.label(_t(title), "Heading")
	h.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(h)
	v.add_child(top)
	var cc := CenterContainer.new()
	cc.add_child(body)
	v.add_child(cc)
	box.add_child(v)
	return box


static func _arrow() -> Control:
	var r := TextureRect.new()
	r.texture = ControlHint.arrow("right", 22, Color("8a4b14"))
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## (tick) SEMANGAT  /  (cross) LEMAH
static func _mark_line(right: bool, word: String) -> Control:
	var row := UI.hbox(6)
	var b = AnswerMark.Badge.new()
	b.right = right
	b.custom_minimum_size = Vector2(22, 22)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	var l := UI.label(_t(word), "")
	l.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(l)
	return row


## a tip: a keyword in its colour, a few words under it
static func _tip(word: String, what: String, col: Color) -> Control:
	var box := PanelContainer.new()
	var sb := UI.sb(Color(col, 0.16), col, 0, 8, 10)
	sb.border_width_left = 6
	box.add_theme_stylebox_override("panel", sb)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 200
	var v := UI.vbox(2)
	var k := UI.label(word, "InkHeading")
	k.add_theme_color_override("font_color", col.darkened(0.3))
	v.add_child(k)
	var l := UI.label(_t(what), "InkSmall")
	v.add_child(l)
	box.add_child(v)
	return box


## the keys / buttons of one action, then what it does: two cells of the grid
static func _control(grid: GridContainer, caps: Array, what: String) -> void:
	var keys := UI.hbox(4)
	for c in caps:
		keys.add_child(c)
	grid.add_child(keys)
	var l := UI.label(_t(what), "Ink")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)


static func _cap(key: String) -> Control:
	return ControlHint.key_cap(key)


## a round button the colour of an on-screen fight button
static func _dot(col: Color, _t2: String) -> Control:
	var d := Dot.new()
	d.colour = col
	d.custom_minimum_size = Vector2(30, 30)
	return d


class Dot extends Control:
	var colour := Color.WHITE

	func _draw() -> void:
		draw_circle(size / 2.0, 14.0, colour)
		draw_arc(size / 2.0, 14.0, 0, TAU, 32, colour.darkened(0.4), 2.0, true)


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
