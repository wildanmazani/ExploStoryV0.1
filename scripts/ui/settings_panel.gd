extends "res://scripts/ui/modal.gd"
## Tetapan, in tabs: Paparan (Mod Mudah Baca: font, text size and speed,
## read-aloud), Audio (music, sound, ambience, voice), Bahasa (menus in BM or
## English) and Akaun.

const TABS := ["Paparan", "Audio", "Bahasa", "Akaun"]

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
		2: _bahasa()
		3: _akaun()


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


func _bahasa() -> void:
	_body.add_child(UI.label("Bahasa menu", "Heading"))
	var grid := _grid()
	grid.add_child(UI.label("Bahasa"))
	var row := _choice(["ms", "en"], ["Bahasa Melayu", "English"], "lang")
	for b in row.get_children():
		(b as Button).pressed.connect(func(): _show.call_deferred(2))  # redraw in the new language
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


func _slider(key: String) -> HBoxContainer:
	var row := UI.hbox(10)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = float(Game.settings.get(key, 0.8)) * 100.0
	s.custom_minimum_size = Vector2(380, 36)
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
