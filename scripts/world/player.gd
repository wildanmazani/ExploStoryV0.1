extends CharacterBody2D
## Alif in the world. Keyboard (WASD / arrows) or tap-to-move.

const SPEED := 280.0
const ROWS := {"down": 0, "left": 1, "right": 2, "up": 3}
const WALK_FRAMES := [1, 0, 2, 0]

var sheet_path: String = "res://assets/sprites/alif.png"
var bounds: Rect2 = Rect2(0, 0, 1280, 720)
var sprite: Sprite2D
var _target: Variant = null
var _on_arrive: Callable
var _dir: String = "down"
var _anim: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sprite = Sprite2D.new()
	sprite.texture = load(sheet_path)
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.scale = Vector2(4, 4)
	sprite.position = Vector2(0, -44)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 18)
	col.shape = shape
	add_child(col)


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 26, Color(0, 0, 0, 0.28))


func go_to(point: Vector2, on_arrive: Callable = Callable()) -> void:
	_target = Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y))
	_on_arrive = on_arrive


func stop() -> void:
	_target = null
	velocity = Vector2.ZERO


func face(d: String) -> void:
	_dir = d
	sprite.frame = ROWS[_dir] * 3


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if not Game.is_locked():
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v != Vector2.ZERO:
			_target = null
		elif _target != null:
			var to: Vector2 = (_target as Vector2) - global_position
			if to.length() < 10.0:
				_target = null
				if _on_arrive.is_valid():
					var cb := _on_arrive
					_on_arrive = Callable()
					cb.call()
			else:
				v = to.normalized()
	else:
		_target = null
	velocity = v * SPEED
	move_and_slide()
	global_position = Vector2(clampf(global_position.x, bounds.position.x, bounds.end.x), clampf(global_position.y, bounds.position.y, bounds.end.y))
	if v != Vector2.ZERO:
		if absf(v.x) > absf(v.y):
			_dir = "right" if v.x > 0 else "left"
		else:
			_dir = "down" if v.y > 0 else "up"
		_anim += delta * 8.0
		sprite.frame = ROWS[_dir] * 3 + WALK_FRAMES[int(_anim) % 4]
	else:
		_anim = 0.0
		sprite.frame = ROWS[_dir] * 3
