extends "res://scripts/screens/warisan_game.gd"
## Wau Bulan (Pesta Warisan). Alif flies a wau in the wind of the east coast.
## Hold TARIK (Space / up / the mouse / the button) to pull the string: the wau
## climbs. Let go (hulur) and it sinks, unless the wind is strong enough to
## carry it. Keep it inside the green band (the good wind) until the bar is
## full, before the time runs out.
##   the wau touches the ground          a life (three)
##   pulling hard in a strong wind       the string goes taut (TALI in the red);
##                                       too long and it snaps: a life
##   a cloud with "?" (three come by)    fly into it for a revision question:
##                                       right = 4 s on the bar
## Heights are 0 (the ground) .. 1 (the top of the sky).

const GY := 600.0            ## the ground, play px
const WX := 800.0            ## where the wau flies
const ALIF := Vector2(250, GY)
const PULL := 0.85
const TAUT := 1.85           ## wind + pull over this: the string is in the red
const SNAP := 0.9            ## seconds in the red before it snaps
const BAND := [0.16, 0.125, 0.095]   ## half the green band, by level
const GUST := [0.7, 1.0, 1.25]       ## how much the wind swings
const GOAL := [18.0, 22.0, 26.0]     ## seconds in the band to win
const LIMIT := 75.0
const BONUS := 4.0
const CLOUDS_AT := [8.0, 27.0, 46.0]
const CLOUD_SPEED := 125.0
const LIVES := 3
const SCENERY := ["rumah_biru", "palm", "tree_ketapang", "palm", "wakaf_padang", "tree_round", "rumah_merah", "palm"]

var level := 1
var state := "pilih"      ## pilih, main, soalan, tamat
var h := 0.4              ## the wau's height
var v := 0.0
var wind := 0.6
var band := 0.5           ## the middle of the green band
var held := 0.0           ## seconds in the band so far
var time := 0.0
var lives := LIVES
var right := 0
var won := false
var taut := 0.0           ## seconds the string has been in the red
var pulling := false
var clouds: Array = []    ## {x, h, sprite}

var _sky: Node2D
var _alif: AnimatedSprite2D
var _wau: Sprite2D
var _hud: Control
var _info: Label
var _pull: Button
var _hearts: HBoxContainer
var _button := false
var _pointer := false
var _shield := 0.0
var _next_cloud := 0
var _band3: MeshInstance3D
var _string3: ImmediateMesh


func _ready() -> void:
	setup_game(Color("5aa552"))
	_sky = Langit.new()
	_sky.game = self
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sky)
	_alif = AnimatedSprite2D.new()
	_alif.sprite_frames = CharacterFrames.build(Game.skin_folder(), false)
	_alif.offset = CharacterFrames.feet_offset(Game.skin_folder())
	_alif.scale = Vector2(3, 3)
	_alif.position = ALIF
	_alif.play("idle_east")
	_sky.add_child(_alif)
	_wau = Sprite2D.new()
	_wau.texture = load("res://assets/warisan/wau.png")
	_wau.scale = Vector2(4, 4)
	_wau.set_meta("ground_y", GY)
	_sky.add_child(_wau)
	var painter := Langit.new()
	painter.game = self
	painter.ground = true
	if make_stage(_sky, painter, Rect2(-700.0, GY - 460.0, 2700.0, 760.0)):
		_dress_stage()

	_hud = Hud.new()
	_hud.game = self
	UI.full(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var top := UI.panel()
	top.position = Vector2(24, 20)
	var row := UI.hbox(16)
	row.add_child(UI.label("WAU BULAN", "Heading"))
	_info = UI.label("")
	_info.custom_minimum_size.x = 130
	row.add_child(_info)
	var out := UI.button("« Keluar")
	out.focus_mode = Control.FOCUS_NONE
	out.pressed.connect(func(): Game.goto("pesta"))
	row.add_child(out)
	top.add_child(row)
	add_child(top)
	_hearts = UI.hbox(6)
	_hearts.position = Vector2(Game.screen_w() - 386.0, 28.0)
	for i in LIVES:
		var heart := TextureRect.new()
		heart.texture = load("res://assets/warisan/hati.png")
		heart.custom_minimum_size = Vector2(33, 30)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hearts.add_child(heart)
	add_child(_hearts)
	_pull = UI.button(tr("TARIK"), "Primary", 240)
	_pull.custom_minimum_size.y = 96
	_pull.focus_mode = Control.FOCUS_NONE
	_pull.position = Vector2(Game.screen_w() - 280.0, 720.0 - 124.0)
	_pull.button_down.connect(func(): _button = true)
	_pull.button_up.connect(func(): _button = false)
	add_child(_pull)
	_place()
	if params.has("level"):
		_start(int(params["level"]))
	else:
		_level_card()


## HD-2D: the kampung behind the field, the band and the string as 3D things
func _dress_stage() -> void:
	stage.cam_offset = Vector3(0, 4.5, 27.0)
	stage.cam_look_up = 6.4
	stage.look_at_px(Vector2(640.0, GY), true)
	for i in range(-3, 13):
		stage.prop(load("res://assets/objects/%s.png" % SCENERY[posmod(i, SCENERY.size())]), Vector2(i * 210.0, GY - 190.0 - (i & 1) * 60.0), 3.0)
	_band3 = MeshInstance3D.new()
	_band3.mesh = QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.95, 0.5, 0.28)
	m.disable_fog = true
	_band3.material_override = m
	_band3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(_band3)
	_string3 = ImmediateMesh.new()
	var line := MeshInstance3D.new()
	line.mesh = _string3
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color("f6efe0")
	line.material_override = lm
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(line)


func _level_card() -> void:
	state = "pilih"
	level_card("WAU BULAN", tr("Terbangkan wau dalam angin Pantai Timur. Tahan TARIK untuk naik, lepas untuk turun. Kekalkan wau dalam jalur hijau sehingga bar penuh.\n\nJangan biar wau cecah tanah, dan jangan tarik kuat ketika angin kencang: tali boleh putus.\n\nTerbang masuk awan bertanda \"?\" untuk soalan: betul tambah 4 saat."), _start)


func _start(lv: int) -> void:
	level = clampi(lv, 0, 2)
	close_card()
	for c in clouds:
		c["sprite"].queue_free()
	clouds = []
	h = 0.4
	v = 0.0
	held = 0.0
	time = 0.0
	lives = LIVES
	right = 0
	taut = 0.0
	_shield = 1.5
	_next_cloud = 0
	state = "main"


func _finish(victory: bool, why: String) -> void:
	state = "tamat"
	won = victory
	var res := WarisanRules.finish("wau", victory, level, right, time)
	var text := why + " " + tr("Tak apa, cuba lagi: tiada penalti.")
	if victory:
		Sfx.play("sparkle")
		MusicDirector.stinger("st_levelup" if res["level_up"] else "st_correct")
		text = tr("Wau kau terbang megah selama %.1f saat!%s\n\n+%d EXP   +%d Syiling (%d soalan betul)") % [
			time, (" " + tr("Rekod baharu!")) if res["best"] else "", res["exp"], res["coins"], right]
	result_card(tr("MENANG!") if victory else tr("WAU JATUH!"), text, _level_card)
	print("wau: won=%s level=%d time=%.1f held=%.1f lives=%d right=%d" % [victory, level, time, held, lives, right])


# ---------------------------------------------------------------- play

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.pressed and state == "main"


func y_of(height: float) -> float:
	return lerpf(GY - 60.0, 100.0, height)


func _lose_life(why: String) -> void:
	lives -= 1
	Sfx.play("fall")
	Game.toast(why, Color("e0705f"))
	h = 0.4
	v = 0.0
	taut = 0.0
	_shield = 1.6
	if lives <= 0:
		_finish(false, why)


func _process(delta: float) -> void:
	_sky.queue_redraw()
	_hud.queue_redraw()
	_pull.visible = state == "main"
	_hearts.visible = state != "pilih"
	for i in LIVES:
		_hearts.get_child(i).modulate.a = 1.0 if i < lives else 0.2
	if state != "main":
		_place()
		return
	time += delta
	_shield = maxf(0.0, _shield - delta)
	wind = clampf(0.65 + GUST[level] * (0.38 * sin(time * 0.45) + 0.24 * sin(time * 1.3 + 1.0) + 0.1 * sin(time * 3.1)), 0.08, 1.35)
	band = 0.55 + 0.24 * sin(time * 0.33 + 0.6) + 0.07 * sin(time * 0.9)
	if _auto:   # the dev bot: under the middle of the band, pull (not into a taut string)
		pulling = h < band - 0.02 and (wind < 0.98 or h < band - 0.1)
	else:
		pulling = _button or _pointer or Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	v += (wind + (PULL if pulling else 0.0) - 1.0) * 0.9 * delta
	v *= exp(-1.8 * delta)
	h = minf(h + v * delta, 1.0)
	if absf(h - band) <= BAND[level]:
		held += delta
	taut = taut + delta if wind + (PULL if pulling else 0.0) > TAUT else maxf(0.0, taut - delta * 2.0)

	if _next_cloud < CLOUDS_AT.size() and time >= CLOUDS_AT[_next_cloud]:
		_next_cloud += 1
		var s := Sprite2D.new()
		s.texture = load("res://assets/warisan/awan_soalan.png")
		s.scale = Vector2(4, 4)
		s.set_meta("ground_y", GY)
		_sky.add_child(s)
		clouds.append({"x": Game.screen_w() + 120.0, "h": clampf(band + randf_range(-0.08, 0.08), 0.2, 0.9), "sprite": s})
	for c in clouds.duplicate():
		c["x"] -= CLOUD_SPEED * delta
		if absf(c["x"] - WX) < 70.0 and absf(c["h"] - h) < 0.1:
			clouds.erase(c)
			c["sprite"].queue_free()
			state = "soalan"
			_pointer = false
			_button = false
			question_card(tr("AWAN SOALAN"), tr("Betul! +4 saat pada bar."), "", func(ok: bool):
				state = "main"
				_shield = 1.0
				if ok:
					right += 1
					held += BONUS)
			_place()
			return
		elif c["x"] < -200.0:
			clouds.erase(c)
			c["sprite"].queue_free()
	_place()
	_info.text = "%s: %d s" % [tr("Baki"), ceili(LIMIT - time)]

	if held >= GOAL[level]:
		_finish(true, "")
	elif time >= LIMIT:
		_finish(false, tr("Masa tamat sebelum bar penuh."))
	elif h <= 0.0 and _shield <= 0.0:
		_lose_life(tr("Wau cecah tanah!"))
	elif taut >= SNAP:
		_lose_life(tr("Tali putus! Jangan tarik ketika angin kencang."))
	h = maxf(h, 0.0)


func _place() -> void:
	_wau.position = Vector2(WX + sin(time * 1.1) * 14.0, y_of(h))
	_wau.rotation = sin(time * 2.3) * 0.1 - v * 0.9
	_wau.modulate.a = 0.5 if _shield > 0.0 and fmod(_shield, 0.2) < 0.1 else 1.0
	for c in clouds:
		c["sprite"].position = Vector2(c["x"], y_of(c["h"]))
	if stage:
		var half: float = BAND[level]
		var top := GY - y_of(band + half)
		var bottom := GY - y_of(band - half)
		(_band3.mesh as QuadMesh).size = Vector2(15.0, (top - bottom) * Stage.K)
		_band3.position = stage.to3(Vector2(WX, GY), (top + bottom) / 2.0) + Vector3(0, 0, -0.4)
		_band3.visible = state == "main" or state == "soalan"
		_string3.clear_surfaces()
		_string3.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in string_points():
			_string3.surface_add_vertex(stage.to3(Vector2(p.x, GY), GY - p.y) + Vector3(0, 0, 0.02))
		_string3.surface_end()


## the string, from Alif's hand to the wau: it sags when it is slack
func string_points() -> PackedVector2Array:
	var a := ALIF + Vector2(22, -58)
	var b := _wau.position + Vector2(0, 30)
	var sag := 90.0 * clampf(1.3 - wind - (PULL if pulling else 0.0), 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
	return pts


## the sky, the kampung under it, the band of good wind, the string
class Langit extends Node2D:
	var game: Control
	var ground := false   ## HD-2D: only the field (the stage stands the rest up)
	var _tex := {}

	func _t(name: String) -> Texture2D:
		if not _tex.has(name):
			_tex[name] = load("res://assets/objects/%s.png" % name)
		return _tex[name]

	func _draw() -> void:
		var w := Game.screen_w()
		var gy: float = game.GY
		if ground:
			for i in 60:   # tufts on the field
				var g := Vector2(-680.0 + fposmod(i * 197.0, 2660.0), gy - 440.0 + fposmod(i * 131.0, 720.0))
				draw_line(g, g + Vector2(-5, -12), Color("3e7d3c"), 3.0)
				draw_line(g + Vector2(4, 0), g + Vector2(8, -10), Color("3e7d3c"), 3.0)
			return
		for i in 12:   # the sky, paler towards the ground
			draw_rect(Rect2(0, i * (gy / 12.0), w, gy / 12.0 + 1.0), Color("5fb0e6").lerp(Color("c9e8f6"), i / 11.0))
		for i in 5:    # far clouds
			var cx := fposmod(i * 310.0 - game.time * (8.0 + i * 3.0), w + 300.0) - 150.0
			var cy := 90.0 + fposmod(i * 97.0, 260.0)
			for k in 3:
				draw_circle(Vector2(cx + k * 34.0, cy + (k % 2) * 8.0), 30.0 - k * 3.0, Color(1, 1, 1, 0.55))
		for i in range(-1, int(w / 210.0) + 2):
			var tex := _t(game.SCENERY[posmod(i, game.SCENERY.size())])
			var sz := tex.get_size() * 3.0
			draw_texture_rect(tex, Rect2(Vector2(i * 210.0 - sz.x / 2.0, gy - 22.0 - sz.y), sz), false)
		draw_rect(Rect2(0, gy - 26.0, w, 720.0 - gy + 26.0), Color("5aa552"))
		draw_rect(Rect2(0, gy - 26.0, w, 6.0), Color("4a8f44"))
		if game.state in ["main", "soalan"]:
			var half: float = game.BAND[game.level]
			var y0: float = game.y_of(game.band + half)
			var y1: float = game.y_of(game.band - half)
			draw_rect(Rect2(game.WX - 300.0, y0, 600.0, y1 - y0), Color(0.45, 0.95, 0.5, 0.25))
			draw_rect(Rect2(game.WX - 300.0, y0, 600.0, y1 - y0), Color(0.3, 0.75, 0.35, 0.8), false, 3.0)
			for i in 7:   # the wind, faster when it blows harder
				var x := fposmod(i * 173.0 + game.time * (120.0 + 420.0 * game.wind), w + 160.0) - 80.0
				var y := 110.0 + fposmod(i * 71.0, gy - 220.0)
				draw_line(Vector2(x, y), Vector2(x + 26.0 + 40.0 * game.wind, y), Color(1, 1, 1, 0.5), 3.0)
		draw_polyline(game.string_points(), Color("f6efe0"), 2.0, true)


## lives, the bar to fill, the wind and the string
class Hud extends Control:
	var game: Control

	func _bar(at: Vector2, w: float, label: String, value: float, col: Color, mark := -1.0) -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, at + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6e8c4"))
		draw_rect(Rect2(at.x + 78, at.y, w, 18), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(at.x + 78, at.y, w * clampf(value, 0.0, 1.0), 18), col)
		if mark >= 0.0:
			draw_rect(Rect2(at.x + 78 + w * mark - 2, at.y - 4, 4, 26), Color("e0453a"))

	func _draw() -> void:
		if game.state == "pilih":
			return
		var w := size.x
		var a := Vector2(w - 400.0, 20.0)
		draw_rect(Rect2(a, Vector2(376, 132)), Color(0.1, 0.07, 0.04, 0.78))
		_bar(a + Vector2(14, 50), 270.0, tr("ZON"), game.held / game.GOAL[game.level], Color("6fcf6a"))
		_bar(a + Vector2(14, 76), 270.0, tr("ANGIN"), game.wind / 1.35, Color("6fb7ff"))
		var pull: float = game.wind + (game.PULL if game.pulling else 0.0)
		_bar(a + Vector2(14, 102), 270.0, tr("TALI"), pull / 2.2, Color("e0453a") if pull > game.TAUT else Color("f2c14e"), game.TAUT / 2.2)
