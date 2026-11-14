extends PanelContainer
## One outfit in Kedai Skin, dressed by its tier (data/skins.json "tier"):
##   basic: steel blue, plain
##   elite: violet, soft glow
##   epic : gold, glow, a light sweeping across and sparkles
## Alif stands on a lit stage in the tier's colour, with a ribbon on top.

const UI = preload("res://scripts/ui/ui.gd")

const TIERS := {
	"basic": {"name": "BASIC", "main": Color("7f9bb8"), "dark": Color("2a3446"), "glow": 0.0, "stars": 1},
	"elite": {"name": "ELITE", "main": Color("b07cff"), "dark": Color("2e2350"), "glow": 0.45, "stars": 2},
	"epic": {"name": "EPIC", "main": Color("ffc23d"), "dark": Color("4a2a10"), "glow": 0.7, "stars": 3},
}

var skin: Dictionary = {}
var owned := false
var worn := false
var button: Button  ## filled in by the shop (Pakai / Beli / Sedang dipakai)

var _tier: Dictionary
var _t := 0.0
var _stage: Control
var _pic: TextureRect


static func tier_of(s: Dictionary) -> String:
	var t := str(s.get("tier", "basic"))
	return t if TIERS.has(t) else "basic"


func _ready() -> void:
	_tier = TIERS[tier_of(skin)]
	var main: Color = _tier["main"]
	var dark: Color = _tier["dark"]
	custom_minimum_size = Vector2(366, 0)
	var box := UI.sb(dark.darkened(0.25), main if not worn else UI.GREEN, 4, 14, 12)
	box.shadow_color = Color(main, float(_tier["glow"]))
	box.shadow_size = 10 if float(_tier["glow"]) > 0.0 else 0
	add_theme_stylebox_override("panel", box)

	var col := UI.vbox(8)
	# ribbon: tier name, plus a "dipakai" tag
	var top := UI.hbox(6)
	var rib := PanelContainer.new()
	var rs := UI.sb(main, main.darkened(0.4), 2, 8, 4)
	rs.content_margin_left = 12
	rs.content_margin_right = 12
	rib.add_theme_stylebox_override("panel", rs)
	var rl := UI.label(str(_tier["name"]), "Small")
	rl.add_theme_color_override("font_color", dark.darkened(0.4))
	rib.add_child(rl)
	top.add_child(rib)
	top.add_child(UI.spacer())
	if worn:
		var tag := UI.label(tr("DIPAKAI"), "Small")
		tag.add_theme_color_override("font_color", Color("8fe08a"))
		top.add_child(tag)
	elif owned:
		var tag := UI.label(tr("DIMILIKI"), "Small")
		tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		top.add_child(tag)
	col.add_child(top)

	# the stage: Alif in the outfit on a pool of the tier's light
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 150)
	_stage.clip_contents = true
	_stage.draw.connect(_draw_stage)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pic.offset_top = 4
	_pic.offset_bottom = -2
	var folder := str(skin.get("folder", "alif"))
	var path := "res://assets/characters32/%s/%s_south.png" % [folder, folder]
	_pic.texture = UI.tex(path) if ResourceLoader.exists(path) else UI.tex("res://assets/icons/kunci.png")
	_stage.add_child(_pic)
	col.add_child(_stage)

	var nm := UI.label(str(skin.get("name", "")), "Heading")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_color_override("font_color", main.lightened(0.35))
	col.add_child(nm)
	var info := UI.label(str(skin.get("info", "")), "Small", true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(330, 52)
	col.add_child(info)
	if button:
		col.add_child(button)
	add_child(col)
	# a light that sweeps across epic cards
	if tier_of(skin) == "epic":
		var shine := Control.new()
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shine.draw.connect(_draw_shine.bind(shine))
		add_child(shine)
		set_meta("shine", shine)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_pic):  # a small breathing bob
		_pic.position.y = 4 - absf(sin(_t * 2.2)) * 3.0
	_stage.queue_redraw()
	if has_meta("shine"):
		(get_meta("shine") as Control).queue_redraw()


func _draw_stage() -> void:
	var s := _stage.size
	var main: Color = _tier["main"]
	var dark: Color = _tier["dark"]
	_stage.draw_rect(Rect2(Vector2.ZERO, s), dark)
	# rays from behind Alif, turning slowly (elite and epic)
	var c := Vector2(s.x / 2.0, s.y * 0.55)
	var rays := 0 if tier_of(skin) == "basic" else 12
	for i in rays:
		var a := _t * 0.25 + TAU * i / rays
		var w := 0.11
		var far := s.x
		_stage.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - w) * far, c + Vector2.from_angle(a + w) * far]),
			Color(main, 0.10 if tier_of(skin) == "elite" else 0.16))
	# a soft pool of light, brightest at the middle
	for r in range(6, 0, -1):
		_stage.draw_circle(c, s.y * 0.09 * r, Color(main, 0.05))
	# the floor he stands on
	_stage.draw_set_transform(Vector2(s.x / 2.0, s.y - 16), 0, Vector2(1, 0.28))
	_stage.draw_circle(Vector2.ZERO, 58, Color(main, 0.35))
	_stage.draw_circle(Vector2.ZERO, 40, Color(0, 0, 0, 0.35))
	_stage.draw_set_transform(Vector2.ZERO)
	# sparkles (epic): little plus-shaped glints that blink
	if tier_of(skin) == "epic":
		for i in 9:
			var p := Vector2(fmod(i * 97.0, s.x - 20) + 10, fmod(i * 53.0 + 17, s.y - 30) + 8)
			var k := maxf(0.0, sin(_t * 2.6 + i * 1.7))
			if k <= 0.05:
				continue
			var col := Color(1, 0.95, 0.7, k)
			var l := 2.0 + 4.0 * k
			_stage.draw_line(p - Vector2(l, 0), p + Vector2(l, 0), col, 2)
			_stage.draw_line(p - Vector2(0, l), p + Vector2(0, l), col, 2)
	# frame line under the stage
	_stage.draw_rect(Rect2(Vector2.ZERO, s), Color(main, 0.6), false, 2)


## a slanted band of light crossing the card every few seconds
func _draw_shine(c: Control) -> void:
	var s := c.size
	var cycle := fmod(_t, 3.6) / 1.2  # 0..3: crosses during the first third
	if cycle > 1.0:
		return
	var x := -120.0 + (s.x + 240.0) * cycle
	var band := PackedVector2Array([Vector2(x, 0), Vector2(x + 40, 0), Vector2(x - 40, s.y), Vector2(x - 80, s.y)])
	c.draw_colored_polygon(band, Color(1, 0.97, 0.8, 0.13))
