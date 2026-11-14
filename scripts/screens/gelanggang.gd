extends Control
## Gelanggang Pesta Silat: the side-view brawl screen. Each round: a question
## card (arena frozen) -> who got Semangat -> AKSI! (live fight, 10 s).
## params: {"format": "1v1"|"2v2"|"1v2"|"1v3", "level": "mudah"|"biasa"|"sukar"}
## The rules live in scripts/brawl/ (BrawlMatch, BrawlFighter, BrawlAI).
## Jeda (button, Esc or P) pauses the match and has the Cara Main guide and
## the keyboard layout switch; the guide also opens before the first match.
## Online (params.online, from a Bilik Pertarungan room): the room host runs
## the fight and sends snapshots over a RealtimeChannel; the others send their
## buttons and answers. Nothing pauses online: Jeda only offers to leave.
##   params: {online, code, my_id, host_id, players: [{id, name, skin}], team:
##            "pvp"|"coop", level, stage, chapter}
## Ujian Bab (params.ujian = chapter, params.foe = {name, skin}): 1 lawan 1
## against the boss with that chapter's questions; winning goes back to the
## Ujian screen (the win scene and the penutup), losing offers another go.

const UI = preload("res://scripts/ui/ui.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const BrawlGuide = preload("res://scripts/ui/brawl_guide.gd")
var _pad_row: HBoxContainer
const LETTERS := ["A", "B", "C", "D"]
const BG := "res://assets/backgrounds/bg_gelanggang.png"
const BG_FALLBACK := "res://assets/backgrounds/bg_zon1_3_balai_penghadapan.png"

var params: Dictionary = {}
var match_node: BrawlMatch
var _rows := {}            ## fighter id -> {hp: ProgressBar, badge: Label, row}
var _round: Label
var _phase: Label
var _clock: Label
var _card: PanelContainer
var _q: Label
var _q_timer: ProgressBar
var _q_status: Label
var _buttons: Array[Button] = []
var _banner: PanelContainer
var _banner_box: VBoxContainer
var _hint: Label
var _big: Label
var _touch: CanvasLayer
var _result: Control
var _pause: Control        ## the Jeda overlay (null when playing)
var _leaving := false      ## Keluar pressed: the match is frozen until the scene changes
var _online := false
var _host := true
var _net: RealtimeChannel
var _net_t := 0.0
var _last_snap := 0.0      ## seconds since the host was last heard (not the host)
var _press := [0, 0, 0, 0, 0]   ## punch, kick, jump, grab, special presses sent so far
var _built := false
const SNAP_EVERY := 0.1    ## host: snapshots per second = 10
const INPUT_EVERY := 0.066
const HOST_LOST := 8.0

signal _pause_closed


func _ready() -> void:
	UI.full(self)
	# this screen keeps running while paused (for the Jeda menu); the match and
	# the touch buttons stop
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pad_free")  # a controller fights; only the cards below take its focus
	Game.use_brawl_keys(true)
	Game.lock_16_9(true)
	tree_exited.connect(func(): Game.lock_16_9(false))
	Game.main.set_pau_visible(false)
	MusicDirector.play("melaka")
	MusicDirector.puzzle(true)
	var stage := Game.stage_def(str(params.get("stage", "")), bool(params.get("online", false)))
	add_child(_stage_bg(stage))
	if stage.get("mat", false):
		add_child(Mat.new())
	match_node = BrawlMatch.new()
	_online = bool(params.get("online", false))
	if _online:
		_host = str(params.get("host_id", "")) == str(params.get("my_id", ""))
		match_node.setup_online(_online_roster(), str(params.get("my_id", "")), _host, str(params.get("level", "biasa")), int(params.get("chapter", 1)))
	else:
		if params.has("ujian"):
			BattleRules.chapter = int(params["ujian"])
		match_node.setup(str(params.get("format", "1v1")), str(params.get("level", "biasa")), params.get("foe", {}))
		# an Ujian Bab passed before is revision: no EXP from the fight either
		match_node.no_reward = params.has("ujian") and Game.save["ujian"].has(int(params["ujian"]))
	match_node.me_autopilot = bool(params.get("autopilot", false))
	match_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(match_node)
	_touch = TouchControls.new()
	_touch.brawl = true
	_touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_touch)
	match_node.phase_changed.connect(_on_phase)
	match_node.changed.connect(_refresh)
	if _online:
		await _start_online()
		return
	_build_screen()
	if Game.save["seen"].has("gelanggang_cara") or match_node.me_autopilot:
		match_node.start()
	else:  # first time here: how to play, then fight
		Game.save["seen"].append("gelanggang_cara")
		Game.persist()
		await _open_pause(true)
		match_node.start()


func _build_screen() -> void:
	if _built:
		return
	_built = true
	_build_hud()
	_build_card()
	_build_banner()
	move_child(_touch, get_child_count() - 1)


# ------------------------------------------------------------------ online
## the fighters of an online room, built by the host: every player by their
## account id; against each other the players split into two teams in the
## order they joined, as a team against bots every player gets one bot
func _online_roster() -> Array:
	var players: Array = params.get("players", [])
	var out: Array = []
	var coop := str(params.get("team", "pvp")) == "coop"
	for i in players.size():
		var p: Dictionary = players[i]
		out.append({"id": str(p["id"]), "name": str(p.get("name", "?")), "skin": str(p.get("skin", "alif")),
			"team": 0 if coop else i % 2})
	if coop:
		var used := players.map(func(p): return str(p.get("skin", "")))
		var bots := LocalBattle.BOTS.filter(func(b): return not used.has(str(b["skin"])))
		if bots.is_empty():
			bots = LocalBattle.BOTS
		for i in players.size():
			var b: Dictionary = bots[i % bots.size()]
			out.append({"id": "bot%d" % i, "name": str(b["name"]), "skin": str(b["skin"]), "team": 1})
	return out


func _start_online() -> void:
	_net = RealtimeChannel.new()
	_net.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_net)
	_net.message.connect(_on_net)
	_net.open("gel-" + str(params.get("code", "")))
	match_node.want_answer.connect(func(i: int): _net.send("ans", {"id": str(params.get("my_id", "")), "i": i}))
	match_node.roster_ready.connect(_build_screen)
	if _host:
		_build_screen()
		_flash_big(tr("Menunggu pemain..."))
		var t := 0.0
		while not _net.is_joined and t < 10.0:
			await get_tree().create_timer(0.2).timeout
			t += 0.2
		await get_tree().create_timer(2.5).timeout  # the others are opening the screen too
		if is_inside_tree():
			match_node.start()
	else:
		_flash_big(tr("Menyambung ke tuan bilik..."))


func _on_net(event: String, p: Dictionary) -> void:
	if _host:
		match event:
			"in":
				match_node.remote_input[str(p.get("id", ""))] = p
			"ans":
				match_node.remote_answer(str(p.get("id", "")), int(p.get("i", -1)))
	elif event == "snap":
		_last_snap = 0.0
		match_node.apply_snapshot(p)


func _online_tick(delta: float) -> void:
	_net_t += delta
	if _host:
		if _net_t >= SNAP_EVERY and match_node.phase != "":
			_net_t = 0.0
			_net.send("snap", match_node.snapshot())
		return
	# the buttons: presses counted every frame, sent a few times a second
	for k in 5:
		if Input.is_action_just_pressed(["attack_punch", "attack_kick", "jump", "grab", "special"][k]):
			_press[k] += 1
	if _net_t >= INPUT_EVERY:
		_net_t = 0.0
		var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_net.send("in", {"id": str(params.get("my_id", "")), "mv": [snappedf(mv.x, 0.01), snappedf(mv.y, 0.01)],
			"run": Input.is_action_pressed("run"), "blk": Input.is_action_pressed("block"), "c": _press})
	if match_node.phase != "tamat":
		_last_snap += delta
		if _last_snap > HOST_LOST and not _leaving:
			_leaving = true
			await Main.ask(tr("Sambungan dengan tuan bilik terputus. Pertarungan ini tamat. Cuba buka bilik semula."), "Kembali ke Arena", "OK")
			Game.goto("lobby")


## every way out (Keluar, Main lagi, Kembali, Log keluar) ends here: nothing
## of the match may stay paused, slowed or ducked in the next scene
func _exit_tree() -> void:
	if _net:
		_net.close()
	get_tree().paused = false
	Engine.time_scale = 1.0
	MusicDirector.puzzle(false)
	Game.use_brawl_keys(false)


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var top := UI.hbox(12)
	top.position = Vector2(16, 10)
	top.size = Vector2(1248, 0)
	var mine := match_node.me.team if match_node.me else 0
	var teams := [mine, 1 - mine]   # your own team always on the left
	for t in 2:
		var panel := UI.panel()
		panel.custom_minimum_size = Vector2(430, 0)
		var col := UI.vbox(4)
		var title := UI.label("PASUKAN ANDA" if t == 0 else "LAWAN", "Small")
		title.add_theme_color_override("font_color", UI.GOLD if t == 0 else Color("ff8a7a"))
		col.add_child(title)
		for f in match_node.fighters:
			if f.team != teams[t]:
				continue
			var row := UI.hbox(8)
			var head := UI.head_icon(f.skin, 34)
			row.add_child(head)
			var nm := UI.label(f.display_name + (tr(" (anda)") if f.is_me else ""), "Small")
			nm.custom_minimum_size.x = 132
			nm.clip_text = true
			row.add_child(nm)
			var hp := ProgressBar.new()
			hp.theme_type_variation = "Good"
			hp.max_value = BrawlRules.HP
			hp.value = f.hp
			hp.show_percentage = false
			hp.custom_minimum_size = Vector2(98, 16)
			hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(hp)
			var pill := _pill("")
			pill.custom_minimum_size.x = 100
			pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pill)
			col.add_child(row)
			_rows[f.id] = {"hp": hp, "badge": pill.get_child(0), "pill": pill, "row": row}
		panel.add_child(col)
		if t == 1:
			var mid := UI.vbox(0)
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			var mid_panel := UI.panel()
			mid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			mid_panel.add_child(mid)
			_round = UI.label("", "Heading")
			_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_round)
			_clock = UI.label("", "Title")
			_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_clock)
			_phase = UI.label("", "Small")
			_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_phase)
			top.add_child(mid_panel)
		top.add_child(panel)
	var pause := UI.button(tr("Jeda"), "", 110)
	pause.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pause.tooltip_text = tr("Jeda dan cara main (Esc)")
	pause.pressed.connect(_open_pause)
	top.add_child(pause)
	add_child(top)
	_hint = UI.label("", "Small", true)
	_hint.position = Vector2(20, 682)
	_hint.size = Vector2(1100, 30)
	add_child(_hint)
	_pad_row = UI.hbox(16)  # controller: the fight buttons, drawn
	_pad_row.position = Vector2(20, 678)
	for h in BrawlGuide.PAD:
		_pad_row.add_child(Game.main.Pad.hint(h[0], h[2]))
	_pad_row.visible = false
	add_child(_pad_row)
	_big = UI.label("", "Title")
	_big.add_theme_font_size_override("font_size", 96)
	_big.add_theme_color_override("font_color", UI.GOLD)
	_big.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	_big.add_theme_constant_override("outline_size", 14)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.position = Vector2(0, 250)
	_big.size = Vector2(1280, 130)
	_big.pivot_offset = Vector2(640, 65)
	_big.modulate.a = 0.0
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_big)


func _process(_d: float) -> void:
	if match_node == null:
		return
	if _online and _net:
		_online_tick(_d)
	if not _built:
		return
	var left := 0.0
	match match_node.phase:
		"soalan":
			left = BrawlRules.ASK_TIME - match_node.phase_t
			_q_timer.value = left
		"aksi":
			left = BrawlRules.FIGHT_TIME - match_node.phase_t
	_clock.text = "%d" % ceili(maxf(left, 0.0)) if match_node.phase in ["soalan", "aksi"] else ""
	_clock.add_theme_color_override("font_color", Color("ff6a5a") if match_node.phase == "aksi" and left < 3.0 else UI.GOLD)
	if _touch:
		_touch.suspended = match_node.phase != "aksi" or not match_node.me.alive()


func _refresh() -> void:
	if not _built:
		return
	for f in match_node.fighters:
		var r: Dictionary = _rows.get(f.id, {})
		if r.is_empty():
			continue
		var hp: ProgressBar = r["hp"]
		create_tween().tween_property(hp, "value", float(f.hp), 0.25)
		hp.theme_type_variation = "Good" if f.hp > BrawlRules.HP / 2 else ("Warn" if f.hp > BrawlRules.HP / 4 else "")
		var pill: PanelContainer = r["pill"]
		if not f.alive():
			_set_pill(pill, "pengsan")
			(r["row"] as Control).modulate.a = 0.55
		elif match_node.phase == "soalan":
			_set_pill(pill, "jawab" if match_node.answers.has(f.id) else "")
		elif match_node.phase in ["keputusan", "aksi"]:
			_set_pill(pill, ("jurus" if f.special_ready else "semangat") if f.answered_right else "lemah")
	_round.text = tr("Pusingan %d") % match_node.round_no
	if match_node.phase == "soalan" and match_node.answers.has(match_node.me.id):
		_q_status.text = tr("Jawapan dihantar. Menunggu yang lain...")


## the state badges: a coloured pill, the same look in the HUD and the banner
const PILLS := {
	"semangat": ["SEMANGAT", "f2c14e", "3a2405", "serangan penuh"],
	"jurus": ["JURUS!", "ff7a2f", "ffffff", "Jurus Kilat sedia"],
	"lemah": ["LEMAH", "5d6878", "e6ebf2", "serangan 30%"],
	"pengsan": ["PENGSAN", "7b5aa6", "f3eaff", ""],
	"jawab": ["sudah jawab", "3f8f5a", "eafff0", ""],
}


func _pill(kind: String, size := "Small") -> PanelContainer:
	var p := PanelContainer.new()
	var l := UI.label("", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_set_pill(p, kind)
	return p


func _set_pill(p: PanelContainer, kind: String) -> void:
	var l: Label = p.get_child(0)
	if kind == "" or not PILLS.has(kind):
		l.text = ""
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	var d: Array = PILLS[kind]
	if l.text == tr(d[0]) and p.has_meta("kind") and p.get_meta("kind") == kind:
		return
	var changed: bool = str(p.get_meta("kind", "")) != kind
	p.set_meta("kind", kind)
	l.text = tr(d[0])
	l.add_theme_color_override("font_color", Color(d[2]))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(d[1])
	sb.border_color = Color(d[1]).darkened(0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	if changed and is_inside_tree():  # a little pop when it changes
		p.pivot_offset = p.size / 2.0
		p.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ question card
func _build_card() -> void:
	_card = UI.panel("Paper")
	_card.add_to_group("pad_scope")
	_card.set_meta("pad_no_cancel", true)
	_card.custom_minimum_size = Vector2(1100, 0)
	var col := UI.vbox(10)
	_q_timer = ProgressBar.new()
	_q_timer.show_percentage = false
	_q_timer.max_value = BrawlRules.ASK_TIME
	_q_timer.custom_minimum_size = Vector2(0, 14)
	col.add_child(_q_timer)
	var qrow := UI.hbox(10)
	_q = UI.label("", "InkHeading", true)
	_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_q)
	col.add_child(qrow)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for i in 4:
		var b := UI.button("")
		b.custom_minimum_size = Vector2(535, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_answer.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	col.add_child(grid)
	var foot := UI.hbox(10)
	_q_status = UI.label("", "InkSmall", true)
	_q_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_q_status)
	# a break or a way out in the middle of a question too
	var stop := UI.button(tr("Jeda"), "", 120)
	stop.pressed.connect(_open_pause)
	foot.add_child(stop)
	var quit := UI.button(tr("Keluar kuiz"), "", 170)
	quit.name = "KeluarKuiz"
	quit.pressed.connect(_ask_leave)
	foot.add_child(quit)
	col.add_child(foot)
	_card.add_child(col)
	_card.position = Vector2(90, 150)
	_card.visible = false
	add_child(_card)


func _answer(i: int) -> void:
	if match_node.phase != "soalan" or match_node.answers.has(match_node.me.id) or not match_node.me.alive():
		return
	match_node.answer(i)
	for j in _buttons.size():
		_buttons[j].disabled = true
		_buttons[j].theme_type_variation = "Blue" if j == i else ""
	Sfx.play("select")


func _unhandled_input(e: InputEvent) -> void:
	var pause_key: bool = e.is_action_pressed("menu") or (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_P)
	if _leaving:
		get_viewport().set_input_as_handled()
		return
	if pause_key and _result == null:
		get_viewport().set_input_as_handled()
		if _pause:
			_close_pause()
		else:
			_open_pause()
		return
	if _pause:
		return
	if match_node and match_node.phase == "soalan" and e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode - KEY_1
		if k >= 0 and k < 4:
			_answer(k)


# ------------------------------------------------------------------ banner (who got Semangat)
func _build_banner() -> void:
	_banner = UI.panel()
	_banner.custom_minimum_size = Vector2(700, 0)
	_banner_box = UI.vbox(6)
	_banner.add_child(_banner_box)
	_banner.position = Vector2(290, 170)
	_banner.visible = false
	add_child(_banner)


## long questions or big text make the card taller: lift it so the bottom
## row of answers never runs off the screen
func _fit_card() -> void:
	_card.reset_size()
	var h := get_viewport_rect().size.y
	_card.position.y = clampf(h - _card.size.y - 16.0, 16.0, 150.0)


func _on_phase(p: String) -> void:
	if not _built:
		return
	_card.visible = p == "soalan"
	_banner.visible = p == "keputusan"
	match p:
		"soalan":
			_q.text = str(match_node.q["q"])
			for i in _buttons.size():
				var b := _buttons[i]
				b.text = "%s.  %s" % [LETTERS[i], match_node.q["options"][i]]
				b.disabled = not match_node.me.alive()
				b.theme_type_variation = ""
				b.modulate = Color.WHITE
			_q_status.text = tr("Jawab betul untuk dapat SEMANGAT (serangan penuh) dan senjata sekolah!") if match_node.me.alive() else tr("Anda pengsan. Sokong rakan sepasukan!")
			_phase.text = tr("SOALAN")
			_hint.text = ""
			Sfx.play("pop", -6.0)
			if bool(Game.settings.get("auto_read", false)):
				Tts.speak(_q.text)
			_fit_card.call_deferred()
		"keputusan":
			for c in _banner_box.get_children():
				c.queue_free()
			var head := UI.label(tr("Jawapan: %s. %s") % [LETTERS[match_node.answer_index], match_node.q["options"][match_node.answer_index]], "Heading", true)
			_banner_box.add_child(head)
			if match_node.explain != "":
				_banner_box.add_child(UI.label(match_node.explain, "Small", true))
			for r in match_node.results:
				var line := UI.hbox(10)
				var f := match_node.find(str(r.get("id", "")))
				if f:
					line.add_child(UI.head_icon(f.skin, 30))
				var nm := UI.label("%s%s" % [r["name"], tr(" (anda)") if r["me"] else ""], "")
				nm.custom_minimum_size.x = 190
				nm.add_theme_color_override("font_color", UI.GOLD if r["me"] else Color.WHITE)
				line.add_child(nm)
				var ok := UI.label(tr("BETUL") if r["right"] else tr("SALAH"), "Small")
				ok.custom_minimum_size.x = 70
				ok.add_theme_color_override("font_color", Color("8ee59a") if r["right"] else Color("ff8a7a"))
				line.add_child(ok)
				var pill := _pill("semangat" if r["right"] else "lemah")
				line.add_child(pill)
				var why := UI.label(tr(PILLS["semangat" if r["right"] else "lemah"][3]), "Small")
				why.add_theme_color_override("font_color", Color("c9d2de"))
				line.add_child(why)
				if r["fastest"]:
					line.add_child(_pill("jurus"))
					var key := UI.label(tr("butang Jurus") if BrawlGuide.on_touch() else tr("tekan %s") % Game.brawl_key_names("special"), "Small")
					key.add_theme_color_override("font_color", Color("ffb27a"))
					line.add_child(key)
				_banner_box.add_child(line)
				line.modulate.a = 0.0
				var t := create_tween()
				t.tween_interval(0.15 * _banner_box.get_child_count())
				t.tween_property(line, "modulate:a", 1.0, 0.2)
			_phase.text = tr("KEPUTUSAN")
			if match_node.me.alive():
				# under the banner, over the fighters, so neither hides the other
				if match_node.me.answered_right:
					_flash_big(tr("JURUS KILAT!") if match_node.me.special_ready else tr("SEMANGAT!"), UI.GOLD, 360.0)
				else:
					_flash_big(tr("LEMAH..."), Color("a8b4c4"), 360.0)
			if match_node.me.answered_right:
				MusicDirector.stinger("st_correct")
		"aksi":
			_phase.text = tr("AKSI!")
			_flash_big(tr("AKSI!"))
			_hint.text = _controls_hint()
		"tamat":
			_hint.text = ""
			_show_result()
	_refresh()
	_pad_row.visible = Game.pad_mode() and p == "aksi"


func _flash_big(text: String, col := UI.GOLD, y := 250.0) -> void:
	if _big == null:
		return
	_big.text = text
	_big.position.y = y
	_big.add_theme_color_override("font_color", col)
	move_child(_big, get_child_count() - 1)
	_big.scale = Vector2(1.6, 1.6)
	_big.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.5)
	t.tween_property(_big, "modulate:a", 0.0, 0.3)


# ------------------------------------------------------------------ result
func _show_result() -> void:
	MusicDirector.puzzle(false)
	Game.note_battle_played()  # Kempen Syiling: maklum balas needs one battle
	var won := match_node.me != null and match_node.winner_team == match_node.me.team
	_result = Control.new()
	_result.add_to_group("pad_scope")
	_result.set_meta("pad_no_cancel", true)
	UI.full(_result)
	_result.add_child(UI.dim(0.55))
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(640, 0)
	var c := UI.vbox(12)
	c.add_child(UI.center(UI.icon("res://assets/icons/%s.png" % ("mahkota" if won else "bendera"), 96)))
	var t := UI.label(tr("PASUKAN ANDA MENANG!") if won else tr("PASUKAN LAWAN MENANG"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var reward := "+%d EXP" % BrawlRules.REWARD_EXP + (("   +%d " % BrawlRules.coins_for(match_node.level, match_node.online)) + tr("Syiling") if won else "")
	if match_node.no_reward:
		reward = tr("Ulang kaji: tiada EXP.")
	var r := UI.label(reward, "Ink")
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(r)
	var note := UI.label(tr("Syabas! Setiap soalan yang anda jawab ialah ulang kaji %s.") % BattleRules.chapter_name() if won else tr("Tak apa, cuba lagi! Lagi banyak jawapan betul, lagi kuat serangan anda."), "InkSmall", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(note)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not _online:  # online: the room is over, open a new one from the Arena
		var again := UI.button("Main lagi", "Primary", 200)
		again.pressed.connect(func(): Game.goto("gelanggang", params))
		row.add_child(again)
	var back := UI.button("Kembali", "", 200)
	back.pressed.connect(func(): Game.goto("lobby"))
	row.add_child(back)
	if params.has("ujian"):  # the chapter test: win to go on, or try again
		for b in row.get_children():
			b.queue_free()
		t.text = tr("%s TUMBANG!") % str(params.get("foe", {}).get("name", "")).to_upper() if won else tr("BELUM KALI INI")
		note.text = tr("Ujian Bab %d lulus!") % int(params["ujian"]) if won else tr("Ulang kaji Nota Alif, kemudian cuba lagi. Soalan baru setiap kali.")
		if won:
			var go := UI.button(tr("Teruskan »"), "Primary", 240)
			go.pressed.connect(func(): Game.goto("ujian", {"chapter": int(params["ujian"]), "won": true}))
			row.add_child(go)
		else:
			var rev := UI.button(tr("Ulang kaji dulu"), "", 240)
			rev.pressed.connect(func(): Game.goto("peta"))
			row.add_child(rev)
			var again2 := UI.button(tr("Cuba lagi »"), "Primary", 240)
			again2.pressed.connect(func(): Game.goto("gelanggang", params))
			row.add_child(again2)
	c.add_child(row)
	card.add_child(c)
	_result.add_child(UI.center(card))
	add_child(_result)
	MusicDirector.stinger("st_levelup" if won else "st_zone")
	if won:
		Game.toast("+%d Syiling" % BrawlRules.coins_for(match_node.level, match_node.online))
	_flash_big(tr("MENANG!") if won else tr("KALAH"))


## one line of controls under the arena while fighting
func _controls_hint() -> String:
	if Game.pad_mode():
		return ""  # the buttons are drawn instead (_pad_hint)
	if BrawlGuide.on_touch():
		return tr("Guna butang di kanan bawah. Tekan Jeda untuk cara main.")
	var k := func(a: String) -> String: return Game.brawl_key_names(a)
	return tr("%s Tumbuk · %s Sepak · %s Lompat · %s Ambil/Baling · %s Tangkis · %s Jurus · %s Lari · Esc Jeda") % [
		k.call("attack_punch"), k.call("attack_kick"), k.call("jump"), k.call("grab"),
		k.call("block"), k.call("special"), k.call("run")]


# ------------------------------------------------------------------ Jeda (pause)
## first = the intro before the first match: just the guide and "Mula"
func _open_pause(first := false) -> void:
	if _pause or _leaving:
		return
	if _online:  # the others keep fighting: no pause, only a way out
		if await Main.ask(tr("Keluar dari gelanggang dalam talian? Pertarungan diteruskan tanpa anda."), "Keluar", "Terus main"):
			_leaving = true
			Game.goto("lobby")
		return
	if not first:  # (the intro comes before the match: nothing to stop, and
		get_tree().paused = true  # pausing would freeze the screen fade-in)
	Sfx.play("pop", -6.0)
	_pause = Control.new()
	_pause.add_to_group("pad_scope")
	UI.full(_pause)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(UI.dim(0.6))
	add_child(_pause)
	if first:
		_show_guide("Mula bertarung!")
	else:
		_show_menu()
	await _pause_closed  # never comes if the player leaves: the wait ends with the screen


func _close_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false
	_pause_closed.emit()
	if match_node and match_node.phase == "aksi":
		_hint.text = _controls_hint()  # the layout may have changed


func _clear_pause() -> void:
	for c in _pause.get_children():
		if not c is ColorRect:
			c.queue_free()


func _show_menu() -> void:
	_clear_pause()
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(460, 0)
	var c := UI.vbox(14)
	var t := UI.label(tr("JEDA"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var go := UI.button(tr("Sambung"), "Primary", 380)
	go.pressed.connect(_close_pause)
	c.add_child(go)
	var how := UI.button(tr("Cara main"), "Blue", 380)
	how.pressed.connect(func(): _show_guide("« Kembali", true))
	c.add_child(how)
	var out := UI.button(tr("Keluar gelanggang"), "", 380)
	out.pressed.connect(_leave)
	c.add_child(out)
	card.add_child(c)
	_pause.add_child(UI.center(card))
	go.grab_focus()


## "Keluar kuiz" on the question card: stop the clock, then make sure
func _ask_leave() -> void:
	if _leaving or _result != null:
		return
	if _online:
		_open_pause()  # online: no pause, just the "leave?" question
		return
	if _pause == null:
		_open_pause()  # stops the match; the menu is replaced at once below
	_clear_pause()
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(520, 0)
	var c := UI.vbox(14)
	var t := UI.label(tr("Keluar kuiz?"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var note := UI.label(tr("Pertarungan ini tamat dan tiada ganjaran."), "Ink", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(note)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var stay := UI.button(tr("Terus main"), "Primary", 200)
	stay.pressed.connect(_close_pause)
	row.add_child(stay)
	var out := UI.button(tr("Keluar"), "", 200)
	out.pressed.connect(_leave)
	row.add_child(out)
	c.add_child(row)
	card.add_child(c)
	_pause.add_child(UI.center(card))
	stay.grab_focus()


func _show_guide(button_text: String, back_to_menu := false) -> void:
	_clear_pause()
	var card := BrawlGuide.card(button_text, true)
	var ok: Button = card.find_child("Ok", true, false)
	ok.pressed.connect(_show_menu if back_to_menu else _close_pause)
	_pause.add_child(UI.center(card))
	ok.grab_focus()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	# freeze the match itself (not the tree: the fade to the lobby must run)
	match_node.process_mode = Node.PROCESS_MODE_DISABLED
	_touch.process_mode = Node.PROCESS_MODE_DISABLED
	if _pause:
		for b in _pause.find_children("*", "Button", true, false):
			(b as Button).disabled = true
	get_tree().paused = false
	MusicDirector.puzzle(false)
	Engine.time_scale = 1.0
	Game.goto("peta" if params.has("ujian") else "lobby")


## the silat mat on the floor (a trapezoid, so the floor reads as depth)
## the stage picture, scaled and moved so its ground lies under the fighters
## (data/stages.json: zoom, ground_y)
func _stage_bg(stage: Dictionary) -> Control:
	var path := str(stage.get("bg", BG))
	if not ResourceLoader.exists(path):
		return UI.bg_image(BG_FALLBACK, Color(0.55, 0.5, 0.55))
	var z := float(stage.get("zoom", 1.0))
	var ground := float(stage.get("ground_y", 602))
	if is_equal_approx(z, 1.0) and is_equal_approx(ground, 602.0):
		return UI.bg_image(path)
	var r := TextureRect.new()
	r.texture = UI.tex(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(1280, 720) * z
	r.position = Vector2(640.0 - 640.0 * z, 602.0 - ground * z)
	return r


class Mat extends Control:
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := BrawlRules.SCREEN_FLOOR
		var top := f.position.y - 38
		var bot := f.end.y + 24
		var pts := PackedVector2Array([Vector2(f.position.x + 60, top), Vector2(f.end.x - 60, top), Vector2(f.end.x + 40, bot), Vector2(f.position.x - 40, bot)])
		draw_colored_polygon(pts, Color(0.62, 0.16, 0.14, 0.92))
		var inner := PackedVector2Array([Vector2(f.position.x + 110, top + 18), Vector2(f.end.x - 110, top + 18), Vector2(f.end.x - 20, bot - 18), Vector2(f.position.x + 20, bot - 18)])
		draw_colored_polygon(inner, Color(0.16, 0.3, 0.55, 0.95))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.95, 0.85, 0.55), 4.0)
		var mid := Vector2((f.position.x + f.end.x) / 2.0, (top + bot) / 2.0)
		draw_set_transform(mid, 0, Vector2(1, 0.32))
		draw_arc(Vector2.ZERO, 120, 0, TAU, 48, Color(0.95, 0.85, 0.55, 0.8), 4.0, true)
		draw_set_transform(Vector2.ZERO)
