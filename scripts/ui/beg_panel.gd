extends "res://scripts/ui/modal.gd"
## Beg Alif: every artifact Alif has found rides along in his school bag.
## One row of pockets per Bab (an artifact slot for each mission) plus the
## Kad Tokoh met in that Bab. Tap a found artifact and Pau tells its story
## (zone "ganjaran.cerita", else its "info"). Tabs switch between open chapters.
## Opened from the world, the bag also holds the Jalan Pintas: tap a place
## already unlocked and Alif is there (world.fast_travel).

const ICON := "res://assets/icons/beg.png"
const TRAVEL := "Jalan Pintas"
const AisyahLook = preload("res://scripts/ui/aisyah_look.gd")

var world: Node  ## set when opened in the world: shows the Jalan Pintas tab
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
	if open.size() > 1 or world:
		_tabs = UI.hbox(8)
		for n in open:
			var b := UI.button(tr("Bab %d") % n, "", 130)
			b.pressed.connect(_show.bind(n))
			_tabs.add_child(b)
		if world:
			var t := UI.button(tr(TRAVEL), "Blue", 200)
			t.pressed.connect(_show_travel)
			_tabs.add_child(t)
		content.add_child(_tabs)
	_body = UI.vbox(10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_show(open[-1] if not open.is_empty() else 1)


## light up the tab with this text, clear the page
func _page(tab: String) -> void:
	if _tabs:
		for b in _tabs.get_children():
			(b as Button).theme_type_variation = "Primary" if b.text == tab else ("Blue" if b.text == tr(TRAVEL) else "")
	for c in _body.get_children():
		c.queue_free()


func _show(ch: int) -> void:
	_page(tr("Bab %d") % ch)
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
" if not big else "") + tr("Klik untuk dengar ceritanya")) if have else ""
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
	if ch == 2 and Game.save["seen"].has("lembah_intro"):
		_body.add_child(_klu_poster())
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


## Bab 2: "ORANG HILANG", the girl the officer took. Her picture is a dark
## shape that fills in with every clue (tudung, baju, kain, then her face).
func _klu_poster() -> Control:
	var shown: Array = []
	var row := UI.hbox(18)
	var notes := UI.vbox(6)
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_child(UI.label(tr("Klu Aisyah  %d/4") % Game.klu_count(), "InkHeading"))
	for k in Game.klu_list():
		var no := int(k["no"])
		var got := Game.klu_found(no)
		if got:
			shown.append(AisyahLook.PARTS[no - 1])
		var line := UI.label(("%d. %s: %s" % [no, tr(str(k["nama"])), tr(str(k["isi"]))]) if got else ("%d. %s: ???" % [no, tr(str(k["nama"]))]), "Ink" if got else "InkSmall", true)
		notes.add_child(line)
	if Game.klu_count() < 4:
		notes.add_child(UI.label(tr("Cari tempat yang bersinar selepas Misi 2.1, 2.3, 2.5 dan 2.7."), "InkSmall", true))
	var pic := TextureRect.new()
	pic.texture = AisyahLook.texture(shown)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(144, 144)
	var frame := UI.vbox(2)
	var head := UI.label(tr("ORANG HILANG"), "InkHeading")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(head)
	frame.add_child(pic)
	row.add_child(frame)
	row.add_child(notes)
	var paper := UI.panel("Paper")
	paper.add_child(row)
	return paper


## the artifact's story, told over the bag
func _tell(g: Dictionary) -> void:
	if Main.is_dialogue_open():
		return
	Sfx.play("chime", -8.0)
	var lines: Array = g.get("cerita", [])
	if lines.is_empty():
		lines = [{"s": "pau", "t": str(g.get("info", ""))}]
	await Game.say(lines)


## Jalan Pintas: a card per place on the map (data/map_legend.json); the ones
## unlocked have PERGI, the rest say what to finish first
func _show_travel() -> void:
	_page(tr(TRAVEL))
	_body.add_child(UI.label("Pilih tempat yang dah dibuka. Alif terus sampai ke sana.", "Small", true))
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	for t in world.travel_places():
		var p: Dictionary = t["place"]
		var ok: bool = t["ok"]
		var card := UI.panel("SlotGood" if ok else "Slot")
		card.custom_minimum_size = Vector2(320, 0)
		var row := UI.hbox(10)
		var col := MapView.status_color(MapView.zone_status(str(p["zone"]))) if p.has("zone") else UI.CREAM
		var sym: Control = MapView.Symbol.new("flag", col) if p.has("zone") else MapView.Symbol.new("badge", Color.WHITE, UI.tex(str(p["icon"])))
		sym.custom_minimum_size = Vector2(36, 36)
		row.add_child(sym)
		var txt := UI.vbox(0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UI.label(str(p["name"]), "", true))
		txt.add_child(UI.label(str(p.get("info", "")) if ok else str(t["why"]), "Small", true))
		row.add_child(txt)
		var stack := UI.vbox(6)
		stack.add_child(row)
		if ok:
			var go := UI.button("PERGI", "Primary", 96)
			go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			go.pressed.connect(_travel.bind(p))
			row.add_child(go)
			var zid := str(p.get("zone", ""))
			if zid != "" and Game.zone_done(zid) and not ZoneRunner.replaying(zid):
				var again := UI.button(tr("MAIN SEMULA (tiada EXP)"))
				again.name = "MainSemula_" + zid
				again.pressed.connect(_replay.bind(p))
				stack.add_child(again)
		else:
			card.modulate = Color(1, 1, 1, 0.55)
		card.add_child(stack)
		grid.add_child(card)
	scroll.add_child(grid)
	_body.add_child(scroll)


## a finished mission again, for revision (no EXP): go there and its "!" light up
func _replay(p: Dictionary) -> void:
	var zid := str(p["zone"])
	var w := world
	close()
	ZoneRunner.start_replay(zid)
	GameState.flags["replay_hint"] = true
	if not w.fast_travel(p):
		Game.zone_state(zid).erase("replay")
		GameState.flags["replay_hint"] = false
		Game.persist()
		Game.toast(tr("Tak boleh pindah sekarang. Cuba lagi sekejap."))


func _travel(p: Dictionary) -> void:
	var w := world
	close()
	if not w.fast_travel(p):
		Game.toast(tr("Tak boleh pindah sekarang. Cuba lagi sekejap."))
