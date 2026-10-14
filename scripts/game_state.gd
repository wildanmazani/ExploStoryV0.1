extends Node
## Autoload: progress that survives scene changes, input actions, fade transition.

const CHAPTERS := [
	"Warisan Negara Bangsa",
	"Kebangkitan Nasionalisme",
	"Konflik Dunia dan Pendudukan Jepun",
	"Era Peralihan Kuasa British",
	"Persekutuan Tanah Melayu 1948",
	"Ancaman Komunis dan Darurat",
	"Usaha ke Arah Kemerdekaan",
	"Pilihan Raya",
	"Perlembagaan Persekutuan 1957",
	"Pemasyhuran Kemerdekaan",
]

## keyboard bindings; touch buttons press the same actions
const ACTIONS := {
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"act": [KEY_E, KEY_SPACE, KEY_ENTER, KEY_Z],
	"run": [KEY_SHIFT, KEY_X],
}

var unlocked_chapters := 1   # how many flags can be entered
var completed_chapters := 0  # how many flags are waving
var artifacts: Array[String] = []
var flags := {}              # story flags, e.g. flags["met_pau"] = true
var spawn_cell = null        # Vector2i to place Alif at after a warp
var spawn_facing := "south"

var _fade: ColorRect


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func go_to(scene_path: String, color := Color.BLACK) -> void:
	_fade.color = Color(color, _fade.color.a)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.4)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.4)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
