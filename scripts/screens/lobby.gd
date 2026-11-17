extends Control
## Bilik Pertarungan hub (Arena Ulang Kaji). Two ways to play:
##  - Lawan Bot: you against 2-4 classmate bots, on this device, no internet.
##  - Main dengan Rakan: open a room and share its 6-digit code (or type a
##    friend's code); 2-4 friends join and the host starts. No friend list
##    needed. Needs the online server (Supabase, supabase/multiplayer.sql and
##    its patches); offline it says so.

const ControlHint = preload("res://scripts/ui/control_hint.gd")
const UI = preload("res://scripts/ui/ui.gd")
const BrawlGuide = preload("res://scripts/ui/brawl_guide.gd")

var params: Dictionary = {}
var _format := "1v1"
var _level := "mudah"  ## new players start easy
var _faces: HBoxContainer
var _fighter_row: HBoxContainer
var _stage_row: HBoxContainer
var _right: VBoxContainer
var _room_code := ""
var _room_box: VBoxContainer
var _room_foot: HBoxContainer   ## in a room: Mula! (host) or waiting
var _poll_t := 0.0
var _polling := false
## room settings the host picks (sent with set_room_config)
var _room_cfg := {"chapter": 1, "team": "pvp", "bot_level": "mudah", "mode": "kuiz", "stage": "sekolah"}
var _cfg_box: VBoxContainer
var _cfg_sent := false
const TEAMS := {"pvp": "Lawan sesama", "coop": "Sepasukan lwn Bot"}


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(true)
	MusicDirector.play("melaka")
	Game.context_hint = "Jawab betul untuk serang pemain yang kau pilih. Yang terakhir berdiri menang 20 syiling!"
	add_child(UI.bg_image("res://assets/backgrounds/bg_zon1_3_balai_penghadapan.png", Color(0.6, 0.55, 0.58)))
	var root := UI.vbox(10)
	UI.full(root)
	root.add_child(UI.header_bar("BILIK PERTARUNGAN", tr("Jawab betul, serang lawan.")))
	_fighter_row = UI.hbox(8)
	_fighter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_fighter_row)
	_show_fighters()
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_bot_card())
	_right = UI.vbox(12)
	row.add_child(_card(BLUE, "res://assets/icons/kumpulan.png", "Main dengan Rakan", BattleRules.COINS_FRIENDS, _right))
	# the two cards scroll when big text makes them taller than the screen;
	# the button row below stays put so Kembali is always reachable
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	root.add_child(scroll)
	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("« Kembali", "", 220)
	back.pressed.connect(func(): Game.goto("arka"))
	btns.add_child(back)
	var prof := UI.button("Profil & Kedai", "Blue", 220)
	prof.pressed.connect(func(): Game.main.open_profile())
	btns.add_child(prof)
	var papan := UI.button("Papan Markah", "", 220)
	papan.pressed.connect(func(): Game.main.open_papan())
	btns.add_child(papan)
	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(200, 60), " Tetapan")
	st.pressed.connect(func(): Game.main.open_settings())
	btns.add_child(st)
	root.add_child(UI.margin(btns, 0, 0, 0, 12))
	add_child(root)
	_build_friends()


# ------------------------------------------------------------------ looks
const GREEN := Color("4f9a45")
const BLUE := Color("3f7fc4")
const LEVEL_COLOURS := {"mudah": Color("4f9a45"), "biasa": Color("d39a1f"), "sukar": Color("c94a4a")}


## a card with a coloured band on top: its picture, its name, the coins a win pays
func _card(col: Color, icon: String, title: String, coins: int, body: Control) -> Control:
	var card := PanelContainer.new()
	var sb := UI.sb(Color(0.97, 0.94, 0.88, 0.96), col.darkened(0.3), 3, 12, 0)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(590, 0)
	var v := UI.vbox(0)
	var band := PanelContainer.new()
	var bs := UI.sb(col, col.darkened(0.3), 0, 0, 10)
	bs.corner_radius_top_left = 10
	bs.corner_radius_top_right = 10
	bs.content_margin_left = 16
	bs.content_margin_right = 12
	band.add_theme_stylebox_override("panel", bs)
	var head := UI.hbox(10)
	head.add_child(UI.icon(icon, 32))
	var t := UI.label(tr(title), "Heading")
	t.add_theme_color_override("font_color", Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var prize := PanelContainer.new()   # what a win pays
	prize.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0, 14, 4))
	var pr := UI.hbox(4)
	pr.add_child(UI.icon("res://assets/icons/syiling.png", 22))
	var pl := UI.label("+%d" % coins, "")
	pl.add_theme_color_override("font_color", UI.GOLD)
	pr.add_child(pl)
	prize.add_child(pr)
	prize.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prize.tooltip_text = tr("Syiling bila menang")
	head.add_child(prize)
	band.add_child(head)
	v.add_child(band)
	v.add_child(UI.margin(body, 16, 12, 16, 14))
	card.add_child(v)
	return card


## a choice in a row: light when off, coloured when picked
func _chip(text: String, on: bool, col: Color = GREEN, min_w := 0) -> Button:
	var b := UI.button(text, "", min_w)
	_paint_chip(b, on, col)
	return b


func _paint_chip(b: Button, on: bool, col: Color) -> void:
	var st := UI.sb(col if on else Color("e9dfc8"), col.darkened(0.35) if on else Color("c9b890"), 2, 8, 8)
	st.border_width_bottom = 4
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	var hover := st.duplicate() as StyleBoxFlat
	hover.bg_color = col.lightened(0.12) if on else Color("f3ead6")
	for s in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, hover)
	var fc := Color.WHITE if on else UI.INK
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fc)
	b.set_meta("chip_colour", col)


## a row of choices with its name and picture on the left
func _choice_row(icon: String, name_text: String) -> HBoxContainer:
	var row := UI.hbox(6)
	var tag := UI.hbox(6)
	tag.custom_minimum_size.x = 112
	tag.add_child(UI.icon(icon, 22))
	var l := UI.label(tr(name_text), "InkSmall")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(l)
	row.add_child(tag)
	return row


## Gelanggang Pesta Silat vs classmate bots: pick the teams and how tough
func _bot_card() -> Control:
	var c := UI.vbox(10)
	var top := UI.hbox(10)
	_faces = UI.hbox(4)
	_faces.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_faces)
	var how := UI.button(tr("Cara Main"), "Blue", 0)
	how.pressed.connect(_show_guide)
	how.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(how)
	c.add_child(top)
	var fmt := _choice_row("res://assets/icons/orang.png", "Pasukan")
	for f in BrawlRules.FORMATS:
		var b := _chip(f.replace("v", " lwn "), f == _format, GREEN, 96)
		b.pressed.connect(func():
			_format = f
			_pick(fmt, b)
			_show_faces())
		fmt.add_child(b)
	c.add_child(fmt)
	var lv := _choice_row("res://assets/icons/bintang.png", "Tahap")
	for l in BrawlRules.LEVELS:
		var b := _chip(BrawlRules.LEVELS[l]["name"], l == _level, LEVEL_COLOURS.get(l, GREEN), 122)
		b.pressed.connect(func():
			_level = l
			_pick(lv, b))
		lv.add_child(b)
	c.add_child(lv)
	# where to fight: the school hall, more places as Alif finishes each Bab
	_stage_row = _choice_row("res://assets/icons/peta.png", "Tempat")
	c.add_child(_stage_row)
	_show_stages()
	# which chapter the questions come from (only chapters the player has opened)
	var open := BattleRules.chapters_open()
	if not open.has(BattleRules.chapter) and BattleRules.chapter != 0:
		BattleRules.chapter = open[-1] if not open.is_empty() else 1
	if open.size() > 1:
		var ch_row := _choice_row("res://assets/icons/kitab.png", "Soalan")
		for n in open + [0]:
			var b := _chip(tr("Campur") if n == 0 else tr("Bab %d") % n, n == BattleRules.chapter, GREEN, 96)
			b.pressed.connect(func():
				BattleRules.chapter = n
				_pick(ch_row, b))
			ch_row.add_child(b)
		c.add_child(ch_row)
	c.add_child(UI.spacer(false))
	# both ways in on one row so they stay on screen without scrolling
	var go_row := UI.hbox(10)
	var go := UI.button("Masuk Gelanggang", "Primary", 0)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_stretch_ratio = 1.8
	go.custom_minimum_size.y = 58
	go.pressed.connect(func():
		Sfx.play("select")
		Game.goto("gelanggang", {"format": _format, "level": _level, "stage": str(Game.stage_def()["id"])}))
	go_row.add_child(go)
	# the plain quiz battle (no fighting) is still there for anyone who prefers it
	var quiz := UI.button("Kuiz Sahaja", "", 0)
	quiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiz.tooltip_text = tr("Kuiz pertarungan tanpa aksi")
	quiz.pressed.connect(func(): Game.goto("pertarungan", {"mode": "bot", "bots": maxi(BattleRules.MIN_FRIENDS, BrawlRules.FORMATS[_format][1])}))
	go_row.add_child(quiz)
	c.add_child(go_row)
	_show_faces()
	go.call_deferred("grab_focus")
	return _card(GREEN, "res://assets/icons/pedang.png", "Lawan Bot", BattleRules.COINS_BOTS, c)


## the same Cara Main as the Gelanggang pause menu
func _show_guide() -> void:
	Sfx.play("pop", -6.0)
	var cover := Control.new()
	UI.full(cover)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.add_child(UI.dim(0.6))
	var card := BrawlGuide.card("Faham!")
	var ok: Button = card.find_child("Ok", true, false)
	ok.pressed.connect(cover.queue_free)
	cover.add_child(UI.center(card))
	add_child(cover)
	ok.grab_focus()


func _pick(row: HBoxContainer, chosen: Button) -> void:
	Sfx.play("tick", -8.0)
	for b in row.get_children():
		if b is Button:  # skip the row's name
			_paint_chip(b, b == chosen, b.get_meta("chip_colour", GREEN))


## your team (you + allies) vs the other team, as heads
func _show_faces() -> void:
	for ch in _faces.get_children():
		ch.queue_free()
	var sizes: Array = BrawlRules.FORMATS[_format]
	var bots := Game.bot_roster(LocalBattle.BOTS)
	_faces.add_child(UI.head_icon(Game.battle_look(), 46))
	for i in int(sizes[0]) - 1:
		_faces.add_child(UI.head_icon(str(bots[i % bots.size()]["skin"]), 46))
	var vs := UI.label(" LWN ", "InkHeading")
	_faces.add_child(vs)
	for i in int(sizes[1]):
		_faces.add_child(UI.head_icon(str(bots[(i + int(sizes[0]) - 1) % bots.size()]["skin"]), 46))


## Pilih gelanggang: a picture of each place; locked ones are dark with a
## padlock and say which Bab opens them
func _show_stages() -> void:
	while _stage_row.get_child_count() > 1:
		var c := _stage_row.get_child(1)
		_stage_row.remove_child(c)
		c.queue_free()
	var chosen := str(Game.stage_def()["id"])
	for s in Game.stages():
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 68)
		b.theme_type_variation = "Primary" if s["id"] == chosen else ""
		b.tooltip_text = tr(str(s["name"])) if s["ok"] else str(s["why"])
		var pic := TextureRect.new()
		pic.texture = UI.tex(str(s["bg"]))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.position = Vector2(5, 5)
		pic.size = Vector2(120, 40)
		pic.clip_contents = true
		b.add_child(pic)
		var nm := UI.label(tr(str(s["name"])), "Small")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.position = Vector2(2, 44)
		nm.size = Vector2(126, 22)
		b.add_child(nm)
		if not s["ok"]:
			pic.modulate = Color(0.25, 0.25, 0.3)
			var lock := UI.icon("res://assets/icons/kunci.png", 28)
			lock.position = Vector2(51, 10)
			b.add_child(lock)
		b.pressed.connect(func():
			if not s["ok"]:
				Sfx.play("bump", -4.0)
				Game.toast(str(s["why"]), Color("ff9a8a"))
				return
			Sfx.play("select")
			Game.save["stage"] = str(s["id"])
			Game.persist()
			_show_stages())
		_stage_row.add_child(b)


## Pilih watak: one Alif card (a click drops down the outfits he owns) and
## the classmates whose memory Alif has brought back (locked ones show which
## Bab frees them)
func _show_fighters() -> void:
	for c in _fighter_row.get_children():
		c.queue_free()
	_fighter_row.add_child(UI.label(tr("Pilih watak:"), "Heading"))
	var look := Game.battle_look()
	var outfits: Array = []
	var friends: Array = []
	for f in Game.fighters():
		(outfits if str(f["name"]).begins_with("Alif · ") else friends).append(f)
	if not outfits.is_empty():
		# the card shows the outfit picked last (or the one he wears in the world)
		var alif: Dictionary = outfits[0]
		for f in outfits:
			if f["folder"] == look or (not _is_outfit(outfits, look) and f["folder"] == Game.skin_folder()):
				alif = f
		var b := _fighter_card(str(alif["folder"]), tr("Alif"), _is_outfit(outfits, look), true, str(alif["name"]))
		var more := TextureRect.new()   # it opens the outfit list
		more.texture = ControlHint.arrow("down", 18)
		more.position = Vector2(94, 6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(more)
		b.pressed.connect(func(): _outfit_menu(b, outfits, look))
		_fighter_row.add_child(b)
	for f in friends:
		var b := _fighter_card(str(f["folder"]), str(f["name"]), f["folder"] == look, f["ok"], str(f["name"]) if f["ok"] else str(f["why"]))
		b.pressed.connect(func():
			if not f["ok"]:
				Sfx.play("bump", -4.0)
				Game.toast(str(f["why"]), Color("ff9a8a"))
				return
			_pick_fighter(str(f["folder"])))
		_fighter_row.add_child(b)


func _is_outfit(outfits: Array, folder: String) -> bool:
	return outfits.any(func(f): return f["folder"] == folder)


func _fighter_card(folder: String, label: String, picked: bool, ok: bool, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 80)
	b.theme_type_variation = "Primary" if picked else ""
	b.tooltip_text = tip
	var col := UI.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.full(col)
	var head := UI.head_icon(folder, 50)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	var nm := UI.label(label, "Small")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	b.add_child(col)
	if not ok:
		head.modulate = Color(0, 0, 0, 0.75)  # a silhouette until Alif frees them
		var lock := UI.icon("res://assets/icons/kunci.png", 26)
		lock.position = Vector2(88, 4)
		b.add_child(lock)
	return b


func _pick_fighter(folder: String) -> void:
	Sfx.play("select")
	Game.set_fighter(folder)
	_show_fighters()
	_show_faces()


## the outfits Alif owns, in a small list under his card (click outside closes)
func _outfit_menu(card: Control, outfits: Array, look: String) -> void:
	Sfx.play("select", -6.0)
	var layer := Control.new()
	layer.name = "PilihPakaian"
	UI.full(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	var box := UI.panel()
	var col := UI.vbox(4)
	col.add_child(UI.label(tr("Pakaian Alif"), "Small"))
	for f in outfits:
		var row := Button.new()
		row.custom_minimum_size = Vector2(250, 52)
		row.theme_type_variation = "Primary" if f["folder"] == look else ""
		var h := UI.hbox(10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.full(h)
		var hm := UI.margin(UI.head_icon(str(f["folder"]), 40), 8, 0, 0, 0)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(hm)
		var nm := UI.label(str(f["name"]).get_slice(" · ", 1), "")
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(nm)
		row.add_child(h)
		var folder := str(f["folder"])
		row.pressed.connect(func():
			layer.queue_free()
			_pick_fighter(folder))
		col.add_child(row)
	box.add_child(col)
	layer.add_child(box)
	add_child(layer)
	# under the card, kept on screen
	await get_tree().process_frame
	if not is_instance_valid(box):
		return
	var r := card.get_global_rect()
	var vp := get_viewport_rect().size
	var pos := Vector2(r.position.x, r.end.y + 6)
	if pos.y + box.size.y > vp.y - 8:
		pos.y = r.position.y - box.size.y - 6
	pos.x = clampf(pos.x, 8, vp.x - box.size.x - 8)
	box.global_position = pos


# ------------------------------------------------------------------ friends (online)
## Main dengan Rakan: no friend list, just a room code of 6 digits. Open a
## room (and share the code), or type a friend's code to join theirs.
func _build_friends() -> void:
	for c in _right.get_children():
		c.queue_free()
	_room_box = null
	if not Backend.can_play_online():
		var off := UI.hbox(12)
		off.add_child(UI.icon("res://assets/icons/kunci.png", 40))
		var l := UI.label(tr("Perlu internet dan akaun e-mel."), "Ink", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		off.add_child(l)
		_right.add_child(off)
		var tip := UI.label(tr("Sementara itu, cuba Lawan Bot dulu!"), "InkSmall", true)
		_right.add_child(tip)
		var teach := UI.label(tr("Untuk guru: jalankan supabase/schema.sql dan supabase/multiplayer.sql di Supabase, kemudian isi config/backend.json."), "InkSmall", true)
		teach.add_theme_color_override("font_color", Color("8a7a60"))
		_right.add_child(teach)
		return
	if _room_code != "":
		_show_room()
		return
	var tiles := UI.hbox(12)
	# open a room
	var open_tile := _tile(Color("4f9a45"))
	var ov := UI.vbox(8)
	ov.add_child(_tile_title("res://assets/icons/kunci.png", "Buka Bilik"))
	ov.add_child(_tile_note("Dapat kod 6 nombor. Kongsi dengan rakan."))
	ov.add_child(UI.spacer(false))
	var create := UI.button("Buka Bilik", "Primary")
	create.custom_minimum_size.y = 54
	create.pressed.connect(_create_room)
	ov.add_child(create)
	open_tile.add_child(ov)
	tiles.add_child(open_tile)
	# join a room with its code
	var join_tile := _tile(BLUE)
	var jv := UI.vbox(8)
	jv.add_child(_tile_title("res://assets/icons/rakan.png", "Masuk Bilik"))
	var code := LineEdit.new()
	code.placeholder_text = "000000"
	code.max_length = 6
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code.add_theme_font_size_override("font_size", 34)
	code.custom_minimum_size.y = 58
	code.text_changed.connect(func(t: String):   # digits only
		var d := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				d += ch
		if d != t:
			code.text = d
			code.caret_column = d.length())
	jv.add_child(code)
	var join := UI.button("Sertai", "Blue")
	join.custom_minimum_size.y = 54
	join.pressed.connect(func(): _join_room(code.text))
	code.text_submitted.connect(func(_t): _join_room(code.text))
	jv.add_child(join)
	join_tile.add_child(jv)
	tiles.add_child(join_tile)
	_right.add_child(tiles)


func _tile(col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.sb(Color(col, 0.12), Color(col, 0.6), 2, 10, 12)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _tile_title(icon: String, text: String) -> HBoxContainer:
	var h := UI.hbox(8)
	h.add_child(UI.icon(icon, 28))
	h.add_child(UI.label(tr(text), "InkHeading"))
	return h


func _tile_note(text: String) -> Label:
	var l := UI.label(tr(text), "InkSmall", true)
	l.custom_minimum_size.x = 220
	return l


func _create_room() -> void:
	var code: String = await Backend.create_room()
	if code == "":
		Game.toast(tr("Tak dapat buka bilik. Cuba lagi."), Color("ff9a8a"))
		return
	_room_code = code
	var open := BattleRules.chapters_open()
	_room_cfg["chapter"] = open[-1] if not open.is_empty() else 1
	_cfg_sent = false
	_build_friends()
	_send_cfg()


func _join_room(code: String) -> void:
	code = code.strip_edges()
	if code.length() != 6:
		Game.toast(tr("Kod bilik ada 6 nombor."), Color("ff9a8a"))
		return
	var res: String = await Backend.join_room(code)
	if res != "ok":
		Game.toast(tr({"not_found": "Bilik tidak dijumpai.", "started": "Pertarungan sudah bermula.", "full": "Bilik penuh."}.get(res, "Gagal sertai bilik.")), Color("ff9a8a"))
		return
	_room_code = code.to_upper()
	_build_friends()


## in a room: the code big enough to read out, who is in, the host's settings
func _show_room() -> void:
	var head := UI.hbox(10)
	var digits := UI.hbox(5)
	for ch in _room_code:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.sb(UI.NAVY, BLUE, 2, 6, 4))
		box.custom_minimum_size = Vector2(44, 52)
		var d := UI.label(ch, "Title")
		d.add_theme_color_override("font_color", UI.GOLD)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(d)
		digits.add_child(box)
	head.add_child(digits)
	var what := UI.vbox(0)
	what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	what.add_child(UI.label(tr("KOD BILIK"), "InkHeading"))
	what.add_child(UI.label(tr("Kongsi dengan rakan"), "InkSmall"))
	head.add_child(what)
	var leave := UI.button(tr("Tutup"), "", 0)
	leave.tooltip_text = tr("Keluar dari bilik ini")
	leave.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func():
		_room_code = ""
		_build_friends())
	head.add_child(leave)
	_right.add_child(head)
	_room_box = UI.vbox(8)
	_right.add_child(_room_box)
	_cfg_box = UI.vbox(6)
	_right.add_child(_cfg_box)
	_room_foot = UI.hbox(10)
	_right.add_child(_room_foot)


## the host's settings: Bab, teams, bot level (bots only) and mode. Players
## who join see them as one line (_cfg_line), filled in by the room poll.
func _build_cfg(host: bool, s: Dictionary) -> void:
	if not is_instance_valid(_cfg_box):
		return
	for c in _cfg_box.get_children():
		c.queue_free()
	if not host:
		var line := UI.label(_cfg_line(s), "Ink", true)
		_cfg_box.add_child(line)
		return
	var bab := _choice_row("res://assets/icons/kitab.png", "Bab")
	for n in BattleRules.chapters_open():
		bab.add_child(_cfg_button(tr("Bab %d") % n, int(_room_cfg["chapter"]) == n, func(): _set_cfg("chapter", n)))
	_cfg_box.add_child(bab)
	var team := _choice_row("res://assets/icons/orang.png", "Pasukan")
	for t in TEAMS:
		team.add_child(_cfg_button(tr(TEAMS[t]), _room_cfg["team"] == t, func(): _set_cfg("team", t)))
	_cfg_box.add_child(team)
	if _room_cfg["team"] == "coop":
		var lv := _choice_row("res://assets/icons/bintang.png", "Tahap bot")
		for l in BrawlRules.LEVELS:
			lv.add_child(_cfg_button(tr(BrawlRules.LEVELS[l]["name"]), _room_cfg["bot_level"] == l, func(): _set_cfg("bot_level", l), LEVEL_COLOURS.get(l, GREEN)))
		_cfg_box.add_child(lv)
	var mode := _choice_row("res://assets/icons/pedang.png", "Mod")
	mode.add_child(_cfg_button(tr("Gelanggang"), _room_cfg["mode"] == "gelanggang", func(): _set_cfg("mode", "gelanggang")))
	mode.add_child(_cfg_button(tr("Kuiz"), _room_cfg["mode"] == "kuiz", func(): _set_cfg("mode", "kuiz")))
	_cfg_box.add_child(mode)
	if _room_cfg["mode"] == "gelanggang":
		# where: the host's own progress opens the places
		var place := _choice_row("res://assets/icons/peta.png", "Tempat")
		for s2 in Game.stages():
			var b := _cfg_button(tr(str(s2["name"])), _room_cfg["stage"] == s2["id"], func(): _set_cfg("stage", str(s2["id"])))
			if not s2["ok"]:   # a padlock only: the row stays inside the card
				b.text = ""
				b.icon = UI.tex("res://assets/icons/kunci.png")
				b.expand_icon = false
				b.tooltip_text = tr(str(s2["name"])) + ": " + str(s2["why"])
				b.pressed.disconnect(b.pressed.get_connections()[0]["callable"])
				b.pressed.connect(func():
					Sfx.play("bump", -4.0)
					Game.toast(str(s2["why"]), Color("ff9a8a")))
			place.add_child(b)
		_cfg_box.add_child(place)


func _cfg_button(text: String, on: bool, action: Callable, col: Color = BLUE) -> Button:
	var b := _chip(text, on, col)
	b.pressed.connect(action)
	return b


func _cfg_line(s: Dictionary) -> String:
	var line := tr("Bab %d") % int(s.get("chapter", 1)) + "  ·  " + tr(TEAMS.get(str(s.get("team", "pvp")), ""))
	if str(s.get("team", "")) == "coop":
		line += "  ·  " + tr("Bot %s") % tr(str(BrawlRules.LEVELS.get(str(s.get("bot_level", "mudah")), {}).get("name", "")))
	if str(s.get("game_mode", "kuiz")) == "gelanggang":
		var st := Game.stage_def(str(s.get("stage", "sekolah")))
		return line + "  ·  " + tr("Gelanggang") + " (" + tr(str(st["name"])) + ")"
	return line + "  ·  " + tr("Kuiz")


func _set_cfg(key: String, value) -> void:
	if _room_cfg[key] == value:
		return
	_room_cfg[key] = value
	Sfx.play("select", -6.0)
	_build_cfg(true, {})
	await _send_cfg()


func _send_cfg() -> void:
	var res := await Backend.set_room_options(_room_code, int(_room_cfg["chapter"]), str(_room_cfg["team"]), str(_room_cfg["bot_level"]),
		str(_room_cfg["mode"]), str(_room_cfg["stage"]))
	_cfg_sent = res == "ok"
	if res != "ok":
		Game.toast(tr("Tetapan bilik tidak disimpan. Pastikan pelayan sudah dikemas kini (patch_tetapan_bilik.sql)."), Color("ff9a8a"))


func _process(delta: float) -> void:
	if _room_code == "":
		return
	_poll_t += delta
	if _poll_t < 1.5 or _polling:
		return
	_poll_t = 0.0
	_polling = true
	var code := _room_code
	var s: Dictionary = await Backend.room_state(code)
	_polling = false
	if s.is_empty() or code != _room_code:
		return
	if str(s.get("status", "")) == "gelanggang":
		var humans: Array = s.get("players", []).filter(func(p): return not p.get("bot", false))
		Game.goto("gelanggang", {"online": true, "code": _room_code, "my_id": Backend.user_id,
			"host_id": str(s.get("host", "")), "players": humans, "team": str(s.get("team", "pvp")),
			"level": str(s.get("bot_level", "mudah")), "stage": str(s.get("stage", "sekolah")),
			"chapter": int(s.get("chapter", 1))})
		_room_code = ""
		return
	if str(s.get("status", "")) != "lobby":
		Game.goto("pertarungan", {"mode": "online", "code": _room_code})
		_room_code = ""
		return
	_render_room(s)


## who is in the room (their faces) and, for the host, Mula!
func _render_room(s: Dictionary) -> void:
	if _room_box == null or not is_instance_valid(_room_box):
		return
	var host: bool = str(s.get("host", "")) == Backend.user_id
	if is_instance_valid(_cfg_box) and (_cfg_box.get_child_count() == 0 or not host):
		_build_cfg(host, s)
	for c in _room_box.get_children():
		c.queue_free()
	var players: Array = s.get("players", []).filter(func(p): return not p.get("bot", false))
	var who := UI.hbox(8)
	var count := UI.label("%d / %d" % [players.size(), BattleRules.MAX_FRIENDS + 1], "InkHeading")
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(count)
	for p in players:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.sb(Color("e9dfc8"), Color("c9b890"), 2, 18, 4))
		var h := UI.hbox(4)
		h.add_child(UI.head_icon(str(p.get("skin", "alif")), 30))
		var n := UI.label(str(p["name"]), "InkSmall")
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
		if str(p.get("id", "")) == str(s.get("host", "")):
			h.add_child(UI.icon("res://assets/icons/mahkota.png", 20))
		chip.add_child(h)
		who.add_child(chip)
	_room_box.add_child(who)
	for c in _room_foot.get_children():
		c.queue_free()
	if host:
		var start := UI.button("Mula!", "Primary")
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.custom_minimum_size.y = 48
		# against each other: you + at least one more; as a team against bots: anyone
		var ready: bool = _cfg_sent and (players.size() >= 2 or _room_cfg["team"] != "pvp")
		start.disabled = not ready
		start.pressed.connect(func(): await Backend.start_battle(_room_code))
		_room_foot.add_child(start)
		if not ready and players.size() < 2 and _room_cfg["team"] == "pvp":
			var w := UI.label(tr("Tunggu rakan masuk..."), "InkSmall")
			w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_room_foot.add_child(w)
	else:
		_room_foot.add_child(UI.label(tr("Menunggu tuan bilik tekan Mula..."), "InkSmall"))
