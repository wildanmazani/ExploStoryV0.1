extends Node
## End-to-end play-through used by CI and for screenshots.
## Run:  godot --path . -- --autotest [--shots=/abs/dir]
## title -> guest login -> prologue -> wake-up in Bilik Alif (bag, first
## mission, map arrow) -> every Bab 1 puzzle at
## its place in the world (one wrong try + Pau hints each) -> summaries ->
## penutup -> Beg Alif -> lobby, then prints AUTOTEST PASS (exit 0, 1 on fail).

const UI = preload("res://scripts/ui/ui.gd")
const TIMEOUT := 1200.0

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
	# tap through every dialogue (--watch: hands off, cutscenes must play by themselves)
	if Main.dialog_box.visible and _adv_t > 0.08 and not "--watch" in OS.get_cmdline_user_args():
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
## group chat, room, reading, then the dream: classmates at the port, Nirbana
## in Gua Warisan. It is a cutscene: the dialogue taps above just hurry it.
func _check_prologue() -> bool:
	await wait_screen("prologue")
	var phases := {}
	var dream_shots := {"bg_pelabuhan_huru": false, "rakan_aisyah_north": false, "nirbana_south": false}
	var tw := 0.0
	while screen_name() == "prologue" and tw < 480.0:
		var ph := str(scene().phase)
		if ph != "" and not phases.has(ph):
			phases[ph] = true
			await wait(1.2)
			await shot("prologue_" + ph)
			if screen_name() != "prologue":
				break
		if ph == "reading" and not phases.has("ingatan") and int(scene()._words_read) >= 3:
			phases["ingatan"] = true  # key words in the jar, the oldest falling out
			await shot("prologue_ingatan")
		for c in scene().get_children():
			if c is TextureRect and c.texture:
				for k in dream_shots:
					if not dream_shots[k] and c.texture.resource_path.get_file().get_basename() == k and c.modulate.a > 0.9:
						dream_shots[k] = true
						await shot("prologue_" + k)
		await wait(0.1)
		tw += 0.1
	for ph in ["phone", "room", "reading", "doze", "port", "gua"]:
		if not phases.has(ph):
			_fail("prologue never reached '%s' (got %s)" % [ph, str(phases.keys())])
			return false
	if dream_shots.values().has(false):
		_fail("prologue dream scenes not shown: %s" % str(dream_shots))
		return false
	return true


func _run() -> void:
	if "--only=brawl" in OS.get_cmdline_user_args():
		# quick loop while working on the Gelanggang
		await wait_screen("title")
		Game.load_profile("Tetamu", "guest")
		Game.goto("lobby")
		await wait_screen("lobby")
		await shot("lobby")
		await _check_brawl()
		print("AUTOTEST PASS (brawl only)")
		get_tree().quit(0)
		return
	if "--only=ronda3" in OS.get_cmdline_user_args():
		await _check_ronda3()
		return
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

	# ---- prologue + the wake-up in Alif's room, played in full
	if not await _check_prologue():
		return
	if not await _check_bilik():
		return
	if "--only=prologue" in OS.get_cmdline_user_args():
		# quick loop while working on the introduction
		await wait_idle(240)
		await shot("world_start")
		print("AUTOTEST PASS (prologue only) in %d s" % int(_t))
		get_tree().quit(0)
		return
	await wait_idle(120)
	await wait(0.5)
	await shot("world_start")
	# first visit to Kampung Jejak: title card + why we are here (once only)
	scene().player.place_at(Vector2i(31, 31))
	scene()._enter_area_at(Vector2i(31, 31))
	await wait(0.9)
	await shot("area_card_kampung")
	await wait_idle()
	var seen_n: int = Game.save["seen"].size()
	scene()._enter_area_at(Vector2i(31, 31))
	await wait_idle()
	if Game.save["seen"].size() != seen_n:
		_fail("area intro should only play once")
		return

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

	# ---- Bab 1: the four zones, each puzzle at its spot in the world
	if not await _play_zones(Game.chapter_zones(1)):
		return
	if not await _play_ujian(1, true):
		return
	if not await _finish_penutup("bab2"):
		return
	await wait_screen("world")
	await wait_idle()
	await shot("world_after_bab1")
	scene().hud.set_menu_open(true)
	await wait(0.3)
	await shot("hud_menu")
	if not scene().hud.is_menu_open():
		_fail("HUD menu did not open")
		return
	scene().hud.set_menu_open(false)
	scene().open_map()
	await wait(0.5)
	var mo: Node = Main.overlay_root().get_child(Main.overlay_root().get_child_count() - 1)
	mo._select_tab(1, "_show_keywords")
	await wait(0.3)
	await shot("map_keywords_bab1")
	var before_center: Vector2 = mo.view.center
	mo._focus_zone("1_1")
	if mo.view.center == before_center:
		_fail("tapping a keyword should move the map")
		return
	mo._kw_filter = "melaka"
	mo._fill_keywords()
	await wait(0.3)
	await shot("map_keywords_search")
	mo._kw_filter = "zzz"
	mo._fill_keywords()
	await wait(0.1)
	if mo._kw_box.get_child_count() != 1:
		_fail("keyword search with no hit should show one 'tiada' line")
		return
	mo.close()
	await wait(0.2)
	Main.open_beg()
	await wait(0.4)
	await shot("beg")
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
	await _check_papan()
	await _check_battle()
	await _check_brawl()

	# ---- Bab 2: through the Pintu Kabus into Lembah Kebangkitan, eight missions
	var ent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/entities.json"))
	GameState.spawn_cell = Vector2i(int(ent["arrive2"][0]), int(ent["arrive2"][1]))
	Game.goto("world")
	await wait_screen("world")
	await wait_idle()
	await shot("lembah_arrive")
	if scene().entities().get("misi_signs", []).size() != 8:
		_fail("Lembah should have 8 numbered mission signposts")
		return
	if scene().fog_rects().size() != 8:
		_fail("all 8 Bab 2 places should start under the Kabus, got %d" % scene().fog_rects().size())
		return
	scene().open_map()
	await wait(0.5)
	await shot("map_lembah_fog")
	close_top_overlay()
	if scene().portals.is_empty():
		_fail("Bab 2 portal should be open after Bab 1")
		return
	for c in scene().portals:
		if not scene().is_walkable(c):
			_fail("portal cell %s should be walkable" % str(c))
			return
	if not await _play_zones(Game.chapter_zones(2)):
		return
	if not await _play_ujian(2, false):
		return
	if not await _finish_penutup("bab3"):
		return
	await wait_screen("world")
	await wait_idle()
	await shot("world_after_bab2")
	if not scene().fog_rects().is_empty():
		_fail("the Kabus should be gone after Bab 2, left: %d" % scene().fog_rects().size())
		return
	if scene()._gabenor != null:
		_fail("Gabenor Sekatan should be gone after Misi 2.8")
		return
	Main.open_beg()
	await wait(0.4)
	await shot("beg_bab2")
	close_top_overlay()
	Main.open_nota()
	await wait(0.4)
	await shot("nota_bab2")
	close_top_overlay()
	BattleRules.chapter = 2
	await _check_battle()
	if not await _check_rooms():
		return

	# ---- checks
	if not Game.chapter_done(2):
		_fail("Bab 2 not marked done")
		return
	if not Game.chapter_done(1):
		_fail("Bab 1 not marked done")
		return
	for z in Game.ZONES:
		if not Game.zone_done(z):
			_fail("zone %s not done" % z)
			return
	var old_skin: String = Game.save["skin"]
	Game.save["skin"] = "melayu"
	if not Game.portrait_path("alif", "happy").ends_with("alif_melayu_happy.png"):
		_fail("Alif's dialogue portrait should follow the skin")
		return
	Game.save["skin"] = old_skin
	if not Game.save["seen"].has("area_kampung"):
		_fail("area intro for Kampung Jejak never shown")
		return
	if Game.save["artifacts"].size() < 12:
		_fail("artifacts missing: %s" % str(Game.save["artifacts"]))
		return
	print("AUTOTEST PASS level=%d exp=%d coins=%d figures=%s" % [Game.save["level"], Game.save["exp"], Game.save["coins"], str(Game.save["figures"])])
	get_tree().quit(0)


## Plays every zone in the list: walks to each step's spot, solves its puzzle,
## then continues from the summary. False (after _fail) if something broke.
func _play_zones(zones: Array) -> bool:
	for z in zones:
		if z == "1_3":
			GameState.go_to("res://scenes/interior/balai.tscn")
			await wait_screen("balai")
			await wait_idle()
		elif screen_name() != "world":
			await wait_screen("world")
			await wait_idle()
		await shot("zone_" + z)
		if z == "2_8" and screen_name() == "world" and scene()._gabenor == null:
			_fail("Gabenor Sekatan should guard the Menara during Misi 2.8")
			return false
		for s in Game.zone_data(z)["steps"]:
			if not _walk_to(str(s["at"])):
				_fail("no spot for %s in %s" % [s["at"], screen_name()])
				return false
			var tt := 0.0
			while Game.active_puzzle == null:
				await wait(0.1)
				tt += 0.1
				if tt > 30:
					_fail("puzzle %s never opened" % s["puzzle"])
					return false
			await wait(0.4)
			await _solve(Game.active_puzzle, "%s_%s" % [z, s["puzzle"]])
			await wait_idle(60)
			await wait(0.3)
			if s == Game.zone_data(z)["steps"][0]:
				await shot("world_after_%s" % s["puzzle"])
		await wait_screen("zone_summary", 40)
		await shot("summary_" + z)
		hosted()._continue()
		if not Game.is_last_zone(z):
			await wait_screen("world")
			await wait_idle()
	return true


## Ujian Bab after a chapter's last summary. With fail_first: lose all hearts,
## go back to revise, check the boss blocks the way on the map, talk to him and
## pass. Passing = 7 right answers.
func _play_ujian(ch: int, fail_first: bool) -> bool:
	await wait_screen("ujian", 30)
	if fail_first:
		var p = await _ujian_puzzle()
		if p == null:
			return false
		await shot("ujian_%d" % ch)
		for i in 3:
			p._pick((int(p._q()["answer"]) + 1) % 4)
			await wait(0.2)
			if i < 2:
				p._advance()
		await wait(3.0)
		await wait_idle()
		var back := find_button(hosted(), "Ulang kaji")
		if back == null:
			_fail("Ujian fail card missing")
			return false
		await shot("ujian_%d_fail" % ch)
		back.pressed.emit()
		await wait_screen("world")
		await wait_idle()
		if Game.chapter_done(ch) or not scene().portals.is_empty() and ch == 1:
			_fail("chapter %d should stay closed until the Ujian is passed" % ch)
			return false
		if not _walk_to(str(Game.ujian_def(ch)["npc"])):
			_fail("Ujian boss %d not on the map" % ch)
			return false
		await shot("ujian_%d_boss_on_map" % ch)
		await wait_screen("ujian", 30)
	var q = await _ujian_puzzle()
	if q == null:
		return false
	for i in int(Game.ujian_def(ch)["need"]):
		q._pick(int(q._q()["answer"]))
		await wait(0.2)
		if i == 2:
			await shot("ujian_%d_hp" % ch)
		if q.get("_next").visible:
			q._advance()
	await wait(2.0)
	var go := find_button(q, "Teruskan")
	if go == null:
		_fail("Ujian %d not won" % ch)
		return false
	go.pressed.emit()
	if not Game.save["ujian"].has(ch):
		_fail("Ujian %d not saved" % ch)
		return false
	return true


func _ujian_puzzle():
	var t := 0.0
	while Game.active_puzzle == null:
		await wait(0.1)
		t += 0.1
		if t > 60:
			_fail("Ujian puzzle never opened")
			return null
	await wait(0.4)
	return Game.active_puzzle


## Pau wakes Alif in his room and explains; the start prompt sits on the bag,
## the door waits for it, then Misi 1.1 starts and the map arrow points there.
func _check_bilik() -> bool:
	await wait_screen("bilik_alif", 120)
	await wait(2.0)
	await shot("bilik_wake")
	var t := 0.0
	while not scene()._waiting_bag:
		await wait(0.2)
		t += 0.2
		if t > 240.0:
			_fail("the wake-up never got to the bag")
			return false
	await wait(0.5)
	await shot("bilik_start_prompt")
	if scene()._prompt == null:
		_fail("no start prompt over the bag")
		return false
	scene()._leave()
	await wait(0.5)
	if screen_name() != "bilik_alif":
		_fail("Alif left his room without the bag")
		return false
	scene().player.place_at(Vector2i(12, 8), "north")
	scene()._interact(Vector2i(12, 7))
	await wait_idle(120)
	if not Game.save["seen"].has("bilik_tutorial") or scene()._prompt != null:
		_fail("taking the bag should clear the prompt and start Misi 1.1")
		return false
	await shot("bilik_mission_start")
	scene()._leave()
	await wait_screen("world", 60)
	var goal: Dictionary = scene().objective()
	if str(goal.get("name", "")) != "Misi 1.1":
		_fail("the map arrow should point at Misi 1.1, not %s" % str(goal))
		return false
	await shot("world_arrow")
	return true


## The story rooms: enter from the map door, read every exhibit,
## walk out again.
func _check_rooms() -> bool:
	for id in ["rumah_alif", "sitc", "jelutong_press"]:
		Game.goto("world")
		await wait_screen("world")
		await wait_idle()
		scene()._talk_or_act(id)
		var room: String = scene().ROOMS[id][0].get_file().get_basename()
		await wait_screen(room, 30)
		await wait_idle()
		await shot("room_" + room)
		var s := scene()
		if s._exhibits.is_empty():
			_fail("room %s has no exhibits" % room)
			return false
		for ex in s._exhibits:
			s._interact(s._exhibits[ex]["cells"][0])
			await wait(0.2)
			for c in Main.overlay_root().get_children():
				if c.has_method("close"):
					c.close()
			await wait_idle()
		if s.npc:  # Bilik Alif has nobody but Pau
			s._interact(s.npc.cell)
			await wait_idle()
		s._on_step(s.exit_cells[0])
		await wait_screen("world", 30)
		await wait_idle()
	return true


## Clicks through the chapter ending: flag, Nota Alif, wellbeing card, teaser.
func _finish_penutup(teaser: String) -> bool:
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
			await shot("nota_alif_" + teaser)
			nota.close()
		elif not Main.dialog_box.visible:
			var b := find_button(hosted(), "Teruskan")
			if b == null:
				b = find_button(hosted(), "KEMBALI")
				if b:
					await shot("teaser_" + teaser)
			if b:
				b.pressed.emit()
		elif not shot_flag:
			shot_flag = true
			await shot("penutup_flag_" + teaser)
		await wait(0.2)
		t += 0.2
		if t > 120:
			_fail("penutup stuck")
			return false
	return true


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
	var shot_ko := false
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
		if not shot_ko and st == "question" and BattleRules.alive(b.state["players"]).size() < b.state["players"].size():
			shot_ko = true
			Engine.time_scale = 1.0
			await wait(0.6)
			await shot("battle_knocked_out")
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


## Gelanggang Pesta Silat in every format, a bot playing for you (autopilot).
## Damage only lands in AKSI, Lemah hits weaker than Semangat, someone
## faints, the match ends and the winners get their syiling.
func _check_brawl() -> void:
	for fmt in ["1v1", "2v2", "1v2", "1v3"]:
		var coins := int(Game.save["coins"])
		Game.goto("gelanggang", {"format": fmt, "level": "mudah", "autopilot": true})
		await wait_screen("gelanggang")
		var s := hosted()
		var m: BrawlMatch = s.match_node
		var sizes: Array = BrawlRules.FORMATS[fmt]
		if m.team_alive(0).size() != sizes[0] or m.team_alive(1).size() != sizes[1]:
			_fail("brawl %s: wrong team sizes" % fmt)
			return
		Engine.time_scale = 1.0 if fmt == "1v1" and shots_dir != "" else 4.0
		var shots_done := {}
		var hp_at_question := -1
		var t := 0.0
		var hits := {"weak": 0, "full": 0}   # lambdas capture by value: count in a dictionary
		m.hit_landed.connect(func(by, _target, dmg):
			if m.phase != "aksi":
				_fail("brawl: damage outside AKSI")
			if by.mult < 1.0:
				hits["weak"] += 1
				if dmg > 4:
					_fail("brawl: Lemah hit did %d" % dmg)
			else:
				hits["full"] += 1)
		while m.phase != "tamat":
			if fmt == "1v1":
				if m.phase == "soalan" and not shots_done.has("q") and m.phase_t > 0.5:
					shots_done["q"] = true
					await shot("brawl_soalan")
				elif m.phase == "keputusan" and not shots_done.has("k") and m.phase_t > 0.4:
					shots_done["k"] = true
					await shot("brawl_keputusan")
				elif m.phase == "aksi" and not shots_done.has("a") and m.phase_t > 2.5:
					shots_done["a"] = true
					await shot("brawl_aksi")
				elif m.phase == "aksi" and not shots_done.has("a2") and m.phase_t > 6.0:
					shots_done["a2"] = true
					await shot("brawl_aksi_2")
					Engine.time_scale = 4.0
			elif m.phase == "aksi" and not shots_done.has("a") and m.phase_t > 3.0:
				shots_done["a"] = true
				Engine.time_scale = 1.0
				await shot("brawl_%s" % fmt)
				Engine.time_scale = 4.0
			if m.phase == "soalan" and hp_at_question < 0:
				hp_at_question = 0
				for f in m.fighters:
					hp_at_question += f.hp
			await wait(0.1)
			t += 0.1
			if t > 200.0:
				Engine.time_scale = 1.0
				_fail("brawl %s never finished (round %d, phase %s)" % [fmt, m.round_no, m.phase])
				return
		Engine.time_scale = 1.0
		await wait(0.6)
		await shot("brawl_result_%s" % fmt)
		if hits["full"] == 0:
			_fail("brawl %s: no full-power hits landed" % fmt)
			return
		var won := m.winner_team == 0
		if won and int(Game.save["coins"]) != coins + BrawlRules.REWARD_COINS:
			_fail("brawl %s: winners should get %d syiling" % [fmt, BrawlRules.REWARD_COINS])
			return
		print("brawl %s: rounds=%d won=%s hits full=%d weak=%d" % [fmt, m.round_no, str(won), hits["full"], hits["weak"]])
	Game.goto("lobby")
	await wait_screen("lobby")


## Papan Markah offline: sample classmates + you, ranked by EXP then wins.
func _check_papan() -> void:
	var rows: Array = load("res://scripts/ui/papan_panel.gd").sample_rows("all")
	var mine: Dictionary = rows.filter(func(r): return r["me"])[0]
	var above := rows.filter(func(r): return not r["me"] and (r["exp"] > mine["exp"] or (r["exp"] == mine["exp"] and r["wins"] > mine["wins"]))).size()
	if int(mine["rank"]) != above + 1:
		_fail("papan: my rank %d, expected %d" % [int(mine["rank"]), above + 1])
		return
	var pp: Node = Main.open_papan()
	await wait(0.4)
	await shot("papan_seluruh")
	pp._show(1)
	await wait(0.3)
	await shot("papan_negeri")
	pp._show(2)
	await wait(0.3)
	await shot("papan_rakan")
	pp.close()
	await wait(0.2)


## Profil & Kedai: buy and wear a skin with the syiling earned in Bab 1.
func _check_shop() -> void:
	var before := int(Game.save["coins"])
	Game.save["profile"]["negeri"] = "Melaka"
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
	if scene().hud._avatar.texture != UI.head("alif_pengakap"):
		_fail("HUD picture should follow the outfit")
		return


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


## Playtest round 3 (2026-10-24): room exit, mission replay, Nota huraian,
## Ujian Bab feedback, Gelanggang Cara Main / Jeda / key layouts.
func _check_ronda3() -> void:
	await wait_screen("title")
	Game.load_profile("Tetamu", "guest")
	Game.save["prolog_done"] = true
	for z in Game.chapter_zones(1):
		var st := Game.zone_state(z)
		st["done"] = true
		st["steps"] = []
		for step in Game.zone_data(z).get("steps", []):
			st["steps"].append(step["puzzle"])
	Game.persist()
	# room: Keluar arrow + HUD button take Alif back outside
	GameState.go_to("res://scenes/interior/balai.tscn")
	await wait_screen("balai")
	await wait_idle()
	await shot("r3_balai_exit")
	var out := find_button(scene(), "Keluar")
	if out == null:
		_fail("no Keluar button in the Balai")
		return
	out.pressed.emit()
	await wait_screen("world")
	print("ronda3: Keluar ok")
	# replay a finished mission from its NPC
	GameState.go_to("res://scenes/interior/balai.tscn")
	await wait_screen("balai")
	await wait_idle()
	var exp_before := int(Game.save["exp"])
	scene()._interact(scene().npc.cell)
	await wait(0.8)
	await shot("r3_replay_ask")
	var yes := find_button(Main.overlay_root(), "Main semula")
	if yes == null:
		_fail("no replay prompt")
		return
	yes.pressed.emit()
	var t := 0.0
	while Game.active_puzzle == null and t < 20.0:
		await wait(0.2)
		t += 0.2
	if not Game.zone_state("1_3").has("replay") or Game.active_puzzle == null:
		_fail("replay did not start")
		return
	await shot("r3_replay_puzzle")
	print("ronda3: replay started, exp before ", exp_before)
	# Nota opens on the mission page with the huraian
	var n: Control = Main.open_nota("1_3")
	await wait(0.6)
	await shot("r3_nota_top")
	n._scroll.scroll_vertical = 600
	await wait(0.3)
	await shot("r3_nota_huraian")
	n.close()
	Game.active_puzzle.queue_free()
	Game.active_puzzle = null
	Game.unlock_input()
	# Ujian Bab: lose every heart, then the feedback card
	Game.goto("ujian", {"chapter": 1})
	await wait_screen("ujian")
	t = 0.0
	while Game.active_puzzle == null and t < 30.0:
		await wait(0.2)
		t += 0.2
	for k in 3:
		var p = Game.active_puzzle
		if p == null:
			break
		p._pick((int(p._q()["answer"]) + 1) % 4)
		await wait(0.4)
		if p._next.visible:
			p._advance()
			await wait(0.3)
	await wait(4.0)
	await shot("r3_ujian_fail")
	if find_button(scene(), "Cuba lagi") == null:
		_fail("no fail card")
		return
	print("ronda3: ujian feedback ok")
	# Gelanggang: first visit shows Cara Main, then Jeda works
	Game.save["seen"].erase("gelanggang_cara")
	Game.goto("gelanggang", {"format": "1v1", "level": "mudah"})
	await wait_screen("gelanggang", 30.0)
	await wait(0.5)
	await shot("r3_brawl_guide")
	var ok := find_button(scene(), "Mula")
	if ok == null:
		_fail("no Cara Main before the first match")
		return
	ok.pressed.emit()
	await wait(1.0)
	hosted()._open_pause()
	await wait(0.4)
	await shot("r3_brawl_pause")
	find_button(scene(), "Cara main").pressed.emit()
	await wait(0.3)
	find_button(scene(), "Anak panah").pressed.emit()
	await wait(0.3)
	await shot("r3_brawl_keys_panah")
	if Game.brawl_scheme() != "panah":
		_fail("layout switch")
		return
	Game.set_setting("brawl_keys", "wasd")
	hosted()._close_pause()
	print("AUTOTEST PASS (ronda3)")
	get_tree().quit(0)
