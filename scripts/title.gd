extends Control
## Title screen: tap / click / any key to start.

var _t := 0.0
var _leaving := false

@onready var start_label: Label = $StartLabel
@onready var pau: TextureRect = $Pau


func _process(delta: float) -> void:
	_t += delta
	start_label.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)
	pau.position.y = 560 - absf(sin(_t * 4.0)) * 24


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		_leaving = true
		GameState.go_to("res://scenes/world/world.tscn")
