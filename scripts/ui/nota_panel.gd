extends "res://scripts/ui/modal.gd"
## Nota Alif: visual summary of Bab 1, built from the zones the player
## has completed. Can be opened any time for revision.

var _data: Dictionary
var _page: int = 0
var _page_box: VBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button


func _init() -> void:
	title_text = "NOTA ALIF"
	panel_size = Vector2(1000, 600)
	panel_variation = "Paper"


func _build() -> void:
	_data = Game.load_json("res://data/nota.json")
	_page_box = UI.vbox(12)
	_page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_page_box)
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
	_show(0)


func _pages() -> Array:
	return _data.get("pages", [])


func _show(i: int) -> void:
	var pages := _pages()
	_page = clampi(i, 0, pages.size() - 1)
	for c in _page_box.get_children():
		c.queue_free()
	var p: Dictionary = pages[_page]
	var unlocked := Game.zone_done(str(p.get("zone", "")))
	_page_label.text = "Halaman %d / %d" % [_page + 1, pages.size()]
	_prev.disabled = _page == 0
	_next.disabled = _page >= pages.size() - 1
	var head := UI.label(str(p.get("title", "")), "InkHeading")
	_page_box.add_child(head)
	if not unlocked:
		var lock := UI.hbox(16)
		lock.add_child(UI.icon("res://assets/icons/kunci.png", 72))
		lock.add_child(UI.label("Selesaikan Zon %s untuk membuka halaman ini." % str(p["zone"]).replace("_", "."), "Ink", true))
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


func _read_page() -> void:
	var p: Dictionary = _pages()[_page]
	var parts: PackedStringArray = [str(p.get("title", ""))]
	for it in p.get("items", []):
		parts.append("%s. %s." % [it.get("text", ""), it.get("sub", "")])
	Tts.speak(" ".join(parts).replace("»", ","))
