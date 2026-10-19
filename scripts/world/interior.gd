extends Node2D
## A one-screen interior (Pokémon-style building) drawn from a 320x180
## illustrated background. Alif walks on a set of floor cells; stepping onto
## an exit cell fades back to the overworld. Zone steps run through ZoneRunner.

const TILE := 16
const UI = preload("res://scripts/ui/ui.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const ZonePrep = preload("res://scripts/screens/zone_prep.gd")

@export var background: Texture2D
@export var title := ""
@export var zone_id := ""
@export var music := "balai"
## floor rows as "y:x0-x1" strings, e.g. ["9:5-14", "10:2-17"]
@export var floor_rows: PackedStringArray
@export var exit_cells: Array[Vector2i] = []
@export var enter_cell := Vector2i(10, 10)
@export var return_cell_world := Vector2i(55, 30)   ## overworld cell outside the door
@export var npc_id := ""
@export var npc_cell := Vector2i(10, 9)
## extra objects: "id:texture:x:y:w" (anchor = bottom-left cell, w = width in cells)
@export var props: PackedStringArray

var _floor := {}
var busy := false
var npc: Npc
var runner := ZoneRunner.new()
var hud: Control
var _props := {}  ## id -> {sprite, cells}

@onready var player: Player = $Objects/Player
@onready var pau: Pau = $Objects/Pau
@onready var prompt: Button = $HUD/Prompt


func _ready() -> void:
	$Background.texture = background
	for row in floor_rows:
		var parts := row.split(":")
		var span := parts[1].split("-")
		for x in range(int(span[0]), int(span[1]) + 1):
			_floor[Vector2i(x, int(parts[0]))] = true
	for c in exit_cells:
		_floor[c] = true
	for p in props:
		var f := p.split(":")
		var tex: Texture2D = load("res://assets/objects/%s.png" % f[1])
		var s := Sprite2D.new()
		s.texture = tex
		s.offset = CharacterFrames.visible_bottom_offset(tex)
		var at := Vector2i(int(f[2]), int(f[3]))
		var w := int(f[4])
		s.position = Vector2((at.x + w / 2.0) * TILE, (at.y + 1) * TILE)
		$Objects.add_child(s)
		var cells := []
		for dx in w:
			cells.append(at + Vector2i(dx, 0))
			_floor.erase(at + Vector2i(dx, 0))
		_props[f[0]] = {"sprite": s, "cells": cells}
	if npc_id != "":
		npc = Npc.new()
		npc.setup(npc_id, npc_cell, "south")
		$Objects.add_child(npc)

	hud = Hud.new()
	$HUD.add_child(hud)
	$HUD.move_child(hud, 0)
	hud.set_location(title.to_upper(), str(Game.zone_data(zone_id).get("subtopik", "")) if zone_id != "" else "")
	prompt.theme = Game.theme
	prompt.pressed.connect(func(): _interact(player.facing_cell()))

	player.world = self
	player.get_node("Camera2D").enabled = false
	player.place_at(enter_cell, "north")
	pau.place_at(enter_cell + Vector2i(-1, 0))
	pau.follow(player)
	player.step_finished.connect(_on_step)
	player.bumped.connect(func(_c): Sfx.play_varied("bump", -4.0))
	Main.set_pau_visible(true)
	MusicDirector.play(music)
	add_child(runner)
	runner.setup(self)
	_welcome()


func _welcome() -> void:
	if zone_id == "" or Game.zone_done(zone_id) or not Game.zone_state(zone_id)["steps"].is_empty():
		return
	if not Game.zone_unlocked(zone_id) or GameState.flags.get("welcomed_" + zone_id, false):
		return
	GameState.flags["welcomed_" + zone_id] = true
	busy = true
	await get_tree().create_timer(0.5).timeout
	var prep := ZonePrep.new()
	prep.set("params", {"zone": zone_id})
	Main.overlay_root().add_child(prep)
	await prep.closed
	await Game.say(str(Game.zone_data(zone_id).get("intro", "")))
	runner.refresh()
	busy = false


# --- ZoneRunner host API ---------------------------------------------------------
func spot_ids() -> Array:
	var ids := _props.keys()
	if npc_id != "":
		ids.append(npc_id)
	return ids


func marker_pos(id: String) -> Vector2:
	if id == npc_id:
		return Player.cell_to_pos(npc_cell) + Vector2(0, -34)
	var p: Dictionary = _props.get(id, {})
	if p.is_empty():
		return Vector2.ZERO
	var s: Sprite2D = p["sprite"]
	return s.position + Vector2(0, -s.texture.get_image().get_used_rect().size.y - 4)


func apply_after(_zid: String, _s: Dictionary, _animate: bool) -> void:
	pass


func on_zone_complete(_zid: String) -> void:
	pass


func return_cell() -> Vector2i:
	return return_cell_world


# --- movement / interaction ---------------------------------------------------------
func is_walkable(c: Vector2i) -> bool:
	return _floor.has(c) and not (npc and c == npc.cell)


func _on_step(c: Vector2i) -> void:
	Sfx.play_varied("step_wood", -6.0, 0.12)
	if c in exit_cells:
		busy = true
		player.can_move = false
		GameState.spawn_cell = return_cell_world
		GameState.spawn_facing = "south"
		GameState.go_to("res://scenes/world/world.tscn")


func _process(_d: float) -> void:
	var c := player.facing_cell()
	var label := ""
	if not busy and not runner.busy and not Game.is_locked() and not player.moving:
		if npc and c == npc.cell:
			label = Game.char_name(npc_id)
		else:
			for id in _props:
				if c in _props[id]["cells"]:
					label = _prop_label(id)
	prompt.visible = label != ""
	if prompt.visible:
		prompt.text = "E / Ketik: " + label
		prompt.reset_size()
		var screen := get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, 14))
		prompt.position = Vector2(clampf(screen.x - prompt.size.x / 2.0, 10, 1270 - prompt.size.x), clampf(screen.y + 8, 120, 640))


func _prop_label(id: String) -> String:
	for o in Game.zone_data(zone_id).get("objects", []):
		if str(o["id"]) == id and o.has("label"):
			return str(o["label"])
	return "Lihat"


func _unhandled_input(event: InputEvent) -> void:
	if busy or runner.busy or Game.is_locked() or player.moving:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact(player.facing_cell())
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		Main.open_settings()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var tc := get_node_or_null("TouchControls")
		if tc and tc.owns(event.position):
			return  # a thumb on the D-pad / joystick, not a tap on the floor
		var cell := Vector2i((get_global_mouse_position() / TILE).floor())
		var target_id := ""
		if npc and (cell == npc.cell or cell == npc.cell + Vector2i(0, -1)):
			cell = npc.cell
			target_id = npc_id
		for id in _props:
			if cell in _props[id]["cells"]:
				target_id = id
		if target_id != "":
			var path := Pathfind.to_neighbour(self, player.cell, cell)
			var go := func():
				player.face_cell(cell)
				_interact(cell)
			if path.is_empty():
				go.call()
			else:
				player.walk_path(path, go)
		elif is_walkable(cell):
			player.walk_path(Pathfind.find(self, player.cell, cell))


func _interact(c: Vector2i) -> void:
	if busy or runner.busy or Game.is_locked():
		return
	var id := ""
	if npc and c == npc.cell:
		id = npc_id
		npc.face_towards(player.cell)
	elif c == pau.cell:
		busy = true
		pau.hop()
		await Game.say(Dialogue.lines("pau_tap"))
		busy = false
		return
	else:
		for pid in _props:
			if c in _props[pid]["cells"]:
				id = pid
	if id == "":
		return
	busy = true
	var handled: bool = await runner.handle(id)
	if not handled and Dialogue.has(id):
		await Game.say(Dialogue.lines(id))
	busy = false
