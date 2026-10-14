extends CanvasLayer
## Peta Jejak Pembelajaran overlay (GDS section 4), opened from the stone
## monument in Kampung Jejak. 10 flags along the path; unlocked ones wave,
## locked ones are grey. Tap a flag to read its chapter.

signal closed

## flag pole bases on the 320x180 illustrated map, in chapter order
const FLAGS := [
	Vector2(276, 118), Vector2(255, 92), Vector2(222, 86), Vector2(180, 96), Vector2(150, 104),
	Vector2(115, 112), Vector2(78, 112), Vector2(45, 100), Vector2(35, 72), Vector2(55, 48),
]
const OPEN := preload("res://assets/ui/bendera_berkibar.png")
const LOCKED := preload("res://assets/ui/bendera_berkunci.png")

var _flags: Array[TextureRect] = []
var _t := 0.0

@onready var map: TextureRect = $Map
@onready var info: Label = $InfoPanel/Info


func _ready() -> void:
	layer = 28
	Game.lock_input()
	$Close.pressed.connect(_close)
	Sfx.play("whoosh", -10.0)
	for i in FLAGS.size():
		var unlocked: bool = i < GameState.unlocked_chapters
		var f := TextureRect.new()
		f.texture = OPEN if unlocked else LOCKED
		f.size = Vector2(72, 96)
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.pivot_offset = Vector2(20, 96)
		f.position = FLAGS[i] * 4.0 - Vector2(20, 92)
		f.modulate = Color.WHITE if unlocked else Color(0.75, 0.75, 0.8)
		f.mouse_filter = Control.MOUSE_FILTER_STOP
		f.gui_input.connect(_on_flag_input.bind(i))
		map.add_child(f)
		_flags.append(f)
	_show_info(0)
	map.modulate.a = 0.0
	map.scale = Vector2(0.96, 0.96)
	map.pivot_offset = Vector2(640, 360)
	var t := create_tween().set_parallel()
	t.tween_property(map, "modulate:a", 1.0, 0.35)
	t.tween_property(map, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	for i in _flags.size():
		if i < GameState.unlocked_chapters:  # waving + glow on open chapters
			_flags[i].rotation = sin(_t * 3.0 + i) * 0.05
			_flags[i].self_modulate = Color(1, 1, 1).lerp(Color(1.35, 1.25, 0.9), (sin(_t * 3.0) + 1.0) * 0.25)


func _on_flag_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		Sfx.play("select")
		_show_info(i)


func _show_info(i: int) -> void:
	var status := "Sedang diterokai" if i < GameState.unlocked_chapters else "Berkunci"
	if Game.chapter_done(i + 1):
		status = "Selesai!"
	info.text = "Bab %d: %s   ·   %s" % [i + 1, GameState.CHAPTERS[i], status]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("select")
	var t := create_tween()
	t.tween_property(map, "modulate:a", 0.0, 0.2)
	await t.finished
	Game.unlock_input()
	closed.emit()
	queue_free()
