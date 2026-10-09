extends "res://scripts/puzzles/puzzle_base.gd"
## Reflection ("Pilihan Alif"): not a quiz, every choice is accepted.


func _build_puzzle() -> void:
	feedback.text = "Tiada jawapan salah."
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for opt in def.get("options", []):
		var b := UI.button("", "")
		b.custom_minimum_size = Vector2(340, 300)
		var c := UI.vbox(12)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 16
		c.offset_right = -16
		c.offset_top = 20
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(UI.icon(str(opt.get("icon", "")), 120))
		var l := UI.label(str(opt.get("text", "")), "", true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(l)
		b.add_child(c)
		var o: Dictionary = opt
		b.pressed.connect(func(): _pick(o))
		row.add_child(b)
	body.add_child(row)


func _pick(opt: Dictionary) -> void:
	Game.save["reflection"] = str(opt.get("id", ""))
	finish(str(opt.get("result", "")))


func _hint(_tier: int) -> void:
	Game.main.pau_say("Pilih apa sahaja yang paling dekat dengan hidup kau. Semua pilihan diterima.")
