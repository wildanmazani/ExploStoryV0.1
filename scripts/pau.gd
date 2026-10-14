class_name Pau
extends Node2D
## Pau follows Alif one tile behind (HG/SS style): whenever Alif starts a
## step, Pau hops into the tile Alif just left. Squishy bounce on every hop.

const TEX := preload("res://assets/characters32/pau/pau_small.png")

var cell := Vector2i.ZERO
var _t := 0.0
var _hop := 0.0
var _squash := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = TEX
	sprite.offset = CharacterFrames.visible_bottom_offset(TEX)


func follow(player: Player) -> void:
	player.step_started.connect(_on_leader_step)


func place_at(c: Vector2i) -> void:
	cell = c
	position = Player.cell_to_pos(c)


func _on_leader_step(from: Vector2i, _to: Vector2i, duration: float) -> void:
	if from == cell:
		return
	var dir := Vector2(from - cell)
	cell = from
	sprite.flip_h = dir.x < 0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position", Player.cell_to_pos(from), duration)
	tween.tween_method(func(v: float): _hop = sin(v * PI) * 5.0, 0.0, 1.0, duration)
	tween.chain().tween_property(self, "_squash", 1.0, 0.0)
	tween.chain().tween_property(self, "_squash", 0.0, 0.18)


func _process(delta: float) -> void:
	_t += delta
	var idle := absf(sin(_t * 3.0)) * 1.5  # gentle breathing bounce when still
	sprite.position.y = -_hop - idle
	var s := _squash * 0.25 + (1.0 - absf(sin(_t * 3.0))) * 0.05
	sprite.scale = Vector2(1.0 + s, 1.0 - s)


## happy hop when tapped or talked to
func hop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_hop", 9.0, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_hop", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_squash", 1.0, 0.0)
	tween.tween_property(self, "_squash", 0.0, 0.18)


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 5, Color(0, 0, 0, 0.25))
