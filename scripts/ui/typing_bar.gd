extends CanvasLayer
## On a phone the on-screen keyboard covers the bottom half of the game, often
## right over the box being typed in. While a text box has focus on a touch
## screen, this bar at the very top shows what it is for and what has been
## typed (dots for a password), with a Selesai button that closes the keyboard.

const UI = preload("res://scripts/ui/ui.gd")

var _panel: PanelContainer
var _name: Label
var _text: Label
var _field: LineEdit


func _ready() -> void:
	layer = 90
	_panel = UI.panel()
	_panel.theme = Game.theme
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := UI.hbox(14)
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UI.label("", "Small")
	col.add_child(_name)
	_text = UI.label("", "Heading")
	_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	_text.clip_text = true
	col.add_child(_text)
	row.add_child(col)
	var done := UI.button("Selesai", "Primary", 150)
	done.focus_mode = Control.FOCUS_NONE  # pressing it must not take focus itself first
	done.pressed.connect(func():
		if is_instance_valid(_field):
			_field.release_focus())
	row.add_child(done)
	_panel.add_child(row)
	add_child(_panel)
	get_viewport().gui_focus_changed.connect(_on_focus)


func _on_focus(c: Control) -> void:
	if c is LineEdit and DisplayServer.is_touchscreen_available():
		_field = c
		_panel.visible = true
		_name.text = _label_for(c)
	else:
		_field = null
		_panel.visible = false


func _label_for(e: LineEdit) -> String:
	if e.has_meta("typing_label"):
		return tr(str(e.get_meta("typing_label")))
	return tr(e.placeholder_text) if e.placeholder_text != "" else tr("Sedang menaip")


func _process(_d: float) -> void:
	if not _panel.visible:
		return
	if not is_instance_valid(_field) or not _field.has_focus():
		_panel.visible = false
		return
	var t := _field.text
	if _field.secret:
		t = "•".repeat(t.length())
	_text.text = (t if t != "" else " ") + "|"
	_panel.position = Vector2(12, 8)
	_panel.size = Vector2(Game.screen_w() - 24, 0)
