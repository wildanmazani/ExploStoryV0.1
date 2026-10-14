extends Control
## Calm moment: Pau slowly grows and shrinks; the player can breathe along.
## A comfort feature in the game only, not a treatment.

const UI = preload("res://scripts/ui/ui.gd")
const CYCLE := 8.0  # 4 s in, 4 s out

var _pau: TextureRect
var _text: Label
var _t: float = 0.0
var _cycles: int = 0


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.lock_input()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.13, 0.22, 0.92)
	UI.full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_pau = TextureRect.new()
	_pau.texture = UI.sheet_frame("res://assets/proto/sprites/pau.png", 3, 0, 16, 16)
	_pau.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pau.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pau.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pau.size = Vector2(240, 240)
	_pau.pivot_offset = Vector2(120, 120)
	_pau.position = Vector2(640 - 120, 300 - 120)
	_pau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pau)
	_text = UI.label("Tarik nafas...", "Title")
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.position = Vector2(0, 470)
	_text.size = Vector2(1280, 80)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	var sub := UI.label("Bernafas ikut Pau. Ketik di mana-mana untuk kembali.", "Small")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 570)
	sub.size = Vector2(1280, 40)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)
	Tts.speak("Tarik nafas perlahan-lahan bersama Pau.")


func _process(delta: float) -> void:
	_t += delta
	var phase := fmod(_t, CYCLE) / CYCLE
	var s: float
	if phase < 0.5:
		s = lerpf(0.8, 1.3, ease(phase * 2.0, -2.0))
		_text.text = "Tarik nafas..."
	else:
		s = lerpf(1.3, 0.8, ease((phase - 0.5) * 2.0, -2.0))
		_text.text = "Hembus perlahan..."
	_pau.scale = Vector2(s, s)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	Game.unlock_input()
	Tts.stop()
	queue_free()
