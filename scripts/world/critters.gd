class_name Critter
extends Node2D
## Little animals that make the kampung feel lived in: ayam (chickens) that
## wander and peck around the houses and itik (ducks) paddling on the pond and
## river. Drawn in code, purely for looks: they never block anyone.

const TILE := 16

var kind := "ayam"
var world: Node2D
var home := Vector2.ZERO        ## they never stray far from here
var _target := Vector2.ZERO
var _wait := 0.0
var _peck := 0.0
var _t := randf() * TAU
var _flip := false


func setup(w: Node2D, what: String, cell: Vector2i) -> void:
	world = w
	kind = what
	position = Vector2(cell) * TILE + Vector2(8, 12)
	home = position
	_target = position
	_wait = randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	_t += delta
	_peck = maxf(_peck - delta, 0.0)
	var to := _target - position
	if to.length() > 0.5:
		var speed := 7.0 if kind == "itik" else 12.0
		position += to.limit_length(speed * delta)
		_flip = to.x < 0
	else:
		_wait -= delta
		if _wait <= 0:
			_wait = randf_range(1.5, 4.5)
			if kind == "ayam" and randf() < 0.45:
				_peck = 0.9  # stays put, pecks the ground
			else:
				_pick_target()
	queue_redraw()


func _pick_target() -> void:
	for i in 8:
		var p := home + Vector2(randf_range(-40, 40), randf_range(-28, 28))
		var c := Vector2i((p / TILE).floor())
		if _ok(c) and _ok(Vector2i(((position + p) / 2.0 / TILE).floor())):
			_target = p
			return


func _ok(c: Vector2i) -> bool:
	var water: bool = world.terrain.is_water(c) and not world.walk_over.has(c)
	if kind == "itik":
		return water and world.terrain.terrain_at(c) == TerrainBuilder.RIVER
	return not water and not world.blocked.has(c)


func _draw() -> void:
	if _flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	if kind == "itik":
		_draw_duck()
	else:
		_draw_chicken()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _draw_chicken() -> void:
	var walking := (_target - position).length() > 0.5
	var bob := 1.0 if walking and sin(_t * 16.0) > 0 else 0.0
	var head_down := _peck > 0 and fmod(_peck, 0.3) < 0.15
	var white := Color("f6f1e4")
	var shade := Color("d9cfbb")
	var out := Color("4a3a2a")
	# shadow, legs
	draw_circle(Vector2(0, 0), 3.5, Color(0, 0, 0, 0.18))
	_px(-1, -2, 1, 2, Color("e0a030"))
	_px(1, -2, 1, 2, Color("e0a030"))
	# body and tail
	_px(-4, -7 - bob, 7, 5, out)
	_px(-3, -6 - bob, 5, 3, white)
	_px(-3, -4 - bob, 5, 1, shade)
	_px(-5, -9 - bob, 2, 3, out)
	_px(-4, -8 - bob, 1, 2, white)
	# head (dips when pecking)
	var hy := -6.0 if head_down else -10.0
	var hx := 3.0 if head_down else 2.0
	_px(hx - 1, hy - bob - 1, 4, 4, out)
	_px(hx, hy - bob, 2, 2, white)
	_px(hx, hy - bob - 2, 2, 1, Color("e23b3b"))   # comb
	_px(hx + 2, hy - bob + 1, 2, 1, Color("f0b030"))  # beak
	_px(hx + 1, hy - bob, 1, 1, Color("1d1a18"))   # eye


func _draw_duck() -> void:
	var bob := sin(_t * 3.0) * 0.5
	# ripple ring under the duck
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(-1 if _flip else 1, 0.4))
	draw_arc(Vector2(0, 0), 7.0 + sin(_t * 2.0), 0, TAU, 16, Color(1, 1, 1, 0.35), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if _flip else 1, 1))
	var out := Color("3a3028")
	_px(-5, -4 + bob, 9, 4, out)
	_px(-4, -3 + bob, 7, 2, Color("f4efe2"))
	_px(-5, -5 + bob, 2, 2, out)
	_px(2, -8 + bob, 4, 4, out)
	_px(3, -7 + bob, 2, 2, Color("3f9a52"))   # green head
	_px(5, -6 + bob, 2, 1, Color("f0a020"))   # beak
	_px(4, -7 + bob, 1, 1, Color("101010"))
