extends Node
## End-to-end play-through used by CI and for screenshots.
## Run:  godot --path . -- --autotest [--shots=/abs/dir]
## Plays title -> guest login -> prolog -> all 4 zones (with one wrong try per
## puzzle and Pau hints) -> summaries -> penutup -> Bab 2 teaser -> map,
## then prints AUTOTEST PASS and quits with code 0 (1 on failure/timeout).

const TIMEOUT := 420.0

var shots_dir: String = ""
var _t: float = 0.0
var _adv_t: float = 0.0
var _shot_n: int = 0
var auto_dialog: bool = true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# start from a clean guest profile
	var d := DirAccess.open("user://")
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
	var m: Node = Game.main
	if auto_dialog and m and m.dialog_box.visible and _adv_t > 0.08:
		_adv_t = 0.0
		m.dialog_box._advance()


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


func screen() -> Node:
	return Game.main.current


func wait_screen(name: String, limit: float = 20.0) -> void:
	var t := 0.0
	while Game.main.current_name != name or Game.main._switching:
		await wait(0.1)
		t += 0.1
		if t > limit:
			_fail("screen %s did not appear (at %s)" % [name, Game.main.current_name])
			return
	await wait(0.5)


func wait_idle(limit: float = 30.0) -> void:
	## wait until no dialogue is open and the area is not busy
	var t := 0.0
	while true:
		var sc := screen()
		var busy: bool = Game.main.dialog_box.visible or Game.is_locked()
		if sc and "busy" in sc and sc.busy:
			busy = true
		if not busy:
			break
		await wait(0.1)
		t += 0.1
		if t > limit:
			_fail("still busy after %d s on %s" % [int(limit), Game.main.current_name])
			return


func find_button(root: Node, prefix: String) -> Button:
	for c in root.get_children():
		if c is Button and (c as Button).visible and (c as Button).text.begins_with(prefix):
			return c
		var r := find_button(c, prefix)
		if r:
			return r
	return null


# ------------------------------------------------------------------ the run
func _run() -> void:
	await wait_screen("title")
	await shot("title")
	screen()._start()
	await wait_screen("login")
	await shot("login")
	Game.goto("register")
	await wait_screen("register")
	await shot("register")
	Game.goto("login")
	await wait_screen("login")
	screen()._guest()

	# ---- prolog (played, with auto taps)
	await wait_screen("prolog")
	var shot_read := false
	var t := 0.0
	while Game.main.current_name == "prolog":
		var p := screen()
		if p._waiting == "read":
			if not shot_read:
				shot_read = true
				await wait(0.6)
				await shot("prolog_scrambled_text")
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			p._on_read_tap(ev)
			await wait(0.4)
		elif p._waiting == "pau":
			await shot("prolog_room")
			p.step_done.emit()
		await wait(0.1)
		t += 0.1
		if t > 120:
			_fail("prolog stuck")
			return
	await wait_screen("peta")
	await wait_idle()
	await shot("peta_start")

	# overlays
	Game.main.open_settings()
	await wait(0.4)
	await shot("settings")
	Game.main.overlay_root().get_child(Game.main.overlay_root().get_child_count() - 1).close()
	Game.main._on_pau_tap()
	await wait(0.3)
	await shot("pau_hint_bubble")

	# ---- the four zones
	for z in Game.ZONES:
		Game.goto("zone_prep", {"zone": z})
		await wait_screen("zone_prep")
		await shot("prep_" + z)
		Game.goto("zone", {"zone": z})
		await wait_screen("zone")
		await wait_idle()
		await shot("zone_" + z)
		var area := screen()
		for s in area._steps():
			var it: Dictionary = area.get_it(str(s["at"]))
			if it.is_empty():
				_fail("missing object " + str(s["at"]))
				return
			area.player.global_position = it["pos"] + Vector2(0, 40)
			area._try_interact(it)
			# wait for puzzle
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
			await wait(0.2)
		await wait_screen("zone_summary", 40)
		await shot("summary_" + z)
		screen()._continue()
		if z != "1_4":
			await wait_screen("peta")
			await wait_idle()

	# ---- penutup
	await wait_screen("penutup", 30)
	t = 0.0
	var shot_flag := false
	while Game.main.current_name == "penutup":
		var root: Control = Game.main.overlay_root()
		var nota: Node = null
		for c in root.get_children():
			if c.has_method("_read_page"):
				nota = c
		if nota:
			await wait(0.5)
			await shot("nota_alif")
			nota._show(5)
			await wait(0.3)
			await shot("nota_alif_waadat")
			nota.close()
		elif not Game.main.dialog_box.visible:
			var b := find_button(screen(), "Teruskan")
			if b == null:
				b = find_button(screen(), "KEMBALI KE PETA")
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
	await wait_screen("peta")
	await wait_idle()
	await shot("peta_after_bab1")
	Game.main.open_muzium()
	await wait(0.4)
	await shot("muzium")
	Game.main.overlay_root().get_child(Game.main.overlay_root().get_child_count() - 1).close()
	Game.goto("lobby")
	await wait_screen("lobby")
	await shot("lobby")

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


func _solve(p: Node, label: String) -> void:
	var path: String = p.get_script().resource_path
	if path.ends_with("choice.gd"):
		await shot("puzzle_" + label)
		p._pick(p.def["options"][0])
	elif path.ends_with("board.gd"):
		var links: Array = p.links
		# one wrong attempt, one Pau hint
		var ids: Array = p.cards.keys()
		var a = p.cards[links[0][0]]
		var wrong = null
		for id in ids:
			if p._key(links[0][0], id) == "" and id != links[0][0]:
				wrong = p.cards[id]
				break
		if wrong:
			p.try_link(a, wrong)
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
