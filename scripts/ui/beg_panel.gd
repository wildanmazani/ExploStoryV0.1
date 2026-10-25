extends "res://scripts/ui/modal.gd"
## Beg Alif: every artifact Alif has found rides along in his school bag.
## One row of pockets per Bab (an artifact slot for each mission) plus the
## Kad Tokoh met in that Bab. Tap a found artifact and Pau tells its story
## (zone "ganjaran.cerita", else its "info"). Tabs switch between open chapters.

const ICON := "res://assets/icons/beg.png"

var _body: VBoxContainer
var _tabs: HBoxContainer


func _init() -> void:
	title_text = "BEG ALIF"
	panel_size = Vector2(1060, 620)


## the bag icon for menus: assets/icons/beg.png when it exists, else a small
## school bag drawn in pixels (24x24, same size as the other menu icons)
static func icon() -> Texture2D:
	if ResourceLoader.exists(ICON):
		return load(ICON)
	const ROWS := [
		"....####....", "...#....#...", "..########..", ".#BBBBBBBB#.",
		".#BBBBBBBB#.", ".#BBBBBBBB#.", ".#bbbGGbbb#.", ".#bbbbbbbb#.",
		".#bbbbbbbb#.", ".#bbbbbbbb#.", ".#bbbbbbbb#.", "..########..",
	]
	var cols := {"#": Color("1b2a44"), "B": Color("5a8fd6"), "b": Color("3b6fb6"), "G": Color("ffd24a")}
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		for x in ROWS[y].length():
			if cols.has(ROWS[y][x]):
				img.fill_rect(Rect2i(x * 2, y * 2, 2, 2), cols[ROWS[y][x]])
	return ImageTexture.create_from_image(img)


func _build() -> void:
	var open: Array = []
	for n in range(1, Game.current_chapter() + 1):
		if not Game.chapter_zones(n).is_empty():
			open.append(n)
	if open.size() > 1:
		_tabs = UI.hbox(8)
		for n in open:
			var b := UI.button(tr("Bab %d") % n, "", 130)
			b.pressed.connect(_show.bind(n))
			_tabs.add_child(b)
		content.add_child(_tabs)
	_body = UI.vbox(10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_show(open[-1] if not open.is_empty() else 1)


func _show(ch: int) -> void:
	if _tabs:
		for b in _tabs.get_children():
			(b as Button).theme_type_variation = "Primary" if b.text == tr("Bab %d") % ch else ""
	for c in _body.get_children():
		c.queue_free()
	var zones := Game.chapter_zones(ch)
	var big := zones.size() <= 4
	var shelf := GridContainer.new()
	shelf.columns = 4
	shelf.add_theme_constant_override("h_separation", 16)
	shelf.add_theme_constant_override("v_separation", 10)
	for z in zones:
		var zd := Game.zone_data(z)
		var g: Dictionary = zd.get("ganjaran", {})
		var have: bool = Game.save["artifacts"].has(str(g.get("id", "")))
		var slot := UI.panel("SlotGood" if have else "Slot")
		slot.custom_minimum_size = Vector2(230, 250 if big else 150)
		slot.tooltip_text = ((str(g.get("info", "")) + "
" if not big else "") + tr("Ketik untuk dengar ceritanya")) if have else ""
		if have:
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					_tell(g))
		var c := UI.vbox(4 if big else 2)
		var ic := UI.icon("res://assets/icons/%s.png" % g.get("icon", "kunci") if have else "res://assets/icons/kunci.png", 110 if big else 56)
		if not have:
			ic.modulate = Color(1, 1, 1, 0.5)
		c.add_child(ic)
		var n := UI.label(str(g.get("nama", "?")) if have else "???", "Heading" if have and big else "Small", true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(n)
		if big or not have:
			var info := UI.label(str(g.get("info", "")) if have else tr("Selesaikan Misi %s") % str(zd.get("no", "")), "Small", true)
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(info)
		slot.add_child(c)
		shelf.add_child(slot)
	_body.add_child(UI.center(shelf))
	_body.add_child(UI.label("Kad Tokoh", "Heading"))
	var row := UI.hbox(10)
	for id in Game.characters.keys():
		var ch_def: Dictionary = Game.characters[id]
		if not ch_def.get("tokoh", false) or Game.chapter_of(str(ch_def.get("zon", "1_1"))) != ch:
			continue
		var met: bool = Game.save["figures"].has(id)
		var card := UI.panel("Card" if met else "CardLocked")
		card.custom_minimum_size = Vector2(118 if not big else 140, 0)
		card.tooltip_text = str(ch_def.get("lore", "")) if met else tr("Temui tokoh ini di Misi %s") % str(ch_def.get("zon", "")).replace("_", ".")
		var cc := UI.vbox(2)
		var pic := UI.icon(Game.portrait_path(id), 64)  # 64 px portraits: 1:1, crisp
		if not met:
			pic.modulate = Color(0, 0, 0, 0.85)
		cc.add_child(pic)
		var nm := UI.label(str(ch_def["name"]) if met else "Berkunci", "InkSmall" if met else "Small", true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(nm)
		card.add_child(cc)
		row.add_child(card)
	_body.add_child(row)


## the artifact's story, told over the bag
func _tell(g: Dictionary) -> void:
	if Main.is_dialogue_open():
		return
	Sfx.play("chime", -8.0)
	var lines: Array = g.get("cerita", [])
	if lines.is_empty():
		lines = [{"s": "pau", "t": str(g.get("info", ""))}]
	await Game.say(lines)
