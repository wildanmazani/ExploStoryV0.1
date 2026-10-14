extends Node2D
## Dunia Explo-Story overworld. Builds itself from data/world/ (made by
## tools/gen_world.py): terrain tiles, props with collision, NPCs, signs and
## flag gates. Handles talking/reading, and area titles as you walk.

const TILE := 16
const SWAY := preload("res://shaders/sway.gdshader")
const WATER := preload("res://shaders/water.gdshader")

## char -> texture name in assets/objects/, footprint (w, h) in cells,
## sway = wind shader, flat = drawn under characters with no collision,
## walk = footprint cells become walkable (jetty over water),
## open = footprint columns that stay walkable (gate opening)
const OBJECTS := {
	"P": {"tex": "palm", "foot": Vector2i(1, 1), "sway": 1.2},
	"T": {"tex": "tree", "foot": Vector2i(2, 1), "sway": 1.0},
	"B": {"tex": "bush", "foot": Vector2i(2, 1), "sway": 0.6},
	"R": {"tex": "rocks", "foot": Vector2i(2, 1)},
	"F": {"tex": "flowers", "foot": Vector2i(2, 1), "flat": true, "sway": 0.5},
	"f": {"tex": "fence", "foot": Vector2i(2, 1)},
	"H": {"tex": "house", "foot": Vector2i(6, 3), "talk": "house"},
	"U": {"tex": "muzium", "foot": Vector2i(6, 3)},
	"M": {"tex": "stall", "foot": Vector2i(4, 2)},
	"K": {"tex": "monument", "foot": Vector2i(4, 2)},
	"Y": {"tex": "banyan", "foot": Vector2i(6, 2), "sway": 0.8},
	"G": {"tex": "gate_open", "foot": Vector2i(4, 1), "open": [1, 2]},
	"L": {"tex": "gate_locked", "foot": Vector2i(4, 1)},
	"S": {"tex": "sign", "foot": Vector2i(1, 1)},
	"I": {"tex": "istana", "foot": Vector2i(10, 4)},
	"J": {"tex": "jetty", "foot": Vector2i(2, 6), "flat": true, "walk": true},
	"X": {"tex": "ship", "foot": Vector2i(6, 4)},
	"b": {"tex": "perahu", "foot": Vector2i(3, 1)},
	"1": {"tex": "gate_funan", "foot": Vector2i(3, 1)},
	"2": {"tex": "gate_champa", "foot": Vector2i(3, 1)},
	"3": {"tex": "gate_srivijaya", "foot": Vector2i(3, 1)},
	"4": {"tex": "gate_melaka", "foot": Vector2i(3, 1)},
	"5": {"tex": "gate_johor", "foot": Vector2i(3, 1)},
}

var terrain := TerrainBuilder.new()
var blocked := {}      ## Vector2i -> true
var walk_over := {}    ## Vector2i -> true (jetty planks over water)
var interact := {}     ## Vector2i -> {type, id, ...}
var npcs := {}         ## Vector2i -> Npc
var areas: Array = []
var current_area := ""
var busy := false
var _banner_tween: Tween

@onready var ground: TileMapLayer = $Ground
@onready var decor: Node2D = $Decor
@onready var objects: Node2D = $Objects
@onready var player: Player = $Objects/Player
@onready var pau: Pau = $Objects/Pau
@onready var camera: Camera2D = $Objects/Player/Camera2D
@onready var dialog: DialogBox = $Dialog
@onready var banner: PanelContainer = $HUD/AreaBanner
@onready var banner_label: Label = $HUD/AreaBanner/Label


func _ready() -> void:
	terrain.load_layout("res://data/world/terrain.txt")
	terrain.paint(ground)
	var water := ShaderMaterial.new()
	water.shader = WATER
	ground.material = water

	_build_objects()
	_build_entities()

	camera.limit_right = terrain.width * TILE
	camera.limit_bottom = terrain.height * TILE

	player.world = self
	player.step_finished.connect(_on_step_finished)
	pau.follow(player)
	var ent := _entities()
	var spawn: Vector2i = GameState.spawn_cell if GameState.spawn_cell != null else Vector2i(ent["spawn"][0], ent["spawn"][1])
	player.place_at(spawn, GameState.spawn_facing)
	pau.place_at(spawn + Vector2i(-1, 0))
	camera.reset_smoothing()
	_on_step_finished(spawn)


func _entities() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/world/entities.json"))


# --- building -----------------------------------------------------------
func _build_objects() -> void:
	var rows := FileAccess.get_file_as_string("res://data/world/objects.txt").split("\n", false)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if OBJECTS.has(ch):
				_spawn_object(ch, Vector2i(x, y))


func _spawn_object(ch: String, anchor: Vector2i) -> void:
	var def: Dictionary = OBJECTS[ch]
	var foot: Vector2i = def["foot"]
	var tex: Texture2D = load("res://assets/objects/%s.png" % def["tex"])
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = CharacterFrames.visible_bottom_offset(tex)
	# bottom-centre of the footprint
	s.position = Vector2((anchor.x + foot.x / 2.0) * TILE, (anchor.y + 1) * TILE)
	if def.has("sway"):
		var m := ShaderMaterial.new()
		m.shader = SWAY
		m.set_shader_parameter("strength", def["sway"])
		s.material = m
	if def.get("flat", false):
		decor.add_child(s)
	else:
		objects.add_child(s)

	var open: Array = def.get("open", [])
	for dy in foot.y:
		for dx in foot.x:
			var c := Vector2i(anchor.x + dx, anchor.y - dy)
			if def.get("walk", false):
				walk_over[c] = true
			elif not def.get("flat", false) and not (dx in open):
				blocked[c] = true
			if def.has("talk"):
				interact[c] = {"type": "talk", "id": def["talk"]}


func _build_entities() -> void:
	var ent := _entities()
	for s in ent["signs"]:
		var size: Array = s.get("size", [1, 1])
		for dy in size[1]:
			for dx in size[0]:
				interact[Vector2i(s["pos"][0] + dx, s["pos"][1] - dy)] = {"type": "talk", "id": s["id"]}
	for g in ent["gates"]:
		var id := "gate_open_%d" % g["chapter"] if g["open"] else "gate_locked"
		for dx in 4:
			interact[Vector2i(g["pos"][0] + dx, g["pos"][1])] = {"type": "talk", "id": id}
	for n in ent["npcs"]:
		var npc := Npc.new()
		var at := Vector2i(n["pos"][0], n["pos"][1])
		npc.setup(n["id"], at, n["facing"])
		objects.add_child(npc)
		npcs[at] = npc
		blocked[at] = true
		interact[at] = {"type": "npc", "id": n["id"]}
	areas = ent["areas"]


# --- queries used by Player ------------------------------------------------
func is_walkable(c: Vector2i) -> bool:
	if blocked.has(c):
		return false
	if walk_over.has(c):
		return true
	return terrain.terrain_at(c) != TerrainBuilder.SEA


# --- interaction ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if busy or dialog.active:
		return
	if event.is_action_pressed("act") and not player.moving:
		get_viewport().set_input_as_handled()
		_interact(player.facing_cell())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i((get_global_mouse_position() / TILE).floor())
		if cell == pau.cell or cell == pau.cell + Vector2i(0, -1):
			get_viewport().set_input_as_handled()
			_talk_to_pau()


func _interact(c: Vector2i) -> void:
	if c == pau.cell:
		_talk_to_pau()
		return
	if not interact.has(c):
		return
	var it: Dictionary = interact[c]
	if it["type"] == "npc":
		npcs[c].face_towards(player.cell)
	await talk(it["id"])


func _talk_to_pau() -> void:
	pau.hop()
	await talk("pau_tap")


func talk(id: String) -> void:
	busy = true
	player.can_move = false
	await dialog.play(Dialogue.lines(id))
	player.can_move = true
	busy = false


# --- areas ---------------------------------------------------------------
func _on_step_finished(c: Vector2i) -> void:
	for a in areas:
		var r: Array = a["rect"]
		if c.x >= r[0] and c.x <= r[2] and c.y >= r[1] and c.y <= r[3]:
			if a["id"] != current_area:
				current_area = a["id"]
				_show_banner(a["name"])
			return


func _show_banner(text: String) -> void:
	banner_label.text = text
	if _banner_tween:
		_banner_tween.kill()
	var tween := create_tween()
	_banner_tween = tween
	banner.position.y = -90
	tween.tween_property(banner, "position:y", 20.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.2)
	tween.tween_property(banner, "position:y", -90.0, 0.3).set_ease(Tween.EASE_IN)
