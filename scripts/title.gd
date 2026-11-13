extends Control
## Title screen: tap / click / any key to start. The backdrop is
## scripts/ui/title_backdrop.gd (parallax PixelLab layers, or the old picture).

const TitleBackdrop = preload("res://scripts/ui/title_backdrop.gd")
const LOGO := "res://assets/ui/logo_explostory.png"
const STUDIO := "res://assets/ui/logo_cavan_tech.png"

var _t := 0.0
var _leaving := false
static var _splash_seen := false  ## the partner logos show once per visit
var _splash: Control = null

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
	_partners_splash()


## Right after the game loads (once per visit): KPT, DICE 4.0 and Cavan Tech
## on white, then the title. A click skips it. Not during the autotest.
func _partners_splash() -> void:
	if _splash_seen or "--autotest" in OS.get_cmdline_user_args():
		return
	_splash_seen = true
	var s := Control.new()
	s.name = "Rakan"
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 80)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["kpt", 130.0], ["dice", 170.0], ["cavan_tech", 160.0]]:
		var path := "res://assets/ui/logo_%s.png" % pair[0]
		if not ResourceLoader.exists(path):
			continue
		var t: Texture2D = load(path)
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(pair[1] * t.get_width() / t.get_height(), pair[1])
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(row)
	s.add_child(cc)
	add_child(s)
	_splash = s
	row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_end_splash)
	s.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
			tw.kill()
			var out := create_tween()
			out.tween_property(s, "modulate:a", 0.0, 0.25)
			out.tween_callback(_end_splash))


func _end_splash() -> void:
	if is_instance_valid(_splash):
		_splash.queue_free()
	_splash = null


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
	if _splash != null:
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed):
			_end_splash()  # a key skips the logos too
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.position.x > Game.screen_w() - 100 and event.position.y < 90:
		return  # the settings gear
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_leaving = true
		Game.fullscreen_on_phone()
		Sfx.play("select")
		Game.goto("login")
