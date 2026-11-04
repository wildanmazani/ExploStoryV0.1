class_name Npc
extends Node2D
## A villager or historical figure standing on one tile. Turns to face Alif
## when spoken to, breathes gently while idle. With enable_wander() it strolls
## one tile at a time around its home spot (never further than the radius),
## asking the world first whether the tile is free. With enable_patrol() it
## walks a loop of waypoints (Guru Jalal round his arena), resting at each.

var id := ""
var look := ""  ## sprite folder: id, or its "stand_in" art until its own sprite exists
var cell := Vector2i.ZERO
var facing := "south"

const STEP_TIME := 0.42

var home := Vector2i.ZERO
var wander_radius := 0
var moving := false

var _sprite: AnimatedSprite2D
var _t := randf() * TAU
var _world: Node
var _rest := 0.0
var patrol: Array[Vector2i] = []  ## waypoints, walked in a loop
var _leg := 0


func setup(npc_id: String, at: Vector2i, face: String) -> void:
	id = npc_id
	look = npc_id
	if not ResourceLoader.exists("%s%s/%s_south.png" % [CharacterFrames.BASE, npc_id, npc_id]):
		look = str(Game.characters.get(npc_id, {}).get("stand_in", {}).get("sprite", npc_id))
	cell = at
	facing = face
	position = Player.cell_to_pos(at)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = CharacterFrames.build(look)
	_sprite.offset = CharacterFrames.feet_offset(look)
	add_child(_sprite)
	_sprite.play("idle_" + facing)


func enable_wander(world: Node, radius := 2) -> void:
	_world = world
	home = cell
	wander_radius = radius
	_sprite.sprite_frames = CharacterFrames.build(look, true)
	_sprite.play("idle_" + facing)
	_rest = randf_range(1.5, 5.0)


func enable_patrol(world: Node, points: Array[Vector2i]) -> void:
	_world = world
	home = cell
	patrol = points
	_sprite.sprite_frames = CharacterFrames.build(look, true)
	_sprite.play("idle_" + facing)
	_rest = randf_range(1.0, 3.0)


func face_towards(other: Vector2i) -> void:
	var d := other - cell
	if absi(d.x) > absi(d.y):
		facing = "east" if d.x > 0 else "west"
	else:
		facing = "south" if d.y > 0 else "north"
	_sprite.play("idle_" + facing)


## a cutscene walks this NPC, t seconds a step. Pass the world when the NPC is
## registered there (its blocked tile and talk tile move with it).
func script_walk(cells: Array, t := STEP_TIME, world: Node = null) -> void:
	_sprite.sprite_frames = CharacterFrames.build(look, true)
	for next: Vector2i in cells:
		face_towards(next)
		if world:
			world.move_npc(self, next)
		cell = next
		moving = true
		var walk := "walk_" + facing
		if _sprite.sprite_frames.get_frame_count(walk) > 0:
			_sprite.play(walk)
		var tw := create_tween()
		tw.tween_property(self, "position", Player.cell_to_pos(next), t)
		await tw.finished
		moving = false
	_sprite.play("idle_" + facing)


func _process(delta: float) -> void:
	_t += delta
	_sprite.scale.y = 1.0 + sin(_t * 2.2) * 0.02  # breathing
	if (wander_radius > 0 or not patrol.is_empty()) and not moving:
		_rest -= delta
		if _rest <= 0.0:
			if patrol.is_empty():
				_rest = randf_range(2.0, 5.0)
				_wander()
			else:
				_rest = 0.0
				_patrol_step()


## one tile towards the next waypoint (across first, then up or down); at a
## waypoint he stops a moment and looks over the sparring before walking on
func _patrol_step() -> void:
	if not _world.npc_may_wander(self):
		_rest = 0.5
		return
	var goal: Vector2i = patrol[_leg]
	if cell == goal:
		_leg = (_leg + 1) % patrol.size()
		var ahead: Vector2i = patrol[_leg] - cell
		face_towards(cell + Vector2i(-signi(ahead.y), signi(ahead.x)))  # towards the inside of the loop
		_rest = randf_range(1.2, 2.8)
		return
	var d := goal - cell
	var to := cell + (Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y)))
	if not _world.npc_cell_free(to):
		_rest = 0.6  # someone in the way: wait for them
		return
	face_towards(to)
	_world.move_npc(self, to)
	cell = to
	moving = true
	var walk := "walk_" + facing
	if _sprite.sprite_frames.has_animation(walk) and _sprite.sprite_frames.get_frame_count(walk) > 0:
		_sprite.play(walk)
	var tw := create_tween()
	tw.tween_property(self, "position", Player.cell_to_pos(to), STEP_TIME)
	await tw.finished
	moving = false
	if cell == patrol[_leg]:
		_sprite.play("idle_" + facing)


func _wander() -> void:
	if not _world.npc_may_wander(self):
		return
	var options: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c: Vector2i = cell + d
		var off := c - home
		if absi(off.x) <= wander_radius and absi(off.y) <= wander_radius and _world.npc_cell_free(c):
			options.append(c)
	if options.is_empty():
		return
	var to: Vector2i = options.pick_random()
	face_towards(to)
	_world.move_npc(self, to)
	cell = to
	moving = true
	var walk := "walk_" + facing
	if _sprite.sprite_frames.has_animation(walk) and _sprite.sprite_frames.get_frame_count(walk) > 0:
		_sprite.play(walk)
	var tw := create_tween()
	tw.tween_property(self, "position", Player.cell_to_pos(to), STEP_TIME)
	await tw.finished
	moving = false
	_sprite.play("idle_" + facing)


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.28))
