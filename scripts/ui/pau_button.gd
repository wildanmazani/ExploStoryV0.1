extends Control
## Pau, always in the bottom-right corner: just the bun, squishy under the
## finger. Tap = hint (3 levels inside a puzzle). Press and hold = calm moment.

const UI = preload("res://scripts/ui/ui.gd")
const HOLD_TIME := 0.6
const SPRING := 260.0
const DAMP := 11.0
const ART := "res://assets/ui/pau_besar.png"
const ART_SQUEEZED := "res://assets/ui/pau_besar_picit.png"
const FALLBACK := "res://assets/characters32/pau/pau_small.png"

signal tapped
signal held

var _sprite: TextureRect
var _face: Texture2D
var _squeezed: Texture2D
var _t: float = 0.0
var _press_time: float = -1.0
var _held_fired: bool = false
var _squish: float = 0.0
var _squish_v: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	custom_minimum_size = Vector2(120, 130)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Klik: petunjuk. Tekan lama: bertenang."
	_face = UI.tex(ART if ResourceLoader.exists(ART) else FALLBACK)
	_squeezed = UI.tex(ART_SQUEEZED) if ResourceLoader.exists(ART_SQUEEZED) else _face
	_sprite = TextureRect.new()
	_sprite.texture = _face
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.size = Vector2(112, 112)
	_sprite.position = Vector2(4, 12)
	_sprite.pivot_offset = Vector2(56, 112)  # squeezed from the feet, like dough on a table
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)


## a little jiggle when Pau speaks
func happy() -> void:
	_squish_v = -9.0


## a spring pulls the squish towards pressed (1) or rest (0), so the bun sinks
## under the finger and wobbles back when let go
func _process(delta: float) -> void:
	_t += delta
	var pressed := _press_time >= 0.0
	var target := 1.0 if pressed else 0.0
	_squish_v += ((target - _squish) * SPRING - _squish_v * DAMP) * delta
	_squish += _squish_v * delta
	var breathe := sin(_t * 2.6) * 0.025
	_sprite.scale = Vector2(1.0 + _squish * 0.3 + breathe, 1.0 - _squish * 0.32 - breathe)
	_sprite.texture = _squeezed if pressed else _face
	if pressed and _t - _press_time >= HOLD_TIME and not _held_fired:
		_held_fired = true
		held.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_time = _t
			_held_fired = false
		elif _press_time >= 0.0:
			var short := not _held_fired
			_press_time = -1.0
			if short:
				tapped.emit()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pau"):
		tapped.emit()
		get_viewport().set_input_as_handled()
