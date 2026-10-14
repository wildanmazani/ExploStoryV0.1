extends Node2D
## A one-screen interior (Pokémon-style building) drawn from a 320x180
## illustrated background. Alif walks on a set of floor cells; stepping onto
## an exit cell fades back to the overworld.

const TILE := 16

@export var background: Texture2D
@export var title := ""
## floor rows as "y:x0-x1" strings, e.g. ["9:5-14", "10:2-17"]
@export var floor_rows: PackedStringArray
@export var exit_cells: Array[Vector2i] = []
@export var enter_cell := Vector2i(10, 10)
@export var return_cell := Vector2i(55, 30)   ## overworld cell outside the door
@export var npc_id := ""
@export var npc_cell := Vector2i(10, 9)

var _floor := {}
var busy := false
var npc: Npc

@onready var player: Player = $Objects/Player
@onready var pau: Pau = $Objects/Pau
@onready var dialog: DialogBox = $Dialog


func _ready() -> void:
	$Background.texture = background
	for row in floor_rows:
		var parts := row.split(":")
		var span := parts[1].split("-")
		for x in range(int(span[0]), int(span[1]) + 1):
			_floor[Vector2i(x, int(parts[0]))] = true
	for c in exit_cells:
		_floor[c] = true
	if npc_id != "":
		npc = Npc.new()
		npc.setup(npc_id, npc_cell, "south")
		$Objects.add_child(npc)
	player.world = self
	player.get_node("Camera2D").enabled = false
	player.place_at(enter_cell, "north")
	pau.place_at(enter_cell + Vector2i(-1, 0))
	pau.follow(player)
	player.step_finished.connect(_on_step)
	player.bumped.connect(func(_c): Sfx.play_varied("bump", -4.0))
	if title != "":
		_show_title()


func is_walkable(c: Vector2i) -> bool:
	return _floor.has(c) and not (npc and c == npc.cell)


func _on_step(c: Vector2i) -> void:
	Sfx.play_varied("step_wood", -6.0, 0.12)
	if c in exit_cells:
		player.can_move = false
		GameState.spawn_cell = return_cell
		GameState.spawn_facing = "south"
		GameState.go_to("res://scenes/world/world.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if busy or dialog.active or player.moving:
		return
	if event.is_action_pressed("act"):
		var f := player.facing_cell()
		if npc and f == npc.cell:
			npc.face_towards(player.cell)
			_talk(npc_id)
		elif f == pau.cell:
			pau.hop()
			_talk("pau_tap")


func _talk(id: String) -> void:
	busy = true
	player.can_move = false
	await dialog.play(Dialogue.lines(id))
	player.can_move = true
	busy = false


func _show_title() -> void:
	var label: Label = $HUD/Title
	label.text = title
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.5)
	t.tween_interval(2.0)
	t.tween_property(label, "modulate:a", 0.0, 0.6)
