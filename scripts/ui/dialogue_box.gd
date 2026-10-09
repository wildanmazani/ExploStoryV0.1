extends Control
## NPC / Pau dialogue box with portrait, typewriter text and a read-aloud
## button on every line. Cream background, short lines, no time limit.

const UI = preload("res://scripts/ui/ui.gd")

signal finished

var _lines: Array = []
var _i: int = 0
var _typing: bool = false
var _shown: float = 0.0
var _panel: PanelContainer
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _name: Label
var _text: Label
var _next: Button
var _speak: Button
var _tag: Label


func _ready() -> void:
	UI.full(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18)
	UI.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_panel = UI.panel("Paper")
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -150
	_panel.offset_top = -230
	_panel.offset_bottom = -20
	add_child(_panel)
	var row := UI.hbox(18)
	_panel.add_child(row)

	_portrait_frame = UI.panel("Slot")
	_portrait_frame.custom_minimum_size = Vector2(160, 160)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.custom_minimum_size = Vector2(144, 144)
	_portrait_frame.add_child(_portrait)
	row.add_child(_portrait_frame)

	var col := UI.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UI.hbox(12)
	_name = UI.label("", "InkHeading")
	name_row.add_child(_name)
	_tag = UI.label("", "InkSmall")
	name_row.add_child(_tag)
	col.add_child(name_row)
	_text = UI.label("", "Ink", true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(600, 110)
	col.add_child(_text)
	row.add_child(col)

	var btns := UI.vbox(10)
	_speak = UI.icon_button("res://assets/icons/suara.png", "Blue")
	_speak.tooltip_text = "Baca dengan suara"
	_speak.pressed.connect(_on_speak)
	btns.add_child(_speak)
	_next = UI.button("»", "Primary")
	_next.custom_minimum_size = Vector2(72, 64)
	_next.tooltip_text = "Seterusnya"
	_next.pressed.connect(_advance)
	btns.add_child(_next)
	row.add_child(btns)


func play(lines_arr: Array) -> void:
	_lines = lines_arr
	_i = 0
	visible = true
	_show_line()
	await finished


func _show_line() -> void:
	var line: Dictionary = _lines[_i]
	var who: String = str(line.get("s", "narator"))
	_name.text = Game.char_name(who)
	_tag.text = "(dialog rekaan)" if line.get("rekaan", false) else ""
	var p := Game.portrait_path(who, str(line.get("e", "")))
	_portrait.texture = UI.tex(p)
	_portrait_frame.visible = p != ""
	_text.text = str(line.get("t", ""))
	if who == "narator":
		_text.theme_type_variation = "InkSmall"
	else:
		_text.theme_type_variation = "Ink"
	var spd := Game.type_speed()
	if spd <= 0.0:
		_text.visible_characters = -1
		_typing = false
	else:
		_text.visible_characters = 0
		_shown = 0.0
		_typing = true
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(_text.text)
	_next.grab_focus()


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += delta * Game.type_speed()
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _text.text.length():
		_text.visible_characters = -1
		_typing = false


func _advance() -> void:
	if _typing:
		_typing = false
		_text.visible_characters = -1
		return
	_i += 1
	if _i >= _lines.size():
		visible = false
		Tts.stop()
		finished.emit()
	else:
		_show_line()


func _on_speak() -> void:
	Tts.speak(_text.text)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()
