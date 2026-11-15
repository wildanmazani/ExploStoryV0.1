extends "res://scripts/screens/warisan_game.gd"
## Tarik Upih (Pesta Warisan). A race down a straight track: Alif pulls Pau,
## who sits on an upih (the sheath of a pinang frond), against a classmate
## pulling another. Step LEFT, RIGHT, LEFT, RIGHT in an even rhythm: steps in
## the green part of the Rentak bar make Alif fast, steps that come too quickly
## shake the upih (Goyang), and when it is full Pau rolls off and Alif has to
## stop and put him back.
## Three question gates on the way: a right answer is a sprint (pecutan), a
## wrong one is a mud puddle. First over the line wins.
## Keys: left / right arrows or A / D; on a phone the two big buttons.

const TRACK := 4200.0               ## start line to finish line, px
const GATES := [0.25, 0.5, 0.75]
const LANE_RIVAL := 412.0           ## where the feet are, screen y
const LANE_ME := 548.0
const SCENE_Y := 258.0              ## the foot of the houses and trees behind the track
const CROWD_Y := 304.0              ## where the people watching stand
const SCENERY := ["rumah_merah", "palm", "tree_mempelam", "gerai_buah", "palm", "rumah_hijau", "tree_rambutan",
	"wakaf_padang", "palm", "rumah_biru", "tree_ketapang", "gerai_rempah", "palm", "tree_round"]
const CROWD := ["makcik", "rakan_aisyah", "pakcik_lembah", "rakan_meiling", "nelayan", "penjaga", "pelatih"]
const HASTY := 0.17                 ## a step sooner than this after the last one is too hasty
const GOOD := [0.24, 0.36]          ## the green part of the Rentak bar, seconds between steps
const SLOW := 0.5
const BAR := 0.6                    ## the whole Rentak bar, seconds
const PACE := {"tepat": 192.0, "ok": 152.0, "lambat": 112.0}   ## px/s a step pulls the speed towards
const RIVAL_SPEED := [126.0, 148.0, 166.0]
const RIVAL_FALLS := [[0.3, 0.65], [0.55], []]                 ## where the rival's rider rolls off, by level
const FALL_TIME := 1.7
const BOOST_TIME := 3.0
const MUD_TIME := 2.6

var level := 1
var state := "pilih"      ## pilih (level card), sedia (3, 2, 1), main, soalan, tamat
var time := 0.0
var right := 0
var won := false
var me := {}              ## {x, v, wobble, side, since, fallen, boost, mud, steps}
var rival := {}           ## {x, fallen, falls}
var gates: Array = []     ## {x, state}: "" not reached, "betul", "salah"

var _track: Node2D
var _alif: AnimatedSprite2D
var _pau: Sprite2D
var _upih: Array = []       ## [back, front]: the rider sits between them
var _r_puller: AnimatedSprite2D
var _r_rider: AnimatedSprite2D
var _r_upih: Array = []
var _crowd: Array[AnimatedSprite2D] = []
var _hud: Control
var _info: Label
var _count: Label
var _left: Button
var _right: Button
var _countdown := 0.0
var _auto_in := 0.0
var _gates3: Array = []   ## HD-2D: [board, label] of each question gate


func _ready() -> void:
	setup_game(Color("5aa552"))
	_track = Track.new()
	_track.game = self
	_track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_track)
	var x := -360.0
	var n := 0
	while x < TRACK + 900.0:   # the kampung comes to watch
		var who := _person(CROWD[n % CROWD.size()], 2.6)
		who.play("idle_south")
		who.position = Vector2(x, CROWD_Y)
		_crowd.append(who)
		x += 150.0 + 40.0 * ((n * 7) % 3)
		n += 1
	_r_upih = [_upih_sprite("belakang")]
	_r_rider = _person("rakan_daniel", 3.0)
	_r_upih.append(_upih_sprite("depan"))
	_r_puller = _person("rakan_ravi", 3.4)
	_upih = [_upih_sprite("belakang")]
	_pau = Sprite2D.new()
	_pau.texture = load("res://assets/characters32/pau/pau_small.png")
	_pau.scale = Vector2(2.4, 2.4)
	_pau.offset = Vector2(0, -12)
	_track.add_child(_pau)
	_upih.append(_upih_sprite("depan"))
	_alif = _person(Game.skin_folder(), 3.4)
	var painter := Track.new()
	painter.game = self
	painter.ground = true
	if make_stage(_track, painter, Rect2(-420.0, 330.0, TRACK + 1380.0, 372.0)):
		_dress_stage()

	_hud = Hud.new()
	_hud.game = self
	UI.full(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	var top := UI.panel()
	top.position = Vector2(24, 20)
	var row := UI.hbox(16)
	row.add_child(UI.label("TARIK UPIH", "Heading"))
	_info = UI.label("")
	_info.custom_minimum_size.x = 150
	row.add_child(_info)
	var out := UI.button("« Keluar")
	out.focus_mode = Control.FOCUS_NONE
	out.pressed.connect(func(): Game.goto("pesta"))
	row.add_child(out)
	top.add_child(row)
	add_child(top)

	_left = _step_button("◀  KIRI", -1)
	_right = _step_button("KANAN  ▶", 1)
	_count = UI.label("", "Heading")
	_count.add_theme_font_size_override("font_size", 96)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.position = Vector2(0, 150)
	_count.size = Vector2(Game.screen_w(), 120)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_reset()
	if params.has("level"):
		_start(int(params["level"]))
	else:
		_level_card()


func _person(folder: String, k: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = CharacterFrames.build(folder, true)
	s.offset = CharacterFrames.feet_offset(folder)
	s.scale = Vector2(k, k)
	s.play("idle_east")
	_track.add_child(s)
	return s


func _upih_sprite(part: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/warisan/upih_%s.png" % part)
	s.scale = Vector2(4, 4)
	_track.add_child(s)
	return s


## HD-2D: the kampung stands behind the track, the gates are signs by Alif's lane
func _dress_stage() -> void:
	stage.cam_offset = Vector3(0, 17.0, 24.0)
	stage.cam_look_up = 0.8
	stage.look_at_px(Vector2(190.0, LANE_RIVAL + 30.0), true)
	var step := 250.0
	for i in range(-1, int((TRACK + 900.0) / step) + 1):
		stage.prop(load("res://assets/objects/%s.png" % SCENERY[posmod(i, SCENERY.size())]), Vector2(i * step, SCENE_Y), 3.0)
	var fence: Texture2D = load("res://assets/objects/pagar.png")
	for i in range(-6, int((TRACK + 900.0) / 64.0)):
		stage.prop(fence, Vector2(i * 64.0 + 32.0, SCENE_Y + 30.0), 2.0)
	for who in _crowd:
		who.set_meta("ground_y", CROWD_Y)
	for g in gates.size():
		var at: Vector3 = stage.to3(Vector2(GATES[g] * TRACK, LANE_ME - 76.0))
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.22, 3.4, 0.22)
		post.mesh = pm
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("3f7a36")
		post.material_override = wood
		post.position = at + Vector3(0, 1.7, 0)
		stage.add_child(post)
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.2, 1.1, 0.14)
		board.mesh = bm
		board.material_override = StandardMaterial3D.new()
		board.position = at + Vector3(0, 3.6, 0)
		stage.add_child(board)
		var mark := Label3D.new()
		mark.font = Game.theme.default_font
		mark.font_size = 120
		mark.pixel_size = 0.0075
		mark.modulate = Color("2b1c10")
		mark.outline_size = 0
		mark.position = at + Vector3(0, 3.6, 0.09)
		stage.add_child(mark)
		_gates3.append([board, mark])
	for i in 2:   # what sits in or on an upih stands on the lane, drawn back to front
		var lane: float = [LANE_ME, LANE_RIVAL][i]
		var parts: Array = [[_upih[0], _pau, _upih[1], _alif], [_r_upih[0], _r_rider, _r_upih[1], _r_puller]][i]
		for k in parts.size():
			parts[k].set_meta("ground_y", lane)
			parts[k].set_meta("order", float(k))


## the two big step buttons: a phone has no arrow keys
func _step_button(text: String, side: int) -> Button:
	var b := UI.button(text, "", 230)
	b.custom_minimum_size.y = 96
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(40.0 if side < 0 else Game.screen_w() - 270.0, 720.0 - 122.0)
	b.button_down.connect(step.bind(side))
	add_child(b)
	return b


# ---------------------------------------------------------------- cards

func _level_card() -> void:
	state = "pilih"
	level_card("TARIK UPIH", tr("Tarik Pau di atas upih pinang sampai ke garisan penamat sebelum Ravi!\n\nLangkah KIRI, KANAN, KIRI, KANAN ikut rentak: tekan ketika penanda berada di bahagian hijau. Terlalu gopoh, upih bergoyang dan Pau tergolek.\n\nTiga pintu soalan: jawab betul dapat pecutan, salah kena lopak lumpur."), _start)


func _reset() -> void:
	me = {"x": 0.0, "v": 0.0, "wobble": 0.0, "side": 0, "since": 0.0, "fallen": 0.0, "boost": 0.0, "mud": 0.0, "steps": 0}
	rival = {"x": 0.0, "fallen": 0.0, "falls": []}
	gates = []
	for g in GATES:
		gates.append({"x": TRACK * g, "state": ""})
	time = 0.0
	right = 0
	_place()


func _start(lv: int) -> void:
	level = clampi(lv, 0, 2)
	close_card()
	_reset()
	rival["falls"] = RIVAL_FALLS[level].duplicate()
	state = "sedia"
	_countdown = 3.0


func _gate(g: Dictionary) -> void:
	state = "soalan"
	question_card(tr("PINTU SOALAN"), tr("Betul! Pecutan!"), tr("Lopak lumpur di depan."), func(ok: bool):
		state = "main"
		g["state"] = "betul" if ok else "salah"
		me["since"] = 0.0
		if ok:
			right += 1
			me["boost"] = BOOST_TIME
			Sfx.play("whoosh")
		else:
			me["mud"] = MUD_TIME
			Sfx.play("squish"))


func _finish(victory: bool) -> void:
	state = "tamat"
	won = victory
	var res := WarisanRules.finish("upih", victory, level, right, time)
	var text := tr("Ravi sampai dulu. Tak apa, cuba lagi: jaga rentak, jangan gopoh.")
	if victory:
		Sfx.play("sparkle")
		MusicDirector.stinger("st_levelup" if res["level_up"] else "st_correct")
		text = tr("Kau dan Pau sampai dulu dalam %.1f saat!%s\n\n+%d EXP   +%d Syiling (%d soalan betul)") % [
			time, (" " + tr("Rekod baharu!")) if res["best"] else "", res["exp"], res["coins"], right]
	result_card(tr("MENANG!") if victory else tr("KALAH!"), text, _level_card)
	print("upih: won=%s level=%d time=%.1f steps=%d right=%d" % [victory, level, time, me["steps"], right])


# ---------------------------------------------------------------- play

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_left"):
		step(-1)
	elif event.is_action_pressed("ui_right"):
		step(1)
	elif event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_A:
			step(-1)
		elif event.physical_keycode == KEY_D:
			step(1)


## one step with the left (-1) or right (1) foot
func step(side: int) -> void:
	if state != "main" or me["fallen"] > 0.0:
		return
	var dt: float = me["since"]
	me["since"] = 0.0
	me["steps"] += 1
	if side == me["side"]:   # the same foot twice: a stumble
		me["v"] *= 0.6
		me["wobble"] += 0.2
		Sfx.play("bump", -8.0)
	else:
		var kind := "ok"
		if me["side"] == 0:
			kind = "ok"                  # the first step
		elif dt < HASTY:
			kind = "gopoh"
		elif dt >= GOOD[0] and dt <= GOOD[1]:
			kind = "tepat"
		elif dt > SLOW:
			kind = "lambat"
		me["side"] = side
		match kind:
			"gopoh":
				me["wobble"] += 0.34
			"tepat":
				me["wobble"] -= 0.12
			"lambat":
				me["wobble"] -= 0.06
			_:
				if dt < GOOD[0] and me["steps"] > 1:
					me["wobble"] += 0.08
		if kind != "gopoh":
			me["v"] = lerpf(me["v"], PACE[kind], 0.4)
		Sfx.play("step_sand" if kind != "tepat" else "tick", -6.0)
		_hud.flash(kind)
	me["wobble"] = maxf(me["wobble"], 0.0)
	if me["wobble"] >= 1.0:
		me["fallen"] = FALL_TIME
		me["v"] = 0.0
		me["wobble"] = 0.0
		me["side"] = 0
		Sfx.play("fall")
		Game.toast(tr("Pau tergolek! Terlalu gopoh."), Color("e0705f"))


func _process(delta: float) -> void:
	_track.queue_redraw()
	_hud.queue_redraw()
	_left.theme_type_variation = "Primary" if state == "main" and me["side"] >= 0 else ""
	_right.theme_type_variation = "Primary" if state == "main" and me["side"] < 0 else ""
	if state == "sedia":
		_countdown -= delta
		_count.text = str(ceili(_countdown)) if _countdown > 0.0 else ""
		if _countdown <= 0.0:
			state = "main"
			Sfx.play("bell")
			Game.toast(tr("MULA!"))
	else:
		_count.text = ""
	if state != "main":
		_place()
		return
	time += delta
	if _auto:
		_auto_in -= delta
		if _auto_in <= 0.0 and me["fallen"] <= 0.0:
			_auto_in = 0.30
			step(1 if me["side"] <= 0 else -1)

	# Alif
	me["since"] += delta
	me["wobble"] = maxf(0.0, me["wobble"] - 0.15 * delta)
	me["boost"] = maxf(0.0, me["boost"] - delta)
	me["mud"] = maxf(0.0, me["mud"] - delta)
	if me["fallen"] > 0.0:
		me["fallen"] -= delta
		me["since"] = 0.0
	else:
		if me["since"] > 0.45:   # no step: the upih drags to a stop
			me["v"] *= exp(-1.8 * delta)
		var k := (1.5 if me["boost"] > 0.0 else 1.0) * (0.55 if me["mud"] > 0.0 else 1.0)
		me["x"] += me["v"] * k * delta

	# the rival: a steady pace, and his rider rolls off where the level says
	if rival["fallen"] > 0.0:
		rival["fallen"] -= delta
	else:
		rival["x"] += RIVAL_SPEED[level] * (1.0 + 0.08 * sin(time * 0.9)) * delta
		if not rival["falls"].is_empty() and rival["x"] >= TRACK * float(rival["falls"][0]):
			rival["falls"].pop_front()
			rival["fallen"] = FALL_TIME
	_place()

	for g in gates:
		if g["state"] == "" and me["x"] >= g["x"]:
			_gate(g)
			return
	_info.text = "%s: %.1f s" % [tr("Masa"), time]
	if me["x"] >= TRACK:
		_finish(true)
	elif rival["x"] >= TRACK:
		_finish(false)


## everything on the track where it belongs; the track scrolls with Alif
func _place() -> void:
	_track.position.x = -clampf(me["x"] - 420.0, -300.0, TRACK - Game.screen_w() + 340.0)
	for i in _crowd.size():   # they hop when a racer goes by
		var near: bool = absf(_crowd[i].position.x - me["x"]) < 260.0 or absf(_crowd[i].position.x - rival["x"]) < 260.0
		_crowd[i].position.y = CROWD_Y - (absf(sin(time * 7.0 + i * 1.3)) * 9.0 if near and state == "main" else 0.0)
	if stage:
		stage.look_at_px(Vector2(me["x"] + 190.0, LANE_RIVAL + 30.0))
		for i in _gates3.size():
			var st: String = gates[i]["state"]
			_gates3[i][0].material_override.albedo_color = {"betul": Color("6fcf6a"), "salah": Color("b08a5a")}.get(st, Color("ffd64d"))
			_gates3[i][1].text = {"betul": "+", "salah": "x"}.get(st, "?")
	var moving: bool = me["v"] > 20.0 and me["fallen"] <= 0.0 and state == "main"
	var fast: bool = me["boost"] > 0.0 and _alif.sprite_frames.has_animation("run_east")
	_pose(_alif, _upih, Vector2(me["x"], LANE_ME), moving, me["fallen"] > 0.0, maxf(me["v"], 60.0) / 150.0, fast)
	var seat: Vector2 = _upih[0].position + Vector2(-34, -2)   # the middle of the scoop
	_pau.position = seat + Vector2(2, 4)
	_pau.rotation = sin(time * 15.0) * 0.45 * float(me["wobble"])
	if me["fallen"] > 0.0:   # on his side on the track, behind the upih
		_pau.position = seat + Vector2(-96, 12)
		_pau.rotation = -PI / 2.0
	var r_moving: bool = rival["fallen"] <= 0.0 and state == "main"
	_pose(_r_puller, _r_upih, Vector2(rival["x"], LANE_RIVAL), r_moving, rival["fallen"] > 0.0, 1.0, false)
	_r_rider.position = _r_upih[0].position + Vector2(-34, 16)
	_r_rider.rotation = 0.0
	if rival["fallen"] > 0.0:
		_r_rider.position = _r_upih[0].position + Vector2(-134, 4)
		_r_rider.rotation = -PI / 2.0


func _pose(puller: AnimatedSprite2D, upih: Array, feet: Vector2, moving: bool, fallen: bool, speed: float, fast: bool) -> void:
	puller.position = feet
	for part in upih:
		part.position = feet + Vector2(-102, -34)   # the tip of the stalk is in the puller's hands
	var anim := "idle_west" if fallen else (("run_east" if fast else "walk_east") if moving else "idle_east")
	if puller.animation != anim:
		puller.play(anim)
	puller.speed_scale = speed if moving else 1.0


## the track: two lanes of packed earth, the lines, the gates, the puddles
class Track extends Node2D:
	var game: Control
	var ground := false   ## HD-2D: only what lies flat, the whole length (the stage stands the rest up)

	var _tex := {}

	func _t(name: String) -> Texture2D:
		if not _tex.has(name):
			_tex[name] = load("res://assets/objects/%s.png" % name)
		return _tex[name]

	func _draw() -> void:
		var x0 := -position.x - 40.0
		var x1 := x0 + Game.screen_w() + 80.0
		if ground:
			x0 = -420.0
			x1 = game.TRACK + 960.0
		else:
			draw_rect(Rect2(x0, 0, x1 - x0, game.SCENE_Y - 6.0), Color("7cc4e8"))             # sky
			draw_rect(Rect2(x0, game.SCENE_Y - 60.0, x1 - x0, 60.0), Color("4d9648"))        # far grass
			# the kampung behind: houses, palms, fruit trees, stalls
			var step := 250.0
			for i in range(int(floorf((x0 - 400.0) / step)), int(x1 / step) + 1):
				var tex := _t(game.SCENERY[posmod(i, game.SCENERY.size())])
				var sz := tex.get_size() * 3.0
				draw_texture_rect(tex, Rect2(Vector2(i * step - sz.x / 2.0, game.SCENE_Y - sz.y), sz), false)
			var fence := _t("pagar")
			for i in range(int(floorf(x0 / 64.0)), int(x1 / 64.0) + 1):
				draw_texture_rect(fence, Rect2(i * 64.0, game.SCENE_Y - 34.0, 64, 64), false)
		for lane in [game.LANE_RIVAL, game.LANE_ME]:
			draw_rect(Rect2(x0, lane - 70, x1 - x0, 100), Color("d9b47a"))
			draw_rect(Rect2(x0, lane - 70, x1 - x0, 5), Color("b98f58"))
			draw_rect(Rect2(x0, lane + 25, x1 - x0, 5), Color("b98f58"))
			for i in range(int(floorf(x0 / 90.0)), int(x1 / 90.0) + 1):   # pebbles and ruts: so the speed shows
				var px := i * 90.0 + fposmod(i * 37.0, 50.0)
				draw_rect(Rect2(px, lane - 50.0 + fposmod(i * 23.0, 60.0), 10, 4), Color("c9a268"))
				draw_rect(Rect2(px + 40.0, lane - 40.0 + fposmod(i * 41.0, 55.0), 5, 3), Color("b98f58"))
		for i in range(int(floorf(x0 / 120.0)), int(x1 / 120.0) + 1):       # tufts between the lanes and in front
			for y in [game.LANE_RIVAL + 48.0, game.LANE_ME + 52.0, 690.0]:
				var gx := i * 120.0 + fposmod(i * 53.0 + y, 100.0)
				draw_line(Vector2(gx, y), Vector2(gx - 5, y - 12), Color("3e7d3c"), 3.0)
				draw_line(Vector2(gx + 4, y), Vector2(gx + 8, y - 10), Color("3e7d3c"), 3.0)
		var font := ThemeDB.fallback_font
		_line(0.0, "MULA", Color.WHITE)
		_line(game.TRACK, "TAMAT", Color("ffd64d"))
		for g in game.gates:
			var gx: float = g["x"]
			var c := Color("ffd64d")
			var mark := "?"
			if g["state"] == "betul":
				c = Color("6fcf6a")
				mark = "+"
			elif g["state"] == "salah":
				c = Color("b08a5a")
				mark = "x"
				_puddle(Vector2(gx + 230.0, game.LANE_ME - 14.0))
				_puddle(Vector2(gx + 420.0, game.LANE_ME - 20.0))
			if ground:
				continue
			var y: float = game.LANE_ME - 158.0
			draw_rect(Rect2(gx - 5, y, 10, 186), Color("3f7a36"))
			draw_rect(Rect2(gx - 46, y - 34, 92, 44), Color("5a381e"))
			draw_rect(Rect2(gx - 42, y - 30, 84, 36), c)
			draw_string(font, Vector2(gx - 42, y - 2), mark, HORIZONTAL_ALIGNMENT_CENTER, 84, 30, Color("2b1c10"))
		_stalk(Vector2(game.rival["x"], game.LANE_RIVAL), game.rival["fallen"] <= 0.0 and game.state == "main")
		_stalk(Vector2(game.me["x"], game.LANE_ME), game.me["v"] > 20.0 and game.me["fallen"] <= 0.0 and game.state == "main")

	## the dust behind an upih on the move
	func _stalk(feet: Vector2, moving: bool) -> void:
		if moving:
			for i in 4:
				var t := fposmod(game.time * 2.2 + i * 0.25, 1.0)
				draw_circle(feet + Vector2(-210.0 - t * 70.0, 2.0 - t * 16.0 - (i % 2) * 6.0), 5.0 + t * 9.0, Color(0.93, 0.85, 0.68, 0.55 * (1.0 - t)))

	func _line(x: float, text: String, c: Color) -> void:
		for lane in [game.LANE_RIVAL, game.LANE_ME]:
			for i in 6:   # chequered
				draw_rect(Rect2(x, lane - 62 + i * 14.5, 10, 14.5), c if i % 2 == 0 else Color("2b1c10"))
				draw_rect(Rect2(x + 10, lane - 62 + i * 14.5, 10, 14.5), Color("2b1c10") if i % 2 == 0 else c)
		draw_string(ThemeDB.fallback_font, Vector2(x - 40, game.LANE_RIVAL - 78), text, HORIZONTAL_ALIGNMENT_CENTER, 100, 24, Color.WHITE)

	func _puddle(at: Vector2) -> void:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(at + Vector2(cos(a) * (74.0 + 8.0 * sin(a * 3.0)), sin(a) * 26.0))
		draw_colored_polygon(pts, Color("6b4a2c"))
		draw_arc(at + Vector2(-14, -4), 16.0, PI * 1.1, PI * 1.7, 8, Color("8a6844"), 3.0)


## over the track: who is where, the Rentak bar, the Goyang bar
class Hud extends Control:
	var game: Control
	var _flash := ""
	var _flash_t := 0.0

	func flash(kind: String) -> void:
		_flash = kind
		_flash_t = 0.5

	func _process(delta: float) -> void:
		_flash_t = maxf(0.0, _flash_t - delta)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x
		var ink := Color(0.1, 0.07, 0.04, 0.78)
		# who is where
		var a := Vector2(w - 560.0, 58.0)
		draw_rect(Rect2(a.x - 20, a.y - 34, 560, 68), ink)
		draw_line(a, a + Vector2(520, 0), Color("f6e8c4"), 4.0)
		for g in game.GATES:
			draw_rect(Rect2(a.x + 520.0 * g - 3, a.y - 9, 6, 18), Color("ffd64d"))
		draw_rect(Rect2(a.x + 514, a.y - 12, 6, 24), Color.WHITE)
		draw_circle(a + Vector2(520.0 * clampf(game.rival["x"] / game.TRACK, 0, 1), -10), 8.0, Color("e0705f"))
		draw_circle(a + Vector2(520.0 * clampf(game.me["x"] / game.TRACK, 0, 1), 10), 8.0, Color("6fb7ff"))
		draw_string(font, a + Vector2(-12, -18), "Ravi", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e0705f"))
		draw_string(font, a + Vector2(-12, 28), "Alif", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6fb7ff"))
		if game.state != "main" and game.state != "sedia":
			return
		# Rentak: the marker runs from the last step; step when it is in the green
		var bw := 440.0
		var b := Vector2((w - bw) / 2.0, size.y - 96.0)
		draw_rect(Rect2(b.x - 14, b.y - 34, bw + 28, 104), ink)
		draw_string(font, b + Vector2(0, -10), tr("RENTAK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f6e8c4"))
		var k: float = bw / game.BAR
		draw_rect(Rect2(b.x, b.y, bw, 26), Color("d9a441"))
		draw_rect(Rect2(b.x, b.y, game.HASTY * k, 26), Color("c8473c"))
		draw_rect(Rect2(b.x + game.GOOD[0] * k, b.y, (game.GOOD[1] - game.GOOD[0]) * k, 26), Color("58b84c"))
		draw_rect(Rect2(b.x + game.SLOW * k, b.y, bw - game.SLOW * k, 26), Color("8a8a8a"))
		var m: float = b.x + clampf(game.me["since"], 0.0, game.BAR) * k
		draw_rect(Rect2(m - 3, b.y - 6, 6, 38), Color.WHITE)
		if _flash_t > 0.0:
			var words := {"tepat": "TEPAT!", "gopoh": "GOPOH!", "lambat": "LAMBAT", "ok": ""}
			var cols := {"tepat": Color("8fe88a"), "gopoh": Color("ff8a7a"), "lambat": Color("cfcfcf"), "ok": Color.WHITE}
			draw_string(font, b + Vector2(0, -10), tr(words[_flash]), HORIZONTAL_ALIGNMENT_RIGHT, bw, 20, cols[_flash])
		# Goyang: full = Pau rolls off
		var gy := b.y + 40.0
		draw_string(font, Vector2(b.x, gy + 16), tr("GOYANG"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6e8c4"))
		draw_rect(Rect2(b.x + 90, gy, bw - 90, 18), Color(1, 1, 1, 0.15))
		var wob: float = clampf(game.me["wobble"], 0.0, 1.0)
		draw_rect(Rect2(b.x + 90, gy, (bw - 90) * wob, 18), Color("58b84c").lerp(Color("e0453a"), wob))
		if game.me["boost"] > 0.0:
			draw_string(font, Vector2(0, size.y - 150.0), tr("PECUTAN!"), HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color("ffd64d"))
		elif game.me["mud"] > 0.0:
			draw_string(font, Vector2(0, size.y - 150.0), tr("LUMPUR..."), HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color("c9a06a"))
