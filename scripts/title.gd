extends Control
## Title screen: tap / click / any key to start. The backdrop is
## scripts/ui/title_backdrop.gd (parallax PixelLab layers, or the old picture).

const TitleBackdrop = preload("res://scripts/ui/title_backdrop.gd")
const LOGO := "res://assets/ui/logo_explostory.png"
const STUDIO := "res://assets/ui/logo_cavan_tech.png"

var _t := 0.0
var _leaving := false

@onready var start_label: Label = $StartLabel


var gear: Button


func _ready() -> void:
	$Background.visible = false
	var bd := TitleBackdrop.new()
	add_child(bd)
	move_child(bd, 0)
	Main.set_pau_visible(false)
	MusicDirector.play("tajuk")
	gear = Button.new()
	gear.icon = load("res://assets/icons/tetapan.png")
	gear.expand_icon = true
	gear.custom_minimum_size = Vector2(64, 60)
	_place_gear()
	get_viewport().size_changed.connect(_place_gear)
	gear.tooltip_text = "Tetapan"
	gear.pressed.connect(func(): Main.open_settings())
	add_child(gear)
	_logos()
	var ver := Label.new()
	ver.text = "Prototaip v0.2  |  Mod Mudah Baca dalam Tetapan"
	ver.theme_type_variation = "Small"
	ver.position = Vector2(20, 684)
	add_child(ver)


## the EXPLO-STORY wordmark in place of the plain title, and the Cavan Tech
## studio badge in the corner (tools/gen_logo.py)
func _logos() -> void:
	if ResourceLoader.exists(LOGO):
		$TitleLabel.visible = false
		var logo := TextureRect.new()
		logo.name = "Logo"
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
		logo.offset_left = -300
		logo.offset_right = 300
		logo.offset_top = 14
		logo.offset_bottom = 14 + 187
		add_child(logo)
		var tw := logo.create_tween().set_loops()  # a slow float, like the loading page
		tw.tween_method(func(v: float):
			logo.offset_top = 14 - v
			logo.offset_bottom = 14 + 187 - v, 0.0, 6.0, 1.6).set_trans(Tween.TRANS_SINE)
		tw.tween_method(func(v: float):
			logo.offset_top = 14 - v
			logo.offset_bottom = 14 + 187 - v, 6.0, 0.0, 1.6).set_trans(Tween.TRANS_SINE)
		$Subtitle.offset_top = 200
		$Subtitle.offset_bottom = 250
	if ResourceLoader.exists(STUDIO):
		var badge := TextureRect.new()
		badge.name = "CavanTech"
		badge.texture = load(STUDIO)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -20 - 115
		badge.offset_right = -20
		badge.offset_top = -20 - 90
		badge.offset_bottom = -20
		add_child(badge)


func _process(delta: float) -> void:
	_t += delta
	start_label.modulate.a = 0.8 + 0.2 * sin(_t * 3.0)  # stays readable on the bright art


func _place_gear() -> void:
	gear.position = Vector2(Game.screen_w() - 84, 20)


func _input(event: InputEvent) -> void:
	if _leaving or Game.is_locked():
		return
	if event is InputEventMouseButton and event.position.x > Game.screen_w() - 100 and event.position.y < 90:
		return  # the settings gear
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		_leaving = true
		Game.fullscreen_on_phone()
		Sfx.play("select")
		Game.goto("login")
