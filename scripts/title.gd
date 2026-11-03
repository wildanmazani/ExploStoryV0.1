extends Control
## Title screen: tap / click / any key to start. The backdrop is
## scripts/ui/title_backdrop.gd (parallax PixelLab layers, or the old picture).

const TitleBackdrop = preload("res://scripts/ui/title_backdrop.gd")

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
	var ver := Label.new()
	ver.text = "Prototaip v0.2  |  Mod Mudah Baca dalam Tetapan"
	ver.theme_type_variation = "Small"
	ver.position = Vector2(20, 684)
	add_child(ver)


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
