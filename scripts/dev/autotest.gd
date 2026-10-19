extends Node
## End-to-end play-through used by CI and for screenshots.
## Run:  godot --path . -- --autotest [--shots=/abs/dir]
## title -> guest login -> prologue -> world intro -> every Bab 1 puzzle at
## its place in the world (one wrong try + Pau hints each) -> summaries ->
## penutup -> Muzium -> lobby, then prints AUTOTEST PASS (exit 0, 1 on fail).

const TIMEOUT := 600.0

var shots_dir: String = ""
var _t: float = 0.0
var _adv_t: float = 0.0
var _shot_n: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d := DirAccess.open("user://")  # start from a clean guest profile
	if d:
		for f in d.get_files():
			if f.begins_with("simpan_"):
				d.remove(f)
	_run()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout after %d s" % int(TIMEOUT))
	_adv_t += delta
	if Main.dialog_box.visible and _adv_t > 0.08:  # tap through every dialogue
		_adv_t = 0.0
		Main.dialog_box._advance()


func _fail(msg: String) -> void:
	printerr("AUTOTEST FAIL: " + msg)
	get_tree().quit(1)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	_shot_n += 1
	img.save_png("%s/%02d_%s.png" % [shots_dir, _shot_n, name])
	print("shot ", name)


func scene() -> Node:
	return get_tree().current_scene


## name of what's on screen: scene file name, or the hosted prototype screen
func screen_name() -> String:
	var s := scene()
	if s == null:
		return ""
	var n := s.scene_file_path.get_file().get_basename()
	return Game.pending_screen if n == "screen_host" else n


func hosted() -> Node:
	return scene().get_child(scene().get_child_count() - 1)


func wait_screen(name: String, limit: float = 30.0) -> void:
	var t := 0.0
	while screen_name() != name:
		await wait(0.1)
		t += 0.1
		if t > limit:
			_fail("screen %s did not appear (at %s)" % [name, screen_name()])
			return
	await wait(0.6)


## zone briefings ("Persiapan Misi") wait for MULA MENEROKA: shoot and close them
func _close_preps() -> void:
	for c in Main.overlay_root().get_children():
		if c.has_method("_close") and not c.is_queued_for_deletion() and str(c.get_script().resource_path).ends_with("zone_prep.gd"):
			await shot("prep_" + str(c.get("params").get("zone", "")))
			if is_instance_valid(c) and not c.is_queued_for_deletion():
				c._close()


func wait_idle(limit: float = 60.0) -> void:
	var t := 0.0
	while true:
		await _close_preps()
		var s := scene()
		var busy: bool = Main.dialog_box.visible or Game.is_locked()
		if s and "busy" in s and s.busy:
			busy = true
		if s and "runner" in s and s.runner.busy:
			busy = true
		if not busy:
			break
		await wait(0.1)
		t += 0.1
		if t > limit:
			_fail("still busy after %d s on %s" % [int(limit), screen_name()])
			return


func find_button(root: Node, prefix: String) -> Button:
	for c in root.get_children():
		if c is Button and (c as Button).visible and (c as Button).text.begins_with(prefix):
			return c
		var r := find_button(c, prefix)
		if r:
			return r
	return null


func close_top_overlay() -> void:
	var root: Control = Main.overlay_root()
	var top := root.get_child(root.get_child_count() - 1)
	if top.has_method("close"):
		top.close()


# ------------------------------------------------------------------ the run
func _run() -> void:
	await wait_screen("title")
	await shot("title")
	Game.goto("login")
	await wait_screen("login")
	await shot("login")
	Game.goto("register")
	await wait_screen("register")
	await shot("register")
	Game.goto("login")
	await wait_screen("login")
	hosted()._guest()

	# ---- prologue + world intro, played in full
	await wait_screen("prologue")
	await wait(3.0)
	await shot("prologue_room")
	await wait_screen("world", 120)
	await wait(2.0)
	await shot("world_intro_sweep")
	await wait_idle(120)
	await wait(0.5)
	await shot("world_start")

	var sp: Node = Main.open_settings()
	await wait(0.4)
	await shot("settings")
	sp._show(1)
	await wait(0.3)
	await shot("settings_audio")
	close_top_overlay()
	Game.set_setting("lang", "en")
	await wait(0.4)
	await shot("world_english")
	if scene().hud._level.text.begins_with("TAHAP"):
		_fail("HUD not translated to English")
		return
	Game.set_setting("lang", "ms")
	await _check_map()
	await _check_controls()
	Main._on_pau_tap()
	await wait(0.3)
	await shot("pau_hint_bubble")

	# ---- the four zones, each puzzle at its spot in the world
	for z in Game.ZONES:
		if z == "1_3":
			GameState.go_to("res://scenes/interior/balai.tscn")
			await wait_screen("balai")
			await wait_idle()
		elif screen_name() != "world":
			await wait_screen("world")
			await wait_idle()
		await shot("zone_" + z)
		for s in Game.zone_data(z)["steps"]:
			if not _walk_to(str(s["at"])):
				_fail("no spot for %s in %s" % [s["at"], screen_name()])
				return
			var tt := 0.0
			while Game.active_puzzle == null:
				await wait(0.1)
				tt += 0.1
				if tt > 30:
					_fail("puzzle %s never opened" % s["puzzle"])
					return
			await wait(0.4)
			await _solve(Game.active_puzzle, "%s_%s" % [z, s["puzzle"]])
			await wait_idle(60)
			await wait(0.3)
			if s == Game.zone_data(z)["steps"][0]:
				await shot("world_after_%s" % s["puzzle"])
		await wait_screen("zone_summary", 40)
		await shot("summary_" + z)
		hosted()._continue()
		if z != "1_4":
			await wait_screen("world")
			await wait_idle()

	# ---- penutup
	await wait_screen("penutup", 30)
	var t := 0.0
	var shot_flag := false
	while screen_name() == "penutup":
		var nota: Node = null
		for c in Main.overlay_root().get_children():
			if c.has_method("_read_page"):
				nota = c
		if nota:
			await wait(0.5)
			await shot("nota_alif")
			nota.close()
		elif not Main.dialog_box.visible:
			var b := find_button(hosted(), "Teruskan")
			if b == null:
				b = find_button(hosted(), "KEMBALI")
				if b:
					await shot("teaser_bab2")
			if b:
				b.pressed.emit()
		elif not shot_flag:
			shot_flag = true
			await shot("penutup_flag")
		await wait(0.2)
		t += 0.2
		if t > 120:
			_fail("penutup stuck")
			return
	await wait_screen("world")
	await wait_idle()
	await shot("world_after_bab1")
	scene().open_map()
	await wait(0.5)
	var mo: Node = Main.overlay_root().get_child(Main.overlay_root().get_child_count() - 1)
	mo._select_tab(1, "_show_keywords")
	await wait(0.3)
	await shot("map_keywords_bab1")
	mo.close()
	await wait(0.2)
	Main.open_muzium()
	await wait(0.4)
	await shot("muzium")
	close_top_overlay()
	Main.open_nota()
	await wait(0.4)
	await shot("nota")
	close_top_overlay()
	await _check_shop()
	Game.goto("arka")
	await wait_screen("arka")
	await shot("arka")
	hosted()._enter({"no": 2}, false)
	hosted()._show_arc(1)
	await wait(0.3)
	await shot("arka_t5_locked")
	Game.goto("lobby")
	await wait_screen("lobby")
	await shot("lobby")
	await _check_battle()

	# ---- checks
	if not Game.chapter_done(1):
		_fail("Bab 1 not marked done")
		return
	for z in Game.ZONES:
		if not Game.zone_done(z):
			_fail("zone %s not done" % z)
			return
	if Game.save["artifacts"].size() < 4:
		_fail("artifacts missing: %s" % str(Game.save["artifacts"]))
		return
	print("AUTOTEST PASS level=%d exp=%d coins=%d figures=%s" % [Game.save["level"], Game.save["exp"], Game.save["coins"], str(Game.save["figures"])])
	get_tree().quit(0)


## Bilik Pertarungan vs 2 bots, sped up: answer right, hit the weakest,
## play until one is left. The winner gets +20 syiling.
func _check_battle() -> void:
	var coins := int(Game.save["coins"])
	var played := int(Game.save["battle"]["played"])
	Game.goto("pertarungan", {"mode": "bot", "bots": 2})
	await wait_screen("pertarungan")
	var b: Node = hosted().battle
	Engine.time_scale = 6.0
	var shot_q := false
	var shot_hit := false
	var t := 0.0
	while str(b.state.get("status", "")) != "over":
		var st := str(b.state.get("status", ""))
		if st == "question" and b.me()["alive"] and int(b.me()["answer"]) < 0:
			var q: Dictionary = b._questions[b._qi]
			hosted()._pick_target(BattleRules.auto_target(b.state["players"], b.my_id))
			if not shot_q:
				shot_q = true
				Engine.time_scale = 1.0
				await shot("battle_question")
				Engine.time_scale = 6.0
			hosted()._answer(int(q["answer"]))
		elif st == "reveal" and not shot_hit and not b.state["hits"].is_empty():
			shot_hit = true
			Engine.time_scale = 1.0
			await wait(0.3)
			await shot("battle_hits")
			Engine.time_scale = 6.0
		await wait(0.1)
		t += 0.1
		if t > 120.0:
			Engine.time_scale = 1.0
			_fail("battle never finished (round %d)" % int(b.state.get("round", 0)))
			return
	Engine.time_scale = 1.0
	await wait(0.5)
	await shot("battle_result")
	if int(Game.save["battle"]["played"]) != played + 1:
		_fail("battle not counted")
		return
	var won: bool = b.state["winner"] == b.my_id
	if won and int(Game.save["coins"]) != coins + BattleRules.REWARD_COINS:
		_fail("winner did not get %d syiling (%d -> %d)" % [BattleRules.REWARD_COINS, coins, int(Game.save["coins"])])
		return
	print("battle: rounds=%d winner=%s won=%s" % [int(b.state["round"]), str(b.state["winner"]), str(won)])


## Profil & Kedai: buy and wear a skin with the syiling earned in Bab 1.
func _check_shop() -> void:
	var before := int(Game.save["coins"])
	var pp: Node = Main.open_profile()
	await wait(0.5)
	await shot("profile")
	pp._show(1)
	await wait(0.3)
	var err := Game.buy_skin("pengakap")
	if err != "" or int(Game.save["coins"]) != before - 120:
		_fail("buying a skin failed: %s (coins %d -> %d)" % [err, before, int(Game.save["coins"])])
		return
	Game.equip_skin("pengakap")
	pp._show(1)
	await wait(0.3)
	await shot("shop")
	pp.close()
	await wait(0.3)
	await shot("world_new_skin")


## Mini map in the corner (Pau button hidden), zoom levels, full map + legend.
func _check_map() -> void:
	var w := scene()
	if not w.minimap.visible or Main.pau_button.visible:
		_fail("mini map should replace the Pau button in the world")
		return
	await shot("minimap")
	w.minimap._set_zoom(2)
	await wait(0.3)
	await shot("minimap_whole")
	w.minimap._set_zoom(0)
	w.open_map()
	await wait(0.5)
	var m: Node = Main.overlay_root().get_child(Main.overlay_root().get_child_count() - 1)
	if not m.has_method("_show_keywords"):
		_fail("full map did not open")
		return
	await shot("map_places")
	m._zoom(1.5)
	m._select_tab(1, "_show_keywords")
	await wait(0.3)
	await shot("map_keywords")
	m._select_tab(2, "_show_symbols")
	m.view.set_zoom(0.0)
	await wait(0.3)
	await shot("map_symbols_whole")
	m.close()
	await wait(0.2)


## Tetapan > Kawalan: D-pad, joystick (fake thumb drag walks Alif east),
## left-handed + big, tap only; then back to Automatik.
func _check_controls() -> void:
	Game.set_setting("controls", "joystick")
	var sp: Node = Main.open_settings()
	sp._show(2)
	await wait(0.3)
	await shot("settings_kawalan")
	close_top_overlay()
	var w := scene()
	var tc: Node = w.get_node("TouchControls")
	Game.set_setting("controls", "dpad")
	await wait(0.3)
	if tc.get_child_count() != 6 or not tc.visible:
		_fail("D-pad should have 6 buttons (has %d)" % tc.get_child_count())
		return
	if w.minimap.position.y > 300:
		_fail("mini map should move up when controls are on screen")
		return
	await shot("controls_dpad")
	Game.set_setting("controls", "joystick")
	await wait(0.3)
	var st: Node = tc._stick
	if st == null:
		_fail("joystick not built")
		return
	await shot("controls_joystick_idle")
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.pressed = true
	down.position = st.rest
	st._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = st.rest + Vector2(st.radius * 0.6, 4)
	st._input(drag)
	if not Input.is_action_pressed("move_right") or Input.is_action_pressed("run"):
		_fail("joystick push right should press move_right only")
		return
	await wait(0.5)
	await shot("controls_joystick_push")
	if w.player.facing != "east":
		_fail("joystick did not turn Alif east (%s)" % w.player.facing)
		return
	if not tc.owns(st.rest) or tc.owns(Vector2(900, 200)):
		_fail("joystick zone should block tap-to-walk only in its corner")
		return
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.pressed = false
	up.position = drag.position
	st._input(up)
	if Input.is_action_pressed("move_right"):
		_fail("joystick release should let go of move_right")
		return
	Game.set_setting("left_handed", true)
	Game.set_setting("pad_size", 2)
	Game.set_setting("controls", "dpad")
	await wait(0.3)
	await shot("controls_dpad_lefty_big")
	if w.minimap.position.x > 640:
		_fail("left-handed: mini map should move to the left side")
		return
	Game.set_setting("controls", "tap")
	await wait(0.3)
	if tc.get_child_count() != 0 or tc.visible:
		_fail("Ketik sahaja should show no buttons")
		return
	Game.set_setting("left_handed", false)
	Game.set_setting("pad_size", 1)
	Game.set_setting("controls", "auto")
	await wait(0.4)  # let the player stop walking before the zones start


## Put Alif next to a spot (NPC, object or prop), face it and interact.
func _walk_to(id: String) -> bool:
	var s := scene()
	var target := Vector2i(-999, -999)
	if s.has_method("spot_ids") and "spots" in s and s.spots.has(id):
		var sp: Dictionary = s.spots[id]
		target = Vector2i(sp["pos"][0], sp["pos"][1])
	elif "npcs" in s:
		for at in s.npcs:
			if s.npcs[at].id == id:
				target = at
	if "npc" in s and s.npc and s.npc_id == id:
		target = s.npc.cell
	if "_props" in s and s._props.has(id):
		target = s._props[id]["cells"][0]
	if target.x == -999:
		return false
	var stand := Vector2i.ZERO
	var found := false
	for r in range(1, 4):
		for d in [Vector2i(0, r), Vector2i(-r, 0), Vector2i(r, 0), Vector2i(0, -r)]:
			if s.is_walkable(target + d):
				stand = target + d
				found = true
				break
		if found:
			break
	if not found:
		return false
	# multi-cell objects: step next to the nearest footprint cell
	var face := target
	if "spots" in s and s.spots.has(id):
		var sp: Dictionary = s.spots[id]
		for dy in sp["size"][1]:
			for dx in sp["size"][0]:
				var c := Vector2i(sp["pos"][0] + dx, sp["pos"][1] - dy)
				if (c - stand).length_squared() == 1:
					face = c
	s.player.place_at(stand)
	s.player.face_cell(face)
	s._interact(face)
	return true


func _solve(p: Node, label: String) -> void:
	var path: String = p.get_script().resource_path
	if path.ends_with("choice.gd"):
		await shot("puzzle_" + label)
		p._pick(p.def["options"][0])
	elif path.ends_with("objektif.gd"):
		for qi in p.questions.size():
			var ans := int(p.questions[qi]["answer"])
			p._pick((ans + 1) % 4)  # one wrong try, then a hint that removes an answer
			p.request_hint()
			p.request_hint()
			await wait(0.2)
			if qi == 0:
				await shot("puzzle_" + label)
			p._pick(ans)
			await wait(0.2)
			if qi + 1 < p.questions.size():
				p._advance()
	elif path.ends_with("suaikan.gd"):
		p._tap_left(0)
		p.try_match(0, (p._right_of(0) + 1) % p.pairs.size())  # one wrong pair
		p.request_hint()
		p.request_hint()
		p.request_hint()  # tier 3 joins a pair
		await wait(0.2)
		for i in p.pairs.size():
			if i == p.pairs.size() / 2:
				await shot("puzzle_" + label)
			if not p._done.has(i):
				p._tap_left(i)
				p.try_match(i, p._right_of(i))
				await wait(0.05)
	elif path.ends_with("board.gd"):
		var links: Array = p.links
		var ids: Array = p.cards.keys()
		var a = p.cards[links[0][0]]
		for id in ids:  # one wrong attempt, one Pau hint
			if p._key(links[0][0], id) == "" and id != links[0][0]:
				p.try_link(a, p.cards[id])
				break
		p.request_hint()
		await wait(0.2)
		for i in links.size():
			if i == links.size() / 2:
				await shot("puzzle_" + label)
			var l: Array = links[i]
			if not p._is_made("%s|%s" % [l[0], l[1]]):
				p.try_link(p.cards[l[0]], p.cards[l[1]])
				await wait(0.05)
	else:
		var cards: Array = p.cards
		var c0 = cards[0]
		for tid in p.targets.keys():
			if tid != str(c0.item["target"]):
				p.try_place(c0, p.targets[tid])
				break
		p.request_hint()
		p.request_hint()
		await wait(0.2)
		await shot("puzzle_" + label)
		for c in cards:
			if not c.placed:
				p.try_place(c, p.targets[str(c.item["target"])])
				await wait(0.05)
	var tt := 0.0
	while not p._finished:
		await wait(0.1)
		tt += 0.1
		if tt > 10:
			_fail("puzzle %s did not finish" % label)
			return
	await wait(0.4)
	await shot("done_" + label)
	p.completed.emit(p.stats)
