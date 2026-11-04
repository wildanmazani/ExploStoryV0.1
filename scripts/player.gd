class_name Player
extends Node2D
## Alif on the overworld grid, Pokémon-style: one 16 px tile per step (two
## direction keys together step diagonally), a quick tap only turns him, hold
## B (Shift / X) to run.

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
var _held_vec := Vector2i.ZERO
var _turned := false
var _bump_cooldown := 0.0
var _path: Array = []
var _on_arrive: Callable
var _look := ""  ## set_look(): a sprite folder worn instead of the outfit
var _bag: Sprite2D  ## the school bag, over any outfit (Game.bag_worn())
var _bag_dir := ""

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_bag = Sprite2D.new()
	add_child(_bag)
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
	_bag.visible = bag_on()
	_bag.offset = sprite.offset
	_bag_dir = ""


func bag_on() -> bool:
	return Game.bag_worn() and _look == ""


## the bag turns with Alif: on his back from behind and from the side, its
## two straps over his shoulders from the front. It bobs with his steps and
## falls with him.
func _update_bag() -> void:
	if facing != _bag_dir:
		_bag_dir = facing
		_bag.texture = load("res://assets/characters32/beg/beg_%s.png" % facing)
		move_child(_bag, get_child_count() - 1)
	_bag.rotation = sprite.rotation
	_bag.position = Vector2(0, 1 if moving and sprite.frame % 3 == 1 else 0)


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


## a cutscene walks Alif (can_move off): one cell after another, t seconds a step
func script_walk(cells: Array, t := WALK_TIME) -> void:
	for next: Vector2i in cells:
		var d := next - cell
		facing = "east" if d.x > 0 else "west" if d.x < 0 else "south" if d.y > 0 else "north"
		var from := cell
		cell = next
		moving = true
		sprite.play("walk_" + facing)
		sprite.speed_scale = WALK_TIME / t
		step_started.emit(from, next, t)
		var tween := create_tween()
		tween.tween_property(self, "position", cell_to_pos(next), t)
		await tween.finished
		moving = false
		step_finished.emit(cell)
	sprite.speed_scale = 1.0
	_idle()


func _process(delta: float) -> void:
	if _bag.visible:
		_update_bag()
	_bump_cooldown = maxf(_bump_cooldown - delta, 0)
	if moving or not can_move or Game.is_locked():
		return
	var v := _input_vec()
	if v != Vector2i.ZERO:
		_path.clear()  # keyboard / D-pad always wins over a tap path
	elif not _path.is_empty():
		var next: Vector2i = _path.pop_front()
		var pdir := dir_name(next - cell)
		facing = pdir
		if world and not world.is_walkable(next):
			_path.clear()
			_idle()
			return
		_try_step(next - cell)
		if _path.is_empty() and _on_arrive.is_valid():
			var cb := _on_arrive
			_on_arrive = Callable()
			await step_finished
			cb.call()
		return
	if v == Vector2i.ZERO:
		_held_vec = Vector2i.ZERO
		_hold_time = 0.0
		_idle()
		return
	var dir := dir_name(v)
	if v != _held_vec:  # new press
		var fresh := _held_vec == Vector2i.ZERO
		_held_vec = v
		if fresh:
			_hold_time = 0.0
			_turned = dir != facing
		facing = dir
		_idle()
	_hold_time += delta
	if _turned and _hold_time < TURN_GRACE:
		return  # tap = turn on the spot
	_try_step(v)


## the held direction keys as one step: two keys together walk diagonally
func _input_vec() -> Vector2i:
	var v := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): v.y -= 1
	if Input.is_action_pressed("move_down"): v.y += 1
	if Input.is_action_pressed("move_left"): v.x -= 1
	if Input.is_action_pressed("move_right"): v.x += 1
	return v


## the way a step faces: sideways for diagonals (the sprites have four sides)
static func dir_name(v: Vector2i) -> String:
	if v.x != 0:
		return "east" if v.x > 0 else "west"
	return "south" if v.y > 0 else "north"


func _try_step(v: Vector2i) -> void:
	if v.x != 0 and v.y != 0 and world:
		# a diagonal step needs the corner free on both sides (no cutting
		# through a wall's edge); otherwise slide along the open side
		var side := cell + Vector2i(v.x, 0)
		var up := cell + Vector2i(0, v.y)
		if not (world.is_walkable(cell + v) and world.is_walkable(side) and world.is_walkable(up)):
			if world.is_walkable(side):
				v = Vector2i(v.x, 0)
			elif world.is_walkable(up):
				v = Vector2i(0, v.y)
			else:
				v = Vector2i(v.x, 0)
	var dir := dir_name(v)
	facing = dir
	var target: Vector2i = cell + v
	if world and not world.is_walkable(target):
		_idle()
		if _bump_cooldown <= 0:
			_bump_cooldown = 0.35
			bumped.emit(target)
			_bump_wobble()
		return
	var running := Input.is_action_pressed("run")
	var t := RUN_TIME if running else WALK_TIME
	if v.x != 0 and v.y != 0:
		t *= 1.4  # the same speed along the diagonal
	var from := cell
	cell = target
	moving = true
	sprite.play("walk_" + dir)
	sprite.speed_scale = WALK_TIME / t * (1.4 if v.x != 0 and v.y != 0 else 1.0)
	step_started.emit(from, target, t)
	var tween := create_tween()
	tween.tween_property(self, "position", cell_to_pos(target), t)
	await tween.finished
	moving = false
	step_finished.emit(cell)
	if _input_vec() == Vector2i.ZERO and _path.is_empty():
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
