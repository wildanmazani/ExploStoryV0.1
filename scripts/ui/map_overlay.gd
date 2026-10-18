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


func _init() -> void:
	title_text = "PETA DUNIA EXPLO-STORY"
	panel_size = Vector2(1220, 670)


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
	view.custom_minimum_size = Vector2(720, 500)
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
	right.custom_minimum_size = Vector2(400, 0)
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
			sub = MapView.status_text(st) + ("  - SETERUSNYA" if str(p["zone"]) == nz else "") + ("\n" + sub if sub != "" else "")
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


func _show_keywords() -> void:
	var nota: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/nota.json"))
	for z in Game.ZONES:
		var zd := Game.zone_data(z)
		var st := MapView.zone_status(z)
		var head := _row(MapView.Symbol.new("flag", MapView.status_color(st)), "Zon %s: %s" % [str(zd.get("no", z.replace("_", "."))), str(zd.get("title", ""))], MapView.status_text(st), MapView.status_color(st))
		_list.add_child(head)
		if st != "done":
			var l := UI.label("???  Siapkan zon ini untuk buka kata kuncinya.", "Small", true)
			l.add_theme_color_override("font_color", UI.GREY)
			_list.add_child(UI.margin(l, 50, 0, 0, 6))
			continue
		for page in nota["pages"]:
			if str(page["zone"]) != z:
				continue
			var pt := UI.label(str(page["title"]), "Small")
			pt.add_theme_color_override("font_color", UI.GOLD)
			_list.add_child(UI.margin(pt, 50, 0, 0, 0))
			for it in page.get("items", []):
				var r := _row(UI.icon(str(it.get("icon", "")), 32), str(it.get("text", "")), str(it.get("sub", "")))
				_list.add_child(UI.margin(r, 50, 0, 0, 0))
		_list.add_child(HSeparator.new())


func _show_symbols() -> void:
	_list.add_child(_row(MapView.Symbol.new("me"), "Alif (kau di sini)", "Titik merah berkelip"))
	_list.add_child(_row(MapView.Symbol.new("bang"), "Tugasan seterusnya", "Pergi ke tanda seru"))
	_list.add_child(_row(MapView.Symbol.new("flag", MapView.COL_DONE), "Zon siap", "Bendera hijau"))
	_list.add_child(_row(MapView.Symbol.new("flag", MapView.COL_OPEN), "Zon terbuka", "Bendera emas"))
	_list.add_child(_row(MapView.Symbol.new("flag", MapView.COL_LOCKED), "Zon berkunci", "Bendera kelabu: siapkan zon sebelumnya"))
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
