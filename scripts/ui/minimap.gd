extends Control
## Corner mini map in the world (takes the Pau button's place; Pau's hint and
## calm moment live on the Pau follower and the HUD toolbar there).
## + / - zoom through 3 levels, up to the whole map. Tap the map or press M
## for the full map with the legend.

const UI = preload("res://scripts/ui/ui.gd")
const MAP := 156.0
const ZOOMS := [8.0, 4.0, 0.0]  ## px per tile; 0 = whole map

signal open_requested

var world: Node
var view: MapView
var _zoom_i: int = 0
var _zoom_label: Label


func _ready() -> void:
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.sb(Color(0.12, 0.14, 0.2, 0.88), UI.GOLD, 3, 14, 6))
	var col := UI.vbox(4)
	view = MapView.new()
	view.world = world
	view.custom_minimum_size = Vector2(MAP, MAP)
	view.icon_scale = 0.8
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view.tooltip_text = "Ketik untuk buka peta penuh (M)"
	view.gui_input.connect(_on_map_input)
	col.add_child(view)
	var row := UI.hbox(4)
	var minus := _small_button("-", "Zum keluar")
	minus.pressed.connect(func(): _set_zoom(_zoom_i + 1))
	row.add_child(minus)
	_zoom_label = UI.label("", "Small")
	_zoom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.add_theme_font_size_override("font_size", 15)
	row.add_child(_zoom_label)
	var plus := _small_button("+", "Zum masuk")
	plus.pressed.connect(func(): _set_zoom(_zoom_i - 1))
	row.add_child(plus)
	col.add_child(row)
	frame.add_child(col)
	add_child(frame)
	frame.reset_size()
	size = frame.size
	_set_zoom(int(Game.settings.get("minimap_zoom", 0)))


func _small_button(t: String, tip: String) -> Button:
	var b := UI.button(t)
	b.custom_minimum_size = Vector2(44, 36)
	b.add_theme_font_size_override("font_size", 22)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b


func _set_zoom(i: int) -> void:
	_zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	Game.settings["minimap_zoom"] = _zoom_i
	await get_tree().process_frame  # view has its size after the first layout
	var z: float = ZOOMS[_zoom_i]
	view.px_per_tile = view.fit_scale() if z == 0.0 else z
	view.follow_player = z != 0.0
	view.icon_scale = 0.55 if z == 0.0 else 0.8
	view.clamp_center()
	_zoom_label.text = ["DEKAT", "SEDERHANA", "SELURUH"][_zoom_i]
	Sfx.play("tick", -10.0, 1.4)


func _on_map_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		open_requested.emit()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		accept_event()
		_set_zoom(_zoom_i + (-1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
