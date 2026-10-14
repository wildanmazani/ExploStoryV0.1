class_name Npc
extends Node2D
## A villager or historical figure standing on one tile. Turns to face Alif
## when spoken to, breathes gently while idle.

var id := ""
var cell := Vector2i.ZERO
var facing := "south"

var _sprite: AnimatedSprite2D
var _t := randf() * TAU


func setup(npc_id: String, at: Vector2i, face: String) -> void:
	id = npc_id
	cell = at
	facing = face
	position = Player.cell_to_pos(at)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = CharacterFrames.build(npc_id)
	_sprite.offset = CharacterFrames.feet_offset(npc_id)
	add_child(_sprite)
	_sprite.play("idle_" + facing)


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


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.28))
