extends "res://scripts/ui/modal.gd"
## Tetapan, in tabs: Paparan (Mod Mudah Baca: font, text size and speed,
## read-aloud), Audio (music, sound, ambience, voice), Kawalan (on-screen
## controller for phones), Bahasa (menus in BM or English) and Akaun.

const TABS := ["Paparan", "Audio", "Kawalan", "Bahasa", "Akaun"]

var _tab: int = 0
var _body: VBoxContainer
var _tab_row: HBoxContainer


func _init() -> void:
	title_text = "TETAPAN"
	panel_size = Vector2(860, 580)


func _build() -> void:
	_tab_row = UI.hbox(8)
	for i in TABS.size():
		var b := UI.button(TABS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show.bind(i))
		_tab_row.add_child(b)
	content.add_child(_tab_row)
	_body = UI.vbox(14)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_show(_tab)


func _show(i: int) -> void:
	_tab = i
	for j in _tab_row.get_child_count():
		(_tab_row.get_child(j) as Button).theme_type_variation = "Primary" if j == i else ""
	for c in _body.get_children():
		c.queue_free()
	match i:
		0: _paparan()
		1: _audio()
		2: _kawalan()
		3: _bahasa()
		4: _akaun()


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	_body.add_child(grid)
	return grid


# ------------------------------------------------------------------ tabs
func _paparan() -> void:
	_body.add_child(UI.label("Mod Mudah Baca", "Heading"))
	var grid := _grid()
	grid.add_child(UI.label("Fon"))
	grid.add_child(_choice(["lexend", "atkinson", "opendyslexic"], ["Lexend", "Atkinson", "OpenDyslexic"], "font"))
	grid.add_child(UI.label("Saiz teks"))
	grid.add_child(_choice([0, 1, 2], ["Kecil", "Sederhana", "Besar"], "text_size"))
	grid.add_child(UI.label("Kelajuan teks"))
	grid.add_child(_choice([0, 1, 2], ["Perlahan", "Biasa", "Serta-merta"], "text_speed"))
	grid.add_child(UI.label("Baca dialog dengan suara"))
	grid.add_child(_toggle("auto_read"))
	var sample := UI.panel("Paper")
	var col := UI.vbox(4)
	col.add_child(UI.label("Tajuk 1 2 3 4 5 6 7 8 9 0", "InkHeading"))
	col.add_child(UI.label("Contoh: Kesultanan Melayu Melaka muncul pada abad ke-15.", "Ink", true))
	sample.add_child(col)
	_body.add_child(sample)


func _audio() -> void:
	_body.add_child(UI.label("Bunyi", "Heading"))
	var grid := _grid()
	for row in [["Muzik", "music"], ["Bunyi kesan", "sfx"], ["Suara watak", "voice"]]:
		grid.add_child(UI.label(row[0]))
		grid.add_child(_slider(row[1]))
	grid.add_child(UI.label("Senyapkan semua bunyi"))
	grid.add_child(_toggle("muted"))


func _kawalan() -> void:
	_body.add_child(UI.label("Kawalan skrin sentuh", "Heading"))
	var row := UI.hbox(20)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	row.add_child(grid)
	grid.add_child(UI.label("Jenis"))
	var kinds := UI.vbox(6)
	var r1 := _choice(["auto", "dpad"], ["Automatik", "D-pad"], "controls")
	var r2 := _choice(["joystick", "tap"], ["Joystick", "Ketik sahaja"], "controls")
	_join_choices(r1, r2)
	kinds.add_child(r1)
	kinds.add_child(r2)
	grid.add_child(kinds)
	grid.add_child(UI.label("Saiz butang"))
	grid.add_child(_choice([0, 1, 2], ["Kecil", "Sederhana", "Besar"], "pad_size"))
	grid.add_child(UI.label("Kelegapan"))
	grid.add_child(_slider("pad_alpha", 30, 240))
	grid.add_child(UI.label("Tangan kiri"))
	grid.add_child(_toggle("left_handed"))
	row.add_child(ControlsPreview.new())
	_body.add_child(row)
	var note := UI.label(tr(MODE_NOTES.get(str(Game.settings.get("controls", "auto")), "")), "Small", true)
	note.custom_minimum_size.x = 800
	_body.add_child(note)
	Game.settings_changed.connect(func():
		if is_instance_valid(note):
			note.text = tr(MODE_NOTES.get(str(Game.settings.get("controls", "auto")), "")))


const MODE_NOTES := {
	"auto": "Automatik: D-pad muncul di telefon dan tablet. Di komputer, guna papan kekunci (WASD / anak panah) atau klik peta.",
	"dpad": "D-pad: anak panah untuk berjalan, A untuk bercakap atau periksa, B (tekan lama) untuk berlari.",
	"joystick": "Joystick: letak ibu jari di mana-mana sebelah bawah kiri dan tolak. Tolak sampai hujung untuk berlari. A untuk bercakap.",
	"tap": "Ketik sahaja: tiada butang. Ketik tempat atau orang di peta, Alif akan jalan ke sana sendiri.",
}


## the two rows of controller choices act as one group
func _join_choices(a: HBoxContainer, b: HBoxContainer) -> void:
	var group: ButtonGroup = (a.get_child(0) as Button).button_group
	for c in b.get_children():
		(c as Button).button_group = group
	for c in a.get_children() + b.get_children():
		(c as Button).pressed.connect(func():
			for o in a.get_children() + b.get_children():
				(o as Button).theme_type_variation = "Primary" if o == c else "")


func _bahasa() -> void:
	_body.add_child(UI.label("Bahasa menu", "Heading"))
	var grid := _grid()
	grid.add_child(UI.label("Bahasa"))
	var row := _choice(["ms", "en"], ["Bahasa Melayu", "English"], "lang")
	for b in row.get_children():
		(b as Button).pressed.connect(func(): _show.call_deferred(3))  # redraw in the new language
	grid.add_child(row)
	var note := UI.label("Menu, butang dan peta ikut bahasa ini. Dialog, teka-teki dan nota sejarah kekal dalam Bahasa Melayu, sama seperti peperiksaan.", "Small", true)
	note.custom_minimum_size.x = 760
	_body.add_child(note)


func _akaun() -> void:
	var who := UI.label(tr("Pemain: %s") % Game.save["profile"]["username"], "Heading")
	_body.add_child(who)
	var acc := UI.hbox(12)
	var reset := UI.button("Mula semula Bab 1")
	reset.pressed.connect(_confirm_reset.bind(reset))
	acc.add_child(reset)
	var out := UI.button("Log keluar")
	out.pressed.connect(func():
		Backend.sign_out()
		close()
		Game.goto("login"))
	acc.add_child(out)
	_body.add_child(acc)


# ------------------------------------------------------------------ widgets
func _choice(values: Array, names: Array, key: String) -> HBoxContainer:
	var row := UI.hbox(8)
	var group := ButtonGroup.new()
	for i in values.size():
		var b := UI.button(str(names[i]))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = str(Game.settings.get(key)) == str(values[i])
		if b.button_pressed:
			b.theme_type_variation = "Primary"
		var v = values[i]
		b.pressed.connect(func():
			Game.set_setting(key, v)
			for c in row.get_children():
				(c as Button).theme_type_variation = "Primary" if c == b else "")
		row.add_child(b)
	return row


func _toggle(key: String) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = bool(Game.settings.get(key, false))
	c.text = tr("Ya") if c.button_pressed else tr("Tidak")
	c.toggled.connect(func(on: bool):
		c.text = tr("Ya") if on else tr("Tidak")
		Game.set_setting(key, on))
	return c


func _slider(key: String, min_v := 0, width := 380) -> HBoxContainer:
	var row := UI.hbox(10)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = 100
	s.step = 5
	s.value = float(Game.settings.get(key, 0.8)) * 100.0
	s.custom_minimum_size = Vector2(width, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := UI.label("%d%%" % int(s.value), "Small")
	pct.custom_minimum_size.x = 60
	s.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v)
		Game.set_setting(key, v / 100.0))
	s.drag_ended.connect(func(_c): Sfx.play("blip" if key == "voice" else "pop", 0.0, 1.2, "Voice" if key == "voice" else "SFX"))
	row.add_child(s)
	row.add_child(pct)
	return row


func _confirm_reset(btn: Button) -> void:
	if btn.text != tr("Pasti? Ketik lagi"):
		btn.text = tr("Pasti? Ketik lagi")
		return
	Game.reset_progress()
	close()
	Game.goto("peta")


## a little 16:9 phone screen showing where the controls will sit
class ControlsPreview extends Control:
	const W := 300.0

	func _init() -> void:
		custom_minimum_size = Vector2(W, W * 9.0 / 16.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Game.settings_changed.connect(queue_redraw)

	func _draw() -> void:
		var k := W / 1280.0
		draw_rect(Rect2(Vector2.ZERO, size), Color("4f8a4a"))
		draw_rect(Rect2(Vector2(0, size.y * 0.62), Vector2(size.x * 0.35, size.y * 0.38)), Color("3b8fc4"))
		draw_rect(Rect2(Vector2(size.x * 0.45, size.y * 0.25), Vector2(14, 20)), Color("f2efe6"))  # Alif
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.11, 0.06), false, 4.0)
		var m := Game.touch_mode()
		var s: float = [0.8, 1.0, 1.25][clampi(int(Game.settings.get("pad_size", 1)), 0, 2)]
		var a := clampf(float(Game.settings.get("pad_alpha", 0.7)), 0.3, 1.0)
		var lefty := bool(Game.settings.get("left_handed", false))
		var fx := func(x: float) -> float: return size.x - x if lefty else x
		var ink := Color(0.12, 0.08, 0.05, 0.6 * a)
		var cream := Color(1, 0.95, 0.8, a)
		var gold := Color("e8b04a", a)
		var blue := Color("7aa7d9", a)
		var pad := 96.0 * s * k
		var btn := 112.0 * s * k
		var mg := 36.0 * k
		# minimap + Pau move up when controls are on screen
		var mm := Rect2(Vector2(size.x - 12 - 60, size.y - 12 - 46), Vector2(60, 46))
		if m != "none":
			mm.position = Vector2(8, 166 * k) if lefty else Vector2(size.x - 8 - 60, 150 * k)
		draw_rect(mm, Color(0.95, 0.9, 0.75, 0.9))
		draw_rect(mm, Color(0.17, 0.11, 0.06), false, 2.0)
		match m:
			"dpad":
				var c := Vector2(mg + pad * 1.5, size.y - mg - pad * 1.5)
				c.x = fx.call(c.x)
				for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_rect(Rect2(c + d * pad - Vector2(pad, pad) * 0.46, Vector2(pad, pad) * 0.92), ink)
					var tip: Vector2 = c + d * pad * 1.25
					var side: Vector2 = d.orthogonal() * pad * 0.2
					draw_colored_polygon(PackedVector2Array([tip, c + d * pad * 0.8 + side, c + d * pad * 0.8 - side]), cream)
				draw_circle(Vector2(fx.call(size.x - mg - btn / 2), size.y - mg - btn * 0.95), btn / 2, gold)
				draw_circle(Vector2(fx.call(size.x - mg - btn * 1.6), size.y - mg - btn * 0.4), btn / 2, blue)
			"joystick":
				var r := 80.0 * s * k
				var c := Vector2(fx.call(mg + r * 1.6), size.y - mg - r * 1.6)
				draw_circle(c, r, ink)
				draw_arc(c, r, 0, TAU, 32, cream, 2.0, true)
				draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.45, gold)
				draw_circle(Vector2(fx.call(size.x - mg - btn * 0.7), size.y - mg - btn * 0.7), btn / 2, gold)
			_:
				# tap: a finger tapping the ground, with the dotted path Alif walks
				var to := Vector2(size.x * 0.7, size.y * 0.7)
				var from := Vector2(size.x * 0.45 + 7, size.y * 0.25 + 20)
				for i in 8:
					draw_circle(from.lerp(to, i / 8.0), 2.5, Color(1, 1, 1, 0.8))
				draw_arc(to, 10, 0, TAU, 24, Color.WHITE, 3.0, true)
