extends "res://scripts/ui/modal.gd"
## Full map of Dunia Explo-Story: drag to move, + / - or mouse wheel to zoom.
## Legend on the right: places (tap = show on map), keywords learned in each
## zone (from data/nota.json, hidden until the zone is done) and symbols.

var world: Node
var view: MapView
var _list: VBoxContainer
var _tabs: Array[Button] = []
var _drag_from := Vector2(-1, -1)
var _touches := {}  ## index -> position (two-finger pinch)
var _pinch_d := 0.0
var _kw_box: VBoxContainer
var _kw_filter := ""
var _open_zone := "?"   ## the Misi open in Kata Kunci ("?" = pick the latest done)


func _init() -> void:
	title_text = "PETA DUNIA EXPLO-STORY"
	panel_size = Vector2(1250, 690)


func _build() -> void:
	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# map + zoom bar
	var left := UI.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UI.sb(UI.NAVY, UI.GOLD, 3, 8, 3))
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view = MapView.new()
	view.world = world
	view.follow_player = false
	view.show_names = true
	view.icon_scale = 1.4
	view.custom_minimum_size = Vector2(820, 520)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.mouse_default_cursor_shape = Control.CURSOR_DRAG
	view.gui_input.connect(_on_map_input)
	holder.add_child(view)
	left.add_child(holder)
	var bar := UI.hbox(8)
	var out := UI.button("-  Zum keluar")
	out.pressed.connect(func(): _zoom(1.0 / 1.5))
	bar.add_child(out)
	var inn := UI.button("+  Zum masuk")
	inn.pressed.connect(func(): _zoom(1.5))
	bar.add_child(inn)
	var whole := UI.button("Seluruh peta")
	whole.pressed.connect(func(): view.set_zoom(0.0))
	bar.add_child(whole)
	var me := UI.button("Cari Alif")
	me.pressed.connect(_find_me)
	bar.add_child(me)
	left.add_child(bar)
	var tip := UI.label("Seret peta untuk gerak. Roda tetikus atau jepit untuk zum.", "Small")
	left.add_child(tip)
	row.add_child(left)

	# legend
	var right := UI.vbox(8)
	right.custom_minimum_size = Vector2(360, 0)
	var tabs := UI.hbox(6)
	for t in [["Tempat", "_show_places"], ["Kata Kunci", "_show_keywords"], ["Simbol", "_show_symbols"]]:
		var b := UI.button(t[0])
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(_tabs.size(), t[1]))
		tabs.add_child(b)
		_tabs.append(b)
	right.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UI.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	right.add_child(scroll)
	row.add_child(right)
	content.add_child(row)

	Sfx.play("whoosh", -10.0, 1.3)
	_select_tab(0, "_show_places")
	await get_tree().process_frame
	view.set_zoom(view.fit_scale() * 1.6)
	_find_me()


func _select_tab(i: int, method: String) -> void:
	for j in _tabs.size():
		_tabs[j].button_pressed = j == i
	for c in _list.get_children():
		c.queue_free()
	call(method)


func _find_me() -> void:
	view.center = Vector2(world.player.cell) + Vector2(0.5, 0.5)
	view.highlight = view.center
	view.clamp_center()


func _zoom(f: float) -> void:
	view.set_zoom(view.px_per_tile * f)
	Sfx.play("tick", -10.0, 1.4)


# ------------------------------------------------------------------ legend tabs
func _row(sym: Control, title: String, sub: String, sub_col: Color = UI.CREAM_D) -> HBoxContainer:
	var r := UI.hbox(10)
	sym.custom_minimum_size = Vector2(40, 40)
	r.add_child(sym)
	var c := UI.vbox(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(UI.label(title, "", true))
	if sub != "":
		var s := UI.label(sub, "Small", true)
		s.add_theme_color_override("font_color", sub_col)
		c.add_child(s)
	r.add_child(c)
	return r


func _show_places() -> void:
	var nz := Game.next_zone()
	for p in MapView.legend()["places"]:
		var sym: Control
		var sub := str(p.get("info", ""))
		var col := UI.CREAM_D
		if p.has("zone"):
			var st := MapView.zone_status(str(p["zone"]))
			sym = MapView.Symbol.new("flag", MapView.status_color(st))
			col = MapView.status_color(st)
			sub = tr(MapView.status_text(st)) + (tr("  - SETERUSNYA") if str(p["zone"]) == nz else "") + ("\n" + tr(sub) if sub != "" else "")
		else:
			sym = MapView.Symbol.new("badge", Color.WHITE, UI.tex(str(p["icon"])))
		# the whole row is a button: tap = show this place on the map
		var b := PanelContainer.new()
		var normal := UI.sb(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.12), 1, 8, 6)
		var hover := UI.sb(Color(1, 0.85, 0.3, 0.14), UI.GOLD, 2, 8, 6)
		b.add_theme_stylebox_override("panel", normal)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "Tunjuk di peta"
		b.mouse_entered.connect(func(): b.add_theme_stylebox_override("panel", hover))
		b.mouse_exited.connect(func(): b.add_theme_stylebox_override("panel", normal))
		var at := Vector2(p["at"][0], p["at"][1]) + Vector2(0.5, 0.5)
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_focus(at))
		var r := _row(sym, str(p["name"]), sub, col)
		_ignore_mouse(r)
		b.add_child(r)
		_list.add_child(b)


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _focus(tile: Vector2) -> void:
	Sfx.play("select", -6.0)
	view.set_zoom(maxf(view.px_per_tile, 9.0))
	view.center = tile
	view.highlight = tile
	view.clamp_center()


## Kata Kunci: a search box, then one folding card per Misi (only one open
## at a time). Inside, the keywords are small cards in two columns: icon +
## the word, with the detail under it. Tap a keyword = show on the map where
## it was learned. Locked Misi stay folded with a padlock.
func _show_keywords() -> void:
	if _open_zone == "?":
		_open_zone = ""
		for z in Game.ZONES:
			if Game.zone_done(z):
				_open_zone = z  # the latest finished Misi starts open
	var search := LineEdit.new()
	search.placeholder_text = tr("Cari kata kunci...")
	search.text = _kw_filter
	search.clear_button_enabled = true
	search.text_changed.connect(func(t: String):
		_kw_filter = t.strip_edges()
		_fill_keywords())
	_list.add_child(search)
	_kw_box = UI.vbox(8)
	_kw_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_kw_box)
	_fill_keywords()


func _fill_keywords() -> void:
	for c in _kw_box.get_children():
		c.queue_free()
	var nota: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/nota.json"))
	var q := _kw_filter.to_lower()
	var shown := 0
	for z in Game.ZONES:
		var done: bool = Game.zone_done(z)
		var pages: Array = nota["pages"].filter(func(pg): return str(pg["zone"]) == z)
		var count := 0
		var matches := 0
		for pg in pages:
			for it in pg.get("items", []):
				count += 1
				if q == "" or (str(it.get("text", "")) + " " + str(it.get("sub", ""))).to_lower().contains(q):
					matches += 1
		if q != "" and (not done or matches == 0):
			continue  # searching: only Misi with a hit
		shown += 1
		var open: bool = done and (q != "" or _open_zone == z)
		_kw_box.add_child(_zone_header(z, done, count, open))
		if not open:
			continue
		for pg in pages:
			var items: Array = pg.get("items", []).filter(func(it): return q == "" or (str(it.get("text", "")) + " " + str(it.get("sub", ""))).to_lower().contains(q))
			if items.is_empty():
				continue
			var pt := UI.label(str(pg["title"]).to_upper(), "Small")
			pt.add_theme_color_override("font_color", UI.GOLD)
			_kw_box.add_child(UI.margin(pt, 4, 4, 0, 0))
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			for it in items:
				grid.add_child(_keyword_chip(it, z))
			_kw_box.add_child(grid)
	if shown == 0:
		var l := UI.label(tr("Tiada kata kunci \"%s\" dalam misi yang sudah siap.") % _kw_filter, "Small", true)
		l.add_theme_color_override("font_color", UI.GREY)
		_kw_box.add_child(l)


func _zone_header(z: String, done: bool, count: int, open: bool) -> Control:
	var zd := Game.zone_data(z)
	var st := MapView.zone_status(z)
	var col := MapView.status_color(st)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(col, 0.18) if done else Color(1, 1, 1, 0.04), col if open else Color(col, 0.5), 2, 8, 6))
	var h := UI.hbox(10)
	var sym: Control = MapView.Symbol.new("flag", col) if done else MapView.Symbol.new("lock")
	sym.custom_minimum_size = Vector2(34, 34)
	h.add_child(sym)
	var c := UI.vbox(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(UI.label("Misi %s: %s" % [str(zd.get("no", z.replace("_", "."))), str(zd.get("title", ""))], "", true))
	var sub := UI.label(tr("%d kata kunci") % count if done else tr("Siapkan misi untuk buka"), "Small")
	sub.add_theme_color_override("font_color", col if done else UI.GREY)
	c.add_child(sub)
	h.add_child(c)
	if done:
		h.add_child(Arrow.new(open))
	card.add_child(h)
	_ignore_mouse(h)
	if done:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Sfx.play("tick", -8.0, 1.2)
				_open_zone = "" if _open_zone == z else z
				_fill_keywords())
	return card


func _keyword_chip(it: Dictionary, z: String) -> Control:
	var chip := PanelContainer.new()
	var normal := UI.sb(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.14), 1, 8, 6)
	var hover := UI.sb(Color(1, 0.85, 0.3, 0.16), UI.GOLD, 2, 8, 6)
	chip.add_theme_stylebox_override("panel", normal)
	chip.custom_minimum_size.x = 168
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	var top := UI.hbox(6)
	top.add_child(UI.icon(str(it.get("icon", "")), 28))
	var word := UI.label(str(it.get("text", "")), "", true)
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word.add_theme_font_size_override("font_size", 19)
	top.add_child(word)
	v.add_child(top)
	if str(it.get("sub", "")) != "":
		var s := UI.label(str(it["sub"]), "Small", true)
		s.add_theme_font_size_override("font_size", 15)
		s.add_theme_color_override("font_color", UI.CREAM_D)
		v.add_child(s)
	chip.add_child(v)
	_ignore_mouse(v)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.tooltip_text = tr("Tunjuk di peta tempat kata kunci ini dipelajari")
	chip.mouse_entered.connect(func(): chip.add_theme_stylebox_override("panel", hover))
	chip.mouse_exited.connect(func(): chip.add_theme_stylebox_override("panel", normal))
	chip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_focus_zone(z))
	return chip


## centre the map on the place of a Misi (data/map_legend.json)
func _focus_zone(z: String) -> void:
	for p in MapView.legend()["places"]:
		if str(p.get("zone", "")) == z:
			_focus(Vector2(p["at"][0], p["at"][1]) + Vector2(0.5, 0.5))
			return


## the little open/closed triangle on a Misi card
class Arrow extends Control:
	var open := false

	func _init(is_open: bool) -> void:
		open = is_open
		custom_minimum_size = Vector2(24, 24)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := size / 2.0
		var pts := PackedVector2Array([c + Vector2(-7, -4), c + Vector2(7, -4), c + Vector2(0, 5)]) if open \
			else PackedVector2Array([c + Vector2(-4, -7), c + Vector2(5, 0), c + Vector2(-4, 7)])
		draw_colored_polygon(pts, Color(1, 0.95, 0.8))


func _show_symbols() -> void:
	_list.add_child(_row(MapView.Symbol.new("me"), "Alif (kau di sini)", "Titik merah berkelip"))
	_list.add_child(_row(MapView.Symbol.new("bang"), "Tugasan seterusnya", "Pergi ke tanda seru"))
	_list.add_child(_row(MapView.Symbol.new("flag", MapView.COL_DONE), "Misi siap", "Bendera hijau"))
	_list.add_child(_row(MapView.Symbol.new("flag", MapView.COL_OPEN), "Misi terbuka", "Bendera emas"))
	_list.add_child(_row(MapView.Symbol.new("flag", MapView.COL_LOCKED), "Misi berkunci", "Bendera kelabu: siapkan misi sebelumnya"))
	_list.add_child(_row(MapView.Symbol.new("npc"), "Orang", "Ketik untuk bercakap"))
	for id in MapView.legend()["landmarks"]:
		var lm: Dictionary = MapView.legend()["landmarks"][id]
		_list.add_child(_row(MapView.Symbol.new("badge", Color.WHITE, UI.tex(str(lm["icon"]))), str(lm["name"]), ""))
	_list.add_child(_row(MapView.Symbol.new("lock"), "Gerbang bab berkunci", "Bab 2 dan seterusnya"))
	_list.add_child(_row(MapView.Symbol.new("mist"), "Kabus Masa", "Belum boleh diterokai"))


# ------------------------------------------------------------------ input
func _on_map_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
		_pinch_d = 0.0
	elif e is InputEventScreenDrag and _touches.size() >= 2:
		_touches[e.index] = e.position
		var pts: Array = _touches.values()
		var d: float = (pts[0] as Vector2).distance_to(pts[1])
		if _pinch_d > 0.0:
			view.set_zoom(view.px_per_tile * d / _pinch_d, ((pts[0] as Vector2) + pts[1]) / 2.0)
		_pinch_d = d
		_drag_from = Vector2(-1, -1)
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = e.position if e.pressed else Vector2(-1, -1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			view.set_zoom(view.px_per_tile * 1.2, e.position)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view.set_zoom(view.px_per_tile / 1.2, e.position)
		accept_event()
	elif e is InputEventMouseMotion and _drag_from.x >= 0 and _touches.size() < 2:
		view.center -= (e.position - _drag_from) / view.px_per_tile
		view.clamp_center()
		_drag_from = e.position
		accept_event()
	elif e is InputEventMagnifyGesture:
		view.set_zoom(view.px_per_tile * e.factor, e.position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("map"):
		close()
		get_viewport().set_input_as_handled()
