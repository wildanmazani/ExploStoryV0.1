class_name Player
extends Node2D
## Alif on the overworld grid, Pokémon-style: one 16 px tile per step,
## a quick tap only turns him, hold B (Shift / X) to run.

signal step_started(from: Vector2i, to: Vector2i, duration: float)
signal step_finished(cell: Vector2i)
signal bumped(cell: Vector2i)

const TILE := 16
const WALK_TIME := 0.22
const RUN_TIME := 0.13
const TURN_GRACE := 0.09  ## a tap shorter than this only turns
const DIRS := {
	"south": Vector2i(0, 1), "north": Vector2i(0, -1),
	"east": Vector2i(1, 0), "west": Vector2i(-1, 0),
}

var cell := Vector2i.ZERO
var facing := "south"
var can_move := true
var moving := false
var world: Node  ## must provide is_walkable(cell) -> bool

var _hold_time := 0.0
var _held_dir := ""
var _turned := false
var _bump_cooldown := 0.0
var _path: Array = []
var _on_arrive: Callable
var _look := ""  ## set_look(): a sprite folder worn instead of the outfit

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_apply_skin()
	Game.skin_changed.connect(_apply_skin)
	_idle()


## Alif's outfit from the shop (Game.save.skin), unless a scene dresses him
## for a moment (set_look: Bilik Alif before he picks up his bag)
func _apply_skin() -> void:
	var folder := Game.skin_folder()
	if _look != "" and ResourceLoader.exists("%s%s/%s_south.png" % [CharacterFrames.BASE, _look, _look]):
		folder = _look
	sprite.sprite_frames = CharacterFrames.build(folder, true)
	sprite.offset = CharacterFrames.feet_offset(folder)
	sprite.play("idle_" + facing)


## wear this sprite folder instead of the shop outfit ("" = back to the outfit)
func set_look(folder: String) -> void:
	_look = folder
	if sprite:
		_apply_skin()


func place_at(c: Vector2i, face := "south") -> void:
	cell = c
	position = cell_to_pos(c)
	facing = face
	_idle()


static func cell_to_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2, c.y * TILE + TILE - 1)


func facing_cell() -> Vector2i:
	return cell + DIRS[facing]


func face_cell(c: Vector2i) -> void:
	var d := c - cell
	if absi(d.x) > absi(d.y):
		facing = "east" if d.x > 0 else "west"
	else:
		facing = "south" if d.y > 0 else "north"
	_idle()


## tap-to-walk: follow a list of cells, then call on_arrive
func walk_path(path: Array, on_arrive := Callable()) -> void:
	_path = path.duplicate()
	_on_arrive = on_arrive


func _process(delta: float) -> void:
	_bump_cooldown = maxf(_bump_cooldown - delta, 0)
	if moving or not can_move or Game.is_locked():
		return
	var dir := _input_dir()
	if dir != "":
		_path.clear()  # keyboard / D-pad always wins over a tap path
	elif not _path.is_empty():
		var next: Vector2i = _path.pop_front()
		var d := next - cell
		var pdir := "east" if d.x > 0 else "west" if d.x < 0 else "south" if d.y > 0 else "north"
		facing = pdir
		if world and not world.is_walkable(next):
			_path.clear()
			_idle()
			return
		_try_step(pdir)
		if _path.is_empty() and _on_arrive.is_valid():
			var cb := _on_arrive
			_on_arrive = Callable()
			await step_finished
			cb.call()
		return
	if dir == "":
		_held_dir = ""
		_hold_time = 0.0
		_idle()
		return
	if dir != _held_dir:  # new press
		_held_dir = dir
		_hold_time = 0.0
		_turned = dir != facing
		facing = dir
		_idle()
	_hold_time += delta
	if _turned and _hold_time < TURN_GRACE:
		return  # tap = turn on the spot
	_try_step(dir)


func _input_dir() -> String:
	# last-pressed wins would be nicer; vertical first is the classic feel
	if Input.is_action_pressed("move_up"): return "north"
	if Input.is_action_pressed("move_down"): return "south"
	if Input.is_action_pressed("move_left"): return "west"
	if Input.is_action_pressed("move_right"): return "east"
	return ""


func _try_step(dir: String) -> void:
	var target: Vector2i = cell + DIRS[dir]
	if world and not world.is_walkable(target):
		_idle()
		if _bump_cooldown <= 0:
			_bump_cooldown = 0.35
			bumped.emit(target)
			_bump_wobble()
		return
	var running := Input.is_action_pressed("run")
	var t := RUN_TIME if running else WALK_TIME
	var from := cell
	cell = target
	moving = true
	sprite.play("walk_" + dir)
	sprite.speed_scale = WALK_TIME / t
	step_started.emit(from, target, t)
	var tween := create_tween()
	tween.tween_property(self, "position", cell_to_pos(target), t)
	await tween.finished
	moving = false
	step_finished.emit(cell)
	if _input_dir() == "" and _path.is_empty():
		_idle()


func _idle() -> void:
	var anim := "idle_" + facing
	if sprite.animation != anim:
		sprite.play(anim)


func _bump_wobble() -> void:
	var tween := create_tween()
	var nudge := Vector2(DIRS[facing]) * 1.5
	tween.tween_property(sprite, "position", nudge, 0.06)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.08)


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.28))
