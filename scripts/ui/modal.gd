extends Control
## Base for full-screen modal panels (settings, notes, museum).
## Subclasses set `title_text` / `panel_size` and fill `content` in _build().

const UI = preload("res://scripts/ui/ui.gd")

signal closed

var title_text: String = ""
var panel_size: Vector2 = Vector2(900, 600)
var panel_variation: String = ""
var content: VBoxContainer
var frame: PanelContainer


func _ready() -> void:
	UI.full(self)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.lock_input()
	add_child(UI.dim(0.6))
	frame = UI.panel(panel_variation)
	frame.custom_minimum_size = panel_size
	var col := UI.vbox(14)
	var head := UI.hbox(12)
	var t := UI.label(title_text, "InkHeading" if panel_variation == "Paper" else "Heading")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UI.button("Tutup", "", 0)
	x.pressed.connect(close)
	head.add_child(x)
	col.add_child(head)
	content = UI.vbox(12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(content)
	frame.add_child(col)
	add_child(UI.center(frame))
	_build()
	x.grab_focus()


func _build() -> void:
	pass


func close() -> void:
	Game.unlock_input()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()
