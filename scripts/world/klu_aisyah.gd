extends RefCounted
## Bab 2: the glowing places where Alif finds the clues about the girl in white
## a British officer pulled into the fog (data/klu_aisyah.json, Game.klu_*).
## One appears once its mission is done, near where it happened, and stays
## until Alif looks at it: the clue goes into Beg Alif (Klu Aisyah). With all
## four, Misi 2.8 opens. The gold arrow points at a waiting clue first.

const TILE := 16


## the clues waiting in the world (world.klu_nodes: no -> {cell, node})
static func build(w: Node) -> void:
	for k in Game.klu_list():
		var no := int(k["no"])
		if Game.klu_found(no) or not Game.zone_done(str(k["zone"])) or w.klu_nodes.has(no):
			continue
		var c: Vector2i = w._nearest_walkable(Vector2i(int(k["near"][0]), int(k["near"][1])))
		var s := Glint.new()
		s.position = Player.cell_to_pos(c)
		w.objects.add_child(s)
		w.blocked[c] = true
		w.interact[c] = {"type": "talk", "id": "klu_aisyah_%d" % no}
		w.klu_nodes[no] = {"cell": c, "node": s}


## the nearest waiting clue (cell), or (-1, -1)
static func waiting(w: Node) -> Vector2i:
	var best := Vector2i(-1, -1)
	for no in w.klu_nodes:
		var c: Vector2i = w.klu_nodes[no]["cell"]
		if best.x < 0 or Vector2(c - w.player.cell).length() < Vector2(best - w.player.cell).length():
			best = c
	return best


## Alif looks closely: what he finds (or who saw what), then the clue is his
static func take(w: Node, no: int) -> void:
	var k: Dictionary = {}
	for d in Game.klu_list():
		if int(d["no"]) == no:
			k = d
	if k.is_empty() or Game.klu_found(no):
		return
	await Game.say(str(k["talk"]))
	Game.save["seen"].append("klu_aisyah_%d" % no)
	Game.persist()
	MusicDirector.stinger("st_item")
	Game.toast(TranslationServer.translate("Klu Aisyah %d/4: %s") % [Game.klu_count(), TranslationServer.translate(str(k["isi"]))], Color("ffe08a"))
	var e: Dictionary = w.klu_nodes.get(no, {})
	if not e.is_empty():
		w.blocked.erase(e["cell"])
		w.interact.erase(e["cell"])
		var n: Node2D = e["node"]
		var t := n.create_tween()
		t.tween_property(n, "modulate:a", 0.0, 0.4)
		t.tween_callback(n.queue_free)
		w.klu_nodes.erase(no)
	if Game.klu_count() >= Game.klu_list().size():
		await Game.say("klu_lengkap")
		w._spawn_gabenor()  # Misi 2.8 is open now: the Gabenor takes his place at the Menara
	w.runner.refresh()


## a small white-gold glint on the ground that pulses and twinkles
class Glint extends Node2D:
	var _t := randf() * TAU

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var p := 0.5 + 0.5 * sin(_t * 3.0)
		draw_set_transform(Vector2(0, -3), 0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 6.0 + p * 2.0, Color(1, 0.9, 0.5, 0.18 + p * 0.12))
		draw_circle(Vector2.ZERO, 3.0, Color(1, 0.95, 0.75, 0.5))
		draw_set_transform(Vector2(0, -6 - p * 2.0), 0, Vector2.ONE)
		var a := 3.0 + p * 2.0
		var col := Color(1, 1, 0.92, 0.75 + p * 0.25)
		draw_line(Vector2(-a, 0), Vector2(a, 0), col, 1.0)
		draw_line(Vector2(0, -a), Vector2(0, a), col, 1.0)
		draw_rect(Rect2(-1, -1, 2, 2), Color.WHITE)
