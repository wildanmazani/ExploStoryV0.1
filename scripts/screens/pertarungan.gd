extends Control
## Bilik Pertarungan: the battle. Player cards on top (tap one to make it
## your target), the shared question below. Answer right to hit your target;
## the last player standing wins. params: {"mode": "bot", "bots": 2..4} or
## {"mode": "online", "code": "ABC123"} (online needs Supabase, see Backend).

const UI = preload("res://scripts/ui/ui.gd")
const LETTERS := ["A", "B", "C", "D"]

var params: Dictionary = {}
var battle: Node
var _cards := {}        ## player id -> {panel, hp, hp_label, status, target}
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
	_cards_row = UI.hbox(12)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_cards_row)

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
	root.add_child(UI.margin(qp, 24, 0, 24, 0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	for i in 4:
		var b := UI.button("")
		b.custom_minimum_size = Vector2(610, 70)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_answer.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	root.add_child(UI.center(grid))
	_info = UI.label("", "", true)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.custom_minimum_size.x = 1200
	root.add_child(UI.center(_info))
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


# ------------------------------------------------------------------ cards
func _build_cards(players: Array) -> void:
	for c in _cards_row.get_children():
		c.queue_free()
	_cards.clear()
	for p in players:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(240, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var col := UI.vbox(2)
		var row := UI.hbox(6)
		row.add_child(UI.icon("res://assets/portraits/%s.png" % str(p["avatar"]), 52))
		var folder := str(p.get("skin", "alif"))
		var sk := UI.icon("res://assets/characters32/%s/%s_south.png" % [folder, folder], 56)
		row.add_child(sk)
		var nc := UI.vbox(0)
		var nm := UI.label(str(p["name"]) + (tr(" (kau)") if p.get("me", false) else ""), "Small")
		nm.clip_text = true
		nm.custom_minimum_size.x = 110
		nc.add_child(nm)
		var target := UI.label("", "Small")
		target.add_theme_color_override("font_color", Color("ff8a7a"))
		nc.add_child(target)
		row.add_child(nc)
		col.add_child(row)
		var hp := ProgressBar.new()
		hp.theme_type_variation = "Good"
		hp.max_value = BattleRules.HP
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(0, 16)
		col.add_child(hp)
		var hl := UI.label("", "Small")
		col.add_child(hl)
		panel.add_child(col)
		for n in [row, nc, nm, hp, hl, col, target, sk]:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		var pid := str(p["id"])
		panel.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_pick_target(pid))
		if not p.get("me", false):
			panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			panel.tooltip_text = tr("Ketik untuk jadikan sasaran")
		_cards_row.add_child(panel)
		_cards[pid] = {"panel": panel, "hp": hp, "hp_label": hl, "target": target}


func _pick_target(id: String) -> void:
	if id == battle.my_id:
		return
	battle.set_target(id)
	Sfx.play("select", -6.0)


func _refresh_cards(s: Dictionary) -> void:
	var me: Dictionary = battle.me()
	for p in s["players"]:
		var c: Dictionary = _cards.get(str(p["id"]), {})
		if c.is_empty():
			continue
		var hpbar: ProgressBar = c["hp"]
		create_tween().tween_property(hpbar, "value", float(p["hp"]), 0.4)
		hpbar.theme_type_variation = "Good" if int(p["hp"]) > 50 else ("Warn" if int(p["hp"]) > 25 else "")
		var status := tr("TERSINGKIR") if not p["alive"] else ("HP %d" % int(p["hp"]))
		if p["alive"] and s["status"] == "question" and p.get("answered", false):
			status += "  ·  " + tr("sudah jawab")
		c["hp_label"].text = status
		var is_target: bool = me.get("alive", false) and str(me.get("target", "")) == str(p["id"])
		c["target"].text = tr("SASARAN") if is_target else ""
		var panel: PanelContainer = c["panel"]
		var style := "CardLocked" if not p["alive"] else ("SlotBad" if is_target else ("SlotGood" if p.get("me", false) else "Slot"))
		panel.theme_type_variation = style
		panel.modulate = Color(1, 1, 1, 0.55) if not p["alive"] else Color.WHITE


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
	var c: Dictionary = _cards.get(id, {})
	if c.is_empty():
		return
	var panel: Control = c["panel"]
	var l := UI.label("-%d" % dmg, "Title")
	l.add_theme_color_override("font_color", Color("ff6a5a") if not by_me else UI.GOLD)
	add_child(l)
	l.position = panel.global_position + Vector2(panel.size.x / 2.0 - 30, 10)
	var t := create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 50, 1.0)
	t.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)
	var orig := panel.position
	var sh := create_tween()
	for i in 4:
		sh.tween_property(panel, "position:x", orig.x + (8 if i % 2 == 0 else -8), 0.04)
	sh.tween_property(panel, "position:x", orig.x, 0.04)
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
	var note := UI.label(tr("Bagus! Setiap soalan yang kau jawab ialah ulang kaji Bab 1.") if not won else tr("Syabas! Fakta Bab 1 memang melekat dalam kepala kau."), "InkSmall", true)
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
