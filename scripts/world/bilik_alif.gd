extends "res://scripts/world/interior.gd"
## Bilik Alif in Dunia Explo-Story (inside Rumah Alif, Kampung Jejak). After
## the prologue Alif wakes up here: Pau explains the artifacts (the four
## Serpihan), the missions and the goal, then teaches walking and talking.
## The first thing to do is pick up the school bag (a blinking start prompt
## points at it); the bag holds every artifact from then on (Menu > Beg Alif).
## Then Pau shows the map and the gold arrow and Misi 1.1 starts: out the door
## and the arrow on the map points at Gerbang Masa. Later visits: just the room.
## Text: data/dialogue/prologue.json (bilik_*), data/interiors/bilik_alif.json.

const StartPrompt = preload("res://scripts/ui/start_prompt.gd")
const BG := "res://assets/backgrounds/bg_int_bilik_alif.png"
const BED_POS := Vector2(72, 84)   ## Alif asleep: head on the pillow
const UP_CELL := Vector2i(6, 5)    ## where he stands after jumping out of bed
const BAG_CELL := Vector2i(12, 7)

signal bag_taken

var _pieces := {}           ## BilikArt piece id -> node
var _waiting_bag := false   ## tutorial: the door waits until the bag is taken
var _prompt: Control
var _emote: Label
var _blanket: Node2D


func _ready() -> void:
	if ResourceLoader.exists(BG):
		background = load(BG)
	_pieces = BilikArt.build(self, $Objects)
	_emote = Label.new()
	_emote.add_theme_font_size_override("font_size", 40)
	_emote.add_theme_color_override("font_outline_color", Color(0.17, 0.11, 0.06))
	_emote.add_theme_constant_override("outline_size", 12)
	_emote.visible = false
	$HUD.add_child(_emote)
	super._ready()


func _process(d: float) -> void:
	super._process(d)
	if _emote.visible:  # the "z z z" / "!" above Alif's head
		_emote.reset_size()
		_emote.position = get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, -36)) - _emote.size / 2.0


func _welcome() -> void:
	if Game.save["seen"].has("beg_alif"):
		_remove_bag(false)
	if not GameState.flags.get("bilik_intro", false):
		return  # a visit later on: just the room
	GameState.flags["bilik_intro"] = false
	await _wake_up()


# --- the wake-up ------------------------------------------------------------
func _wake_up() -> void:
	busy = true
	hud.visible = false
	player.can_move = false
	player.place_at(Vector2i(4, 4), "south")
	player.position = BED_POS
	player.z_index = 1
	_blanket = Blanket.new()  # tucked in up to the chest
	_blanket.room = background
	$Objects.add_child(_blanket)
	pau.visible = false
	_show_emote("z z z")
	await get_tree().create_timer(1.8).timeout

	# Pau bounces onto the floor beside the bed
	pau.place_at(UP_CELL + Vector2i(0, -1))
	pau.visible = true
	pau.hop()
	Sfx.play("pop")
	await get_tree().create_timer(0.6).timeout
	await Game.say(Dialogue.lines("pro_wake_1"))

	# Alif jolts awake and hops out of bed
	_show_emote("!")
	Sfx.play("pop", 0.0, 1.4)
	if _blanket:
		_blanket.queue_free()
	var t := create_tween()
	t.tween_property(player, "position", Player.cell_to_pos(UP_CELL) + Vector2(0, -8), 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "position", Player.cell_to_pos(UP_CELL), 0.12).set_ease(Tween.EASE_IN)
	await t.finished
	player.z_index = 0
	player.place_at(UP_CELL, "north")
	await get_tree().create_timer(0.6).timeout
	_emote.visible = false

	await Game.say(Dialogue.lines("bilik_bangun"))
	var shards := _show_shards()
	await Game.say(Dialogue.lines("bilik_artifak"))
	_hide(shards)
	await Game.say(Dialogue.lines("bilik_misi"))
	await Game.say(Dialogue.lines("bilik_tujuan"))
	hud.visible = true
	await Game.say(Dialogue.lines("bilik_gerak_sentuh" if Game.controls_on_screen() else "bilik_gerak_papan"))

	# the very first thing to do: pick up the bag (start indicator on it)
	busy = false
	player.can_move = true
	_waiting_bag = true
	Game.context_hint = tr("Ambil beg sekolah kau atas lantai dulu.")
	_prompt = StartPrompt.new()
	_prompt.target = _pieces["beg"]
	_prompt.lift = 16.0
	_prompt.action_text = "untuk ambil beg"
	$HUD.add_child(_prompt)


func _show_emote(text: String) -> void:
	_emote.text = text
	_emote.visible = true


## the four scattered Serpihan, dim (none found yet), floating over Pau
func _show_shards() -> Node2D:
	var row := Node2D.new()
	row.z_index = 20
	add_child(row)
	var zones: Array = Game.chapter_zones(1)
	for i in zones.size():
		var g: Dictionary = Game.zone_data(zones[i]).get("ganjaran", {})
		var s := Sprite2D.new()
		s.texture = load("res://assets/icons/%s.png" % g.get("icon", "kunci"))
		s.scale = Vector2.ONE * (14.0 / s.texture.get_width())
		s.position = Vector2(104 + (i - (zones.size() - 1) / 2.0) * 22, 40)
		s.modulate = Color(0.75, 0.7, 0.9, 0.0)
		row.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(0.25 * i)
		tw.tween_property(s, "modulate:a", 0.8, 0.3)
		tw.tween_property(s, "position:y", 36.0, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:y", 40.0, 0.9).set_trans(Tween.TRANS_SINE)
		tw.set_loops()
	return row


func _hide(n: Node2D) -> void:
	var t := create_tween()
	t.tween_property(n, "modulate:a", 0.0, 0.4)
	t.tween_callback(n.queue_free)


# --- the school bag -----------------------------------------------------------
func _show_exhibit(id: String) -> void:
	if id == "beg":
		await _take_bag()
		return
	await super._show_exhibit(id)


func _take_bag() -> void:
	if _prompt:
		_prompt.done()
		_prompt = null
	MusicDirector.stinger("st_item")
	player.face_cell(BAG_CELL)
	_remove_bag(true)
	if not Game.save["seen"].has("beg_alif"):
		Game.save["seen"].append("beg_alif")
		Game.persist()
	Game.toast(tr("Dapat: Beg Alif!"))
	await Game.say(Dialogue.lines("bilik_beg"))
	if _waiting_bag:
		_waiting_bag = false
		await Game.say(Dialogue.lines("bilik_peta"))
		_start_first_mission()
	bag_taken.emit()


## the bag leaves the floor (its tile becomes walkable)
func _remove_bag(animate: bool) -> void:
	_exhibits.erase("beg")
	_floor[BAG_CELL] = true
	var bag: Node2D = _pieces.get("beg")
	if bag == null or not is_instance_valid(bag):
		return
	_pieces.erase("beg")
	if not animate:
		bag.queue_free()
		return
	var t := create_tween().set_parallel()
	t.tween_property(bag, "position:y", bag.position.y - 10, 0.25)
	t.tween_property(bag, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(bag.queue_free)


## Misi 1.1 is on: out of the door, the map arrow points at Gerbang Masa
func _start_first_mission() -> void:
	if not Game.save["seen"].has("bilik_tutorial"):
		Game.save["seen"].append("bilik_tutorial")
		Game.persist()
	var zid := Game.next_zone()
	if zid == "":
		return
	MusicDirector.stinger("st_zone")
	Game.toast(tr("MISI %s BERMULA: %s") % [zid.replace("_", "."), str(Game.zone_data(zid).get("title", ""))], Color("8fe08a"))
	Game.context_hint = tr("Keluar ikut pintu, lepas tu ikut anak panah emas ke misi pertama.")


## the tutorial keeps Alif in until he has his bag
func _leave() -> void:
	if _waiting_bag:
		Main.pau_say(tr("Eh, beg kau! Ambil dulu, baru kita keluar."), 4.0)
		return
	super._leave()


## the batik blanket over sleeping Alif: cut from the room picture when there
## is one, else drawn to match the code-drawn bed in BilikArt
class Blanket extends Node2D:
	const AREA := Rect2(49, 70, 46, 24)  ## the lower bed in room pixels
	var room: Texture2D

	func _ready() -> void:
		z_index = 2

	func _draw() -> void:
		if room:
			draw_texture_rect_region(room, AREA, AREA)
			return
		draw_rect(Rect2(50, 74, 44, 20), Color("3b7fa6"))
		draw_rect(Rect2(50, 74, 44, 3), Color("5a9cc0"))
		for y in range(80, 93, 6):
			for x in range(53, 92, 6):
				draw_rect(Rect2(x + (y / 6) % 2 * 3, y, 1, 1), Color("f3d36a"))
