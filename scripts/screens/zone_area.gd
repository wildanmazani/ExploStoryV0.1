extends "res://scripts/world/walk_area.gd"
## A Bab 1 zone, fully driven by data/zon_1_x.json: objects, ordered (or
## free-order) steps, each step = dialogue -> puzzle -> dialogue.

var zid: String
var zone: Dictionary
var replay: bool = false
var done_steps: Array = []
var _thread: Line2D
var _tree: Sprite2D
var _plain: Dictionary = {}


func _build() -> void:
	zid = str(params.get("zone", "1_1"))
	zone = Game.zone_data(zid)
	replay = Game.zone_done(zid)
	var st := Game.zone_state(zid)
	done_steps = [] if replay else st["steps"].duplicate()
	var wr: Array = zone.get("walk_rect", [80, 400, 1120, 300])
	var sp: Array = zone.get("spawn", [640, 660])
	setup_area(str(zone["background"]), Rect2(wr[0], wr[1], wr[2], wr[3]), Vector2(sp[0], sp[1]),
		"ZON %s: %s" % [zone["no"], str(zone["title"]).to_upper()], str(zone.get("subtopik", "")), true)
	for o in zone.get("objects", []):
		_spawn_object(o)
	# restore visual state of finished steps
	for s in zone.get("steps", []):
		if done_steps.has(s["puzzle"]):
			_apply_after(s, false)
	_refresh()
	if done_steps.is_empty():
		await get_tree().create_timer(0.5).timeout
		await Game.say(str(zone.get("intro", "")))
	_refresh()


func _spawn_object(o: Dictionary) -> void:
	var id := str(o["id"])
	var pos := Vector2(o["pos"][0], o["pos"][1])
	var label := str(o.get("label", ""))
	if o.has("sprite"):
		add_sprite_npc(id, str(o["sprite"]), pos, label)
	elif o.get("panji", false):
		add_texture_obj(id, "res://assets/objects/panji_turun.png", pos, 4, label)
	elif o.get("tree", false):
		_tree = add_texture_obj(id, "res://assets/objects/pokok_0.png", pos, float(o.get("scale", 4)), label)
	else:
		add_texture_obj(id, str(o.get("texture", "")), pos, float(o.get("scale", 4)), label)


func add_texture_obj(id: String, tex_path: String, pos: Vector2, sc: float, label: String = "") -> Sprite2D:
	var s := super.add_texture_obj(id, tex_path, pos, sc, label)
	_plain[id] = s
	return s


func _find_plain(id: String) -> Sprite2D:
	return _plain.get(id, null)


func _steps() -> Array:
	return zone.get("steps", [])


func _available(i: int) -> bool:
	var steps := _steps()
	if done_steps.has(steps[i]["puzzle"]):
		return false
	if zone.get("any_order", false):
		return true
	for j in i:
		if not done_steps.has(steps[j]["puzzle"]):
			return false
	return true


func _refresh() -> void:
	var steps := _steps()
	var first_hint := ""
	for it in interactables:
		set_marker(it["id"], false)
	for i in steps.size():
		if _available(i):
			set_marker(str(steps[i]["at"]), true)
			if first_hint == "":
				first_hint = "Pergi ke %s (ada tanda seru)." % get_it(str(steps[i]["at"])).get("label", "tanda seru")
	Game.context_hint = first_hint if first_hint != "" else "Zon ini hampir selesai!"


func on_interact(it: Dictionary) -> void:
	var steps := _steps()
	var id: String = it["id"]
	for i in steps.size():
		var s: Dictionary = steps[i]
		if str(s["at"]) != id:
			continue
		if done_steps.has(s["puzzle"]):
			continue
		if not _available(i):
			Game.main.pau_say("Belum lagi. Selesaikan tugasan sebelumnya dulu.")
			return
		await _run_step(s)
		return
	# talking to someone with no pending task
	if it.has("label"):
		Game.add_figure(id)
		Game.main.pau_say("%s: tiada tugasan di sini sekarang." % it["label"], 4.0)


func _run_step(s: Dictionary) -> void:
	await Game.say(str(s.get("before", "")))
	var pid: String = s["puzzle"]
	var pdef: Dictionary = zone["puzzles"][pid]
	var stats: Dictionary = await run_puzzle(pdef, "%s_%s" % [zid, pid])
	done_steps.append(pid)
	var st := Game.zone_state(zid)
	if not replay:
		st["steps"] = done_steps.duplicate()
		for k in ["first_try", "retries", "hints", "total"]:
			st[k] = int(st.get(k, 0)) + int(stats.get(k, 0))
		var total := int(stats.get("total", 0))
		var ft := int(stats.get("first_try", 0))
		var exp_gain := ft * 10 + (total - ft) * 5 + 20
		var coins := total * 3 + 5
		var up := Game.add_reward(exp_gain, coins)
		Game.toast("+%d EXP   +%d Syiling" % [exp_gain, coins])
		if up:
			Game.toast("NAIK TAHAP! Tahap %d" % int(Game.save["level"]), Color("8fe08a"))
		Game.persist()
	_apply_after(s, true)
	await Game.say(str(s.get("after", "")))
	_refresh()
	if done_steps.size() >= _steps().size():
		await _complete()


func _apply_after(s: Dictionary, animate: bool) -> void:
	var pid: String = s["puzzle"]
	var obj := _find_plain(str(s["at"]))
	# panji raised
	if obj and get_it(str(s["at"])).size() > 0 and str(s["at"]).begins_with("p_"):
		obj.texture = UI.tex("res://assets/objects/panji_naik.png")
		if animate:
			obj.scale = Vector2(4, 3)
			create_tween().tween_property(obj, "scale", Vector2(4, 4), 0.3).set_trans(Tween.TRANS_BACK)
	# tree growth
	if s.has("tree") and _tree:
		_tree.texture = UI.tex("res://assets/objects/pokok_%d.png" % int(s["tree"]))
		if animate:
			var tw := create_tween()
			tw.tween_property(_tree, "modulate", Color(1.6, 1.5, 0.8), 0.3)
			tw.tween_property(_tree, "modulate", Color.WHITE, 0.6)
	# zone specific arrangement (Zon 1.1 gates + golden thread)
	var after: Dictionary = zone.get("after_step", {}).get(pid, {})
	if after.has("arrange"):
		var pts: Array = []
		for gid in after["arrange"].keys():
			var g := _find_plain(gid)
			var to := Vector2(after["arrange"][gid][0], after["arrange"][gid][1])
			pts.append(to)
			if g:
				if animate:
					create_tween().tween_property(g, "position", to, 0.8).set_trans(Tween.TRANS_SINE)
				else:
					g.position = to
		if after.get("thread", false):
			pts.sort_custom(func(a, b): return a.x < b.x)
			_thread = Line2D.new()
			_thread.width = 6
			_thread.default_color = UI.GOLD
			_thread.z_index = 20
			for p in pts:
				_thread.add_point(p + Vector2(0, -120))
			add_child(_thread)
			if animate:
				_thread.modulate.a = 0.0
				var tw2 := create_tween()
				tw2.tween_interval(0.8)
				tw2.tween_property(_thread, "modulate:a", 1.0, 0.8)


func _complete() -> void:
	if zone.has("outro"):
		if zid == "1_2":
			var ship := _find_plain("kapal")
			if ship:
				create_tween().tween_property(ship, "position", Vector2(820, 330), 2.0).set_trans(Tween.TRANS_SINE)
		await Game.say(str(zone["outro"]))
	var first_time := not replay
	var g: Dictionary = zone.get("ganjaran", {})
	var level_up := false
	if first_time:
		var st := Game.zone_state(zid)
		st["done"] = true
		Game.add_artifact(str(g.get("id", "")))
		level_up = Game.add_reward(100, 50)
		Game.persist()
	Game.goto("zone_summary", {"zone": zid, "first_time": first_time, "level_up": level_up})
