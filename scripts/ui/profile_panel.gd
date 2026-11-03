extends "res://scripts/ui/modal.gd"
## Profil & Kedai: the player's card (display name, Player ID for adding
## friends, negeri for Papan Markah, motto, stats) and the skin shop. The
## profile picture is the head of the outfit being worn. Skins are Alif's
## outfits (data/skins.json), bought with syiling and worn in the world.
## Kawan: the friends list (online accounts), and adding a friend by Player ID.

var start_tab: int = 0
var _tab: int = 0
var _body: VBoxContainer
var _tab_row: HBoxContainer
var _coins: Label
var _preview: TextureRect
var _preview_frames: Array[Texture2D] = []
var _t: float = 0.0


func _init() -> void:
	title_text = "PROFIL & KEDAI"
	panel_size = Vector2(1210, 650)


func _build() -> void:
	var top := UI.hbox(8)
	_tab_row = UI.hbox(8)
	for i in 3:
		var b := UI.button(["Profil", "Kedai Skin", "Kawan"][i], "", 200)
		b.pressed.connect(_show.bind(i))
		_tab_row.add_child(b)
	top.add_child(_tab_row)
	top.add_child(UI.spacer())
	top.add_child(UI.icon("res://assets/icons/syiling.png", 32))
	_coins = UI.label("", "Heading")
	top.add_child(_coins)
	content.add_child(top)
	_body = UI.vbox(12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	Game.stats_changed.connect(_refresh_coins)
	_refresh_coins()
	_show(start_tab)


func _refresh_coins() -> void:
	if is_instance_valid(_coins):
		_coins.text = str(int(Game.save["coins"]))


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_preview) and not _preview_frames.is_empty():
		_preview.texture = _preview_frames[int(_t * 8.0) % _preview_frames.size()]


func _show(i: int) -> void:
	_tab = i
	for j in _tab_row.get_child_count():
		(_tab_row.get_child(j) as Button).theme_type_variation = "Primary" if j == i else ""
	for c in _body.get_children():
		c.queue_free()
	_preview = null
	if i == 0:
		_profile()
	elif i == 1:
		_shop()
	else:
		_friends()


## walking-south frames of a skin, for previews
func _walk_frames(folder: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var f := CharacterFrames.build(folder, true)
	for n in f.get_frame_count("walk_south"):
		out.append(f.get_frame_texture("walk_south", n))
	if out.is_empty():
		out.append(f.get_frame_texture("idle_south", 0))
	return out


# ------------------------------------------------------------------ profile
func _profile() -> void:
	var p: Dictionary = Game.save["profile"]
	var row := UI.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# left: Alif in the equipped skin
	var left := UI.panel("Slot")
	left.custom_minimum_size = Vector2(300, 0)
	var lc := UI.vbox(6)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(260, 260)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_frames = _walk_frames(Game.skin_folder())
	lc.add_child(_preview)
	var sk := UI.label(str(Game.skin_def(str(Game.save["skin"]))["name"]), "Heading")
	sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lc.add_child(sk)
	var change := UI.button("Tukar pakaian", "Blue")
	change.pressed.connect(_show.bind(1))
	lc.add_child(change)
	left.add_child(lc)
	row.add_child(left)

	# right: details
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(UI.label("Nama paparan"))
	var name_e := LineEdit.new()
	name_e.text = str(p.get("display_name", p["username"]))
	name_e.max_length = 16
	name_e.custom_minimum_size.x = 360
	name_e.text_changed.connect(func(t: String):
		if t.strip_edges() != "":
			p["display_name"] = t.strip_edges()
			Game.persist()
			Game.stats_changed.emit())
	grid.add_child(name_e)
	grid.add_child(UI.label("ID Pemain"))
	var id_row := UI.hbox(8)
	var idl := UI.label(str(Game.save["player_id"]), "Heading")
	idl.add_theme_font_size_override("font_size", 30)
	id_row.add_child(idl)
	var copy := UI.button("Salin")
	copy.tooltip_text = tr("Beri ID ini kepada rakan supaya mereka boleh tambah kau.")
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(str(Game.save["player_id"]))
		Game.toast(tr("ID disalin")))
	id_row.add_child(copy)
	grid.add_child(id_row)
	grid.add_child(UI.label("Moto"))
	var motto := LineEdit.new()
	motto.text = str(p.get("motto", ""))
	motto.placeholder_text = tr("Contoh: Sejarah? Boleh!")
	motto.max_length = 40
	motto.text_changed.connect(func(t: String):
		p["motto"] = t
		Game.persist())
	grid.add_child(motto)
	grid.add_child(UI.label("Negeri"))
	var neg := OptionButton.new()
	neg.custom_minimum_size = Vector2(360, 52)
	neg.add_item(tr("(Pilih negeri)"))
	for n in Game.NEGERI:
		neg.add_item(n)
	neg.selected = Game.NEGERI.find(str(p.get("negeri", ""))) + 1
	neg.item_selected.connect(func(i: int):
		p["negeri"] = Game.NEGERI[i - 1] if i > 0 else ""
		Game.persist()
		Sfx.play("select"))
	grid.add_child(neg)
	grid.add_child(UI.label("Gambar profil"))
	var pic_row := UI.hbox(10)
	var pic := UI.panel("Slot")
	pic.add_child(UI.head_icon(Game.skin_folder(), 64))
	pic_row.add_child(pic)
	var pn := UI.label("Ikut pakaian yang kau pakai.", "Small", true)
	pn.custom_minimum_size.x = 280
	pn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic_row.add_child(pn)
	grid.add_child(pic_row)
	right.add_child(grid)

	var stats := UI.hbox(10)
	var done := 0
	for z in Game.ZONES:
		if Game.zone_done(z):
			done += 1
	var battle: Dictionary = Game.save.get("battle", {})
	for s in [
		[tr("Tahap"), str(int(Game.save["level"]))],
		[tr("Misi siap"), "%d / %d" % [done, Game.ZONES.size()]],
		[tr("Pertarungan menang"), "%d / %d" % [int(battle.get("wins", 0)), int(battle.get("played", 0))]],
		[tr("Pakaian"), "%d / %d" % [Game.save["skins_owned"].size(), Game.skins().size()]],
	]:
		var box := UI.panel("Slot")
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bc := UI.vbox(0)
		var v := UI.label(s[1], "Heading")
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bc.add_child(v)
		var k := UI.label(s[0], "Small")
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bc.add_child(k)
		box.add_child(bc)
		stats.add_child(box)
	right.add_child(stats)
	row.add_child(right)
	_body.add_child(row)


# ------------------------------------------------------------------ friends
var _friend_list: VBoxContainer
var _friend_count: Label
var _friends_call := 0


func _friends() -> void:
	if not Backend.can_play_online():
		var box := UI.panel("Slot")
		var msg := UI.label(tr("Senarai kawan perlukan akaun dalam talian. Log masuk dengan akaun untuk tambah kawan dan main sama-sama di Arena Quiz.") if Backend.is_online()
			else tr("Senarai kawan perlukan sambungan ke pelayan dalam talian."), "", true)
		msg.custom_minimum_size.x = 900
		box.add_child(msg)
		_body.add_child(box)
		return
	var add_row := UI.hbox(10)
	add_row.add_child(UI.label(tr("Tambah kawan:"), "Heading"))
	var code := LineEdit.new()
	code.placeholder_text = tr("ID kawan (6 aksara)")
	code.set_meta("typing_label", "ID kawan")
	code.max_length = 6
	code.custom_minimum_size.x = 280
	add_row.add_child(code)
	var add := UI.button("Tambah", "Blue")
	add_row.add_child(add)
	add_row.add_child(UI.spacer())
	var mine := UI.label(tr("ID kau: %s") % str(Game.save["player_id"]), "Heading")
	add_row.add_child(mine)
	_body.add_child(add_row)
	var status := UI.label("", "Small", true)
	_body.add_child(status)
	add.pressed.connect(func():
		if code.text.strip_edges().length() < 6:
			status.text = tr("ID kawan ada 6 aksara.")
			return
		add.disabled = true
		var res: String = await Backend.add_friend(code.text)
		add.disabled = false
		status.text = tr({"accepted": "Kini berkawan!", "pending": "Permintaan dihantar.",
			"not_found": "ID tidak dijumpai. Semak semula dengan kawan kau.", "self": "Itu ID kau sendiri."}.get(res, "Gagal. Semak sambungan internet dan cuba lagi."))
		if res == "accepted" or res == "pending":
			code.text = ""
			Sfx.play("chime", -6.0)
		_load_friend_list())
	_friend_count = UI.label(tr("Kawan"), "Heading")
	_body.add_child(_friend_count)
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_friend_list = UI.vbox(8)
	_friend_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_friend_list)
	_body.add_child(scroll)
	_friend_list.add_child(UI.label(tr("Memuatkan senarai kawan..."), "Small"))
	_load_friend_list()
	# the ID shown must be the server's (friends search for that one)
	await Backend.sync_player_code()
	if is_instance_valid(mine):
		mine.text = tr("ID kau: %s") % str(Game.save["player_id"])


func _load_friend_list() -> void:
	_friends_call += 1
	var call := _friends_call
	var friends: Array = await Backend.my_friends()
	if call != _friends_call or not is_instance_valid(_friend_list):
		return  # a newer load or the tab was closed
	for c in _friend_list.get_children():
		c.queue_free()
	var accepted := friends.filter(func(f): return str(f.get("status", "")) == "accepted")
	_friend_count.text = tr("Kawan (%d)") % accepted.size()
	if friends.is_empty():
		_friend_list.add_child(UI.label(tr("Belum ada kawan. Minta ID Pemain kawan sekelas kau, kemudian tambah di atas."), "", true))
		return
	friends.sort_custom(func(a, b): return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower())
	for f in friends:
		_friend_list.add_child(_friend_row(f))


func _friend_row(f: Dictionary) -> Control:
	var card := UI.panel("Slot")
	var r := UI.hbox(14)
	r.add_child(UI.icon("res://assets/icons/orang.png", 44))
	var c := UI.vbox(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(UI.label(str(f.get("name", "?")), "Heading"))
	c.add_child(UI.label(tr("ID: %s") % str(f.get("code", "")), "Small"))
	r.add_child(c)
	var st := str(f.get("status", ""))
	if st != "accepted":
		r.add_child(UI.label(tr("menunggu") if st == "outgoing" else tr("mahu berkawan"), "Small"))
	card.add_child(r)
	return card


# ------------------------------------------------------------------ shop
func _shop() -> void:
	var hint := UI.label("Kumpul syiling dengan menyelesaikan misi dan menang pertarungan. Pakaian hanya untuk gaya, bukan kuasa.", "Small", true)
	_body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for s in Game.skins():
		grid.add_child(_skin_card(s))
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_body.add_child(scroll)


func _skin_card(s: Dictionary) -> Control:
	var id := str(s["id"])
	var owned: bool = Game.save["skins_owned"].has(id)
	var worn: bool = str(Game.save["skin"]) == id
	var card := PanelContainer.new()
	card.theme_type_variation = "SlotGood" if worn else ("Slot" if owned else "SlotHot")
	card.custom_minimum_size = Vector2(366, 0)
	var row := UI.hbox(10)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(96, 110)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var folder := str(s["folder"])
	var path := "res://assets/characters32/%s/%s_south.png" % [folder, folder]
	pic.texture = UI.tex(path) if ResourceLoader.exists(path) else UI.tex("res://assets/icons/kunci.png")
	row.add_child(pic)
	var col := UI.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(str(s["name"]), "Heading", true)
	nm.custom_minimum_size.x = 220
	col.add_child(nm)
	var info := UI.label(str(s.get("info", "")), "Small", true)
	info.custom_minimum_size.x = 220
	col.add_child(info)
	var btn: Button
	if worn:
		btn = UI.button("Sedang dipakai")
		btn.disabled = true
	elif owned:
		btn = UI.button("Pakai", "Primary")
		btn.pressed.connect(func():
			Game.equip_skin(id)
			Sfx.play("pop")
			_show(1))
	else:
		var price := int(s["price"])
		btn = UI.button(tr("Beli: %d syiling") % price, "Blue")
		btn.icon = UI.tex("res://assets/icons/syiling.png")
		btn.expand_icon = false
		btn.pressed.connect(func():
			var err := Game.buy_skin(id)
			if err != "":
				Sfx.play("bump")
				Game.toast(err, Color("ff9a8a"))
				return
			MusicDirector.stinger("st_item")
			Game.toast(tr("Dapat pakaian baharu: %s!") % str(s["name"]))
			Game.equip_skin(id)
			_show(1))
	col.add_child(btn)
	row.add_child(col)
	card.add_child(row)
	return card
