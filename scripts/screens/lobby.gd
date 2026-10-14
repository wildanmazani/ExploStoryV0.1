extends Control
## Module 6 (Phase 2): Arena Ulang Kaji lobby, following the GDS mockup.
## The interface is ready; hosting/joining rooms needs the online backend
## (Supabase Realtime) and opens after Bab 1, so it shows "Akan Datang".

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(true)
	MusicDirector.play("melaka")
	Game.context_hint = "Arena Ulang Kaji: lawan kuiz bersama rakan menggunakan kod bilik. Akan datang!"
	add_child(UI.bg_image("res://assets/backgrounds/bg_zon1_3_balai_penghadapan.png", Color(0.7, 0.62, 0.6)))
	var root := UI.vbox(0)
	UI.full(root)
	root.add_child(UI.header_bar("LOBI BERBILANG PEMAIN", "TOPIK: SEJARAH TINGKATAN 4 - BAB 1 (WARISAN NEGARA BANGSA)"))
	var card := UI.panel("Glass")
	card.custom_minimum_size = Vector2(640, 0)
	var c := UI.vbox(12)
	var rc := UI.label("KOD BILIK:", "InkHeading")
	rc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(rc)
	var code := UI.label("- - - - - - - -", "Title")
	code.add_theme_color_override("font_color", UI.INK)
	code.add_theme_constant_override("outline_size", 0)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(code)
	var host := UI.button("BUKA BILIK", "Primary", 300)
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.disabled = true
	c.add_child(host)
	var jl := UI.label("SERTAI BILIK:", "InkHeading")
	jl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(jl)
	var join := LineEdit.new()
	join.placeholder_text = "Masukkan kod 8 aksara"
	join.editable = false
	join.alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(join)
	var soon := UI.panel()
	var sl := UI.label("AKAN DATANG: Arena Ulang Kaji dibuka selepas Bab 1 dan memerlukan sambungan dalam talian. Lawan kuiz 1v1 hingga 4v4 menggunakan Kad Tokoh yang kau kumpul.", "", true)
	sl.custom_minimum_size.x = 580
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.add_child(sl)
	c.add_child(soon)
	var status := UI.label("Menunggu pemain...  (status sambungan)", "InkSmall")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(status)
	card.add_child(c)
	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(card)
	root.add_child(mid)
	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("« KEMBALI MENEROKA", "", 300)
	back.pressed.connect(func(): Game.goto("peta"))
	btns.add_child(back)
	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(200, 64), " TETAPAN")
	st.pressed.connect(func(): Game.main.open_settings())
	btns.add_child(st)
	var lb := UI.button("PAPAN PENDAHULU", "", 260)
	lb.disabled = true
	btns.add_child(lb)
	var inv := UI.button("INVENTORI", "", 220)
	inv.pressed.connect(func(): Game.main.open_muzium())
	btns.add_child(inv)
	root.add_child(UI.margin(btns, 0, 0, 0, 24))
	add_child(root)
	back.grab_focus()
