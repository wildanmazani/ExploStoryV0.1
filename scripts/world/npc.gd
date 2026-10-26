class_name Npc
extends Node2D
## A villager or historical figure standing on one tile. Turns to face Alif
## when spoken to, breathes gently while idle. With enable_wander() it strolls
## one tile at a time around its home spot (never further than the radius),
## asking the world first whether the tile is free.

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


func face_towards(other: Vector2i) -> void:
	var d := other - cell
	if absi(d.x) > absi(d.y):
		facing = "east" if d.x > 0 else "west"
	else:
		facing = "south" if d.y > 0 else "north"
	_sprite.play("idle_" + facing)


func _process(delta: float) -> void:
	_t += delta
	_sprite.scale.y = 1.0 + sin(_t * 2.2) * 0.02  # breathing
	if wander_radius > 0 and not moving:
		_rest -= delta
		if _rest <= 0.0:
			_rest = randf_range(2.0, 5.0)
			_wander()


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
