extends Control
## The game's opening backdrop (title, login, register). With the PixelLab
## layers in assets/backgrounds/tajuk/ it is a slow parallax scene: sky, far
## Melaka skyline, kampung hills, then the foreground (tree, Alif and Pau on
## the hill). Each layer is drawn at 4x with nearest filtering so the pixels
## stay sharp; the three back layers are 352x180 so they can drift sideways.
## Without the layers it shows the one-piece PixelLab scene (tajuk_penuh.png),
## else the old picture. Warm pollen drifts in front either way.

const OLD := "res://assets/backgrounds/bg_skrin_tajuk.png"
const FULL := "res://assets/backgrounds/tajuk/tajuk_penuh.png"
const LAYERS := [
	"res://assets/backgrounds/tajuk/tajuk_0_langit.png",
	"res://assets/backgrounds/tajuk/tajuk_1_jauh.png",
	"res://assets/backgrounds/tajuk/tajuk_2_tengah.png",
	"res://assets/backgrounds/tajuk/tajuk_3_depan.png",
]
## how far each layer sways (art pixels): the sky barely, the hills more
const DRIFT := [2.0, 5.0, 9.0, 0.0]
const PX := 4.0  ## art pixel -> screen pixel (320x180 art on 1280x720)

var tint := Color.WHITE  ## login / register darken it a little
var _layers: Array[TextureRect] = []
var _t := 0.0
var _motes: Control


static func layered() -> bool:
	for p in LAYERS:
		if not ResourceLoader.exists(p):
			return false
	return true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = tint
	_motes = Motes.new()
	if not layered():
		var r := TextureRect.new()
		r.texture = load(FULL if ResourceLoader.exists(FULL) else OLD)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		add_child(_motes)
		return
	for p in LAYERS:
		var r := TextureRect.new()
		r.texture = load(p)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = r.texture.get_size() * PX
		add_child(r)
		_layers.append(r)
	add_child(_motes)
	_place()


func _process(delta: float) -> void:
	if not _layers.is_empty():
		_t += delta
		_place()


## centred, swaying slowly and leaning a touch towards the mouse
func _place() -> void:
	var view := get_viewport_rect().size
	var lean := clampf((get_viewport().get_mouse_position().x - view.x / 2.0) / (view.x / 2.0), -1.0, 1.0)
	for i in _layers.size():
		var r := _layers[i]
		var sway := (sin(_t * 0.12 + i) * 0.7 + lean * 0.3) * float(DRIFT[i])
		r.position = Vector2(round((view.x - r.size.x) / 2.0 + sway * PX), view.y - r.size.y)


## golden pollen floating up through the morning light, in 4x4 "art pixels"
class Motes extends Control:
	var _t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 18:
			var speed := 6.0 + (i * 7) % 9
			var x := fmod(i * 71.0 + sin(_t * 0.5 + i) * 6.0, 320.0)
			var y := 180.0 - fmod(_t * speed + i * 37.0, 200.0)
			var a := 0.25 + 0.35 * absf(sin(_t * 1.3 + i))
			draw_rect(Rect2(Vector2(floorf(x), floorf(y)) * 4.0, Vector2(4, 4)), Color(1, 0.92, 0.6, a))
