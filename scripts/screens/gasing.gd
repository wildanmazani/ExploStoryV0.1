extends "res://scripts/screens/warisan_game.gd"
## Gasing (Pesta Warisan): Alif's top against a classmate's in the gelanggang,
## first to win two rounds. A round:
##   1. a revision question: right = the string is wound tighter (more spin)
##   2. LILIT: a marker runs along a bar; LEMPAR while it is in the green
##      for the hardest throw (more spin)
##   3. the two tops spin in the ring. Steer Alif's (WASD / arrows, or hold the
##      mouse / a finger where it should go). A top loses the round when its
##      spin runs out (the other won by URI: it spun longer) or when it is
##      knocked out of the ring (PANGKAH). In a knock the top that was hit
##      loses the most spin, and moving about costs a little: sit tight and
##      outlast, or ram and risk the edge.

const KEYS := [["interact", "Lempar"], ["move", "Kawal gasing"], ["pause", "Jeda"]]
const CENTRE := Vector2(640, 392)
const R := 214.0            ## the ring
const TOP := 26.0           ## a top's radius
const ACCEL := 560.0
const MAX_SPEED := 270.0
const FRICTION := 1.6
const SPIN_DECAY := 0.042   ## of a full spin per second
const SPIN_MOVE := 0.00016  ## ... more per px/s moved
const HIT_SPIN := 0.24      ## spin a full-speed hit takes
const BONUS := 0.2          ## spin for a right answer
const GREEN := [0.70, 0.88] ## the best part of the LILIT bar
const SWEEP := 1.15         ## seconds for the marker to cross the bar
const RIVAL := "rakan_daniel"
const RIVAL_NAME := "Daniel"
const RIVAL_SPIN := [0.72, 0.88, 1.02]
const RIVAL_ACCEL := [300.0, 430.0, 540.0]
const RIVAL_SPEED := [150.0, 215.0, 260.0]
const RIVAL_CHASE := [0.25, 0.6, 1.0]   ## how much of the time he goes for Alif's top
const CROWD := ["rakan_aisyah", "makcik", "rakan_ravi", "pakcik_lembah", "rakan_meiling", "nelayan", "penjaga", "pelatih"]
const WINS := 2

var level := 1
var state := "pilih"      ## pilih, soalan, lilit, pusing, rehat (between rounds), tamat
var me := {}              ## {p, v, spin, angle, out}
var rival := {}
var score := [0, 0]       ## rounds won: Alif, rival
var marker := 0.0         ## on the LILIT bar, 0..1
var power := 0.0
var bonus := false
var right := 0
var time := 0.0
var won := false
var last := ""            ## how the last round ended, for the screen

var _ring: Node2D
var _hud: Control
var _throw: Button
var _info: Label
var _pointer := false
var _dir := 1.0
var _mood := 0.0
var _chasing := false
var _tops3: Array = []   ## HD-2D: the two tops as 3D things [Alif's, the rival's]


func _ready() -> void:
	setup_game(Color("4f9a4a"))
	_ring = Ring.new()
	_ring.game = self
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_ring)
	for i in CROWD.size():   # the kampung round the ring (not at the bottom: the bar is there)
		var a := lerpf(PI * 0.98, PI * 2.02, i / float(CROWD.size() - 1))
		var s := AnimatedSprite2D.new()
		s.sprite_frames = CharacterFrames.build(CROWD[i], false)
		s.offset = CharacterFrames.feet_offset(CROWD[i])
		s.scale = Vector2(2.6, 2.6)
		s.position = CENTRE + Vector2(cos(a) * (R + 84.0), sin(a) * (R + 52.0) + 30.0)
		s.play("idle_south" if sin(a) < -0.5 else ("idle_east" if cos(a) < 0.0 else "idle_west"))
		_ring.add_child(s)
	add_touch_controls()
	var painter := Ring.new()
	painter.game = self
	painter.ground = true
	if make_stage(_ring, painter, Rect2(CENTRE - Vector2(R + 30.0, R + 30.0), Vector2(R + 30.0, R + 30.0) * 2.0)):
		_dress_stage()
	_hud = Hud.new()
	_hud.game = self
	UI.full(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	var top := UI.panel()
	top.position = Vector2(24, 20)
	var row := UI.hbox(16)
	row.add_child(UI.label("GASING", "Heading"))
	_info = UI.label("")
	_info.custom_minimum_size.x = 190
	row.add_child(_info)
	row.add_child(controls(KEYS, false, true))
	row.add_child(exit_button())
	top.add_child(row)
	add_child(top)
	_throw = UI.button(tr("LEMPAR!"), "Primary", 240)
	_throw.custom_minimum_size.y = 84
	_throw.focus_mode = Control.FOCUS_NONE
	_throw.position = Vector2(Game.screen_w() - 280.0, 720.0 - 112.0)
	_throw.button_down.connect(throw)
	add_child(_throw)
	_place_tops()
	if params.has("level"):
		_start(int(params["level"]))
	else:
		_level_card()


## HD-2D: the kampung round the ring, and the tops as real tops
func _dress_stage() -> void:
	stage.cam_offset = Vector3(0, 20.0, 18.0)
	stage.look_at_px(CENTRE + Vector2(0, 16), true)
	for it in Ring.PROPS:
		stage.prop(load("res://assets/objects/%s.png" % it[0]), Vector2(it[1] if it[1] >= 0.0 else Game.screen_w() + it[1], it[2]), 3.0)
	_tops3 = [_top3(Color("cc3e34"), Color("ffd64d")), _top3(Color("4682c8"), Color("f6e8c4"))]


## a top: a turned wooden body on its point, a painted head, two dots that show the spin
func _top3(paint: Color, dots: Color) -> Node3D:
	var r: float = TOP * Stage.K
	var top := Node3D.new()
	var part := func(mesh: Mesh, colour: Color, y: float) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = 0.6
		m.material_override = mat
		m.position.y = y
		top.add_child(m)
		return m
	var body := CylinderMesh.new()
	body.top_radius = r
	body.bottom_radius = r * 0.12
	body.height = r * 1.3
	part.call(body, Color("96623a"), r * 0.65)
	var head := CylinderMesh.new()
	head.top_radius = r * 0.92
	head.bottom_radius = r
	head.height = r * 0.3
	part.call(head, paint, r * 1.45)
	var stem := CylinderMesh.new()
	stem.top_radius = r * 0.16
	stem.bottom_radius = r * 0.2
	stem.height = r * 0.6
	part.call(stem, Color("5a381e"), r * 1.9)
	for side in [-1.0, 1.0]:
		var dot := CylinderMesh.new()
		dot.top_radius = r * 0.24
		dot.bottom_radius = r * 0.24
		dot.height = r * 0.06
		part.call(dot, dots, r * 1.62).position.x = side * r * 0.55
	stage.add_child(top)
	return top


func _sync_tops3() -> void:
	var both := [me, rival]
	for i in 2:
		var t: Dictionary = both[i]
		var n: Node3D = _tops3[i]
		n.visible = state in ["pusing", "rehat", "lilit", "soalan"]
		n.position = stage.to3(CENTRE + t["p"])
		var lean := 0.0
		if state in ["pusing", "rehat"] and float(t["spin"]) < 0.25:   # nearly out of spin: it sways
			lean = 0.45 * (1.0 - float(t["spin"]) / 0.25)
		n.rotation = Vector3(lean * cos(t["angle"] * 0.5), -t["angle"], lean * sin(t["angle"] * 0.5))


func _level_card() -> void:
	state = "pilih"
	level_card("GASING", tr("Lawan gasing Daniel dalam gelanggang. Menang dua pusingan dahulu.\n\nLILIT: tekan LEMPAR ketika penanda di bahagian hijau untuk pusingan paling kuat. Jawab soalan dengan betul dan tali lebih ketat.\n\nDalam gelanggang, kawal gasing kau. Gasing yang berhenti berpusing dahulu kalah (URI), begitu juga gasing yang terkeluar dari gelanggang (PANGKAH)."), _start, KEYS)


func _place_tops() -> void:
	me = {"p": Vector2(0, 118), "v": Vector2.ZERO, "spin": 0.0, "angle": 0.0, "out": 0.0}
	rival = {"p": Vector2(0, -118), "v": Vector2.ZERO, "spin": 0.0, "angle": 1.0, "out": 0.0}


func _start(lv: int) -> void:
	level = clampi(lv, 0, 2)
	close_card()
	score = [0, 0]
	right = 0
	time = 0.0
	last = ""
	_round()


## a round begins: the question, then the bar
func _round() -> void:
	_place_tops()
	state = "soalan"
	question_card(tr("LILIT TALI"), tr("Betul! Tali dililit lebih ketat."), "", func(ok: bool):
		bonus = ok
		if ok:
			right += 1
		marker = 0.0
		_dir = 1.0
		state = "lilit")


## LEMPAR: the marker stops, both tops land in the ring
func throw() -> void:
	if state != "lilit":
		return
	var mid: float = (GREEN[0] + GREEN[1]) / 2.0
	var off := maxf(0.0, absf(marker - mid) - (GREEN[1] - GREEN[0]) / 2.0)
	power = clampf(1.0 - off * 1.5, 0.3, 1.0)
	me["spin"] = 0.5 + 0.45 * power + (BONUS if bonus else 0.0)
	rival["spin"] = RIVAL_SPIN[level]
	me["v"] = Vector2(0, -60)
	rival["v"] = Vector2(0, 60)
	_pointer = false
	_mood = 0.0
	state = "pusing"
	Sfx.play("whoosh")
	Game.toast(tr("Lemparan padu!") if power >= 0.99 else (tr("Lemparan baik.") if power > 0.7 else tr("Lemparan lemah...")))


func _end_round(i_won: bool, how: String) -> void:
	state = "rehat"
	last = how
	score[0 if i_won else 1] += 1
	Sfx.play("chime" if i_won else "gedebuk")
	Game.toast(how, Color("f2c14e") if i_won else Color("e0705f"))
	await get_tree().create_timer(0.3 if _auto else 2.0).timeout
	if not is_inside_tree():
		return
	if score[0] >= WINS or score[1] >= WINS:
		_finish(score[0] >= WINS)
	else:
		_round()


func _finish(victory: bool) -> void:
	state = "tamat"
	won = victory
	var res := WarisanRules.finish("gasing", victory, level, right, time)
	var text := tr("Daniel menang %d-%d. Tak apa, cuba lagi: lempar di hijau, dan jangan terlalu dekat dengan tepi.") % [score[1], score[0]]
	if victory:
		Sfx.play("sparkle")
		MusicDirector.stinger("st_levelup" if res["level_up"] else "st_correct")
		text = tr("Kau menang %d-%d!\n\n+%d EXP   +%d Syiling (%d soalan betul)") % [score[0], score[1], res["exp"], res["coins"], right]
	result_card(tr("MENANG!") if victory else tr("KALAH!"), text, _level_card)
	print("gasing: won=%s level=%d %d-%d time=%.1f right=%d" % [victory, level, score[0], score[1], time, right])


# ---------------------------------------------------------------- play

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.pressed and state == "pusing" and not on_touch_controls(event.position)
	elif event.is_action_pressed("interact") and not event.is_echo():
		throw()


func _steer() -> Vector2:
	if _auto:   # the dev bot sits in the middle and outlasts
		return (-me["p"] / 60.0).limit_length(1.0)
	var v := move_vector()
	if v == Vector2.ZERO and _pointer:
		var to: Vector2 = pointer_on(_ring) - CENTRE - me["p"]
		if to.length() > 8.0:
			v = to / 60.0
	return v.limit_length(1.0)


## the rival: keeps off the edge, and goes for Alif's top as often as the level says
func _rival_steer(delta: float) -> Vector2:
	_mood -= delta
	if _mood <= 0.0:
		_mood = randf_range(1.2, 2.4)
		_chasing = randf() < RIVAL_CHASE[level]
	var p: Vector2 = rival["p"]
	if p.length() > R * 0.62:
		return -p.normalized()
	if _chasing:
		return (me["p"] - p).normalized()
	return (Vector2(cos(time * 0.9), sin(time * 0.9)) * R * 0.3 - p).limit_length(1.0)


func _move(t: Dictionary, steer: Vector2, accel: float, top_speed: float, delta: float) -> void:
	var grip := clampf(float(t["spin"]) / 0.25, 0.35, 1.0)   # a top about to fall hardly answers
	t["v"] += steer * accel * grip * delta
	t["v"] *= exp(-FRICTION * delta)
	t["v"] = t["v"].limit_length(top_speed)
	t["p"] += t["v"] * delta
	t["spin"] = maxf(0.0, float(t["spin"]) - (SPIN_DECAY + SPIN_MOVE * t["v"].length()) * delta)
	t["angle"] += (6.0 + 34.0 * float(t["spin"])) * delta


func _process(delta: float) -> void:
	_ring.queue_redraw()
	if stage:
		_sync_tops3()
	_hud.queue_redraw()
	_throw.visible = state == "lilit"
	touch_controls_on(state == "pusing" or state == "lilit")
	_info.text = "%s %d" % [tr("Pusingan"), mini(score[0] + score[1] + 1, WINS * 2 - 1)] if state != "pilih" else ""
	if state == "lilit":
		marker += _dir * delta / SWEEP
		if marker >= 1.0 or marker <= 0.0:
			marker = clampf(marker, 0.0, 1.0)
			_dir = -_dir
		if _auto and marker > GREEN[0] + 0.04 and marker < GREEN[1]:
			throw()
		return
	if state != "pusing":
		for t in [me, rival]:   # the last spins of the round just over
			t["angle"] += (6.0 + 34.0 * float(t["spin"])) * delta * (1.0 if state == "rehat" else 0.0)
		return
	time += delta
	_move(me, _steer(), ACCEL, MAX_SPEED, delta)
	_move(rival, _rival_steer(delta), RIVAL_ACCEL[level], RIVAL_SPEED[level], delta)

	# a knock: the tops swap what they carried towards each other, and the one hit harder loses more spin
	var d: Vector2 = rival["p"] - me["p"]
	if d.length() < TOP * 2.0 and d.length() > 0.01:
		var n := d.normalized()
		var a: float = me["v"].dot(n)        # Alif's speed into the rival
		var b: float = rival["v"].dot(-n)    # the rival's into Alif
		if a + b > 0.0:
			me["v"] += n * (-a - b * 1.15)
			rival["v"] += n * (b + a * 1.15)
			me["spin"] = maxf(0.0, me["spin"] - 0.015 - HIT_SPIN * maxf(b, 0.0) / MAX_SPEED)
			rival["spin"] = maxf(0.0, rival["spin"] - 0.015 - HIT_SPIN * maxf(a, 0.0) / MAX_SPEED)
			Sfx.play("thwack", -4.0)
		var push := (TOP * 2.0 - d.length()) / 2.0
		me["p"] -= n * push
		rival["p"] += n * push

	if me["p"].length() > R:
		_end_round(false, tr("PANGKAH! Gasing kau terkeluar dari gelanggang."))
	elif rival["p"].length() > R:
		_end_round(true, tr("PANGKAH! Gasing %s terkeluar.") % RIVAL_NAME)
	elif rival["spin"] <= 0.0:
		_end_round(true, tr("URI! Gasing kau berpusing lebih lama."))
	elif me["spin"] <= 0.0:
		_end_round(false, tr("Gasing kau berhenti dahulu."))


## the gelanggang from above: packed earth, a lime line, grass, the two tops
class Ring extends Node2D:
	const PROPS := [["palm", 70.0, 250.0], ["rumah_merah", 150.0, 520.0], ["wakaf_padang", -150.0, 300.0], ["palm", -70.0, 560.0], ["tree_rambutan", -250.0, 190.0]]   ## [object, x (from the right edge when negative), y of its foot]

	var game: Control
	var ground := false   ## HD-2D: only what lies flat (the stage stands the rest up)
	var _tex := {}

	func _t(name: String) -> Texture2D:
		if not _tex.has(name):
			_tex[name] = load("res://assets/objects/%s.png" % name)
		return _tex[name]

	func _oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 40:
			var a := TAU * k / 40.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var c: Vector2 = game.CENTRE
		var r: float = game.R
		var w := Game.screen_w()
		if not ground:
			for i in 22:   # tufts in the grass
				var g := Vector2(fposmod(i * 197.0, w), 150.0 + fposmod(i * 131.0, 540.0))
				if g.distance_to(c) > r + 40.0:
					draw_line(g, g + Vector2(-5, -12), Color("3e7d3c"), 3.0)
					draw_line(g + Vector2(4, 0), g + Vector2(8, -10), Color("3e7d3c"), 3.0)
			for item in PROPS:
				var tex := _t(item[0])
				var sz := tex.get_size() * 3.0
				var x: float = item[1] if item[1] >= 0.0 else w + item[1]
				draw_texture_rect(tex, Rect2(Vector2(x - sz.x / 2.0, item[2] - sz.y), sz), false)
		_oval(c + Vector2(0, 6), r + 22.0, r + 22.0, Color("3e7d3c"))
		_oval(c, r + 14.0, r + 14.0, Color("b98f58"))
		_oval(c, r, r, Color("d9b47a"))
		draw_arc(c, r, 0, TAU, 64, Color("f6efe0"), 5.0, true)          # the line: outside it a top is out
		draw_arc(c, r * 0.5, 0, TAU, 48, Color(0.72, 0.56, 0.34, 0.6), 2.0, true)
		for i in 14:   # scuffs in the earth
			var s := c + Vector2(cos(i * 2.1), sin(i * 2.1)) * (30.0 + fposmod(i * 47.0, r - 60.0))
			draw_rect(Rect2(s, Vector2(9, 3)), Color("c9a268"))
		if not ground and game.state in ["pusing", "rehat", "lilit", "soalan"]:
			_top(c + game.rival["p"], game.rival, [Color("4682c8"), Color("f6e8c4")])
			_top(c + game.me["p"], game.me, [Color("cc3e34"), Color("ffd64d")])

	## a top from above: its painted bands turn as fast as it spins, and it sways when the spin is nearly gone
	func _top(at: Vector2, t: Dictionary, cols: Array) -> void:
		var spin: float = t["spin"]
		var live: bool = game.state in ["pusing", "rehat"]
		if live and spin < 0.25:
			at += Vector2(cos(t["angle"] * 0.6), sin(t["angle"] * 0.6)) * 5.0 * (1.0 - spin / 0.25)
		var rad: float = game.TOP
		_oval(at + Vector2(5, 8), rad, rad * 0.8, Color(0, 0, 0, 0.25))
		draw_circle(at, rad, Color("2b1c10"))
		draw_circle(at, rad - 2.5, Color("96623a"))
		for k in 6:   # the painted bands
			var a0: float = t["angle"] + TAU * k / 6.0
			var pts := PackedVector2Array([at])
			for j in 5:
				var a := a0 + TAU / 6.0 * j / 4.0
				pts.append(at + Vector2(cos(a), sin(a)) * (rad - 6.0))
			draw_colored_polygon(pts, cols[k % 2])
		draw_circle(at, rad * 0.42, Color("c48c4e"))
		draw_circle(at, rad * 0.2, Color("5a381e"))
		draw_arc(at, rad - 4.0, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.55), 3.0, true)
		if live and t["v"].length() > 60.0:   # dust
			for i in 3:
				var back: Vector2 = at - t["v"].normalized() * (rad + 8.0 + i * 12.0)
				draw_circle(back, 6.0 - i * 1.5, Color(0.93, 0.85, 0.68, 0.4 - i * 0.1))


## rounds won, how much spin is left, and the LILIT bar
class Hud extends Control:
	var game: Control

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x
		var ink := Color(0.1, 0.07, 0.04, 0.78)
		var a := Vector2(w - 400.0, 24.0)
		draw_rect(Rect2(a, Vector2(376, 96)), ink)
		var rows := [["Alif", game.me, Color("ffd64d"), game.score[0]], [game.RIVAL_NAME, game.rival, Color("6fb7ff"), game.score[1]]]
		for i in 2:
			var y := a.y + 30.0 + i * 40.0
			draw_string(font, Vector2(a.x + 14, y + 6), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, rows[i][2])
			draw_rect(Rect2(a.x + 90, y - 10, 190, 18), Color(1, 1, 1, 0.15))
			draw_rect(Rect2(a.x + 90, y - 10, 190.0 * clampf(float(rows[i][1]["spin"]) / 1.15, 0.0, 1.0), 18), rows[i][2])
			for k in game.WINS:   # rounds won
				draw_circle(Vector2(a.x + 306 + k * 30.0, y - 1), 10.0, rows[i][2] if k < rows[i][3] else Color(1, 1, 1, 0.18))
		if game.state != "lilit":
			return
		var bw := 520.0
		var b := Vector2((w - bw) / 2.0, size.y - 92.0)
		draw_rect(Rect2(b.x - 14, b.y - 40, bw + 28, 96), ink)
		draw_string(font, b + Vector2(0, -14), tr("LILIT TALI: lempar ketika penanda di hijau"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6e8c4"))
		draw_rect(Rect2(b.x, b.y, bw, 30), Color("c8473c"))
		draw_rect(Rect2(b.x + bw * 0.45, b.y, bw * 0.55, 30), Color("d9a441"))
		draw_rect(Rect2(b.x + bw * game.GREEN[0], b.y, bw * (game.GREEN[1] - game.GREEN[0]), 30), Color("58b84c"))
		draw_rect(Rect2(b.x + bw * game.marker - 4, b.y - 7, 8, 44), Color.WHITE)
		if game.bonus:
			draw_string(font, b + Vector2(0, 50), tr("Tali ketat: bonus pusingan!"), HORIZONTAL_ALIGNMENT_RIGHT, bw, 16, Color("8fe88a"))
