extends CanvasLayer
## On-screen controls for phones, picked in Tetapan > Kawalan:
##  - dpad: D-pad + A (act) / B (run)
##  - joystick: a stick that appears where the thumb lands (bottom-left) + A;
##    push it to the edge to run
##  - none ("Ketik sahaja", or Automatik on a laptop): nothing on screen, tap
##    the map to walk (world.gd _tap)
## Everything presses the same input actions as the keyboard, so player.gd
## does not care which one is used. Size, transparency and left-handed
## layout come from the settings too and apply straight away.

const SIZE := 96          ## D-pad arrow size (screen px, 1280x720 space)
const BTN := 112          ## A/B button diameter
const MARGIN := 36
const SCALES := [0.8, 1.0, 1.25]

var mode := ""
var brawl := false       ## Gelanggang: fight buttons instead of A/B
var suspended := false   ## the screen hides the controls (e.g. while answering)
var _built := ""
var _zones: Array[Rect2] = []  ## screen areas the controls own (taps there don't walk)
var _stick: Stick


func _ready() -> void:
	layer = 20
	Game.settings_changed.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	Input.emulate_touch_from_mouse = false
	if _stick:
		_stick.release()


func _process(_delta: float) -> void:
	# out of the way during dialogue, puzzles and menus
	var on := mode != "none" and not suspended and not Game.is_locked() and Game.active_puzzle == null
	if visible != on:
		visible = on
		if not on and _stick:
			_stick.release()


## true when a tap at this screen position belongs to the controls, so the
## world should not also walk there
func owns(pos: Vector2) -> bool:
	if not visible:
		return false
	for r in _zones:
		if r.has_point(pos):
			return true
	return false


# ------------------------------------------------------------------ layout
func _rebuild() -> void:
	var m := Game.touch_mode()
	var s: float = SCALES[clampi(int(Game.settings.get("pad_size", 1)), 0, 2)]
	var alpha := clampf(float(Game.settings.get("pad_alpha", 0.7)), 0.3, 1.0)
	var lefty := bool(Game.settings.get("left_handed", false))
	var key := "%s|%s|%s|%s" % [m, s, alpha, lefty]
	if key == _built:
		return
	_built = key
	mode = m
	if _stick:
		_stick.release()
	_stick = null
	_zones.clear()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	# a laptop that picked D-pad/joystick on purpose: let the mouse drive them
	Input.emulate_touch_from_mouse = m != "none" and not DisplayServer.is_touchscreen_available()
	var pad := SIZE * s
	var btn := BTN * s
	match m:
		"dpad":
			var c := Vector2(MARGIN + pad * 1.5, 720 - MARGIN - pad * 1.5)
			_zones.append(_flip(Rect2(c - Vector2(pad, pad) * 1.5, Vector2(pad, pad) * 3), lefty))
			_add_button("move_up", _arrow_tex(0), c + Vector2(-pad / 2.0, -pad * 1.5), s, alpha, lefty)
			_add_button("move_down", _arrow_tex(2), c + Vector2(-pad / 2.0, pad * 0.5), s, alpha, lefty)
			_add_button("move_left", _arrow_tex(3 if not lefty else 1), c + Vector2(-pad * 1.5, -pad / 2.0), s, alpha, lefty, "move_right" if lefty else "")
			_add_button("move_right", _arrow_tex(1 if not lefty else 3), c + Vector2(pad * 0.5, -pad / 2.0), s, alpha, lefty, "move_left" if lefty else "")
			if not brawl:
				_add_button("interact", _round_tex(Color("e8b04a")), Vector2(1280 - MARGIN - btn, 720 - MARGIN - btn * 1.45), s, alpha, lefty, "", "A")
				_add_button("run", _round_tex(Color("7aa7d9")), Vector2(1280 - MARGIN - btn * 2.1, 720 - MARGIN - btn * 0.9), s, alpha, lefty, "", "B")
		"joystick":
			_stick = Stick.new()
			_stick.radius = 80.0 * s
			_stick.zone = _flip(Rect2(0, 720 * 0.35, 1280 * 0.42, 720 * 0.65), lefty)
			var rest := Vector2(MARGIN + _stick.radius * 1.6, 720 - MARGIN - _stick.radius * 1.6)
			_stick.rest = Vector2(1280 - rest.x, rest.y) if lefty else rest
			_stick.base = _stick.rest
			_stick.modulate.a = alpha
			add_child(_stick)
			_zones.append(_stick.zone)
			if not brawl:
				_add_button("interact", _round_tex(Color("e8b04a")), Vector2(1280 - MARGIN - btn * 1.2, 720 - MARGIN - btn * 1.2), s, alpha, lefty, "", "A")
	if brawl and m != "none":
		_fight_buttons(s, alpha, lefty)


## Gelanggang: Tumbuk (big), Sepak, Lompat, Ambil/Baling, Tangkis, Jurus
func _fight_buttons(s: float, alpha: float, lefty: bool) -> void:
	var d := BTN * s
	var base := Vector2(1280 - MARGIN - d, 720 - MARGIN - d)
	var k := 0.78   # the smaller buttons
	for b in [
		["attack_punch", "Tumbuk", Color("e8b04a"), base, 1.0],
		["attack_kick", "Sepak", Color("e0805a"), base + Vector2(-d * 1.1, d * 0.2), k],
		["jump", "Lompat", Color("7aa7d9"), base + Vector2(d * 0.1, -d * 0.95), k],
		["grab", "Ambil", Color("8ac27a"), base + Vector2(-d * 1.05, -d * 0.8), k],
		["block", "Tangkis", Color("a8b0bc"), base + Vector2(-d * 2.05, d * 0.25), k],
		["special", "Jurus", Color("c9a0ff"), base + Vector2(-d * 2.0, -d * 0.75), k],
	]:
		_add_button(b[0], _round_tex(b[2]), b[3], s * b[4], alpha, lefty, "", tr(b[1]), int(22 / b[4]))


## mirror a rect to the other side of the screen for left-handed players
func _flip(r: Rect2, lefty: bool) -> Rect2:
	if lefty:
		r.position.x = 1280 - r.position.x - r.size.x
	return r


## action_override: left-handed mirrors the pad, so the button on the left side
## must still show and press "left" (and the right one "right")
func _add_button(action: String, tex: Texture2D, pos: Vector2, s: float, alpha: float, lefty: bool, action_override := "", label := "", font_size := 44) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = tex
	b.action = action_override if action_override != "" else action
	b.scale = Vector2(s, s)
	var w := tex.get_size().x * s
	b.position = Vector2(1280 - pos.x - w, pos.y) if lefty else pos
	b.passby_press = true  # slide a thumb across the D-pad without lifting
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	b.modulate = Color(1, 1, 1, alpha)
	add_child(b)
	if label != "":
		_zones.append(Rect2(b.position, tex.get_size() * s))
		var l := Label.new()
		l.text = label
		l.size = tex.get_size()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", Color(0.17, 0.11, 0.06))
		b.add_child(l)


## rounded square with a triangle pointing up/right/down/left (0..3)
static func _arrow_tex(dir: int) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var bg := Color(0.12, 0.08, 0.05, 0.55)
	var fg := Color(1, 0.95, 0.8, 0.95)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y) - Vector2(SIZE, SIZE) / 2.0
			if absf(p.x) < SIZE * 0.46 and absf(p.y) < SIZE * 0.46:
				img.set_pixel(x, y, bg)
			var q := p.rotated(-dir * PI / 2.0)  # draw an "up" triangle in rotated space
			if q.y > -SIZE * 0.22 and q.y < SIZE * 0.14 and absf(q.x) < (q.y + SIZE * 0.22) * 0.75:
				img.set_pixel(x, y, fg)
	return ImageTexture.create_from_image(img)


static func _round_tex(color: Color) -> Texture2D:
	var img := Image.create(BTN, BTN, false, Image.FORMAT_RGBA8)
	var r := BTN / 2.0
	for y in BTN:
		for x in BTN:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r))
			if d < r - 1:
				img.set_pixel(x, y, color.darkened(0.25) if d > r - 7 else color)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ joystick
## Floating stick: waits faintly at its rest spot, jumps to wherever the thumb
## lands inside its zone and follows the thumb if it slides too far. The
## strongest axis presses one of the four move actions (the world is a grid);
## pushing to the rim also presses "run".
class Stick extends Node2D:
	const DEAD := 0.3
	const RUN := 0.85
	const MOVES := ["move_up", "move_right", "move_down", "move_left"]

	var radius := 80.0
	var zone := Rect2()
	var rest := Vector2.ZERO
	var base := Vector2.ZERO
	var knob := Vector2.ZERO   ## thumb offset from base
	var touch := -1            ## finger index holding the stick, -1 = none
	var _held := {}            ## action -> pressed by us
	var _dir := ""

	func _input(e: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if e is InputEventScreenTouch:
			if e.pressed and touch < 0 and zone.has_point(e.position):
				touch = e.index
				base = e.position
				_move(e.position)
				get_viewport().set_input_as_handled()
			elif not e.pressed and e.index == touch:
				release()
				get_viewport().set_input_as_handled()
		elif e is InputEventScreenDrag and e.index == touch:
			_move(e.position)
			get_viewport().set_input_as_handled()

	func _move(pos: Vector2) -> void:
		var v := pos - base
		if v.length() > radius:
			base = pos - v.normalized() * radius
			v = pos - base
		knob = v
		var n := v / radius
		var want := ""
		if n.length() >= DEAD:
			# a little stickiness near the diagonals so the direction doesn't flicker
			var horiz := absf(n.x) > absf(n.y)
			if _dir in ["move_left", "move_right"]:
				horiz = absf(n.x) * 1.25 > absf(n.y)
			elif _dir in ["move_up", "move_down"]:
				horiz = absf(n.x) > absf(n.y) * 1.25
			if horiz:
				want = "move_right" if n.x > 0 else "move_left"
			else:
				want = "move_down" if n.y > 0 else "move_up"
		_apply(want, n.length() >= RUN)
		queue_redraw()

	func release() -> void:
		touch = -1
		knob = Vector2.ZERO
		base = rest
		_apply("", false)
		queue_redraw()

	func _apply(dir: String, run: bool) -> void:
		_dir = dir
		for a in MOVES + ["run"]:
			var on: bool = a == dir or (a == "run" and run and dir != "")
			if on != bool(_held.get(a, false)):
				_held[a] = on
				if on:
					Input.action_press(a)
				else:
					Input.action_release(a)

	func _draw() -> void:
		var active := touch >= 0
		draw_circle(base, radius, Color(0.12, 0.08, 0.05, 0.45 if active else 0.3))
		draw_arc(base, radius, 0, TAU, 48, Color(1, 0.95, 0.8, 0.8 if active else 0.45), 3.0, true)
		for i in 4:  # little arrows on the rim
			var d := Vector2.UP.rotated(i * PI / 2.0)
			var tip := base + d * (radius - 10)
			var side := d.orthogonal() * 9
			draw_colored_polygon(PackedVector2Array([tip, tip - d * 14 + side, tip - d * 14 - side]), Color(1, 0.95, 0.8, 0.55))
		var k := base + knob
		draw_circle(k, radius * 0.45, Color("e8b04a") if active else Color(0.9, 0.85, 0.7, 0.7))
		draw_arc(k, radius * 0.45, 0, TAU, 32, Color(0.17, 0.11, 0.06, 0.8), 3.0, true)
