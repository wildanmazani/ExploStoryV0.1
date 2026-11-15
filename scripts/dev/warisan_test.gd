extends Node
## Dev test for Pesta Warisan.  Run:  godot --path . -- --warisan-test [--shots=/abs/dir] [--hd2d]
## As a guest: the festival board in Kampung Jejak, the fair's screen, then a
## bot plays the five games (Mudah) to the end. Prints WARISAN TEST PASS and
## quits (exit 1 on a failure). It saves like a real game does: keep your own
## user://simpan_*.json out of the way first.

var shots_dir := ""
var _n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [shots_dir, _n, name])


func _fail(why: String) -> void:
	print("WARISAN TEST FAIL: ", why)
	get_tree().quit(1)


func _screen() -> Node:
	var host := get_tree().current_scene
	return host.get_child(host.get_child_count() - 1) if host and host.get_child_count() > 0 else null


func _run() -> void:
	await _wait(1.0)
	for arg in OS.get_cmdline_user_args():   # --warisan-shot=galah: one game, a few pictures, no checks
		if arg.begins_with("--puzzle-shot="):   # --puzzle-shot=1_1:susun_gerbang: a mission puzzle, solved card by card
			var which := arg.trim_prefix("--puzzle-shot=").split(":")
			Game.save["seen"].append_array(["kampung_intro", "tip_kawalan"])
			Game.goto("world")
			await _wait(3.5)
			get_tree().current_scene.runner.run_puzzle(Game.zone_data(which[0])["puzzles"][which[1]], which[1])
			await _wait(1.5)
			var p: Node = Game.active_puzzle
			var n := 0
			for c in p.cards.duplicate():
				p.try_place(c, p.targets[str(c.item["target"])])
				n += 1
				await _wait(1.2 if n < p.cards.size() else 0.75)
				await _shot("teka_teki_%d" % n)
			get_tree().quit(0)
			return
		if arg == "--warisan-shot=raga-jatuh":   # nobody kicks: the ball on the ground, twice
			Game.goto("raga", {"level": 1})
			await _wait(2.0)
			var rg := _screen()
			for want in [0.12, 0.45, 0.9]:
				while not (rg.state == "jatuh" and rg.drop_t >= want):
					await get_tree().process_frame
				await _shot("jatuh")
			get_tree().quit(0)
			return
		if arg.begins_with("--warisan-shot="):
			Game.goto(arg.trim_prefix("--warisan-shot="), {"auto": true, "level": 1})
			for i in 4:
				await _wait(2.5)
				await _shot("lihat")
			get_tree().quit(0)
			return
	Game.goto("pesta")
	await _wait(2.0)
	await _shot("pesta")

	var coins := int(Game.save["coins"])
	Game.goto("galah", {"auto": true, "level": 0})
	await _wait(2.0)
	var g := _screen()
	if g == null or g.get("state") == null:
		return _fail("Galah Panjang did not open")
	var t := 0.0
	var shown := 0
	while g.state != "tamat" and t < 240.0:
		await _wait(0.5)
		t += 0.5
		if (shown == 0 and t > 3.0) or (shown == 1 and g.state == "soalan") or (shown == 2 and g.phase == "balik"):
			shown += 1
			await _shot("galah_%d" % shown)
	if g.state != "tamat":
		return _fail("Galah Panjang did not end in 240 s (y=%.0f phase=%s lives=%d)" % [g.pos.y, g.phase, g.lives])
	await _wait(0.5)
	await _shot("galah_tamat")
	if g.won and int(Game.save["coins"]) <= coins:
		return _fail("a win paid no coins")
	if int(Game.save["warisan"]["galah"]["main"]) != 1:
		return _fail("the game was not counted")
	var result := "won=%s time=%.1f coins=%d" % [g.won, g.time, int(Game.save["coins"]) - coins]  # (the screen goes with the scene)

	# Sukar for a while: a guard catches the bot and asks his question
	Game.goto("galah", {"auto": true, "level": 2})
	await _wait(2.0)
	g = _screen()
	t = 0.0
	shown = 0
	while t < 40.0 and shown < 2 and g.state != "tamat":
		await _wait(0.5)
		t += 0.5
		if (shown == 0 and t >= 3.0) or (shown == 1 and g.state == "soalan"):
			shown += 1
			await _shot("galah_sukar_%d" % shown)
	if shown < 2:
		return _fail("no question when caught on Sukar")

	Game.goto("upih", {"auto": true, "level": 0})
	await _wait(2.0)
	var u := _screen()
	if u == null or u.get("me") == null:
		return _fail("Tarik Upih did not open")
	await _shot("upih_sedia")
	t = 0.0
	shown = 0
	while u.state != "tamat" and t < 120.0:
		await _wait(0.5)
		t += 0.5
		if (shown == 0 and u.state == "main" and u.time > 4.0) or (shown == 1 and u.state == "soalan") or (shown == 2 and u.me["boost"] > 0.0 and u.state == "main"):
			shown += 1
			await _shot("upih_%d" % shown)
	if u.state != "tamat":
		return _fail("Tarik Upih did not end in 120 s (x=%.0f rival=%.0f)" % [u.me["x"], u.rival["x"]])
	await _wait(0.5)
	await _shot("upih_tamat")
	if not u.won:
		return _fail("the bot lost Tarik Upih on Mudah (%.1f s)" % u.time)
	if int(Game.save["warisan"]["upih"]["main"]) != 1:
		return _fail("Tarik Upih was not counted")
	result += " | upih won=%s time=%.1f right=%d" % [u.won, u.time, u.right]

	Game.goto("gasing", {"auto": true, "level": 0})
	await _wait(2.0)
	var gs := _screen()
	if gs == null or gs.get("marker") == null:
		return _fail("Gasing did not open")
	t = 0.0
	shown = 0
	while gs.state != "tamat" and t < 240.0:
		await _wait(0.25)
		t += 0.25
		if (shown == 0 and gs.state == "lilit") or (shown == 1 and gs.state == "pusing" and gs.me["spin"] < 0.9) or (shown == 2 and gs.state == "rehat"):
			shown += 1
			await _shot("gasing_%d" % shown)
	if gs.state != "tamat":
		return _fail("Gasing did not end in 240 s (%s, %d-%d)" % [gs.state, gs.score[0], gs.score[1]])
	await _wait(0.5)
	await _shot("gasing_tamat")
	if int(Game.save["warisan"]["gasing"]["main"]) != 1:
		return _fail("Gasing was not counted")
	result += " | gasing won=%s %d-%d" % [gs.won, gs.score[0], gs.score[1]]

	Game.goto("dam", {"auto": true, "level": 0})
	await _wait(2.5)
	var dm := _screen()
	if dm == null or dm.get("board") == null:
		return _fail("Dam Haji did not open")
	await _shot("dam_1")
	t = 0.0
	while dm.state != "tamat" and t < 120.0:
		await _wait(0.5)
		t += 0.5
	if dm.state != "tamat":
		return _fail("Dam Haji did not end in 120 s (%d-%d, %s)" % [dm.count(1), dm.count(-1), dm.state])
	await _wait(0.5)
	await _shot("dam_tamat")
	if int(Game.save["warisan"]["dam"]["main"]) != 1:
		return _fail("Dam Haji was not counted")
	result += " | dam won=%s %d-%d" % [dm.won, dm.count(1), dm.count(-1)]

	Game.goto("raga", {"auto": true, "level": 0})
	await _wait(2.0)
	var sr := _screen()
	if sr == null or sr.get("timang") == null:
		return _fail("Sepak Raga did not open")
	t = 0.0
	shown = 0
	while sr.state != "tamat" and t < 180.0:
		await _wait(0.5)
		t += 0.5
		if (shown == 0 and sr.timang >= 3) or (shown == 1 and sr.state == "soalan"):
			shown += 1
			await _shot("raga_%d" % shown)
	if sr.state != "tamat":
		return _fail("Sepak Raga did not end in 180 s (timang=%d lives=%d)" % [sr.timang, sr.lives])
	await _wait(0.5)
	await _shot("raga_tamat")
	if not sr.won:
		return _fail("the bot lost Sepak Raga on Mudah (%d timang)" % sr.timang)
	if int(Game.save["warisan"]["raga"]["main"]) != 1:
		return _fail("Sepak Raga was not counted")
	result += " | raga won=%s timang=%d right=%d" % [sr.won, sr.timang, sr.right]
	# the board on the map: Alif stands under it
	Game.save["seen"].append_array(["kampung_intro", "tip_kawalan"])
	GameState.spawn_cell = Vector2i(31, 35)
	Game.goto("world")
	await _wait(3.5)
	var world := get_tree().current_scene
	if world == null or not world.has_method("is_walkable"):
		return _fail("the world did not open")
	if world.interact.get(Vector2i(31, 34), {}).get("id", "") != "pesta_warisan":
		return _fail("no Pesta Warisan board at (31, 34)")
	await _shot("papan_pesta")
	# Tetapan > Paparan > Dunia 3D switches the view while the world is open
	var args := OS.get_cmdline_user_args()
	if (world.view3d != null) != Hd2dView.enabled():
		return _fail("the HD-2D view does not follow the setting")
	if not ("--2d" in args or "--hd2d" in args):
		var was: bool = Game.settings.get("hd2d", true)
		Game.set_setting("hd2d", not was)
		await _wait(1.0)
		await _shot("paparan_tukar")
		var ok: bool = (world.view3d != null) == (not was) and (was == (world.visibility_layer == 1))
		Game.set_setting("hd2d", was)
		await _wait(1.0)
		await _shot("paparan_balik")
		if not ok or (world.view3d != null) != was:
			return _fail("switching the HD-2D view in Tetapan did not work")
	print("WARISAN TEST PASS ", result)
	get_tree().quit(0)
