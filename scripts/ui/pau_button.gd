extends Control
## Pau, always in the bottom-right corner. Tap = hint (3 levels inside a
## puzzle). Press and hold = calm moment.

const UI = preload("res://scripts/ui/ui.gd")
const HOLD_TIME := 0.6

signal tapped
signal held

var _sprite: TextureRect
var _frames: Array[Texture2D] = []
var _t: float = 0.0
var _press_time: float = -1.0
var _held_fired: bool = false
var _happy_t: float = 0.0
var _label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	custom_minimum_size = Vector2(120, 130)
	size = custom_minimum_size
	position = Vector2(1280 - 130, 720 - 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Ketik: petunjuk. Tekan lama: bertenang."
	var glow := PanelContainer.new()
	var gs := UI.sb(Color(0.12, 0.14, 0.2, 0.75), UI.GOLD, 3, 60, 0)
	glow.add_theme_stylebox_override("panel", gs)
	glow.position = Vector2(8, 4)
	glow.size = Vector2(104, 104)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	for i in 4:
		_frames.append(UI.sheet_frame("res://assets/sprites/pau.png", i, 0, 16, 16))
	_sprite = TextureRect.new()
	_sprite.texture = _frames[0]
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.size = Vector2(88, 88)
	_sprite.position = Vector2(16, 12)
	_sprite.pivot_offset = Vector2(44, 88)
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_label = UI.label("PAU", "Heading")
	_label.position = Vector2(36, 100)
	_label.add_theme_font_size_override("font_size", 20)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func happy() -> void:
	_happy_t = 1.2


func _process(delta: float) -> void:
	_t += delta
	var bounce := absf(sin(_t * 3.0))
	_sprite.position.y = 12 - bounce * 6.0
	if _press_time >= 0.0:
		var held_for := _t - _press_time
		_sprite.scale = Vector2.ONE * (1.0 + minf(held_for / HOLD_TIME, 1.0) * 0.18)
		_sprite.texture = _frames[1]
		if held_for >= HOLD_TIME and not _held_fired:
			_held_fired = true
			held.emit()
	else:
		_sprite.scale = Vector2.ONE
		if _happy_t > 0.0:
			_happy_t -= delta
			_sprite.texture = _frames[3]
		else:
			_sprite.texture = _frames[0] if bounce < 0.8 else _frames[2]


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
