extends "res://scripts/screens/warisan_game.gd"
## Sepak Raga (Pesta Warisan): sepak raga bulatan. Alif and four classmates
## stand in a ring and keep the rattan ball in the air (timang). The
## classmates never miss; when the ball comes to Alif, press SEPAK (Space, a
## click, the button) as it reaches his foot: the circle on the ground closes
## on him as the ball comes down.
##   on time        1 timang (right on it: PADU, 2)
##   too late       the ball drops: a life (three)
## Every fifth kick of Alif's brings a revision question: right = his next
## five kicks count double. Reach the level's number of timang to win. The
## ball flies faster as the rally goes on.

const CENTRE := Vector2(640, 396)
const R := 214.0
const STAND := 0.74          ## of R: where the players stand
const PLAYERS := ["", "rakan_ravi", "rakan_aisyah", "rakan_daniel", "rakan_meiling"]   ## "" = Alif, at the bottom
const ANGLES := [90.0, 162.0, 234.0, 306.0, 18.0]
const FLIGHT := [1.4, 1.2, 1.05]    ## seconds a pass takes, by level
const WINDOW := [0.24, 0.19, 0.15]  ## how far from the landing a kick still counts
const PADU := [0.085, 0.07, 0.055]  ## ... and counts double
const EARLY := 0.4                  ## a press sooner than this before the landing is ignored
const TARGET := [12, 16, 20]
const PEAK := 190.0
const LIVES := 3
const ASK_EVERY := 5
const TO_ALIF := 0.45               ## how often a classmate passes to Alif

var level := 1
var state := "pilih"      ## pilih, main, servis (a new ball is coming), soalan, tamat
var ball := {}            ## {from, to, t, T}: a pass between two players
var timang := 0
var kicks := 0            ## Alif's own
var double := 0           ## kicks that still count double
var lives := LIVES
var right := 0
var time := 0.0
var won := false
var rally := 0

var _field: Node2D
var _people: Array[AnimatedSprite2D] = []
var _ball: Sprite2D
var _shadow: Sprite2D
var _hud: Control
var _info: Label
var _kick: Button
var _hearts: HBoxContainer
var _wait := 0.0
var _hop: Array = [0.0, 0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	setup_game(Color("4f9a4a"))
	_field = Padang.new()
	_field.game = self
	_field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_field)
	_shadow = Sprite2D.new()
	_shadow.texture = load("res://assets/warisan/bola_bayang.png")
	_shadow.scale = Vector2(3, 3)
	_field.add_child(_shadow)
	for i in PLAYERS.size():
		var folder: String = PLAYERS[i] if PLAYERS[i] != "" else Game.skin_folder()
		var s := AnimatedSprite2D.new()
		s.sprite_frames = CharacterFrames.build(folder, false)
		s.offset = CharacterFrames.feet_offset(folder)
		s.scale = Vector2(2.6, 2.6)
		var a: float = deg_to_rad(ANGLES[i])
		s.play("idle_north" if sin(a) > 0.5 else ("idle_south" if sin(a) < -0.5 else ("idle_east" if cos(a) < 0.0 else "idle_west")))
		_field.add_child(s)
		_people.append(s)
	_ball = Sprite2D.new()
	_ball.texture = load("res://assets/warisan/bola_raga.png")
	_field.add_child(_ball)
	var painter := Padang.new()
	painter.game = self
	painter.ground = true
	if make_stage(_field, painter, Rect2(CENTRE - Vector2(R + 30.0, R + 30.0), Vector2(R + 30.0, R + 30.0) * 2.0)):
		stage.cam_offset = Vector3(0, 19.0, 19.0)
		stage.look_at_px(CENTRE + Vector2(0, -4), true)
		for it in Padang.PROPS:
			stage.prop(load("res://assets/objects/%s.png" % it[0]), Vector2(it[1] if it[1] >= 0.0 else Game.screen_w() + it[1], it[2]), 3.0)
		_shadow.visible = false   # the sun casts the ball's shadow there

	_hud = Hud.new()
	_hud.game = self
	UI.full(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var top := UI.panel()
	top.position = Vector2(24, 20)
	var row := UI.hbox(16)
	row.add_child(UI.label("SEPAK RAGA", "Heading"))
	_info = UI.label("")
	_info.custom_minimum_size.x = 150
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
	_kick = UI.button(tr("SEPAK!"), "Primary", 240)
	_kick.custom_minimum_size.y = 96
	_kick.focus_mode = Control.FOCUS_NONE
	_kick.position = Vector2(Game.screen_w() - 280.0, 720.0 - 124.0)
	_kick.button_down.connect(kick)
	add_child(_kick)
	ball = {"from": 2, "to": 0, "t": 0.0, "T": 1.0}
	_place()
	if params.has("level"):
		_start(int(params["level"]))
	else:
		_level_card()


func _level_card() -> void:
	state = "pilih"
	level_card("SEPAK RAGA", tr("Timang bola rotan dalam bulatan bersama rakan sekelas. Bila bola datang kepada kau, tekan SEPAK tepat ketika ia sampai ke kaki: bulatan di tanah mengecil bila bola turun.\n\nTepat pada masanya: PADU, dua timang. Terlambat: bola jatuh, hilang satu nyawa.\n\nSetiap sepakan kelima ada soalan: betul, lima sepakan seterusnya dikira dua kali."), _start)


func spot(i: int) -> Vector2:
	var a: float = deg_to_rad(ANGLES[i])
	return CENTRE + Vector2(cos(a), sin(a)) * R * STAND


func _start(lv: int) -> void:
	level = clampi(lv, 0, 2)
	close_card()
	timang = 0
	kicks = 0
	double = 0
	lives = LIVES
	right = 0
	time = 0.0
	_serve(1.0)


## a new ball, from a classmate to Alif, after a moment
func _serve(after: float) -> void:
	rally = 0
	state = "servis"
	_wait = after
	ball = {"from": 2, "to": 0, "t": 0.0, "T": FLIGHT[level]}


func _pass(from: int, to: int) -> void:
	ball = {"from": from, "to": to, "t": 0.0, "T": FLIGHT[level] * maxf(0.72, 1.0 - 0.012 * rally)}
	_hop[from] = 0.3
	rally += 1
	Sfx.play("thwack", -6.0)


## SEPAK: only when the ball is coming down on Alif
func kick() -> void:
	if state != "main" or ball["to"] != 0:
		return
	var off: float = ball["T"] - ball["t"]   # seconds until it lands (less than 0: already past)
	if off > EARLY:
		return
	if off > WINDOW[level]:   # swung too soon: he has to wait for it now
		Game.toast(tr("Terlalu awal!"), Color("e0705f"))
		return
	var padu: bool = absf(off) <= PADU[level]
	var points := (2 if padu else 1) * (2 if double > 0 else 1)
	timang += points
	kicks += 1
	double = maxi(0, double - 1)
	if padu:
		Game.toast(tr("PADU! +%d") % points, Color("f2c14e"))
	var others := [1, 2, 3, 4]
	_pass(0, others.pick_random())
	if timang >= TARGET[level]:
		_finish(true)
	elif kicks % ASK_EVERY == 0:
		state = "soalan"
		question_card(tr("SOALAN PANTAS"), tr("Betul! Lima sepakan seterusnya dikira dua kali."), "", func(ok: bool):
			state = "main"
			if ok:
				right += 1
				double = 5)


func _finish(victory: bool) -> void:
	state = "tamat"
	won = victory
	var res := WarisanRules.finish("raga", victory, level, right, time)
	var text := tr("Bola jatuh tiga kali pada %d timang. Tak apa, cuba lagi: tunggu bulatan mengecil ke kaki.") % timang
	if victory:
		Sfx.play("sparkle")
		MusicDirector.stinger("st_levelup" if res["level_up"] else "st_correct")
		text = tr("%d timang dalam %.1f saat!%s\n\n+%d EXP   +%d Syiling (%d soalan betul)") % [
			timang, time, (" " + tr("Rekod baharu!")) if res["best"] else "", res["exp"], res["coins"], right]
	result_card(tr("MENANG!") if victory else tr("BOLA JATUH!"), text, _level_card)
	print("raga: won=%s level=%d timang=%d kicks=%d lives=%d right=%d" % [victory, level, timang, kicks, lives, right])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		kick()


func _process(delta: float) -> void:
	_field.queue_redraw()
	_hud.queue_redraw()
	_kick.visible = state in ["main", "servis"]
	_hearts.visible = state != "pilih"
	for i in LIVES:
		_hearts.get_child(i).modulate.a = 1.0 if i < lives else 0.2
	for i in _hop.size():
		_hop[i] = maxf(0.0, _hop[i] - delta)
	_info.text = "%d / %d" % [timang, TARGET[level]] if state != "pilih" else ""
	if state == "servis":
		_wait -= delta
		if _wait <= 0.0:
			state = "main"
			_hop[ball["from"]] = 0.3
			Sfx.play("thwack", -6.0)
	elif state == "main":
		time += delta
		ball["t"] += delta
		if ball["to"] == 0:
			if _auto and ball["T"] - ball["t"] <= 0.03:
				kick()
			elif ball["t"] > ball["T"] + WINDOW[level]:   # nobody kicked it
				lives -= 1
				Sfx.play("gedebuk")
				Game.toast(tr("Bola jatuh!"), Color("e0705f"))
				if lives <= 0:
					_finish(false)
				else:
					_serve(1.2)
		elif ball["t"] >= ball["T"]:   # a classmate: to Alif, or on round the ring
			var from: int = ball["to"]
			var to := 0
			if randf() > TO_ALIF:
				var others := [1, 2, 3, 4]
				others.erase(from)
				to = others.pick_random()
			_pass(from, to)
	_place()


## where the ball is on the ground, and how high
func ball_at() -> Array:
	var u := clampf(float(ball["t"]) / float(ball["T"]), 0.0, 1.15)
	var p: Vector2 = spot(ball["from"]).lerp(spot(ball["to"]), minf(u, 1.0))
	var z := maxf(0.0, 4.0 * PEAK * u * (1.0 - u)) + 22.0 * (1.0 - clampf((u - 1.0) / 0.15, 0.0, 1.0))
	return [p, z if state != "servis" else 34.0]


func _place() -> void:
	for i in _people.size():
		var p := spot(i)
		_people[i].position = p
		_people[i].set_meta("ground_y", p.y)
		if _hop[i] > 0.0:
			_people[i].position.y -= sin(_hop[i] / 0.3 * PI) * 16.0
	var b := ball_at()
	var at: Vector2 = b[0] if state != "servis" else spot(ball["from"])
	_shadow.position = at + Vector2(0, -4)
	_ball.position = at + Vector2(0, -float(b[1]))
	_ball.set_meta("ground_y", at.y + 2.0)
	_ball.rotation = time * 7.0
	var k := 2.6 + float(b[1]) / PEAK * (0.0 if stage else 1.4)   # nearer the eye when it is high (2D only)
	_ball.scale = Vector2(k, k)
	_ball.visible = state in ["main", "servis", "soalan"]
	_shadow.visible = _ball.visible and stage == null


## the ring from above: packed earth, a lime line, where the ball will land
class Padang extends Node2D:
	const PROPS := [["palm", 80.0, 260.0], ["rumah_hijau", 150.0, 540.0], ["gerai_rempah", -160.0, 320.0], ["palm", -70.0, 570.0], ["tree_mempelam", -260.0, 200.0]]   ## [object, x (from the right edge when negative), y of its foot]

	var game: Control
	var ground := false   ## HD-2D: only what lies flat
	var _tex := {}

	func _oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 40:
			var a := TAU * k / 40.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var c: Vector2 = game.CENTRE
		var r: float = game.R
		if not ground:
			var w := Game.screen_w()
			for i in 22:
				var g := Vector2(fposmod(i * 197.0, w), 150.0 + fposmod(i * 131.0, 540.0))
				if g.distance_to(c) > r + 40.0:
					draw_line(g, g + Vector2(-5, -12), Color("3e7d3c"), 3.0)
					draw_line(g + Vector2(4, 0), g + Vector2(8, -10), Color("3e7d3c"), 3.0)
			for item in PROPS:
				if not _tex.has(item[0]):
					_tex[item[0]] = load("res://assets/objects/%s.png" % item[0])
				var tex: Texture2D = _tex[item[0]]
				var sz := tex.get_size() * 3.0
				var x: float = item[1] if item[1] >= 0.0 else w + item[1]
				draw_texture_rect(tex, Rect2(Vector2(x - sz.x / 2.0, item[2] - sz.y), sz), false)
		_oval(c + Vector2(0, 6), r + 22.0, r + 22.0, Color("3e7d3c"))
		_oval(c, r + 14.0, r + 14.0, Color("b98f58"))
		_oval(c, r, r, Color("d9b47a"))
		draw_arc(c, r, 0, TAU, 64, Color("f6efe0"), 5.0, true)
		for i in 14:
			var s := c + Vector2(cos(i * 2.1), sin(i * 2.1)) * (30.0 + fposmod(i * 47.0, r - 60.0))
			draw_rect(Rect2(s, Vector2(9, 3)), Color("c9a268"))
		if game.state == "main" and game.ball["to"] == 0:   # the circle closing on Alif's feet
			var off: float = game.ball["T"] - game.ball["t"]
			var feet: Vector2 = game.spot(0) + Vector2(0, -6)
			var good: bool = absf(off) <= game.WINDOW[game.level]
			draw_arc(feet, 24.0, 0, TAU, 32, Color("58b84c") if good else Color(1, 1, 1, 0.8), 5.0, true)
			if off > 0.0:
				draw_arc(feet, 24.0 + off * 110.0, 0, TAU, 40, Color("ffd64d"), 4.0, true)


class Hud extends Control:
	var game: Control

	func _draw() -> void:
		if game.state == "pilih":
			return
		var font := ThemeDB.fallback_font
		var a := Vector2(size.x - 400.0, 20.0)
		draw_rect(Rect2(a, Vector2(376, 96)), Color(0.1, 0.07, 0.04, 0.78))
		draw_string(font, a + Vector2(14, 72), tr("TIMANG"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6e8c4"))
		draw_rect(Rect2(a.x + 92, a.y + 56, 180, 20), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(a.x + 92, a.y + 56, 180.0 * clampf(game.timang / float(game.TARGET[game.level]), 0.0, 1.0), 20), Color("6fcf6a"))
		draw_string(font, a + Vector2(280, 74), "%d/%d" % [game.timang, game.TARGET[game.level]], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd64d"))
		if game.double > 0:
			draw_string(font, a + Vector2(150, 36), tr("x2 (%d lagi)") % game.double, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8fe88a"))
