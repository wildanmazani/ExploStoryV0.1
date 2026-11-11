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
## after Bab 1: the Arena yards on both islands (sparring players, dummies,
## board) and the Jalan Pintas in Beg Alif (locked places refuse)
## Walk through the Pintu Kabus from Kampung Jejak, as a player does: one
## conversation at a time on arrival (no area card or mission briefing on top
## of it), Alif lands clear of the way back, and walking back works too.
func _check_portal() -> bool:
	for s in ["beg_alif", "bilik_tutorial", "arena_dibuka"]:
		if not Game.save["seen"].has(s):
			Game.save["seen"].append(s)
	for z in Game.chapter_zones(1):
		Game.zone_state(z)["done"] = true
	if not Game.chapter_done(1):
		Game.save["chapters_done"].append(1)
	Game.save["map_pos"] = [11, 28]
	Game.goto("world")
	await wait_screen("world")
	await wait_idle()
	var w := scene()
	w.player.place_at(Vector2i(11, 27), "north")
	w.player._try_step(Vector2i(0, -1))
	await _wait_reload(w)
	# the first seconds in Lembah: who talks, and what else opens
	var t := 0.0
	var clash := ""
	while t < 25.0:
		var preps := Main.overlay_root().get_children().filter(func(c): return str(c.get_script().resource_path).ends_with("zone_prep.gd") if c.get_script() else false)
		var card: bool = scene().title_card.modulate.a > 0.1
		if Main.dialog_box.visible and (not preps.is_empty() or card):
			clash = "dialogue with %s on top" % ("a mission briefing" if not preps.is_empty() else "the area card")
			await shot("portal_clash")
			break
		await _close_preps()
		await wait(0.05)
		t += 0.05
	if clash != "":
		_fail("arriving in Lembah: " + clash)
		return false
	await wait_idle()
	w = scene()
	await shot("portal_lembah")
	if w.player.cell.x < 82:
		_fail("the portal should take Alif to Lembah, he is at %s" % str(w.player.cell))
		return false
	var near := false
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if w.portals.has(w.player.cell + d):
			near = true
	if near:
		_fail("Alif lands right next to the way back (%s): one step and he is home again" % str(w.player.cell))
		return false
	# and back home through the gate behind him
	var back: Vector2i = w.portals.keys().filter(func(c): return c.x >= 82)[0]
	w.player.place_at(back + Vector2i(0, 1), "north")
	w.player._try_step(Vector2i(0, -1))
	await _wait_reload(w)
	await wait_idle()
	w = scene()
	await shot("portal_home")
	if w.player.cell.x >= 82 or w.portals.has(w.player.cell + Vector2i.UP):
		_fail("walking back should land in Kampung Jejak, a step clear of the gate: %s" % str(w.player.cell))
		return false
	return true


func _check_arena_travel() -> bool:
	var w := scene()
	if w.entities().get("arenas", []).size() != 2:
		_fail("there should be an Arena yard on each island")
		return false
	var beg: Node = Main.open_beg(w)
	await wait(0.3)
	if find_button(beg, "Jalan Pintas") == null:
		_fail("Beg Alif in the world should have a Jalan Pintas tab")
		return false
	beg._show_travel()
	await wait(0.3)
	await shot("beg_jalan_pintas")
	close_top_overlay()
	var by_id := {}
	for t in w.travel_places():
		by_id[str(t["place"]["id"])] = t
	if not by_id["pelabuhan"]["ok"] or not by_id["arena_lembah"]["ok"]:
		_fail("after Bab 1, Misi 1.2 and Lembah should be open for Jalan Pintas")
		return false
	if by_id["serantau"]["ok"]:
		_fail("Misi 2.4 should still be locked for Jalan Pintas")
		return false
	# Kampung Jejak arena yard
	w.fast_travel({"at": [40, 38], "name": "Arena Ulang Kaji"})
	await _wait_reload(w)
	await wait_idle()
	await shot("arena_yard")
	# across the Pintu Kabus to the Lembah arena, then back to the port
	w = scene()
	w.fast_travel(by_id["arena_lembah"]["place"])
	await _wait_reload(w)
	await wait_idle()
	if scene().player.cell.x < 82:
		_fail("Jalan Pintas to Arena Lembah should land in Lembah, at %s" % str(scene().player.cell))
		return false
	await shot("arena_lembah")
	w = scene()
	w.fast_travel(by_id["pelabuhan"]["place"])
	await _wait_reload(w)
	await wait_idle()
	if (scene().player.cell - Vector2i(61, 41)).length() > 4.0:
		_fail("Jalan Pintas to Misi 1.2 landed at %s" % str(scene().player.cell))
		return false
	return true


## a world that reloads itself (Jalan Pintas, Pintu Kabus): wait for the new one
func _wait_reload(old: Node) -> void:
	var t := 0.0
	while scene() == old or scene() == null:
		await wait(0.1)
		t += 0.1
		if t > 15.0:
			_fail("the world did not reload")
			return
	await wait_screen("world")


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
			if scene().book_text.get_content_height() > scene().PAGE_LEFT.size.y:
				_fail("the textbook paragraph is taller than its page")
				return false
			await shot("prologue_ingatan")
		var room: Control = scene().room  # the dream is seen through Alif's eyes: in the picture
		for c in [room] + room.get_children() + scene().get_children():
			if is_instance_valid(c) and c is TextureRect and c.texture and c.is_visible_in_tree():
				for k in dream_shots:
					if not dream_shots[k] and c.texture.resource_path.get_file().get_basename() == k and c.modulate.a > 0.9:
						dream_shots[k] = true
						await shot("prologue_" + k)
		await wait(0.1)
		tw += 0.1
	for ph in ["phone", "room", "reading", "doze", "port", "lari", "gua"]:
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
	if "--only=portal" in OS.get_cmdline_user_args():
		await wait_screen("title")
		Game.load_profile("Tetamu", "guest")
		if await _check_portal():
			print("AUTOTEST PASS (portal only) in %d s" % int(_t))
			get_tree().quit(0)
		return
	if "--only=demo" in OS.get_cmdline_user_args():
		# a clip for social media: Alif (autopilot) vs a bot in the Gelanggang,
		# recorded with Godot's Movie Maker (--write-movie <file>.avi)
		await wait_screen("title")
		Game.load_profile("Tetamu", "guest")
		Game.save["seen"].append("gelanggang_cara")
		Game.goto("gelanggang", {"format": "1v1", "level": "sukar", "autopilot": true})
		await wait_screen("gelanggang")
		var dm: BrawlMatch = hosted().match_node
		var dt := 0.0
		while dm.phase != "tamat" and dt < 150.0:
			await wait(0.1)
			dt += 0.1
		await wait(4.0)
		print("AUTOTEST PASS (demo) %d s" % int(dt))
		get_tree().quit(0)
		return
	if "--only=narator" in OS.get_cmdline_user_args():
		# the dialogue box: a narrator line, then a speaker after it
		await wait_screen("title")
		Game.load_profile("Tetamu", "guest")
		Game.save["prolog_done"] = true
		Game.goto("world")
		await wait_screen("world")
		await wait_idle(240)
		Game.say([{"s": "narator", "t": "Seorang budak perempuan terbaring di tengah jalan, berselubung debu."},
			{"s": "aisyah", "t": "Aduh... sakitnya badan aku..."}])
		await wait(2.5)  # run with --watch, or the autotest clicks it away
		await shot("dialog_narator")
		Main.dialog_box._advance()
		await wait(2.5)
		await shot("dialog_aisyah")
		print("AUTOTEST PASS (narator)")
		get_tree().quit(0)
		return
	if "--only=lupa" in OS.get_cmdline_user_args():
		await wait_screen("title")
		if await _check_lupa():
			print("AUTOTEST PASS (lupa only)")
			get_tree().quit(0)
		return
	if "--only=arka" in OS.get_cmdline_user_args():
		await wait_screen("title")
		Game.load_profile("Tetamu", "guest")
		Game.goto("arka")
		await wait_screen("arka")
		hosted()._show_arc(1)
		await wait(0.3)
		await shot("arka_t5_locked")
		if await _check_t5_subtopik():
			print("AUTOTEST PASS (arka only)")
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
	if not await _check_lupa():
		return
	Game.goto("register")
	await wait_screen("register")
	await shot("register")
	Game.goto("login")
	await wait_screen("login")
	hosted()._start_guest()

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

	# the Arena stays shut until the first artifact
	if Game.arena_open():
		_fail("the Arena should be shut before the first artifact")
		return
	await scene()._talk_or_act("arena")
	await wait(0.6)
	if screen_name() != "world":
		_fail("the Arena should refuse Alif before Bab 1 is done")
		return

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
	if MapView.veiled(100.0):
		_fail("the Bab 2 silhouette should open with Bab 1")
		return
	if not Game.save["seen"].has("arena_dibuka") or scene().camera.offset != Vector2.ZERO or scene().busy:
		_fail("the Arena reveal should have played once and returned to Alif")
		return
	# watch it again for a picture of the glide
	Game.save["seen"].erase("arena_dibuka")
	scene()._arena_reveal()
	await wait(2.9)
	var seen_at: Vector2 = scene().camera.get_screen_center_position()
	if seen_at.distance_to(scene().ARENA_VIEW * 16.0) > 32.0:
		_fail("the Arena reveal should centre on the Arena, at %s" % str(seen_at))
		return
	await shot("arena_reveal")
	await wait_idle()
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
	if not await _check_arena_travel():
		return
	await _check_shop()
	Game.goto("arka")
	await wait_screen("arka")
	await shot("arka")
	hosted()._enter({"no": 2}, false)
	hosted()._show_arc(1)
	await wait(0.3)
	await shot("arka_t5_locked")
	if not await _check_t5_subtopik():
		return
	Game.goto("lobby")
	await wait_screen("lobby")
	await shot("lobby")
	await _check_papan()
	await _check_battle()
	await _check_brawl()

	# ---- Bab 2: through the Pintu Kabus into Lembah Kebangkitan, eight missions
	var ent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/entities.json"))
	if not Game.save["seen"].has("lembah_intro"):
		_fail("the Lembah scene should have played on the first trip there (Jalan Pintas)")
		return
	Game.save["seen"].erase("lembah_intro")  # once more, to watch it here
	GameState.spawn_cell = Vector2i(int(ent["arrive2"][0]), int(ent["arrive2"][1]))
	Game.goto("world")
	await wait_screen("world")
	if not await _check_lembah_intro():
		return
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
	# --dump-save=<file>: keep this finished save (Bab 1 and 2 done), e.g. for
	# a demo account with everything done
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump-save="):
			var f := FileAccess.open(a.trim_prefix("--dump-save="), FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(Game.save, "  "))
				f.close()
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
		if z.begins_with("2_") and screen_name() == "world" and not await _take_klu(z):
			return false
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
		if z == "1_1":
			await _skip_rating("kotak_bintang_1_1")
		if not Game.is_last_zone(z):
			await wait_screen("world")
			await wait_idle()
	return true


## Ujian Bab after a chapter's last summary. With fail_first: lose all hearts,
## go back to revise, check the boss blocks the way on the map, talk to him and
## pass. Passing = 7 right answers.
## let a boss fight play out, sped up (name = a picture from the middle of it)
func _boss_fight(p: Node, name: String) -> void:
	Engine.time_scale = 1.0 if name != "" else 6.0
	await wait(0.55)
	if name != "":
		await shot(name)
		Engine.time_scale = 6.0
	var guard := 0
	while p.get("_cutting") and guard < 300:
		await wait(0.1)
		guard += 1
	Engine.time_scale = 1.0
	await wait(0.2)


func _play_ujian(ch: int, fail_first: bool) -> bool:
	await wait_screen("ujian", 30)
	if fail_first:
		var p = await _ujian_puzzle()
		if p == null:
			return false
		await shot("ujian_%d" % ch)
		for i in 3:
			p._pick((int(p._q()["answer"]) + 1) % 4)
			await _boss_fight(p, "ujian_%d_hurt" % ch if i == 0 else "")
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
	if Game.ujian_def(ch).get("brawl", false):
		return await _ujian_brawl(ch)
	var q = await _ujian_puzzle()
	if q == null:
		return false
	for i in int(Game.ujian_def(ch)["need"]):
		q._pick(int(q._q()["answer"]))
		await _boss_fight(q, "ujian_%d_hit" % ch if i == 2 else "")
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


## Ujian Bab 2: find Aisyah, then fight Kapten John in the Gelanggang with
## Bab 2 questions; a win goes back to the Ujian (win scene) and the penutup
func _ujian_brawl(ch: int) -> bool:
	if not await _find_aisyah():
		return false
	await wait_screen("gelanggang", 60)
	var s := hosted()
	var m: BrawlMatch = s.match_node
	if not m.fighters.any(func(f): return f.skin == "kapten_john" and f.display_name == "Kapten John"):
		_fail("Ujian %d should be against Kapten John" % ch)
		return false
	if BattleRules.chapter != ch:
		_fail("Ujian %d should ask Bab %d questions" % [ch, ch])
		return false
	if s._pause:
		s._close_pause()
	m.me_autopilot = true
	Engine.time_scale = 4.0
	var shot_done := false
	var t := 0.0
	while m.phase != "tamat":
		if m.phase == "aksi":
			for f in m.fighters:
				if not f.is_me:
					f.hp = mini(f.hp, 2)  # let the test win
			if not shot_done:
				shot_done = true
				Engine.time_scale = 1.0
				await wait(0.6)
				await shot("ujian_%d_gelanggang" % ch)
				Engine.time_scale = 4.0
		await wait(0.1)
		t += 0.1
		if t > 120.0:
			Engine.time_scale = 1.0
			_fail("the Kapten John fight never ended")
			return false
	Engine.time_scale = 1.0
	await wait(1.5)
	await shot("ujian_%d_menang" % ch)
	var go := find_button(s, "Teruskan")
	if go == null:
		_fail("Ujian %d fight not won" % ch)
		return false
	go.pressed.emit()
	await wait_screen("penutup", 60)
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


## Lembah Kebangkitan, the first time: the officer and the girl in white, Pak
## Wahab, no HUD until it is over, never twice.
func _check_lembah_intro() -> bool:
	var w := scene()
	if not w.busy or w.hud.visible:
		_fail("the Lembah scene should start at once, with the HUD hidden")
		return false
	var shot_pegawai := false
	var t := 0.0
	while not Game.save["seen"].has("lembah_intro"):
		if not shot_pegawai and w.objects.get_children().any(func(n): return n is Npc and n.id == "kapten_john"):
			shot_pegawai = true
			await wait(0.8)
			await shot("lembah_pegawai")
		await wait(0.1)
		t += 0.1
		if t > 120.0:
			_fail("the Lembah scene never finished")
			return false
	await wait_idle()
	if not shot_pegawai or w.npc_node("pakcik_lembah") == null or not w.hud.visible or not w.player.can_move:
		_fail("Lembah scene: officer %s, Pak Wahab %s, then Alif free" % [shot_pegawai, w.npc_node("pakcik_lembah")])
		return false
	return true


## after a Bab 2 mission: a clue may be glowing nearby; the arrow points there
## first, it goes into Beg Alif, and Misi 2.8 stays shut until all four
func _take_klu(z: String) -> bool:
	var w := scene()
	for no in w.klu_nodes.keys():
		if str(w.objective().get("name", "")) != "Klu Aisyah":
			_fail("the gold arrow should point at the waiting clue, not %s" % str(w.objective()))
			return false
		if no == 4 and Game.zone_unlocked("2_8"):
			_fail("Misi 2.8 should wait for the fourth clue")
			return false
		await w._talk_or_act("klu_aisyah_%d" % no)
		await wait_idle()
		if not Game.klu_found(no) or w.klu_nodes.has(no):
			_fail("clue %d was not taken" % no)
			return false
		if no in [2, 4]:
			Main.open_beg(w)
			await wait(0.4)
			await shot("beg_klu_%d" % no)
			close_top_overlay()
	if z == "2_8" and (Game.klu_count() != 4 or not Game.zone_unlocked("2_8")):
		_fail("Misi 2.8 should open with all 4 clues (%d)" % Game.klu_count())
		return false
	return true


## Gua Kabus: three girls in white; a wrong one first (no fight yet), then her
func _find_aisyah() -> bool:
	if Game.save["seen"].has("aisyah_dikenal"):
		return true
	var pick: Node = null
	var t := 0.0
	while pick == null:
		for n in get_tree().root.find_children("*", "Control", true, false):
			if str(n.get_script().resource_path if n.get_script() else "").ends_with("aisyah_pilih.gd"):
				pick = n
		await wait(0.1)
		t += 0.1
		if t > 60.0:
			_fail("the Gua Kabus line-up never opened")
			return false
	await wait(0.5)
	await shot("aisyah_pilih")
	for b in pick.cards:
		if int(b.get_meta("girl")) != 0:
			pick._pick(b)
			break
	await wait(0.4)
	await wait_idle()
	if Game.active_puzzle != null or not is_instance_valid(pick):
		_fail("a wrong girl should not start the Ujian")
		return false
	for b in pick.cards:
		if int(b.get_meta("girl")) == 0:
			pick._pick(b)
	return true


## Pau wakes Alif in his room and explains; the start prompt sits on the bag,
## the door waits for it, then Misi 1.1 starts and the map arrow points there.
func _check_bilik() -> bool:
	await wait_screen("bilik_alif", 120)
	await wait(2.0)
	await shot("bilik_wake")
	var t := 0.0
	var seen_shards := false
	while not scene()._waiting_bag:
		if scene().shards_up and not seen_shards:
			seen_shards = true
			await wait(2.4)
			await shot("bilik_siluet")
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
	if scene().player.bag_on():
		_fail("before he picks up his bag, Alif should not wear one")
		return false
	scene()._leave()
	await wait(0.5)
	if screen_name() != "bilik_alif":
		_fail("Alif left his room without the bag")
		return false
	scene().player.place_at(Vector2i(12, 8), "north")
	scene()._interact(Vector2i(12, 7))
	await wait_screen("world", 60)
	if Game.save["seen"].has("bilik_tutorial"):
		_fail("Misi 1.1 should only start after Mak Som's map")
		return false
	if scene().player.cell != Vector2i(22, 43) or not scene().player.bag_on():
		_fail("Alif should come out of his own door, bag on, at %s" % str(scene().player.cell))
		return false
	Game.set_bag(false)
	if scene().player.bag_on() or scene().player._bag.visible:
		_fail("the bag should come off")
		return false
	Game.set_bag(true)
	if not await _check_kampung_intro():
		return false
	var goal: Dictionary = scene().objective()
	if str(goal.get("name", "")) != "Misi 1.1":
		_fail("the map arrow should point at Misi 1.1, not %s" % str(goal))
		return false
	await shot("world_arrow")
	return true


## Aisyah runs, Alif trips, Mak Som and Guru Jalal: no HUD until the stone map
## is closed, then the world is Alif's again and both go back where they live.
func _check_kampung_intro() -> bool:
	var w := scene()
	if not w.busy or w.hud.visible or w.current_area == "":
		_fail("the Kampung Jejak scene should hold the HUD back, in an area")
		return false
	if not MapView.veiled(100.0) or MapView.veiled(30.0) or w.travel_places().any(func(t): return int(t["place"]["at"][0]) >= 82):
		_fail("Bab 2 should be a silhouette on the map before Bab 1 is done")
		return false
	var mak_home: Vector2i = w.npc_node("makcik").home
	var guru_home: Vector2i = w.npc_node("guru_silat").cell
	var shots := {}
	var t := 0.0
	while not Main.overlay_root().get_children().any(func(c): return c.get("view") != null and c.get("title_text") == "PETA BAB 1"):
		if w.player.sprite.rotation > 1.0 and not shots.has("fall"):
			shots["fall"] = true
			await shot("intro_fall")
		if w.npc_node("guru_silat").cell == Vector2i(30, 32) and not shots.has("guru"):
			shots["guru"] = true
			await shot("intro_guru")
		await wait(0.1)
		t += 0.1
		if t > 200.0:
			_fail("the Kampung Jejak scene never reached the stone map")
			return false
	if not shots.has("fall") or not shots.has("guru") or w.hud.visible:
		_fail("Alif should fall and Guru Jalal come over, with no HUD: %s" % str(shots))
		return false
	await wait(0.6)
	await shot("peta_kertas")
	close_top_overlay()
	await wait_idle(120)
	if not Game.save["seen"].has("bilik_tutorial") or not w.hud.visible or not w.player.can_move or w.player.sprite.rotation != 0.0:
		_fail("after the map the player should be free, on Misi 1.1")
		return false
	if w.npc_node("makcik").cell != mak_home or (w.npc_node("guru_silat").cell - guru_home).length() > 9.0:  # he walks round the arena
		_fail("Mak Som and Guru Jalal should go back home after the scene")
		return false
	if load("res://scripts/world/kampung_intro.gd").needed():
		_fail("the Kampung Jejak scene should only play once")
		return false
	await shot("kampung_intro_done")
	# a locked Nota page: its reason reads across the page, not one letter a line
	var nota: Control = Main.open_nota("1_3")
	await wait(0.4)
	await shot("nota_berkunci")
	var why: Label = nota._page_box.get_child(1).get_child(1)
	if why.size.x < 300.0:
		_fail("the locked Nota text is squeezed to %d px wide" % int(why.size.x))
		return false
	close_top_overlay()
	# Profil > Kawan: offline it explains why there is no list
	var prof: Node = Main.open_profile(2)
	await wait(0.4)
	await shot("profil_kawan")
	if prof._tab != 2:
		_fail("the Kawan tab did not open")
		return false
	close_top_overlay()
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


## The optional star box (after Misi 1.1 and after Bab 1): picture it, then
## Nanti. Waits up to `tries` tenths of a second; true if it was there.
func _skip_rating(pic: String, tries := 10) -> bool:
	for i in tries:
		var kb := Main.overlay_root().find_child("KotakBintang", true, false)
		if kb:
			await wait(0.3)
			await shot(pic)
			find_button(kb, "Nanti").pressed.emit()
			await wait(0.3)
			return true
		await wait(0.1)
	return false


## Clicks through the chapter ending: flag, Nota Alif, wellbeing card, teaser.
func _finish_penutup(teaser: String) -> bool:
	await wait_screen("penutup", 30)
	var t := 0.0
	var shot_flag := false
	while screen_name() == "penutup":
		if await _skip_rating("kotak_bintang_" + teaser, 1):
			continue
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
	if not Game.interact_prompt("Pau").begins_with(tr("Tekan A: ")):
		_fail("with on-screen controls the prompt should name the A button")
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
		_fail("Klik sahaja should show no buttons")
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
## Playtest round 5 (2026-11-05): level curve, Ujian retake without EXP,
## MAIN SEMULA from the Beg, two ways to start again, guest log out, sign-out
func _check_ronda5() -> bool:
	for pair in [[0, 1], [99, 1], [100, 2], [299, 2], [300, 3], [999, 4], [1000, 5], [4500, 10]]:
		if Game.level_for(pair[0]) != pair[1]:
			_fail("level_for(%d) should be %d, got %d" % [pair[0], pair[1], Game.level_for(pair[0])])
			return false
	var lp := Game.level_progress(350)
	if lp != [50, 300]:
		_fail("level_progress(350) should be [50, 300], got %s" % str(lp))
		return false
	# a retaken Ujian Bab: no EXP from the fight
	if not Game.save["ujian"].has(1):
		Game.save["ujian"].append(1)
	Game.goto("gelanggang", {"format": "1v1", "level": "mudah", "ujian": 1})
	await wait_screen("gelanggang", 30.0)
	await wait(0.5)
	if not hosted().match_node.no_reward:
		_fail("a retaken Ujian should give no EXP")
		return false
	hosted()._open_pause()
	hosted()._leave()
	await wait(1.0)
	# MAIN SEMULA in Beg > Jalan Pintas
	Game.zone_state("1_1").erase("replay")
	Game.zone_state("1_3").erase("replay")
	Game.save["map_pos"] = [40, 38]
	Game.goto("world")
	await wait_screen("world", 30.0)
	await wait_idle()
	var exp_before := int(Game.save["exp"])
	var beg: Node = Main.open_beg(scene())
	await wait(0.4)
	beg._show_travel()
	await wait(0.4)
	await shot("r5_main_semula")
	var again := beg.find_child("MainSemula_1_1", true, false) as Button
	if again == null:
		_fail("no MAIN SEMULA for a finished mission in Jalan Pintas")
		return false
	again.pressed.emit()
	await wait(1.5)
	await wait_screen("world", 30.0)
	if not Game.zone_state("1_1").has("replay") or int(Game.save["exp"]) != exp_before:
		_fail("MAIN SEMULA should start a replay of 1_1 with no EXP")
		return false
	print("ronda5: MAIN SEMULA ok")
	# the optional star rating from the HUD: small box, Hantar waits for a star
	await wait(3.0)  # the Jalan Pintas fade (the world is built again)
	await wait_screen("world", 30.0)
	await wait_idle()
	var star := scene().find_child("BintangHUD", true, false) as Button
	if star == null:
		_fail("no star button in the HUD")
		return false
	await shot("r5_hud_bintang")
	star.pressed.emit()
	await wait(0.4)
	await shot("r5_kotak_bintang")
	var kb := Main.overlay_root().find_child("KotakBintang", true, false)
	var hantar: Button = find_button(kb, "Hantar") if kb else null
	if hantar == null or not hantar.disabled:
		_fail("the star box should open with Hantar off until a star is picked")
		return false
	kb.get_parent().pick(4)
	await wait(0.2)
	await shot("r5_kotak_bintang_4")
	var real_url := Backend.url
	Backend.url = ""  # never send a test rating to the real table
	Game.write_json_user(Backend.RATINGS_PENDING, [])
	hantar.pressed.emit()
	await wait(0.5)
	Backend.url = real_url
	var pend = Game.load_json_user(Backend.RATINGS_PENDING)
	var ok_pend: bool = pend is Array and pend.size() == 1 and int(pend[0]["stars"]) == 4 and str(pend[0]["context"]) == "hud"
	if not ok_pend or int(Game.save.get("rated", 0)) != 4 or Main.overlay_root().find_child("KotakBintang", true, false) != null:
		_fail("a 4-star rating should be kept to send and the box closed, got %s" % str(pend))
		return false
	Game.write_json_user(Backend.RATINGS_PENDING, [])
	await wait(0.3)
	await shot("r5_hud_bintang_emas")
	print("ronda5: kotak bintang ok")
	# holding run (Shift / X) plays Alif's PixelLab run cycle, not a fast walk
	var pl: Player = scene().player
	Input.action_press("run")
	var ran := ""
	for a in ["move_down", "move_up", "move_left", "move_right"]:
		Input.action_press(a)
		await wait(0.35)
		if str(pl.sprite.animation).begins_with("run_"):
			ran = str(pl.sprite.animation)
			await shot("r5_lari")
		Input.action_release(a)
		await wait(0.4)
		if ran != "":
			break
	Input.action_release("run")
	if ran == "":
		_fail("holding run should play the run animation, got %s" % pl.sprite.animation)
		return false
	print("ronda5: lari ok (%s)" % ran)
	# Mula semula: two choices
	var sp: Node = Main.open_settings()
	await wait(0.3)
	sp._show(4)
	await wait(0.2)
	find_button(sp, "Mula semula permainan").pressed.emit()
	await wait(0.3)
	await shot("r5_mula_semula")
	var dunia := sp.find_child("Reset_dunia", true, false) as Button
	if dunia == null or sp.find_child("Reset_awal", true, false) == null:
		_fail("Mula semula should offer two starts")
		return false
	dunia.pressed.emit()
	await wait(0.4)
	var sure := find_button(Main.overlay_root(), "Mula semula")
	if sure == null:
		_fail("Mula semula should ask first")
		return false
	sure.pressed.emit()
	await wait_screen("bilik_alif", 30.0)
	if not bool(Game.save["prolog_done"]) or Game.zone_done("1_1"):
		_fail("start from the ExploStory world: prologue skipped, missions cleared")
		return false
	print("ronda5: Mula semula (dunia) ok")
	# a guest who logs out loses the progress
	Game.zone_state("1_1")["done"] = true
	Game.persist()
	await Game.log_out()
	Game.load_profile("Tetamu", "guest")
	if Game.zone_done("1_1"):
		_fail("a guest's progress should be gone after logging out")
		return false
	# the session file is emptied on sign-out (a browser keeps deleted files)
	Game.write_json_user(Backend.SESSION, {"refresh_token": "lama", "email": "a@b.c"})
	await Backend.sign_out()
	var s = Game.load_json_user(Backend.SESSION)
	if s is Dictionary and str(s.get("refresh_token", "")) != "":
		_fail("sign_out should empty the session file")
		return false
	Game.goto("login")
	await wait_screen("login")
	find_button(hosted(), "Main sebagai Tetamu").pressed.emit()
	await wait(0.4)
	await shot("r5_amaran_tetamu")
	var faham := find_button(Main.overlay_root(), "Faham, main")
	if faham == null:
		_fail("no guest warning")
		return false
	faham.pressed.emit()
	await wait(1.0)
	print("ronda5: guest + sign-out ok")
	return true


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
	t = 0.0
	while find_button(scene(), "Cuba lagi") == null and t < 40.0:
		var p = Game.active_puzzle
		if p != null and is_instance_valid(p):
			if p._next.visible:
				p._advance()
			else:
				p._pick((int(p._q()["answer"]) + 1) % 4)
		await wait(0.5)
		t += 0.5
	await wait(1.0)
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
	var g: Node = hosted()
	g._close_pause()
	# Keluar kuiz on the question card: stops the clock and asks first
	var waited := 0.0
	while g.match_node.phase != "soalan" and waited < 20.0:
		await wait(0.2)
		waited += 0.2
	var kk := find_button(scene(), "Keluar kuiz")
	if kk == null:
		_fail("no Keluar kuiz button on the question card")
		return
	kk.pressed.emit()
	await wait(0.4)
	await shot("r3_keluar_kuiz")
	var stay := find_button(scene(), "Terus main")
	if not get_tree().paused or stay == null:
		_fail("Keluar kuiz should pause the match and ask first")
		return
	stay.pressed.emit()
	await wait(0.3)
	if get_tree().paused or g.match_node.phase != "soalan":
		_fail("Terus main should go back to the question")
		return
	# the negeri: once a month
	Game.save["profile"]["negeri"] = ""
	if Game.negeri_wait_left() != 0:
		_fail("the first negeri pick should be free")
		return
	Game.set_negeri("Johor")
	if Game.negeri_wait_left() < 29 * 86400:
		_fail("a new negeri should lock for a month")
		return
	g._open_pause()
	g._leave()
	await wait_screen("lobby", 20.0)
	var pp: Node = Main.open_profile()
	await wait(0.5)
	await shot("r3_profil_negeri_kunci")
	pp.close()
	if not await _check_ronda5():
		return
	print("AUTOTEST PASS (ronda3)")
	get_tree().quit(0)


## Tingkatan 5 (still to come): ten zone cards with titles; a click opens the
## subtopik list, and Tutup closes it
func _check_t5_subtopik() -> bool:
	var t5: Array = Game.chapters["arcs"][1].get("chapters", [])
	if t5.size() != 10:
		_fail("Tingkatan 5 should list its 10 chapters, got %d" % t5.size())
		return false
	hosted()._enter(t5[8], false)
	await wait(0.3)
	var pop: Node = hosted().get_node_or_null("Subtopik")
	if pop == null:
		_fail("a Tingkatan 5 zone card should open its subtopik list")
		return false
	await shot("arka_t5_subtopik")
	pop.queue_free()
	await wait(0.1)
	print("arka: T5 subtopik ok")
	return true


## Lupa kata laluan: the page opened from the reset e-mail asks for the new
## password on the login screen (two fields that must match, 6+ characters)
func _check_lupa() -> bool:
	Backend.recovery = {"token": "ujian", "email": "alif@contoh.my"}
	Game.goto("login")
	await wait_screen("login")
	await wait(0.3)
	var pop: Node = hosted().get_node_or_null("KataLaluanBaharu")
	if pop == null:
		_fail("the reset link should open the new-password box on the login screen")
		return false
	if hosted()._user.text != "alif@contoh.my":
		_fail("the e-mail from the reset link should be filled in")
		return false
	var fields := pop.find_children("*", "LineEdit", true, false)
	(fields[0] as LineEdit).text = "rahsia123"
	(fields[1] as LineEdit).text = "rahsia124"
	for b in pop.find_children("*", "Button", true, false):
		if (b as Button).text == "TUKAR KATA LALUAN":
			(b as Button).pressed.emit()
	await wait(0.2)
	var said := false
	for l in pop.find_children("*", "Label", true, false):
		if (l as Label).text.contains("tidak sama"):
			said = true
	if not said:
		_fail("two different passwords should be refused")
		return false
	await shot("lupa_kata_laluan")
	for b in pop.find_children("*", "Button", true, false):
		if (b as Button).text == "Batal":
			(b as Button).pressed.emit()
	await wait(0.2)
	if not Backend.recovery.is_empty() or is_instance_valid(pop) and not pop.is_queued_for_deletion():
		_fail("Batal should close the new-password box")
		return false
	# an account opened on a new device: the empty save must lose to the cloud
	# copy (it once got saved_at = now and was pushed over the real progress)
	Game.load_profile("akaun_baru_ujian", "local")
	if float(Game.save.get("saved_at", -1)) != 0.0:
		_fail("a new device's empty save should have saved_at 0, got %s" % str(Game.save.get("saved_at")))
		return false
	print("login: lupa kata laluan ok")
	return true
