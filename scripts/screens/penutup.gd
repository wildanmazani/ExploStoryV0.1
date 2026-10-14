extends Control
## Penutup Bab 1: Bendera 1 waves, the road to Bendera 2 lights up,
## Nota Alif opens, then a teaser for Bab 2.

const UI = preload("res://scripts/ui/ui.gd")
const ORIGIN := Vector2(40, 140)  # map-pixel crop origin (map is drawn x4)

var params: Dictionary = {}
var _road: Line2D


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("tajuk")
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/backgrounds/bg_peta_jejak_pembelajaran.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UI.full(bg)
	add_child(bg)
	var flags: Array = load("res://scripts/ui/peta_jejak.gd").FLAGS
	var f1: Vector2 = flags[0] * 4.0
	var f2: Vector2 = flags[1] * 4.0
	_road = Line2D.new()
	_road.width = 26
	_road.default_color = Color(1, 0.85, 0.3, 0.0)
	_road.add_point(f1)
	_road.add_point(f2)
	add_child(_road)
	var flag2 := _img("res://assets/ui/bendera_berkunci.png", f2, 2)
	var flag1 := _img("res://assets/ui/bendera_berkibar.png", f1, 2.5)
	flag1.pivot_offset = Vector2(20, flag1.size.y)
	_img("res://assets/characters32/alif/alif_south.png", f1 + Vector2(-120, 60), 3)
	var pau := _img_pau(f1 + Vector2(-50, 64))
	_run(flag1, flag2, pau)


func _map_to_screen(p: Array) -> Vector2:
	return (Vector2(p[0], p[1]) / 4.0 - ORIGIN) * 4.0


func _img(path: String, feet: Vector2, sc: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.tex(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = r.texture.get_size() * sc
	r.position = feet - Vector2(r.size.x / 2.0, r.size.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _img_frame(path: String, feet: Vector2, sc: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.sheet_frame(path, 0, 0)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(16, 24) * sc
	r.position = feet - Vector2(r.size.x / 2.0, r.size.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _img_pau(feet: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.tex("res://assets/characters32/pau/pau_small.png")
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(96, 96)
	r.position = feet - Vector2(48, 96)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _run(flag1: TextureRect, flag2: TextureRect, pau: TextureRect) -> void:
	# chapter complete
	if not Game.chapter_done(1):
		Game.save["chapters_done"].append(1)
		Game.add_reward(150, 100)
		Game.persist()
	await get_tree().create_timer(0.6).timeout
	var wave := create_tween().set_loops()
	wave.tween_property(flag1, "scale", Vector2(1.08, 1.0), 0.3)
	wave.tween_property(flag1, "scale", Vector2(0.94, 1.0), 0.3)
	var hop := create_tween().set_loops()
	hop.tween_property(pau, "position:y", pau.position.y - 24, 0.25)
	hop.tween_property(pau, "position:y", pau.position.y, 0.25)
	var road := create_tween()
	road.tween_property(_road, "default_color:a", 0.75, 1.5)
	create_tween().tween_property(flag2, "modulate", Color(1.3, 1.2, 0.8), 1.5)
	var banner := UI.label("BENDERA 1 BERKIBAR!", "Title")
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, 40)
	banner.size = Vector2(1280, 100)
	add_child(banner)
	MusicDirector.stinger("st_zone")
	await Game.say("penutup_a")
	hop.kill()
	# Nota Alif
	var nota_panel = load("res://scripts/ui/nota_panel.gd").new()
	Game.main.overlay_root().add_child(nota_panel)
	await nota_panel.closed
	# gentle wellbeing card
	await _card("Satu nota kecil", "Jika rasa tertekan menjelang peperiksaan, bercakaplah dengan guru, kaunselor atau keluarga. Kau tidak keseorangan.", "res://assets/icons/rakan.png")
	# teaser Bab 2
	banner.queue_free()
	await _teaser()
	Game.save["map_pos"] = []
	Game.persist()
	Game.goto("peta")


func _card(title: String, text: String, icon_path: String) -> void:
	var cover := UI.dim(0.55)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	var p := UI.panel("Paper")
	p.custom_minimum_size = Vector2(700, 0)
	var c := UI.vbox(14)
	c.add_child(UI.icon(icon_path, 96))
	var t := UI.label(title, "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var b := UI.label(text, "Ink", true)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(b)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var sp := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(64, 56))
	sp.pressed.connect(func(): Tts.speak(text))
	row.add_child(sp)
	var ok := UI.button("Teruskan »", "Primary", 220)
	row.add_child(ok)
	c.add_child(row)
	p.add_child(c)
	var cc := UI.center(p)
	add_child(cc)
	ok.grab_focus()
	await ok.pressed
	cover.queue_free()
	cc.queue_free()


func _teaser() -> void:
	var dark := ColorRect.new()
	dark.color = Color(0.05, 0.06, 0.1, 0.0)
	UI.full(dark)
	add_child(dark)
	var tw := create_tween()
	tw.tween_property(dark, "color:a", 0.94, 1.0)
	await tw.finished
	var col := UI.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(UI.icon("res://assets/icons/bendera.png", 120))
	var a := UI.label("BAB 2", "Title")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(a)
	var b := UI.label("KEBANGKITAN NASIONALISME", "Heading")
	b.add_theme_font_size_override("font_size", 44)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(b)
	var c := UI.label("Akan Datang", "Small")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(c)
	var cc := UI.center(col)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	col.modulate.a = 0.0
	create_tween().tween_property(col, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(1.4).timeout
	await Game.say("penutup_teaser")
	var btn := UI.button("KEMBALI MENEROKA", "Primary", 320)
	btn.position = Vector2(480, 600)
	add_child(btn)
	btn.grab_focus()
	await btn.pressed
