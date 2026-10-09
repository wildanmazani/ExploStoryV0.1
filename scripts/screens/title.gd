extends Control
## Title screen: logo + "Ketik untuk mula".

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _tap: Label
var _pau: TextureRect
var _t: float = 0.0


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	add_child(UI.bg_image("res://assets/bg/bukit_peta.png"))
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.1, 0.18, 0.35)
	UI.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := UI.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(900, 520)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pau = TextureRect.new()
	_pau.texture = UI.sheet_frame("res://assets/sprites/pau.png", 3, 0, 16, 16)
	_pau.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pau.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pau.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pau.custom_minimum_size = Vector2(120, 120)
	_pau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_pau)
	var logo := UI.label("EXPLO-STORY", "Title")
	logo.add_theme_font_size_override("font_size", 96)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(logo)
	var sub_panel := UI.panel()
	var sub := UI.label("Sejarah Tingkatan 4  |  Bab 1: Warisan Negara Bangsa", "Heading")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_panel.add_child(sub)
	col.add_child(sub_panel)
	col.add_child(UI.spacer(false))
	_tap = UI.label("Ketik untuk mula", "Title")
	_tap.add_theme_font_size_override("font_size", 40)
	_tap.add_theme_color_override("font_color", UI.CREAM)
	_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_tap)
	var cc := UI.center(col)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)

	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(64, 60))
	st.position = Vector2(1280 - 84, 20)
	st.tooltip_text = "Tetapan"
	st.pressed.connect(func(): Game.main.open_settings())
	add_child(st)
	var ver := UI.label("Prototaip v0.1  |  Mod Mudah Baca dalam Tetapan", "Small")
	ver.position = Vector2(20, 680)
	add_child(ver)


func _process(delta: float) -> void:
	_t += delta
	_tap.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)
	_pau.scale = Vector2.ONE * (1.0 + absf(sin(_t * 2.5)) * 0.08)
	_pau.pivot_offset = _pau.size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_start()


func _start() -> void:
	set_process_unhandled_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.goto("login")
