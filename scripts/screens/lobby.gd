extends Control
## Bilik Pertarungan hub (Arena Ulang Kaji). Two ways to play:
##  - Lawan Bot: you against 2-4 classmate bots, on this device, no internet.
##  - Main dengan Rakan: add friends by Player ID, open a room, share its code;
##    2-4 friends join and the host starts. Needs the online server
##    (Supabase, supabase/multiplayer.sql); offline it explains that.

const UI = preload("res://scripts/ui/ui.gd")
const BrawlGuide = preload("res://scripts/ui/brawl_guide.gd")

var params: Dictionary = {}
var _format := "1v1"
var _level := "mudah"  ## new players start easy
var _faces: HBoxContainer
var _right: VBoxContainer
var _room_code := ""
var _room_box: VBoxContainer
var _poll_t := 0.0
var _polling := false


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(true)
	MusicDirector.play("melaka")
	Game.context_hint = "Jawab betul untuk serang pemain yang kau pilih. Yang terakhir berdiri menang 20 syiling!"
	add_child(UI.bg_image("res://assets/backgrounds/bg_zon1_3_balai_penghadapan.png", Color(0.6, 0.55, 0.58)))
	var root := UI.vbox(12)
	UI.full(root)
	root.add_child(UI.header_bar("BILIK PERTARUNGAN", tr("Jawab betul, serang lawan. Yang terakhir berdiri menang %d syiling.") % BattleRules.REWARD_COINS))
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_bot_card())
	_right = UI.vbox(10)
	var friends := UI.panel("Glass")
	friends.custom_minimum_size = Vector2(560, 0)
	friends.add_child(_right)
	row.add_child(friends)
	# the two cards scroll when big text makes them taller than the screen;
	# the button row below stays put so KEMBALI is always reachable
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	root.add_child(scroll)
	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("« KEMBALI", "", 240)
	back.pressed.connect(func(): Game.goto("arka"))
	btns.add_child(back)
	var prof := UI.button("Profil & Kedai", "Blue", 240)
	prof.pressed.connect(func(): Game.main.open_profile())
	btns.add_child(prof)
	var papan := UI.button("Papan Markah", "", 220)
	papan.pressed.connect(func(): Game.main.open_papan())
	btns.add_child(papan)
	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(200, 60), " TETAPAN")
	st.pressed.connect(func(): Game.main.open_settings())
	btns.add_child(st)
	root.add_child(UI.margin(btns, 0, 0, 0, 14))
	add_child(root)
	_build_friends()


## Gelanggang Pesta Silat vs classmate bots: pick the teams and how tough
func _bot_card() -> Control:
	var card := UI.panel("Glass")
	card.custom_minimum_size = Vector2(580, 0)
	var c := UI.vbox(8)
	var head := UI.hbox(10)
	var ht := UI.label("GELANGGANG PESTA SILAT", "InkHeading")
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	var how := UI.button(tr("Cara main"), "Blue", 0)
	how.pressed.connect(_show_guide)
	head.add_child(how)
	c.add_child(head)
	var d := UI.label("Jawab betul untuk dapat semangat dan senjata sekolah, kemudian bertarung! Tiada internet diperlukan.", "Ink", true)
	d.custom_minimum_size.x = 530
	c.add_child(d)
	_faces = UI.hbox(4)
	c.add_child(_faces)
	var fmt := UI.hbox(6)
	fmt.add_child(_row_label("Pasukan"))
	for f in BrawlRules.FORMATS:
		var b := UI.button(f.replace("v", " lwn "), "", 100)
		b.pressed.connect(func():
			_format = f
			_pick(fmt, b)
			_show_faces())
		b.theme_type_variation = "Primary" if f == _format else ""
		fmt.add_child(b)
	c.add_child(fmt)
	var lv := UI.hbox(6)
	lv.add_child(_row_label("Tahap lawan"))
	for l in BrawlRules.LEVELS:
		var b := UI.button(BrawlRules.LEVELS[l]["name"], "", 130)
		b.pressed.connect(func():
			_level = l
			_pick(lv, b))
		b.theme_type_variation = "Primary" if l == _level else ""
		lv.add_child(b)
	c.add_child(lv)
	# which chapter the questions come from (only chapters the player has opened)
	var open := BattleRules.chapters_open()
	if not open.has(BattleRules.chapter) and BattleRules.chapter != 0:
		BattleRules.chapter = open[-1] if not open.is_empty() else 1
	if open.size() > 1:
		var ch_row := UI.hbox(6)
		ch_row.add_child(_row_label("Soalan"))
		for n in open + [0]:
			var b := UI.button(tr("Campur") if n == 0 else tr("Bab %d") % n, "", 110)
			b.pressed.connect(func():
				BattleRules.chapter = n
				_pick(ch_row, b))
			b.theme_type_variation = "Primary" if n == BattleRules.chapter else ""
			ch_row.add_child(b)
		c.add_child(ch_row)
	c.add_child(UI.spacer(false))
	# both ways in on one row so they stay on screen without scrolling
	var go_row := UI.hbox(10)
	var go := UI.button("MASUK GELANGGANG", "Primary", 290)
	go.pressed.connect(func():
		Sfx.play("select")
		Game.goto("gelanggang", {"format": _format, "level": _level}))
	go_row.add_child(go)
	# the plain quiz battle (no fighting) is still there for anyone who prefers it
	var quiz := UI.button("Kuiz sahaja", "", 0)
	quiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiz.tooltip_text = tr("Kuiz pertarungan tanpa aksi")
	quiz.pressed.connect(func(): Game.goto("pertarungan", {"mode": "bot", "bots": maxi(BattleRules.MIN_FRIENDS, BrawlRules.FORMATS[_format][1])}))
	go_row.add_child(quiz)
	c.add_child(go_row)
	card.add_child(c)
	_show_faces()
	go.call_deferred("grab_focus")
	return card


## the name of a row of choices, beside it (not above) so the card stays short
func _row_label(text: String) -> Label:
	var l := UI.label(text, "InkSmall", true)
	l.custom_minimum_size.x = 100
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


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
		if b is Button:  # skip the row's name label
			b.theme_type_variation = "Primary" if b == chosen else ""


## your team (you + allies) vs the other team, as heads
func _show_faces() -> void:
	for ch in _faces.get_children():
		ch.queue_free()
	var sizes: Array = BrawlRules.FORMATS[_format]
	_faces.add_child(UI.head_icon(Game.skin_folder(), 60))
	for i in int(sizes[0]) - 1:
		_faces.add_child(UI.head_icon(str(LocalBattle.BOTS[i]["skin"]), 60))
	var vs := UI.label(" LWN ", "InkHeading")
	_faces.add_child(vs)
	for i in int(sizes[1]):
		_faces.add_child(UI.head_icon(str(LocalBattle.BOTS[(i + int(sizes[0]) - 1) % LocalBattle.BOTS.size()]["skin"]), 60))


# ------------------------------------------------------------------ friends (online)
func _build_friends() -> void:
	for c in _right.get_children():
		c.queue_free()
	_right.add_child(UI.label("MAIN DENGAN RAKAN", "InkHeading"))
	var id_row := UI.hbox(8)
	id_row.add_child(UI.label("ID Pemain kau:", "Ink"))
	var idl := UI.label(str(Game.save["player_id"]), "InkHeading")
	id_row.add_child(idl)
	_right.add_child(id_row)
	if not Backend.can_play_online():
		var off := UI.label(tr("Mod ini perlukan pelayan dalam talian dan akaun yang log masuk dengan e-mel. Buat masa ini, cuba Lawan Bot dulu!") + "\n\n" + tr("Untuk guru: jalankan supabase/schema.sql dan supabase/multiplayer.sql di Supabase, kemudian isi config/backend.json."), "Ink", true)
		off.custom_minimum_size.x = 500
		_right.add_child(off)
		return
	# add a friend
	var add_row := UI.hbox(8)
	var code := LineEdit.new()
	code.placeholder_text = tr("ID rakan (6 aksara)")
	code.max_length = 6
	code.custom_minimum_size.x = 260
	add_row.add_child(code)
	var add := UI.button("Tambah rakan", "Blue")
	var status := UI.label("", "InkSmall", true)
	add.pressed.connect(func():
		var res: String = await Backend.add_friend(code.text)
		status.text = tr({"accepted": "Kini berkawan!", "pending": "Permintaan dihantar. Minta rakan tambah ID kau juga.",
			"not_found": "ID tidak dijumpai.", "self": "Itu ID kau sendiri."}.get(res, "Gagal. Cuba lagi."))
		_load_friends())
	add_row.add_child(add)
	_right.add_child(add_row)
	_right.add_child(status)
	var list := UI.vbox(4)
	list.name = "List"
	_right.add_child(list)
	_load_friends()
	# rooms
	var rooms := UI.hbox(8)
	var create := UI.button("Buka bilik", "Primary")
	create.pressed.connect(_create_room)
	rooms.add_child(create)
	var join_code := LineEdit.new()
	join_code.placeholder_text = tr("Kod bilik")
	join_code.max_length = 6
	join_code.custom_minimum_size.x = 160
	rooms.add_child(join_code)
	var join := UI.button("Sertai")
	join.pressed.connect(func(): _join_room(join_code.text))
	rooms.add_child(join)
	_right.add_child(rooms)
	_room_box = UI.vbox(4)
	_right.add_child(_room_box)


func _load_friends() -> void:
	var list: VBoxContainer = _right.get_node_or_null("List")
	if list == null:
		return
	for c in list.get_children():
		c.queue_free()
	var friends: Array = await Backend.my_friends()
	if friends.is_empty():
		list.add_child(UI.label(tr("Belum ada rakan. Tukar ID dengan kawan sekelas."), "InkSmall"))
	for f in friends:
		var st: String = {"accepted": "", "outgoing": tr("  (menunggu)"), "incoming": tr("  (tambah ID dia untuk terima)")}.get(str(f["status"]), "")
		list.add_child(UI.label("%s  ·  %s%s" % [str(f["name"]), str(f["code"]), st], "Ink"))


func _create_room() -> void:
	_room_code = await Backend.create_room()
	_show_room()


func _join_room(code: String) -> void:
	var res: String = await Backend.join_room(code)
	if res != "ok":
		Game.toast(tr({"not_found": "Bilik tidak dijumpai.", "started": "Pertarungan sudah bermula.", "not_friends": "Kau perlu berkawan dengan tuan bilik dulu.", "full": "Bilik penuh."}.get(res, "Gagal sertai bilik.")), Color("ff9a8a"))
		return
	_room_code = code.strip_edges().to_upper()
	_show_room()


func _show_room() -> void:
	if _room_code == "":
		return
	for c in _room_box.get_children():
		c.queue_free()
	_room_box.add_child(UI.label(tr("Kod bilik: %s  (kongsi dengan rakan)") % _room_code, "InkHeading"))


func _process(delta: float) -> void:
	if _room_code == "":
		return
	_poll_t += delta
	if _poll_t < 1.5 or _polling:
		return
	_poll_t = 0.0
	_polling = true
	var s: Dictionary = await Backend.room_state(_room_code)
	_polling = false
	if s.is_empty():
		return
	if str(s.get("status", "")) != "lobby":
		Game.goto("pertarungan", {"mode": "online", "code": _room_code})
		_room_code = ""
		return
	for c in _room_box.get_children():
		if c != _room_box.get_child(0):
			c.queue_free()
	var players: Array = s.get("players", [])
	_room_box.add_child(UI.label(tr("Pemain: %d / %d") % [players.size(), BattleRules.MAX_FRIENDS + 1], "Ink"))
	for p in players:
		_room_box.add_child(UI.label("·  " + str(p["name"]), "Ink"))
	if str(s.get("host", "")) == Backend.user_id:
		var start := UI.button("Mula!", "Primary")
		start.disabled = players.size() < BattleRules.MIN_FRIENDS + 1
		start.pressed.connect(func(): await Backend.start_battle(_room_code))
		_room_box.add_child(start)
