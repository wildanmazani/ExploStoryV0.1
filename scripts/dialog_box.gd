class_name DialogBox
extends CanvasLayer
## Dyslexia-friendly dialog (GDS section 7): cream panel, large left-aligned
## text with extra spacing, and a read-aloud button on every line.
## Usage: await dialog.play([{"name": "Pau", "text": "...", "portrait": tex}])

signal finished

const BG := Color("fbf3e0")
const INK := Color("2b2118")
const ACCENT := Color("7a4e2d")

var active := false
var at_top := false  ## show near the top so characters at the bottom stay visible

var _lines: Array = []
var _index := 0
var _opened_at := 0
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _listen: Button


func _ready() -> void:
	layer = 10

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = ACCENT
	style.set_border_width_all(6)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(40, 500)
	_panel.custom_minimum_size = Vector2(1200, 190)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(150, 150)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", ACCENT)
	top.add_child(_name)
	_listen = Button.new()
	_listen.text = "Dengar"
	_listen.focus_mode = Control.FOCUS_NONE
	_listen.add_theme_font_size_override("font_size", 22)
	_listen.pressed.connect(_speak)
	top.add_child(_listen)

	var spaced := FontVariation.new()
	spaced.base_font = ThemeDB.fallback_font
	spaced.spacing_glyph = 1
	spaced.spacing_space = 6
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("font", spaced)
	_text.add_theme_font_size_override("font_size", 30)
	_text.add_theme_constant_override("line_spacing", 10)
	_text.add_theme_color_override("font_color", INK)
	col.add_child(_text)

	var hint := Label.new()
	hint.text = "Ketik untuk teruskan  >"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(ACCENT, 0.7))
	col.add_child(hint)

	_panel.hide()


func play(lines: Array) -> void:
	_lines = lines
	_index = 0
	_panel.position.y = 90 if at_top else 500
	_opened_at = Time.get_ticks_msec()
	active = true
	_panel.show()
	_show_current()
	await finished


func _input(event: InputEvent) -> void:
	if not active or Time.get_ticks_msec() - _opened_at < 150:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _listen.get_global_rect().has_point(event.position):
			return  # let the button handle it
		for c in get_tree().get_nodes_in_group("dialog_passthrough"):
			if c is Control and c.is_visible_in_tree() and c.get_global_rect().has_point(event.position):
				return  # e.g. the Skip button
		pressed = true
	elif event.is_action_pressed("act") or event.is_action_pressed("ui_accept"):
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_advance()


## close immediately (used by Skip)
func cancel() -> void:
	if not active:
		return
	DisplayServer.tts_stop()
	active = false
	_panel.hide()
	finished.emit()


func _advance() -> void:
	DisplayServer.tts_stop()
	_index += 1
	if _index >= _lines.size():
		active = false
		_panel.hide()
		finished.emit()
	else:
		_show_current()


func _show_current() -> void:
	var line: Dictionary = _lines[_index]
	_name.text = line.get("name", "")
	_text.text = line.get("text", "")
	_portrait.texture = line.get("portrait", null)
	_portrait.visible = _portrait.texture != null


func _speak() -> void:
	var voice := ""
	for lang in ["ms", "id"]:
		var ids := DisplayServer.tts_get_voices_for_language(lang)
		if not ids.is_empty():
			voice = ids[0]
			break
	if voice == "":
		var all := DisplayServer.tts_get_voices()
		if all.is_empty():
			return
		voice = all[0]["id"]
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(_text.text, voice)
