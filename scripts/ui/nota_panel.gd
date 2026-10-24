extends "res://scripts/ui/modal.gd"
## Nota Alif: visual summary of every open Bab (data/nota.json for Bab 1,
## data/nota_bab<n>.json after that), built from the zones the player has
## completed. Can be opened any time for revision.

var _data: Dictionary
var _page: int = 0
var _page_box: VBoxContainer
var _scroll: ScrollContainer
var _page_label: Label
var _prev: Button
var _next: Button
var start_zone := ""  ## open on this mission's first page


func _init() -> void:
	title_text = "NOTA ALIF"
	panel_size = Vector2(1000, 600)
	panel_variation = "Paper"


func _build() -> void:
	_data = Game.load_json("res://data/nota.json")
	var start := 0
	for n in range(2, Game.current_chapter() + 1):
		var path := "res://data/nota_bab%d.json" % n
		if FileAccess.file_exists(path):
			start = _data["pages"].size()  # open on the newest chapter
			_data["pages"].append_array(Game.load_json(path).get("pages", []))
	# the page scrolls: icon summary on top, the Huraian (textbook notes) under it
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_box = UI.vbox(12)
	_page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page_box)
	content.add_child(_scroll)
	var nav := UI.hbox(12)
	_prev = UI.button("« Sebelum")
	_prev.pressed.connect(func(): _show(_page - 1))
	nav.add_child(_prev)
	_page_label = UI.label("", "InkSmall")
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_page_label)
	var read := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(64, 56))
	read.pressed.connect(_read_page)
	nav.add_child(read)
	_next = UI.button("Seterus »")
	_next.pressed.connect(func(): _show(_page + 1))
	nav.add_child(_next)
	content.add_child(nav)
	if start_zone != "":
		for i in _pages().size():
			if str(_pages()[i].get("zone", "")) == start_zone:
				start = i
				break
	_show(start)


func _pages() -> Array:
	return _data.get("pages", [])


func _show(i: int) -> void:
	var pages := _pages()
	_page = clampi(i, 0, pages.size() - 1)
	for c in _page_box.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0
	var p: Dictionary = pages[_page]
	var unlocked := Game.zone_done(str(p.get("zone", "")))
	_page_label.text = tr("Bab %d") % Game.chapter_of(str(p.get("zone", "1_1"))) + "  ·  " + tr("Halaman %d / %d") % [_page + 1, pages.size()]
	_prev.disabled = _page == 0
	_next.disabled = _page >= pages.size() - 1
	var head := UI.label(str(p.get("title", "")), "InkHeading")
	_page_box.add_child(head)
	if not unlocked:
		var lock := UI.hbox(16)
		lock.add_child(UI.icon("res://assets/icons/kunci.png", 72))
		lock.add_child(UI.label("Selesaikan Misi %s untuk membuka halaman ini." % str(p["zone"]).replace("_", "."), "Ink", true))
		_page_box.add_child(lock)
		return
	var items: Array = p.get("items", [])
	var style := str(p.get("style", "list"))
	if style == "timeline":
		var row := UI.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for k in items.size():
			var it: Dictionary = items[k]
			var c := UI.vbox(4)
			c.custom_minimum_size.x = 160
			c.add_child(UI.icon(str(it.get("icon", "")), 110))
			var l := UI.label(str(it["text"]), "Ink", true)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(l)
			var s := UI.label(str(it.get("sub", "")), "InkSmall", true)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(s)
			row.add_child(c)
			if k < items.size() - 1:
				var arrow := UI.label("»", "InkHeading")
				row.add_child(arrow)
		_page_box.add_child(row)
	else:
		var grid := GridContainer.new()
		grid.columns = 2 if style == "grid" else 1
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 10)
		for it in items:
			var r := UI.hbox(14)
			r.custom_minimum_size.x = 440 if style == "grid" else 900
			r.add_child(UI.icon(str(it.get("icon", "")), 64))
			var tc := UI.vbox(2)
			tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tc.add_child(UI.label(str(it["text"]), "Ink", true))
			tc.add_child(UI.label(str(it.get("sub", "")), "InkSmall", true))
			r.add_child(tc)
			grid.add_child(r)
		_page_box.add_child(grid)
	_add_huraian(p)


## the simplified textbook notes: titled sections of short points, then an
## "Ingat!" box with the one line worth remembering for the exam
func _add_huraian(p: Dictionary) -> void:
	var secs: Array = p.get("huraian", [])
	if secs.is_empty():
		return
	var line := ColorRect.new()
	line.color = Color(0.45, 0.32, 0.2, 0.4)
	line.custom_minimum_size = Vector2(0, 2)
	_page_box.add_child(UI.margin(line, 0, 6, 0, 0))
	_page_box.add_child(UI.label(tr("HURAIAN"), "InkHeading"))
	for sec in secs:
		var h := UI.label(str(sec.get("h", "")), "Ink")
		h.add_theme_color_override("font_color", Color("8a4b14"))
		_page_box.add_child(h)
		for t in sec.get("t", []):
			var l := UI.label("•  " + str(t), "Ink", true)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_page_box.add_child(UI.margin(l, 14, 0, 8, 0))
	if p.has("ingat"):
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.sb(Color("fff1c2"), UI.GOLD, 3, 8, 12))
		var row := UI.hbox(12)
		row.add_child(UI.icon("res://assets/icons/bintang.png", 40))
		var l := UI.label(tr("Ingat! ") + str(p["ingat"]), "Ink", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		box.add_child(row)
		_page_box.add_child(UI.margin(box, 0, 8, 8, 8))


func _read_page() -> void:
	var p: Dictionary = _pages()[_page]
	var parts: PackedStringArray = [str(p.get("title", ""))]
	for it in p.get("items", []):
		parts.append("%s. %s." % [it.get("text", ""), it.get("sub", "")])
	if Game.zone_done(str(p.get("zone", ""))):
		for sec in p.get("huraian", []):
			parts.append(str(sec.get("h", "")) + ".")
			for t in sec.get("t", []):
				parts.append(str(t))
		if p.has("ingat"):
			parts.append(tr("Ingat! ") + str(p["ingat"]))
	Tts.speak(" ".join(parts).replace("»", ","))
