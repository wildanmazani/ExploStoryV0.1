extends Control
## Bilik Pertarungan: the battle. The players stand on a stage at the top,
## big, with their HP under them (tap one to make it your target), the shared question below. Answer right to hit your target;
## the last player standing wins. params: {"mode": "bot", "bots": 2..4} or
## {"mode": "online", "code": "ABC123"} (online needs Supabase, see Backend).

const UI = preload("res://scripts/ui/ui.gd")
const LETTERS := ["A", "B", "C", "D"]

var params: Dictionary = {}
var battle: Node
var _cards := {}        ## player id -> Fighter
var _cards_row: HBoxContainer
var _round: Label
var _timer: ProgressBar
var _q: Label
var _buttons: Array[Button] = []
var _info: Label
var _last_status := ""
var _last_round := -1
var _result: Control


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("melaka")
	MusicDirector.puzzle(true)
	add_child(UI.bg_image("res://assets/backgrounds/bg_zon1_3_balai_penghadapan.png", Color(0.45, 0.42, 0.5)))
	var root := UI.vbox(10)
	UI.full(root)
	var top := UI.hbox(14)
	_round = UI.label("", "Heading")
	top.add_child(_round)
	_timer = ProgressBar.new()
	_timer.show_percentage = false
	_timer.max_value = BattleRules.ROUND_TIME
	_timer.custom_minimum_size = Vector2(0, 18)
	_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_timer)
	var out := UI.button("Keluar")
	out.pressed.connect(_leave)
	top.add_child(out)
	root.add_child(UI.margin(top, 24, 14, 24, 0))
	_cards_row = UI.hbox(24)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_cards_row)

	# question, answers and the explanation share whatever height the stage
	# leaves; with big text or a long explanation this scrolls instead of
	# pushing the bottom row of answers off the screen
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lower := UI.vbox(8)
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lower)
	root.add_child(scroll)
	var qp := UI.panel("Paper")
	var qrow := UI.hbox(10)
	_q = UI.label("", "InkHeading", true)
	_q.custom_minimum_size.x = 1080
	_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_q)
	var sp := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(60, 52))
	sp.tooltip_text = "Baca soalan"
	sp.pressed.connect(func(): Tts.speak(_q.text))
	qrow.add_child(sp)
	qp.add_child(qrow)
	lower.add_child(UI.margin(qp, 24, 0, 24, 0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	for i in 4:
		var b := UI.button("")
		b.custom_minimum_size = Vector2(610, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_answer.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	lower.add_child(UI.center(grid))
	_info = UI.label("", "", true)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.custom_minimum_size.x = 1200
	lower.add_child(UI.margin(UI.center(_info), 0, 0, 0, 12))
	add_child(root)

	if str(params.get("mode", "bot")) == "online":
		battle = OnlineBattle.new()
		add_child(battle)
		battle.state_changed.connect(_on_state)
		battle.join(str(params.get("code", "")))
	else:
		battle = LocalBattle.new()
		add_child(battle)
		battle.setup(int(params.get("bots", BattleRules.MIN_FRIENDS)))
		battle.state_changed.connect(_on_state)
		battle.start()


func _process(_d: float) -> void:
	if battle and battle.state.has("time_left"):
		_timer.value = float(battle.state["time_left"])


# ------------------------------------------------------------------ fighters
func _build_cards(players: Array) -> void:
	for c in _cards_row.get_children():
		c.queue_free()
	_cards.clear()
	for p in players:
		var f := Fighter.new()
		f.setup(p)
		var pid := str(p["id"])
		f.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_pick_target(pid))
		if not p.get("me", false):
			f.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			f.tooltip_text = tr("Ketik untuk jadikan sasaran")
		_cards_row.add_child(f)
		_cards[pid] = f


func _pick_target(id: String) -> void:
	if id == battle.my_id:
		return
	battle.set_target(id)
	Sfx.play("select", -6.0)


func _refresh_cards(s: Dictionary) -> void:
	var me: Dictionary = battle.me()
	for p in s["players"]:
		var f: Fighter = _cards.get(str(p["id"]))
		if f == null:
			continue
		var is_target: bool = me.get("alive", false) and str(me.get("target", "")) == str(p["id"])
		var status := ""
		if not p["alive"]:
			status = tr("TERSINGKIR")
		elif s["status"] == "question" and p.get("answered", false):
			status = tr("sudah jawab")
		f.show_state(int(p["hp"]), p["alive"], is_target, status)


## One player on the battle stage: a name tag, Alif or a classmate drawn big
## and standing on a ring (gold = you, red = your target), the HP bar under
## the feet and a status line. Hits flash red and knock back; knocked-out
## players fall over.
class Fighter extends VBoxContainer:
	const UI = preload("res://scripts/ui/ui.gd")
	const SPRITE := 112.0

	var me := false
	var alive := true
	var target := false
	var _name: Label
	var _tag: Label
	var _stage: Control
	var _sprite: TextureRect
	var _hp: ProgressBar
	var _hp_label: Label
	var _status: Label
	var _t := randf() * TAU
	var _hp_value := -1

	func setup(p: Dictionary) -> void:
		me = p.get("me", false)
		custom_minimum_size = Vector2(210, 0)
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 2)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_tag = UI.label("", "Small")
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tag.add_theme_color_override("font_color", Color("ff8a7a"))
		_tag.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
		_tag.add_theme_constant_override("outline_size", 5)
		add_child(_tag)
		_name = UI.label(str(p["name"]) + (tr(" (kau)") if me else ""), "Heading")
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.clip_text = true
		_name.custom_minimum_size.x = 200
		_name.add_theme_font_size_override("font_size", 24)
		_name.add_theme_color_override("font_color", UI.GOLD if me else Color.WHITE)
		_name.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
		_name.add_theme_constant_override("outline_size", 6)
		add_child(_name)
		_stage = Control.new()
		_stage.custom_minimum_size = Vector2(200, SPRITE + 4)
		_stage.draw.connect(_draw_ring)
		add_child(_stage)
		var folder := str(p.get("skin", "alif"))
		_sprite = UI.icon("res://assets/characters32/%s/%s_south.png" % [folder, folder], SPRITE)
		_sprite.size = Vector2(SPRITE, SPRITE)
		_sprite.pivot_offset = Vector2(SPRITE / 2.0, SPRITE * 0.9)
		_stage.add_child(_sprite)
		_hp = ProgressBar.new()
		_hp.theme_type_variation = "Good"
		_hp.max_value = BattleRules.HP
		_hp.value = BattleRules.HP
		_hp.show_percentage = false
		_hp.custom_minimum_size = Vector2(180, 20)
		_hp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_hp)
		_hp_label = UI.label("", "Small")
		_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_hp_label)
		_status = UI.label(" ", "Small")
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_status)
		for c in [_tag, _name, _stage, _sprite, _hp, _hp_label, _status]:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS

	func show_state(hp: int, is_alive: bool, is_target: bool, status: String) -> void:
		if hp != _hp_value:
			_hp_value = hp
			create_tween().tween_property(_hp, "value", float(hp), 0.4)
			_hp.theme_type_variation = "Good" if hp > 50 else ("Warn" if hp > 25 else "")
			_hp_label.text = "HP %d" % hp
		target = is_target and is_alive
		_tag.text = tr("SASARAN") if target else " "
		_status.text = status if status != "" else " "
		_status.add_theme_color_override("font_color", Color("ff8a7a") if not is_alive else Color("9fe8a0"))
		if alive and not is_alive:
			_fall()
		alive = is_alive
		_stage.queue_redraw()

	## where the damage number pops up (screen space)
	func head_position() -> Vector2:
		return _sprite.global_position + Vector2(SPRITE / 2.0, 10)

	func hit() -> void:
		_sprite.modulate = Color(1, 0.3, 0.3)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE if alive else Color(0.5, 0.5, 0.5, 0.6), 0.35)
		var k := create_tween()
		for i in 4:
			k.tween_property(_sprite, "position:x", _base_x() + (10.0 if i % 2 == 0 else -10.0), 0.04)
		k.tween_property(_sprite, "position:x", _base_x(), 0.05)

	func _fall() -> void:
		var t := create_tween().set_parallel()
		t.tween_property(_sprite, "rotation_degrees", 90.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(_sprite, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.45)
		t.tween_property(_name, "modulate:a", 0.5, 0.45)

	func _base_x() -> float:
		return (_stage.size.x - SPRITE) / 2.0

	func _process(delta: float) -> void:
		_t += delta
		if alive:  # breathing
			_sprite.position.y = 2.0 - absf(sin(_t * 2.2)) * 3.0
		else:
			_sprite.position.y = 16.0
		if _sprite.rotation_degrees == 0.0 and not _shaking():
			_sprite.position.x = _base_x()
		if target:
			_stage.queue_redraw()

	func _shaking() -> bool:
		return absf(_sprite.position.x - _base_x()) > 0.5 and _sprite.modulate.g < 0.99

	func _draw_ring() -> void:
		var c := Vector2(_stage.size.x / 2.0, SPRITE * 0.9)
		_stage.draw_set_transform(c, 0, Vector2(1, 0.32))
		_stage.draw_circle(Vector2.ZERO, SPRITE * 0.39, Color(0, 0, 0, 0.35))
		var col := Color(0, 0, 0, 0)
		if not alive:
			col = Color(0.5, 0.5, 0.5, 0.5)
		elif target:
			col = Color(1, 0.35, 0.3, 0.6 + 0.4 * absf(sin(_t * 5.0)))
		elif me:
			col = UI.GOLD
		if col.a > 0:
			_stage.draw_arc(Vector2.ZERO, SPRITE * 0.43, 0, TAU, 48, col, 5.0, true)
		_stage.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ state
func _on_state(s: Dictionary) -> void:
	if _cards.is_empty() and s.has("players"):
		_build_cards(s["players"])
	var status := str(s.get("status", ""))
	var me: Dictionary = battle.me()
	if status == "question":
		if int(s["round"]) != _last_round:
			_last_round = int(s["round"])
			_new_question(s)
		var answered: bool = int(me.get("answer", -1)) >= 0
		if not me.get("alive", false):
			_info.text = tr("Kau sudah tersingkir. Tengok siapa yang menang!")
		elif answered:
			_info.text = tr("Jawapan dihantar. Menunggu pemain lain...")
		else:
			_info.text = tr("Ketik kad pemain untuk pilih sasaran, kemudian jawab.")
	elif status == "reveal" and _last_status != "reveal":
		_show_reveal(s)
	elif status == "over" and _last_status != "over":
		_show_result(s)
	_round.text = tr("Pusingan %d") % int(s.get("round", 0))
	_refresh_cards(s)
	_last_status = status


func _new_question(s: Dictionary) -> void:
	var q: Dictionary = s["q"]
	_q.text = str(q["q"])
	var alive: bool = battle.me().get("alive", false)
	for i in _buttons.size():
		var b := _buttons[i]
		b.text = "%s.  %s" % [LETTERS[i], q["options"][i]]
		b.disabled = not alive
		b.theme_type_variation = ""
		b.modulate = Color.WHITE
	Sfx.play("pop", -6.0)
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(_q.text)


func _answer(i: int) -> void:
	if str(battle.state.get("status", "")) != "question" or int(battle.me().get("answer", -1)) >= 0:
		return
	battle.answer(i)
	for j in _buttons.size():
		_buttons[j].disabled = true
		_buttons[j].theme_type_variation = "Blue" if j == i else ""
	Sfx.play("select")


func _show_reveal(s: Dictionary) -> void:
	var ans := int(s["answer"])
	var mine := int(battle.me().get("answer", -1))
	for i in _buttons.size():
		# the right answer stays bright green (a disabled button would turn grey)
		_buttons[i].disabled = i != ans
		_buttons[i].theme_type_variation = "Primary" if i == ans else ""
		_buttons[i].modulate = Color.WHITE if i == ans or i == mine else Color(1, 1, 1, 0.45)
	var me: Dictionary = battle.me()
	if me.get("alive", false) or mine >= 0:
		_info.text = (tr("Betul! ") if mine == ans else tr("Jawapan betul: %s. ") % LETTERS[ans]) + str(s.get("explain", ""))
	else:
		_info.text = str(s.get("explain", ""))
	if mine == ans:
		MusicDirector.stinger("st_correct")
	for h in s.get("hits", []):
		_hit(str(h["to"]), int(h["dmg"]), str(h["from"]) == battle.my_id)


func _hit(id: String, dmg: int, by_me: bool) -> void:
	var f: Fighter = _cards.get(id)
	if f == null:
		return
	var l := UI.label("-%d" % dmg, "Title")
	l.add_theme_color_override("font_color", Color("ff6a5a") if not by_me else UI.GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.position = f.head_position() - Vector2(30, 20)
	var t := create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 60, 1.0)
	t.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)
	f.hit()
	Sfx.play_varied("bump", -2.0)
	if id == battle.my_id:
		Main.shake(6.0, 0.3)


func _show_result(s: Dictionary) -> void:
	MusicDirector.puzzle(false)
	var won: bool = s["winner"] == battle.my_id
	var winner := BattleRules.find(s["players"], str(s["winner"]))
	_result = Control.new()
	UI.full(_result)
	_result.add_child(UI.dim(0.6))
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(640, 0)
	var c := UI.vbox(12)
	c.add_child(UI.icon("res://assets/icons/%s.png" % ("mahkota" if won else "bendera"), 96))
	var title := tr("KAU MENANG!") if won else (tr("SERI! Tiada pemenang.") if winner.is_empty() else tr("%s MENANG!") % str(winner["name"]).to_upper())
	var t := UI.label(title, "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var reward := "+%d EXP" % BattleRules.REWARD_EXP + (("   +%d " % BattleRules.REWARD_COINS) + tr("Syiling") if won else "")
	var r := UI.label(reward, "Ink")
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(r)
	var note := UI.label((tr("Bagus! Setiap soalan yang kau jawab ialah ulang kaji %s.") if not won else tr("Syabas! Fakta %s memang melekat dalam kepala kau.")) % BattleRules.chapter_name(), "InkSmall", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(note)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UI.button("Main lagi", "Primary", 200)
	again.pressed.connect(func(): Game.goto("pertarungan", params))
	row.add_child(again)
	var back := UI.button("Kembali", "", 200)
	back.pressed.connect(func(): Game.goto("lobby"))
	row.add_child(back)
	c.add_child(row)
	card.add_child(c)
	_result.add_child(UI.center(card))
	add_child(_result)
	MusicDirector.stinger("st_levelup" if won else "st_zone")
	if won:
		Game.toast("+%d Syiling" % BattleRules.REWARD_COINS)


func _leave() -> void:
	MusicDirector.puzzle(false)
	if battle:
		battle.leave()
	Game.goto("lobby")
