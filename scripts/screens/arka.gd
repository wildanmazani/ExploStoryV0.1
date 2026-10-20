extends Control
## Arka & Zon: each Arka is a Tingkatan (Form), each Zon is a Bab (chapter).
## Open zon show their misi progress; locked ones are greyed with a padlock
## and the word BERKUNCI (never colour only). Data: data/chapters.json.

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _arc: int = 0
var _grid: GridContainer
var _tabs: HBoxContainer
var _info: Label


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(true)
	MusicDirector.play("kampung")
	Game.context_hint = "Pilih Zon yang terbuka. Zon lain akan terbuka bila bab sebelumnya selesai."
	add_child(UI.bg_image("res://assets/backgrounds/bg_peta_jejak_pembelajaran.png", Color(0.55, 0.55, 0.62)))
	var root := UI.vbox(8)
	UI.full(root)
	root.add_child(UI.header_bar("ARKA & ZON", tr("Setiap Arka ialah satu Tingkatan. Setiap Zon ialah satu Bab.")))

	var body := UI.vbox(10)
	_tabs = UI.hbox(10)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	var arcs: Array = Game.chapters.get("arcs", [])
	for i in arcs.size():
		var a: Dictionary = arcs[i]
		var b := UI.button(str(a["name"]).replace("Sejarah ", ""), "", 260)
		if not a.get("open", false):
			b.icon = UI.tex("res://assets/icons/kunci.png")
			b.expand_icon = false
		b.pressed.connect(_show_arc.bind(i))
		_tabs.add_child(b)
	body.add_child(_tabs)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(UI.center(_grid))
	_grid.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info = UI.label("", "", true)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_info)

	var bar := UI.hbox(12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var prof := UI.button("Profil & Kedai", "Blue", 230)
	prof.pressed.connect(func(): if Game.main.has_method("open_profile"): Game.main.open_profile())
	bar.add_child(prof)
	var battle := UI.button("Bilik Pertarungan", "", 260)
	battle.pressed.connect(func(): Game.goto("lobby"))
	bar.add_child(battle)
	var papan := UI.button("Papan Markah", "", 220)
	papan.pressed.connect(func(): Game.main.open_papan())
	bar.add_child(papan)
	var st := UI.button("Tetapan", "", 180)
	st.pressed.connect(func(): Game.main.open_settings())
	bar.add_child(st)
	body.add_child(bar)
	root.add_child(UI.margin(body, 40, 0, 40, 14))
	root.get_child(1).size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)
	_show_arc(0)


func _show_arc(i: int) -> void:
	_arc = i
	for j in _tabs.get_child_count():
		(_tabs.get_child(j) as Button).theme_type_variation = "Primary" if j == i else ""
	for c in _grid.get_children():
		c.queue_free()
	var arc: Dictionary = Game.chapters["arcs"][i]
	if not arc.get("open", false):
		_info.text = tr("%s belum dibuka. Habiskan Tingkatan 4 dulu.") % str(arc["name"])
		for n in 10:
			_grid.add_child(_card({"no": n + 1, "title": "???", "icon": "kunci"}, false))
		Sfx.play("bump", -6.0)
		return
	_info.text = tr("Ketik Zon yang terbuka untuk masuk ke dunianya.")
	for ch in arc.get("chapters", []):
		var open := bool(ch.get("open", false)) and int(ch["no"]) <= GameState.unlocked_chapters
		_grid.add_child(_card(ch, open))
	Sfx.play("select", -8.0)


func _progress(ch: Dictionary) -> Vector2i:
	var zones: Array = ch.get("zones", [])
	var done := 0
	for z in zones:
		if Game.zone_done(str(z)):
			done += 1
	return Vector2i(done, zones.size())


func _card(ch: Dictionary, open: bool) -> Control:
	var no := int(ch["no"])
	var p := _progress(ch)
	var finished := open and p.y > 0 and p.x >= p.y
	var card := PanelContainer.new()
	card.theme_type_variation = ("SlotGood" if finished else "SlotHot") if open else "CardLocked"
	card.custom_minimum_size = Vector2(222, 186)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col := UI.vbox(4)
	var top := UI.hbox(6)
	var zl := UI.label(tr("ZON %d") % no, "Heading")
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(zl)
	if not open:
		top.add_child(UI.icon("res://assets/icons/kunci.png", 30))
	col.add_child(top)
	var ic := UI.icon("res://assets/icons/%s.png" % str(ch.get("icon", "bintang")), 44)
	if not open:
		ic.modulate = Color(0.5, 0.5, 0.55, 0.8)
	col.add_child(ic)
	var t := UI.label(str(ch.get("title", "")), "Small", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 190
	col.add_child(t)
	col.add_child(UI.spacer(false))
	var status := UI.label("", "Small")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if open:
		var bar := ProgressBar.new()
		bar.theme_type_variation = "Good" if finished else ""
		bar.show_percentage = false
		bar.max_value = maxi(p.y, 1)
		bar.value = p.x
		bar.custom_minimum_size = Vector2(0, 14)
		col.add_child(bar)
		status.text = tr("SIAP") if finished else tr("%d / %d misi") % [p.x, p.y]
		status.add_theme_color_override("font_color", Color("8fe08a") if finished else UI.GOLD)
	else:
		status.text = tr("BERKUNCI")
		status.add_theme_color_override("font_color", UI.GREY)
	col.add_child(status)
	card.add_child(col)
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_enter(ch, open))
	return card


func _enter(ch: Dictionary, open: bool) -> void:
	if not open:
		Sfx.play("bump", -4.0)
		Game.main.pau_say(tr("Belum lagi. Zon %d akan terbuka lepas kita habiskan bab sebelumnya.") % int(ch["no"]), 4.0)
		return
	Sfx.play("select")
	MusicDirector.stinger("st_correct")
	# each Bab has its own place in the world: Zon 2 starts in Lembah Kebangkitan
	var ent = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/entities.json"))
	var pos: Array = Game.save.get("map_pos", [])
	var in_lembah := pos.size() == 2 and int(pos[0]) >= 82
	if int(ch["no"]) == 2 and not in_lembah and ent is Dictionary and ent.has("arrive2"):
		GameState.spawn_cell = Vector2i(int(ent["arrive2"][0]), int(ent["arrive2"][1]))
	elif int(ch["no"]) == 1 and in_lembah and ent is Dictionary:
		GameState.spawn_cell = Vector2i(11, 27)
	Game.goto("world" if bool(Game.save.get("prolog_done", false)) else "prolog")
