class_name ZoneRunner
extends Node
## Runs the mission zones (data/zon_<bab>_<n>.json) inside
## the explorable world. Each step is: dialogue -> puzzle -> rewards ->
## dialogue -> a visible change in the world. Steps live at "spots" (NPC ids
## or objects), shown with bouncing "!" markers.
##
## The host (world.gd or interior.gd) provides:
##   spot_ids() -> Array        which step locations exist in this scene
##   marker_pos(id) -> Vector2  where to float the "!" marker
##   apply_after(zid, step, animate)  world reaction after a step
##   on_zone_complete(zid)      before the summary screen (e.g. ship docks)
##   return_cell() -> Vector2i  overworld cell to come back to after summary

const DragMatch = preload("res://scripts/puzzles/drag_match.gd")
const Board = preload("res://scripts/puzzles/board.gd")
const Choice = preload("res://scripts/puzzles/choice.gd")
const Objektif = preload("res://scripts/puzzles/objektif.gd")
const Suaikan = preload("res://scripts/puzzles/suaikan.gd")

signal changed

var host: Node
var markers := {}  ## spot id -> marker Node2D
var busy := false
var _puzzle_layer: CanvasLayer


func setup(h: Node) -> void:
	host = h
	_puzzle_layer = CanvasLayer.new()
	_puzzle_layer.layer = 15
	add_child(_puzzle_layer)
	for id in host.spot_ids():
		var m := Marker.new()
		m.position = host.marker_pos(id)
		m.visible = false
		host.get_node("Objects").add_child(m)
		markers[id] = m
	# restore the world to match saved progress
	for zid in Game.ZONES:
		var done: Array = Game.zone_state(zid)["steps"]
		for s in Game.zone_data(zid).get("steps", []):
			if done.has(s["puzzle"]) and s["at"] in markers:
				host.apply_after(zid, s, false)
	refresh()


## Find the zone step that lives at this spot. {} if none.
func _step_at(id: String) -> Dictionary:
	for zid in Game.ZONES:
		var steps: Array = Game.zone_data(zid).get("steps", [])
		for i in steps.size():
			if str(steps[i]["at"]) == id:
				if not _done(zid, steps[i]):
					return {"zid": zid, "i": i, "step": steps[i]}
	return {}


func owns(id: String) -> bool:
	for zid in Game.ZONES:
		for s in Game.zone_data(zid).get("steps", []):
			if str(s["at"]) == id:
				return true
	return false


func _done(zid: String, s: Dictionary) -> bool:
	return Game.zone_state(zid)["steps"].has(s["puzzle"])


func _available(zid: String, i: int) -> bool:
	if not Game.zone_unlocked(zid):
		return false
	var zone := Game.zone_data(zid)
	var steps: Array = zone.get("steps", [])
	if _done(zid, steps[i]):
		return false
	if zone.get("any_order", false):
		return true
	for j in i:
		if not _done(zid, steps[j]):
			return false
	return true


## Interact with a spot. Returns true if a zone step handled it.
func handle(id: String) -> bool:
	var found := _step_at(id)
	if found.is_empty():
		return false
	var zid: String = found["zid"]
	if not Game.zone_unlocked(zid):
		var prev := Game.prev_zone(zid)
		if prev == "":
			Game.main.pau_say("Belum lagi. Habiskan Bab %d dulu, baru tempat ni terbuka." % (Game.chapter_of(zid) - 1))
		else:
			Game.main.pau_say("Belum lagi. Habiskan Misi %s dulu, baru tempat ni terbuka." % prev.replace("_", "."))
		return true
	if not _available(zid, found["i"]):
		Game.main.pau_say("Belum lagi. Selesaikan tugasan sebelumnya dulu, ikut tanda seru.")
		return true
	await run_step(zid, found["step"])
	return true


func run_step(zid: String, s: Dictionary) -> void:
	busy = true
	var zone := Game.zone_data(zid)
	var st := Game.zone_state(zid)
	await Game.say(str(s.get("before", "")))
	var pid: String = s["puzzle"]
	var stats := await run_puzzle(zone["puzzles"][pid], "%s_%s" % [zid, pid])
	st["steps"].append(pid)
	for k in ["first_try", "retries", "hints", "total"]:
		st[k] = int(st.get(k, 0)) + int(stats.get(k, 0))
	var total := int(stats.get("total", 0))
	var ft := int(stats.get("first_try", 0))
	var exp_gain := ft * 10 + (total - ft) * 5 + 20
	var coins := total * 3 + 5
	var up := Game.add_reward(exp_gain, coins)
	Game.toast("+%d EXP   +%d Syiling" % [exp_gain, coins])
	MusicDirector.stinger("st_item")
	if up:
		Game.toast("NAIK TAHAP! Tahap %d" % int(Game.save["level"]), Color("8fe08a"))
		MusicDirector.stinger("st_levelup")
	Game.persist()
	host.apply_after(zid, s, true)
	await Game.say(str(s.get("after", "")))
	refresh()
	busy = false
	if st["steps"].size() >= zone.get("steps", []).size():
		await complete(zid)


func run_puzzle(def: Dictionary, puzzle_id: String) -> Dictionary:
	var p: Control
	match str(def.get("type", "drag_match")):
		"board": p = Board.new()
		"choice": p = Choice.new()
		"objektif": p = Objektif.new()
		"suaikan": p = Suaikan.new()
		_: p = DragMatch.new()
	p.theme = Game.theme
	p.set("def", def)
	p.set("puzzle_id", puzzle_id)
	Game.lock_input()
	Game.main.set_pau_visible(true)
	Game.main.bubble.visible = false
	MusicDirector.puzzle(true)
	_puzzle_layer.add_child(p)
	Game.active_puzzle = p
	var stats: Dictionary = await p.completed
	Game.active_puzzle = null
	MusicDirector.puzzle(false)
	Game.unlock_input()
	p.queue_free()
	return stats


func complete(zid: String) -> void:
	var zone := Game.zone_data(zid)
	await host.on_zone_complete(zid)
	if zone.has("outro"):
		await Game.say(str(zone["outro"]))
	var st := Game.zone_state(zid)
	var first_time := not bool(st.get("done", false))
	var level_up := false
	if first_time:
		st["done"] = true
		Game.add_artifact(str(zone.get("ganjaran", {}).get("id", "")))
		level_up = Game.add_reward(100, 50)
		Game.persist()
	MusicDirector.stinger("st_zone")
	await get_tree().create_timer(1.2).timeout
	GameState.spawn_cell = host.return_cell()
	Game.goto("zone_summary", {"zone": zid, "first_time": first_time, "level_up": level_up})


func refresh() -> void:
	var hint := ""
	for id in markers:
		var f := _step_at(id)
		var on := not f.is_empty() and _available(f["zid"], f["i"])
		markers[id].visible = on
		if on and hint == "":
			hint = "Pergi ke tanda seru (!) di %s." % Game.zone_data(f["zid"])["title"]
	for n in range(1, 11):
		if hint == "" and Game.ujian_pending(n):
			hint = "Ujian Bab %d menanti di %s. Lawan %s untuk buka jalan seterusnya!" % [n, Game.ujian_def(n)["where"], Game.ujian_def(n)["boss"]]
	if hint == "":
		var next := Game.next_zone()
		if next == "":
			hint = "Semua bab yang dibuka sudah selesai! Buka Nota Alif untuk ulang kaji."
		else:
			hint = str(Game.zone_data(next).get("hint_go", "Ikut tanda seru (!) ke Misi %s." % next.replace("_", ".")))
	Game.context_hint = hint
	changed.emit()


## Bouncing "!" quest marker drawn in pixels (crisp at any zoom).
class Marker extends Node2D:
	var _t := randf() * TAU

	func _ready() -> void:
		z_index = 20
		y_sort_enabled = false

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var y := -sin(_t * 4.0) * 2.0
		var o := Vector2(-3, y - 12)
		draw_rect(Rect2(o + Vector2(-1, -1), Vector2(8, 13)), Color(0.17, 0.11, 0.06))
		draw_rect(Rect2(o, Vector2(6, 11)), Color(1, 0.86, 0.3))
		draw_rect(Rect2(o + Vector2(2, 1), Vector2(2, 6)), Color(0.35, 0.2, 0.05))
		draw_rect(Rect2(o + Vector2(2, 8), Vector2(2, 2)), Color(0.35, 0.2, 0.05))
