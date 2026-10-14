extends "res://scripts/ui/modal.gd"
## Tetapan: Mod Mudah Baca (font, text size, text speed, read-aloud),
## sound, and account actions.


func _init() -> void:
	title_text = "TETAPAN"
	panel_size = Vector2(820, 560)


func _build() -> void:
	var sec := UI.label("Mod Mudah Baca", "Heading")
	content.add_child(sec)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)

	grid.add_child(UI.label("Fon"))
	grid.add_child(_choice(["lexend", "atkinson", "opendyslexic"], ["Lexend", "Atkinson", "OpenDyslexic"], "font"))
	grid.add_child(UI.label("Saiz teks"))
	grid.add_child(_choice([0, 1, 2], ["Kecil", "Sederhana", "Besar"], "text_size"))
	grid.add_child(UI.label("Kelajuan teks"))
	grid.add_child(_choice([0, 1, 2], ["Perlahan", "Biasa", "Serta-merta"], "text_speed"))
	grid.add_child(UI.label("Baca dialog dengan suara"))
	grid.add_child(_toggle("auto_read"))
	grid.add_child(UI.label("Senyapkan semua bunyi"))
	grid.add_child(_toggle("muted"))

	var sample := UI.panel("Paper")
	var sl := UI.label("Contoh: Kesultanan Melayu Melaka muncul pada abad ke-15.", "Ink", true)
	sample.add_child(sl)
	content.add_child(sample)

	var acc := UI.hbox(12)
	var who := UI.label("Pemain: %s" % Game.save["profile"]["username"], "Small")
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc.add_child(who)
	var reset := UI.button("Mula semula Bab 1")
	reset.pressed.connect(_confirm_reset.bind(reset))
	acc.add_child(reset)
	var out := UI.button("Log keluar")
	out.pressed.connect(func():
		Backend.sign_out()
		close()
		Game.goto("login"))
	acc.add_child(out)
	content.add_child(acc)


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
	c.text = "Ya" if c.button_pressed else "Tidak"
	c.toggled.connect(func(on: bool):
		c.text = "Ya" if on else "Tidak"
		Game.set_setting(key, on))
	return c


func _confirm_reset(btn: Button) -> void:
	if btn.text != "Pasti? Ketik lagi":
		btn.text = "Pasti? Ketik lagi"
		return
	Game.reset_progress()
	close()
	Game.goto("peta")
