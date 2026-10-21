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

## how many flags can be entered: chapters finished so far + the one in play
var unlocked_chapters: int:
	get:
		return Game.current_chapter()
var flags := {}              # session flags, e.g. flags["world_intro"] = true
var spawn_cell = null        # Vector2i to place Alif at after a warp
var spawn_facing := "south"

var _fade: ColorRect
var _card: VBoxContainer
var _card_title: Label
var _card_sub: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	# title card shown on the black between two maps ("Lembah Kebangkitan / 1900-an")
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 52)
	_card_title.add_theme_color_override("font_color", Color("ffe39a"))
	_card.add_child(_card_title)
	_card_sub = Label.new()
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub.add_theme_font_size_override("font_size", 26)
	_card_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_card.add_child(_card_sub)
	layer.add_child(_card)


func go_to(scene_path: String, color := Color.BLACK, title := "", subtitle := "") -> void:
	_fade.color = Color(color, _fade.color.a)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.4 if title == "" else 0.6)
	await tween.finished
	if title != "":
		_card_title.text = title
		_card_sub.text = subtitle
		_card_title.theme = Game.theme
		_card_sub.theme = Game.theme
		var light := color.get_luminance() > 0.5
		_card_title.add_theme_color_override("font_color", Color("5a381e") if light else Color("ffe39a"))
		_card_sub.add_theme_color_override("font_color", Color("5a381e") if light else Color(1, 1, 1, 0.85))
		tween = create_tween()
		tween.tween_property(_card, "modulate:a", 1.0, 0.4)
		tween.tween_interval(1.3)
		tween.tween_property(_card, "modulate:a", 0.0, 0.4)
		await tween.finished
	get_tree().change_scene_to_file(scene_path)
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.4)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
