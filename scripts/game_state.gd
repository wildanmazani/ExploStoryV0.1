extends Node
## Autoload: scene transitions (fade), warp spawn point and session flags.
## Saved progress lives in Game.save (scripts/autoload/game.gd).

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

var unlocked_chapters := 1   # how many flags can be entered (Bab 1 only for the final)
var flags := {}              # session flags, e.g. flags["world_intro"] = true
var spawn_cell = null        # Vector2i to place Alif at after a warp
var spawn_facing := "south"

var _fade: ColorRect


func _ready() -> void:
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
