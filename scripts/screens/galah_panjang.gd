extends Control
## Galah Panjang (Pesta Warisan). Alif starts at the bottom of the court,
## must get past four lines, each guarded by a classmate who may only run
## along that line, reach the far end (PERGI) and come all the way back
## (BALIK). A guard who touches him on the line costs one of three lives and
## sends him back to the last box he stood in.
## Jurus Ingatan (Q, three per game): a revision question; answer right and the
## next guard on the way stands frozen for a few seconds. A wrong answer costs
## nothing: history gives the edge, the feet win the game.
## Keys: WASD / arrows (or hold the mouse / a finger where Alif should go).
## params: {"level": 0..2} skips the level card; {"auto": true} lets a bot play (dev test).

const UI = preload("res://scripts/ui/ui.gd")
const W := 440.0          ## court, in screen px
const GAP := 104.0        ## between two lines
const H := GAP * 5.0
const LINES := 4
const SPEED := 170.0
const GUARD_SPEED := [80.0, 105.0, 130.0]   ## by level
const GUARD_REACT := [0.40, 0.26, 0.14]     ## seconds between two looks at Alif
const FREEZE := [5.0, 4.0, 3.5]
const REACH := 30.0       ## how far along the line a guard's arms go
const ON_LINE := 16.0     ## how near the line counts as crossing it
const GUARDS := ["rakan_aisyah", "rakan_ravi", "rakan_meiling", "rakan_daniel"]
const LIVES := 3
const JURUS := 3

var params: Dictionary = {}
var level := 1
var state := "pilih"      ## pilih (level card), main, soalan, tamat
var phase := "pergi"      ## pergi, balik
var pos := Vector2(W / 2.0, H - GAP / 2.0)
var guards: Array = []    ## {y, x, tx, look, frozen, sprite}
var lives := LIVES
var jurus := JURUS
var right := 0
var time := 0.0
var won := false

var _court: Node2D
var _alif: AnimatedSprite2D
var _facing := "north"
var _safe_y := H - GAP / 2.0   ## middle of the last box Alif stood in
var _shield := 0.0             ## seconds he cannot be caught (just sent back)
var _questions: Array = []
var _pointer := false
var _info: Label
var _hearts: HBoxContainer
var _jurus_btn: Button
var _overlay: Control
var _auto := false
var _auto_wait := 0.0


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("kampung")
	_auto = bool(params.get("auto", false))
	_questions = WarisanRules.questions()
	var bg := ColorRect.new()
	bg.color = Color("4f9a4a")
	UI.full(bg)
	add_child(bg)

	_court = Court.new()
	_court.game = self
	_court.y_sort_enabled = true  # whoever stands lower on the court is in front (no z_index: it would rise above the cards)
	_court.position = Vector2(maxf(360.0, (Game.screen_w() - W) / 2.0), 110.0)
	add_child(_court)
	for i in LINES:
		var s := _sprite(GUARDS[i])
		var g := {"y": GAP * (i + 1), "x": W / 2.0, "tx": W / 2.0, "look": 0.0, "frozen": 0.0, "sprite": s}
		s.play("idle_south")
		guards.append(g)
	_alif = _sprite(Game.skin_folder())
	_alif.play("idle_north")

	var side := UI.panel()
	side.position = Vector2(24, 110)
	side.custom_minimum_size = Vector2(300, 0)
	var col := UI.vbox(10)
	col.add_child(UI.label("GALAH PANJANG", "Heading"))
	_info = UI.label("", "", true)
	_info.custom_minimum_size.x = 270
	col.add_child(_info)
	_hearts = UI.hbox(6)
	col.add_child(_hearts)
	_jurus_btn = UI.button("", "Blue")
	_jurus_btn.pressed.connect(ask_question)
	col.add_child(_jurus_btn)
	var tip := UI.label(tr("Gerak: WASD / anak panah, atau tahan tetikus / jari. Penjaga hanya bergerak di atas garisan."), "Small", true)
	tip.custom_minimum_size.x = 270
	col.add_child(tip)
	var out := UI.button("« Keluar")
	out.pressed.connect(func(): Game.goto("pesta"))
	col.add_child(out)
	side.add_child(col)
	add_child(side)
	_refresh_hud()
	if params.has("level"):
		_start(int(params["level"]))
	else:
		_level_card()


func _sprite(folder: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = CharacterFrames.build(folder, true)
	s.offset = CharacterFrames.feet_offset(folder)
	s.scale = Vector2(2, 2)
	_court.add_child(s)
	return s


# ---------------------------------------------------------------- cards

func _card(title: String, text: String) -> VBoxContainer:
	if _overlay:
		_overlay.queue_free()
	_overlay = Control.new()
	UI.full(_overlay)
	_overlay.add_child(UI.dim(0.5))
	var p := UI.panel("Paper")
	p.custom_minimum_size = Vector2(640, 0)
	var col := UI.vbox(12)
	col.add_child(UI.label(title, "InkHeading"))
	var l := UI.label(text, "Ink", true)
	l.custom_minimum_size.x = 600
	col.add_child(l)
	p.add_child(col)
	var c := UI.center(p)
	UI.full(c)
	_overlay.add_child(c)
	add_child(_overlay)
	return col


func _level_card() -> void:
	state = "pilih"
	var col := _card("GALAH PANJANG", tr("Lepasi empat garisan, sampai ke hujung, kemudian balik ke tempat mula. Penjaga hanya boleh berlari di atas garisan mereka: tunggu mereka jauh, kemudian lintas!\n\nJurus Ingatan (Q): jawab soalan Sejarah dengan betul dan penjaga di depan terpaku seketika."))
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in WarisanRules.LEVELS.size():
		var b := UI.button(tr(WarisanRules.LEVELS[i]), "Primary" if i == 1 else "", 170)
		b.pressed.connect(_start.bind(i))
		row.add_child(b)
		if i == 1:
			b.grab_focus.call_deferred()
	col.add_child(row)


func _start(lv: int) -> void:
	level = clampi(lv, 0, 2)
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	pos = Vector2(W / 2.0, H - GAP / 2.0)
	_safe_y = pos.y
	phase = "pergi"
	lives = LIVES
	jurus = JURUS
	right = 0
	time = 0.0
	_shield = 1.0
	for g in guards:
		g["x"] = W / 2.0
		g["frozen"] = 0.0
	state = "main"
	_refresh_hud()


func ask_question() -> void:
	if state != "main" or jurus <= 0 or _questions.is_empty():
		return
	jurus -= 1
	state = "soalan"
	_pointer = false
	var q: Dictionary = _questions.pop_front()
	_questions.append(q)
	var col := _card(tr("JURUS INGATAN"), str(q["q"]))
	var feedback := UI.label("", "Ink", true)
	feedback.custom_minimum_size.x = 600
	var buttons: Array[Button] = []
	var go := UI.button(tr("Teruskan"), "Primary")
	go.visible = false
	for i in q["options"].size():
		var b := UI.button(str(q["options"][i]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		buttons.append(b)
		col.add_child(b)
		b.pressed.connect(func():
			var ok: bool = i == int(q["answer"])
			for other in buttons:
				other.disabled = true
			if ok:
				right += 1
				Sfx.play("chime")
				feedback.text = tr("Betul! Penjaga di depan terpaku.")
			else:
				Sfx.play("bump", -4.0)
				feedback.text = tr("Belum tepat. Jawapannya: %s. %s") % [str(q["options"][int(q["answer"])]), str(q.get("explain", ""))]
			go.visible = true
			go.grab_focus()
			go.pressed.connect(func():
				_overlay.queue_free()
				_overlay = null
				state = "main"
				if ok:
					_freeze_next()
				_refresh_hud(), CONNECT_ONE_SHOT))
	col.add_child(feedback)
	col.add_child(go)
	buttons[0].grab_focus.call_deferred()
	_refresh_hud()
	if _auto:  # the dev bot answers (right, mostly) and goes on
		await get_tree().create_timer(0.4).timeout
		buttons[int(q["answer"])].pressed.emit()
		await get_tree().create_timer(0.4).timeout
		go.pressed.emit()


## the guard Alif meets next on his way stands still for a while
func _freeze_next() -> void:
	var best: Dictionary = {}
	for g in guards:
		var ahead: bool = g["y"] < pos.y if phase == "pergi" else g["y"] > pos.y
		if ahead and (best.is_empty() or absf(g["y"] - pos.y) < absf(best["y"] - pos.y)):
			best = g
	if not best.is_empty():
		best["frozen"] = FREEZE[level]


func _finish(victory: bool) -> void:
	state = "tamat"
	won = victory
	_pointer = false
	var res := WarisanRules.finish("galah", victory, level, right, time)
	var text := tr("Kau tertangkap tiga kali. Tak apa, cuba lagi: tiada penalti.")
	if victory:
		Sfx.play("sparkle")
		MusicDirector.stinger("st_levelup" if res["level_up"] else "st_correct")
		text = tr("Kau sampai ke hujung dan balik dalam %.1f saat!%s\n\n+%d EXP   +%d Syiling (%d soalan betul)") % [
			time, (" " + tr("Rekod baharu!")) if res["best"] else "", res["exp"], res["coins"], right]
	var col := _card(tr("MENANG!") if victory else tr("TERTANGKAP!"), text)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UI.button(tr("Main Lagi"), "Primary", 200)
	again.pressed.connect(_level_card)
	row.add_child(again)
	var back := UI.button(tr("Pesta Warisan"), "", 200)
	back.pressed.connect(func(): Game.goto("pesta"))
	row.add_child(back)
	col.add_child(row)
	again.grab_focus.call_deferred()
	print("galah: won=%s level=%d time=%.1f lives=%d right=%d" % [victory, level, time, lives, right])


# ---------------------------------------------------------------- play

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.pressed and state == "main"
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		ask_question()


func _move_input() -> Vector2:
	if _auto:
		return _auto_input()
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1.0
	if v == Vector2.ZERO and _pointer:
		var to := _court.get_local_mouse_position() - pos
		if to.length() > 6.0:
			v = to
	return v.limit_length(1.0) if v.length() > 1.0 else v


func _process(delta: float) -> void:
	_court.queue_redraw()
	if state != "main":
		_animate(Vector2.ZERO)
		return
	time += delta
	_shield = maxf(0.0, _shield - delta)
	var v := _move_input()
	pos += v * SPEED * delta
	pos.x = clampf(pos.x, 16.0, W - 16.0)
	pos.y = clampf(pos.y, 18.0, H - 10.0)
	_animate(v)

	for i in guards.size():
		var g: Dictionary = guards[i]
		var s: AnimatedSprite2D = g["sprite"]
		if g["frozen"] > 0.0:
			g["frozen"] -= delta
			s.play("idle_south")
			s.modulate = Color(0.6, 0.85, 1.0)
		else:
			s.modulate = Color.WHITE
			g["look"] -= delta
			if g["look"] <= 0.0:
				g["look"] = GUARD_REACT[level]
				if absf(pos.y - g["y"]) < GAP * 1.15:   # Alif is in a box next to this line
					g["tx"] = pos.x
				else:                                    # nobody near: stroll
					g["tx"] = W / 2.0 + sin(time * 0.8 + i * 1.7) * W * 0.32
			var dx: float = clampf(g["tx"] - g["x"], -GUARD_SPEED[level] * delta, GUARD_SPEED[level] * delta)
			g["x"] = clampf(g["x"] + dx, 20.0, W - 20.0)
			var anim := "idle_south" if absf(dx) < 0.05 else ("walk_east" if dx > 0.0 else "walk_west")
			if s.animation != anim:
				s.play(anim)
			if _shield <= 0.0 and absf(pos.y - g["y"]) < ON_LINE and absf(pos.x - g["x"]) < REACH:
				_caught()
				return
		s.position = Vector2(g["x"], g["y"])

	if absf(fmod(pos.y, GAP) - GAP / 2.0) < GAP / 2.0 - 26.0:   # well inside a box: it is the safe one now
		_safe_y = (floorf(pos.y / GAP) + 0.5) * GAP
	if phase == "pergi" and pos.y < GAP - 26.0:
		phase = "balik"
		Sfx.play("chime")
		Game.toast(tr("Sampai hujung! Sekarang BALIK."))
	elif phase == "balik" and pos.y > GAP * LINES + 26.0:
		_finish(true)
	_refresh_hud()


func _animate(v: Vector2) -> void:
	if v.length() > 0.1:
		_facing = ("east" if v.x > 0.0 else "west") if absf(v.x) > absf(v.y) else ("south" if v.y > 0.0 else "north")
	var anim := ("walk_" if v.length() > 0.1 else "idle_") + _facing
	if _alif.animation != anim:
		_alif.play(anim)
	_alif.position = pos
	_alif.modulate.a = 0.45 if _shield > 0.0 and fmod(_shield, 0.2) < 0.1 else 1.0


func _caught() -> void:
	lives -= 1
	Sfx.play("bump")
	Game.toast(tr("Kena tangkap! Balik ke petak tadi."), Color("e0705f"))
	pos = Vector2(W / 2.0, _safe_y)
	_shield = 1.4
	_refresh_hud()
	if lives <= 0:
		_finish(false)


func _refresh_hud() -> void:
	_info.text = "%s\n%s: %.1f s" % [tr("PERGI ke hujung") if phase == "pergi" else tr("BALIK ke tempat mula"), tr("Masa"), time]
	while _hearts.get_child_count() > maxi(lives, 0):
		var h := _hearts.get_child(0)
		_hearts.remove_child(h)
		h.queue_free()
	while _hearts.get_child_count() < lives:
		var h := TextureRect.new()
		h.texture = load("res://assets/warisan/hati.png")
		h.custom_minimum_size = Vector2(36, 33)
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hearts.add_child(h)
	_jurus_btn.text = tr("Jurus Ingatan (Q)  x%d") % jurus
	_jurus_btn.disabled = jurus <= 0 or state != "main"


## dev bot: waits in the middle of a box until the next guard is far to one
## side (or frozen), then runs across on the other side
func _auto_input() -> Vector2:
	var dir := -1.0 if phase == "pergi" else 1.0
	var next: Dictionary = {}
	for g in guards:
		var ahead: bool = g["y"] < pos.y - 4.0 if dir < 0.0 else g["y"] > pos.y + 4.0
		if ahead and (next.is_empty() or absf(g["y"] - pos.y) < absf(next["y"] - pos.y)):
			next = g
	if next.is_empty() or absf(next["y"] - pos.y) > GAP * 0.62:
		return Vector2(0, dir)               # nothing close: walk on
	if absf(next["y"] - pos.y) < ON_LINE + 14.0:
		return Vector2(0, dir)               # already crossing: keep going
	if next["frozen"] > 1.0 or absf(next["x"] - pos.x) > 150.0:
		return Vector2(0, dir)               # the gap is open: go
	_auto_wait += get_process_delta_time()
	if _auto_wait > 6.0 and jurus > 0:       # stuck: use a Jurus Ingatan
		_auto_wait = 0.0
		ask_question.call_deferred()
	# draw the guard to one side, then double back
	var away := 1.0 if fmod(time, 5.0) < 2.5 else -1.0
	return Vector2(away, 0)


## the court: packed earth, bamboo lines, and what each guard can reach
class Court extends Node2D:
	var game: Control

	func _draw() -> void:
		var w: float = game.W
		var h: float = game.H
		draw_rect(Rect2(-14, -14, w + 28, h + 28), Color("3e7d3c"))
		draw_rect(Rect2(0, 0, w, h), Color("d9b47a"))
		draw_rect(Rect2(0, 0, w, game.GAP), Color("e6c88e"))            # HUJUNG
		draw_rect(Rect2(0, h - game.GAP, w, game.GAP), Color("e6c88e"))  # MULA
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(10, 26), "HUJUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.22, 0.1, 0.6))
		draw_string(font, Vector2(10, h - 12), "MULA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.22, 0.1, 0.6))
		draw_rect(Rect2(0, 0, w, h), Color("5a381e"), false, 4.0)
		for g in game.guards:
			var y: float = g["y"]
			draw_line(Vector2(0, y), Vector2(w, y), Color("3f7a36"), 8.0)       # the galah (bamboo)
			draw_line(Vector2(0, y - 2), Vector2(w, y - 2), Color("7cc15c"), 2.0)
			for x in range(40, int(w), 80):
				draw_rect(Rect2(x - 2, y - 4, 4, 8), Color("2f5d2a"))
			var frozen: bool = g["frozen"] > 0.0
			var c := Color(0.5, 0.8, 1.0, 0.35) if frozen else Color(0.8, 0.2, 0.15, 0.22)
			draw_rect(Rect2(g["x"] - game.REACH, y - game.ON_LINE, game.REACH * 2.0, game.ON_LINE * 2.0), c)
