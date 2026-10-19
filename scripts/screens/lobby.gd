extends Control
## Bilik Pertarungan hub (Arena Ulang Kaji). Two ways to play:
##  - Lawan Bot: you against 2-4 classmate bots, on this device, no internet.
##  - Main dengan Rakan: add friends by Player ID, open a room, share its code;
##    2-4 friends join and the host starts. Needs the online server
##    (Supabase, supabase/multiplayer.sql); offline it explains that.

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _bots: int = BattleRules.MIN_FRIENDS
var _bots_label: Label
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
	root.add_child(UI.header_bar("BILIK PERTARUNGAN", tr("Soalan Bab 1. Jawab betul, serang lawan. Yang terakhir berdiri menang %d syiling.") % BattleRules.REWARD_COINS))
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_bot_card())
	_right = UI.vbox(10)
	var friends := UI.panel("Glass")
	friends.custom_minimum_size = Vector2(560, 470)
	friends.add_child(_right)
	row.add_child(friends)
	root.add_child(row)
	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("« KEMBALI", "", 240)
	back.pressed.connect(func(): Game.goto("arka"))
	btns.add_child(back)
	var prof := UI.button("Profil & Kedai", "Blue", 240)
	prof.pressed.connect(func(): Game.main.open_profile())
	btns.add_child(prof)
	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(200, 60), " TETAPAN")
	st.pressed.connect(func(): Game.main.open_settings())
	btns.add_child(st)
	root.add_child(UI.margin(btns, 0, 0, 0, 20))
	add_child(root)
	_build_friends()


func _bot_card() -> Control:
	var card := UI.panel("Glass")
	card.custom_minimum_size = Vector2(500, 470)
	var c := UI.vbox(12)
	c.add_child(UI.label("LAWAN BOT", "InkHeading"))
	var d := UI.label("Latihan dengan rakan sekelas maya. Tiada internet diperlukan.", "Ink", true)
	d.custom_minimum_size.x = 440
	c.add_child(d)
	var faces := UI.hbox(6)
	for b in LocalBattle.BOTS:
		faces.add_child(UI.icon("res://assets/characters32/%s/%s_south.png" % [b["skin"], b["skin"]], 80))
	c.add_child(faces)
	c.add_child(UI.label("Bilangan lawan", "InkSmall"))
	var pick := UI.hbox(10)
	var minus := UI.button("-", "", 60)
	minus.pressed.connect(func(): _set_bots(_bots - 1))
	pick.add_child(minus)
	_bots_label = UI.label("", "InkHeading")
	_bots_label.custom_minimum_size.x = 60
	_bots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_child(_bots_label)
	var plus := UI.button("+", "", 60)
	plus.pressed.connect(func(): _set_bots(_bots + 1))
	pick.add_child(plus)
	c.add_child(pick)
	c.add_child(UI.spacer(false))
	var go := UI.button("MULA PERTARUNGAN", "Primary", 360)
	go.pressed.connect(func():
		Sfx.play("select")
		Game.goto("pertarungan", {"mode": "bot", "bots": _bots}))
	c.add_child(go)
	card.add_child(c)
	_set_bots(_bots)
	go.call_deferred("grab_focus")
	return card


func _set_bots(n: int) -> void:
	_bots = clampi(n, BattleRules.MIN_FRIENDS, BattleRules.MAX_FRIENDS)
	_bots_label.text = str(_bots)


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
