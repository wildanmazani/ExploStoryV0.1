extends Node
## Controller mode (Tetapan > Kawalan > Controller), a child of Main.
## The buttons themselves are bound in Game (PAD_DEFAULT / PAD_BRAWL), so a
## pad walks and talks in any mode. This adds what menus and quizzes need:
##  - a gold focus ring that glides to the button or card the pad is on
##  - D-pad / stick moves it inside the topmost "scope" only (a modal, a
##    puzzle, a menu screen), never to what is behind it
##  - ✕ picks (also cards that only knew mouse clicks), ◯ goes back
##  - a small bar at the bottom that names the buttons for this moment
## A scope is: any child of Main's overlay layer, any Control in the group
## "pad_scope", or a screen_host screen. Scenes in the group "pad_free"
## (Gelanggang) are played directly. With no scope nothing holds the focus,
## so ✕ talks / jumps and cannot press a hidden button.
## A scope may have: pad_cancel() -> bool (◯; true = handled), pad_first() ->
## Control (where the ring starts), meta "pad_back" (Button that ◯ presses),
## meta "pad_no_cancel". A card may have pad_accept().

const UI = preload("res://scripts/ui/ui.gd")
const GROUP := "pad_scope"
const FREE := "pad_free"
const WALK := "pad_walk"   ## scenes where Alif walks: the bar names the walking buttons
const HOST := "res://scenes/screen_host.tscn"
const DIRS := ["ui_left", "ui_right", "ui_up", "ui_down"]
const HOLD_FIRST := 0.36
const HOLD_NEXT := 0.12

var active := false   ## controller mode is chosen
var using := false    ## the last thing touched was the pad (ring and bar shown)
var _layer: CanvasLayer
var _ring: Ring
var _bar: PanelContainer
var _bar_row: HBoxContainer
var _bar_key := ""
var _bar_age := 0.0
var _scope: Node
var _memory := {}     ## scope id -> the control the ring was on
var _last_center := Vector2(-1, -1)
var _nav_dir := Vector2i.ZERO
var _nav_wait := 0.0
var _device := 0
var _fresh := 0.0     ## a new menu ignores ✕ for a moment: no pick by a button still being mashed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the Gelanggang pause menu too
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	var root := Control.new()
	UI.full(root)
	root.theme = Game.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_ring = Ring.new()
	_ring.pad = self
	UI.full(_ring)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ring)
	_bar = PanelContainer.new()
	var sb := UI.sb(Color(0.08, 0.1, 0.16, 0.9), Color(0.94, 0.76, 0.29, 0.75), 2, 19, 5)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.anti_aliasing = true
	_bar.add_theme_stylebox_override("panel", sb)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.modulate.a = 0.0
	_bar_row = UI.hbox(18)
	_bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_bar_row)
	root.add_child(_bar)
	get_viewport().gui_focus_changed.connect(_on_focus)
	Input.joy_connection_changed.connect(_on_joy)


func _exit_tree() -> void:
	_tex.clear()  # the drawn buttons are not kept past the end of the game


func _on_joy(_id: int, connected: bool) -> void:
	if not connected:
		Game.toast(tr("Controller terputus"), UI.RED)
	elif Game.pad_mode():
		Game.toast(tr("Controller disambung"))
	else:
		Game.toast(tr("Controller dikesan. Pilih Controller di Tetapan > Kawalan."))


func connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


# ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	active = Game.pad_mode()
	_layer.visible = active
	if not active:
		return
	var scope := _find_scope()
	if scope != _scope:
		_scope = scope
		_last_center = Vector2(-1, -1)
		_fresh = 0.3
		_nav_dir = Vector2i(9, 9)  # a held direction does not run on into the new menu
	_fresh = maxf(0.0, _fresh - delta)
	var f := get_viewport().gui_get_focus_owner()
	if _scope == null:
		if f:
			f.release_focus()
	else:
		var list := _focusables(_scope)
		if f == null or not list.has(f):
			var pick := _pick(list)
			if pick:
				pick.grab_focus()
			elif f:
				f.release_focus()
			f = pick
		if f:
			_memory[_scope.get_instance_id()] = f
			_last_center = _rect(f).get_center()
			_navigate(delta, f, list)
		_scroll(delta, f)
	_ring.target = f if using else null
	_update_bar(delta)


func _find_scope() -> Node:
	var m: Node = Game.main
	if m == null:
		return null
	var cands: Array = []
	for n in get_tree().get_nodes_in_group(GROUP):
		if n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
			cands.append(n)
	for c in m.overlay_root().get_children():
		if c is Control and c != m.toast_box and c.visible and not c.is_queued_for_deletion():
			cands.append(c)
	var talking: bool = m.is_dialogue_open()
	var best: Control = null
	var best_layer := -999
	for c in cands:
		var l := _layer_of(c)
		if talking and l < 25:
			continue  # the conversation is on top of it
		if best == null or l > best_layer or (l == best_layer and c.is_greater_than(best)):
			best = c
			best_layer = l
	if best:
		return best
	if talking or not get_tree().get_nodes_in_group(FREE).is_empty():
		return null
	var cs := get_tree().current_scene
	return cs if cs and cs.scene_file_path == HOST else null


func _layer_of(c: Control) -> int:
	var l := c.get_canvas_layer_node()
	return l.layer if l else 0


# ------------------------------------------------------------------ what can be picked
func _focusables(scope: Node) -> Array:
	var out: Array = []
	_collect(scope, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is CanvasLayer and not c.visible:
			continue
		if c is Control and _can_focus(c):
			out.append(c)
		_collect(c, out)


func _native(c: Control) -> bool:
	return c is BaseButton or c is LineEdit or c is Slider or c is TextEdit


func _can_focus(c: Control) -> bool:
	if c.size.x < 4 or c.size.y < 4:
		return false
	if c is BaseButton:
		return c.focus_mode != Control.FOCUS_NONE and not c.disabled
	if c is LineEdit:
		return c.focus_mode != Control.FOCUS_NONE and c.editable
	if c is Slider or c is TextEdit:
		return c.focus_mode != Control.FOCUS_NONE
	# cards and panels that take mouse clicks: the pad may land on them too
	if c.mouse_filter == Control.MOUSE_FILTER_STOP and c.mouse_default_cursor_shape in [Control.CURSOR_POINTING_HAND, Control.CURSOR_DRAG]:
		if c.focus_mode == Control.FOCUS_NONE:
			c.focus_mode = Control.FOCUS_ALL
		return true
	return false


func _rect(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	return Rect2(xf.origin, c.size * xf.get_scale())


func _pick(list: Array) -> Control:
	if list.is_empty():
		return null
	var mem = _memory.get(_scope.get_instance_id())
	if mem != null and is_instance_valid(mem) and list.has(mem):
		return mem
	if _last_center.x >= 0.0:  # what the ring was on is gone: the nearest one
		var best: Control = list[0]
		var bd := INF
		for c in list:
			var d := _rect(c).get_center().distance_squared_to(_last_center)
			if d < bd:
				bd = d
				best = c
		return best
	if _scope.has_method("pad_first"):
		var first = _scope.call("pad_first")
		if first is Control and list.has(first):
			return first
	return list[0]


# ------------------------------------------------------------------ moving the ring
func _navigate(delta: float, f: Control, list: Array) -> void:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := Vector2i.ZERO
	if v.length() >= 0.5:
		dir = Vector2i(int(signf(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, int(signf(v.y)))
	if dir == Vector2i.ZERO:
		_nav_dir = dir
		return
	if _nav_dir == Vector2i(9, 9):
		return  # still held from the menu before: wait for a release
	if dir != _nav_dir:
		_nav_dir = dir
		_nav_wait = HOLD_FIRST
	else:
		_nav_wait -= delta
		if _nav_wait > 0.0:
			return
		_nav_wait = HOLD_NEXT
	if dir.x != 0 and (f is LineEdit or f is Slider or f is TextEdit):
		return  # left / right belongs to the text or the slider
	var n := _neighbour(f, list, dir)
	if n:
		using = true
		n.grab_focus()
		Sfx.play("pop", -16.0, 1.7)
	elif dir.y != 0:  # nothing further that way: a long page scrolls
		var sc := _first_scroll(_scope)
		if sc:
			sc.scroll_vertical += dir.y * 110


## the nearest control in that direction: mostly how far along it, and a
## stiff price for being off to the side
func _neighbour(f: Control, list: Array, dir: Vector2i) -> Control:
	var r := _rect(f)
	var best: Control = null
	var best_score := INF
	for c in list:
		if c == f:
			continue
		var o := _rect(c)
		var along: float
		var side: float
		if dir.x != 0:
			along = (o.get_center().x - r.get_center().x) * dir.x
			side = _gap(r.position.y, r.end.y, o.position.y, o.end.y)
			if along < 4.0 or (dir.x > 0 and o.position.x < r.end.x - 6.0 and side > 0.0) or (dir.x < 0 and o.end.x > r.position.x + 6.0 and side > 0.0):
				continue
		else:
			along = (o.get_center().y - r.get_center().y) * dir.y
			side = _gap(r.position.x, r.end.x, o.position.x, o.end.x)
			if along < 4.0 or (dir.y > 0 and o.position.y < r.end.y - 6.0 and side > 0.0) or (dir.y < 0 and o.end.y > r.position.y + 6.0 and side > 0.0):
				continue
		var off := absf((o.get_center() - r.get_center()).dot(Vector2(absf(dir.y), absf(dir.x))))
		var score := along + side * 3.0 + off * 0.15
		if score < best_score:
			best_score = score
			best = c
	return best


## distance between two ranges on one axis (0 when they overlap)
func _gap(a0: float, a1: float, b0: float, b1: float) -> float:
	return maxf(0.0, maxf(b0 - a1, a0 - b1))


func _on_focus(c: Control) -> void:
	if not active or c == null:
		return
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
			return
		p = p.get_parent()


## right stick: scroll a long page (Nota, Cara Main, the leaderboard)
func _scroll(delta: float, f: Control) -> void:
	var y := Input.get_joy_axis(_device, JOY_AXIS_RIGHT_Y)
	if absf(y) < 0.25:
		return
	var sc: ScrollContainer = null
	var p: Node = f.get_parent() if f else null
	while p and sc == null:
		if p is ScrollContainer:
			sc = p
		p = p.get_parent()
	if sc == null:
		sc = _first_scroll(_scope)
	if sc:
		sc.scroll_vertical += int(y * 900.0 * delta)


func _first_scroll(n: Node) -> ScrollContainer:
	for c in n.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is ScrollContainer and c.get_v_scroll_bar().max_value > c.size.y:
			return c
		var deep := _first_scroll(c)
		if deep:
			return deep
	return null


# ------------------------------------------------------------------ buttons
func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using = true
		_device = event.device
	elif event is InputEventMouseButton or event is InputEventScreenTouch or (event is InputEventMouseMotion and event.relative.length() > 3.0):
		using = false
	if _scope == null:
		return
	var f := get_viewport().gui_get_focus_owner()
	for a in DIRS:
		if event.is_action(a):
			if event is InputEventKey and event.pressed:
				using = true
			var across: bool = a in ["ui_left", "ui_right"]
			if f and across and (f is LineEdit or f is Slider or f is TextEdit):
				return
			get_viewport().set_input_as_handled()  # _navigate moves the ring
			return
	# ✕: Godot's own ui_accept has no pad button, so the press is passed on as
	# one (a Button then looks and sounds pressed like with Enter)
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and f:
		get_viewport().set_input_as_handled()
		if _fresh > 0.0 and event.pressed:
			return
		if f is LineEdit:
			if event.pressed:
				open_keyboard(f)
		elif _native(f):
			var a := InputEventAction.new()
			a.action = "ui_accept"
			a.pressed = event.pressed
			Input.parse_input_event(a)
		elif event.pressed:
			_activate(f)
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if f and not _native(f):
			get_viewport().set_input_as_handled()
			_activate(f)
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		_cancel()


## ✕ on a text box: the on-screen keyboard (ui/pad_keyboard.gd)
func open_keyboard(box: LineEdit) -> Control:
	var k: Control = load("res://scripts/ui/pad_keyboard.gd").new()
	k.target = box
	Sfx.play("select", -8.0)
	Game.main.overlay_root().add_child(k)
	return k


func _activate(f: Control) -> void:
	using = true
	Sfx.play("select", -8.0)
	if f.has_method("pad_accept"):
		f.call("pad_accept")
		return
	for down in [true, false]:  # the same click a mouse would give it
		if not is_instance_valid(f):
			return
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = f.size / 2.0
		e.global_position = _rect(f).get_center()
		if f.has_method("_gui_input"):
			f.call("_gui_input", e)
		f.gui_input.emit(e)


func _cancel() -> void:
	if _scope.has_method("pad_cancel") and _scope.call("pad_cancel"):
		return
	if _scope.has_meta("pad_back"):
		var b = _scope.get_meta("pad_back")
		if b is BaseButton and is_instance_valid(b):
			(b as BaseButton).pressed.emit()
		return
	if _scope.has_meta("pad_no_cancel"):
		return
	var a := InputEventAction.new()  # the same as Esc: modals and menus close
	a.action = "menu"
	a.pressed = true
	Input.parse_input_event(a)


# ------------------------------------------------------------------ the bar
func _update_bar(delta: float) -> void:
	var items: Array = []
	var m: Node = Game.main
	if not using:
		pass
	elif _scope != null:
		if _scope.has_method("pad_hints"):
			items = _scope.call("pad_hints")
		elif _scope.has_meta("pad_no_cancel"):
			items = [["cross", "Pilih"]]
		elif Game.active_puzzle != null and is_instance_valid(Game.active_puzzle):
			items = [["cross", "Pilih"], ["circle", "Batal"], ["triangle", "Petunjuk Pau"]]
		else:
			items = [["cross", "Pilih"], ["circle", "Kembali"]]
	elif m and m.is_dialogue_open():
		items = [["cross", "Teruskan"]]
	elif not Game.is_locked() and not get_tree().get_nodes_in_group(WALK).is_empty():
		items = [["stick", "Jalan"], ["cross", "Cakap"], ["square", "Lari"], ["triangle", "Pau"], ["options", "Menu"], ["touchpad", "Peta"]]
	var key := str(items)
	if key != _bar_key:
		_bar_key = key
		_bar_age = 0.0
		for c in _bar_row.get_children():
			_bar_row.remove_child(c)
			c.queue_free()
		for it in items:
			_bar_row.add_child(hint(str(it[0]), str(it[1])))
		_bar.reset_size()
	_bar_age += delta
	# the walking buttons are only a reminder: they fade after a while
	var want := 0.0 if items.is_empty() or (_scope == null and items.size() > 2 and _bar_age > 7.0) else 1.0
	_bar.modulate.a = move_toward(_bar.modulate.a, want, delta * 5.0)
	_bar.position = Vector2((Game.screen_w() - _bar.size.x) / 2.0, 720.0 - _bar.size.y - 5.0)


# ------------------------------------------------------------------ glyphs
const FACE := {
	"cross": Color("8fb8ff"), "circle": Color("ff8585"), "square": Color("f2a8de"), "triangle": Color("72e2b4"),
	"stick": Color("f6efdc"), "dpad": Color("f6efdc"),
}
const WORDS := {"options": "OPTIONS", "touchpad": "TOUCHPAD", "l1": "L1", "r1": "R1", "r2": "R2", "share": "SHARE"}
static var _tex := {}


## one button and what it does, e.g. (✕) Pilih
static func hint(kind: String, text: String, ink := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph(kind, 28))
	var l := Label.new()
	l.text = TranslationServer.translate(text)
	l.theme_type_variation = "InkSmall" if ink else "Small"
	if not ink:
		l.add_theme_color_override("font_color", UI.CREAM)
	row.add_child(l)
	return row


## the picture of a pad button: a dark disc with its coloured shape, or a
## small plate with its name (OPTIONS, L1...)
static func glyph(kind: String, px: float = 28.0) -> Control:
	if WORDS.has(kind):
		var plate := PanelContainer.new()
		var sb := UI.sb(Color("1a2030"), Color("5a6790"), 2, int(px * 0.32), 1)
		sb.content_margin_left = px * 0.3
		sb.content_margin_right = px * 0.3
		sb.anti_aliasing = true
		plate.add_theme_stylebox_override("panel", sb)
		plate.custom_minimum_size.y = px
		plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = WORDS[kind]
		l.add_theme_font_override("font", load(UI.FONTS["lexend"][1]))
		l.add_theme_font_size_override("font_size", int(px * 0.42))
		l.add_theme_color_override("font_color", UI.CREAM)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plate.add_child(l)
		return plate
	var r := TextureRect.new()
	r.texture = tex(kind)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## drawn once, smooth edges (each pixel is sampled 3 x 3)
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	const N := 56
	const SS := 3
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var bg := Color("1a2030")
	var rim := Color("5a6790")
	var ink: Color = FACE.get(kind, UI.CREAM)
	for y in N:
		for x in N:
			var disc := 0.0
			var edge := 0.0
			var mark := 0.0
			for sy in SS:
				for sx in SS:
					var p := (Vector2(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS) / N) * 2.0 - Vector2.ONE
					var d := p.length()
					if d < 0.97:
						disc += 1.0
						if d > 0.86:
							edge += 1.0
						elif _in_mark(kind, p):
							mark += 1.0
			var n := float(SS * SS)
			if disc > 0.0:
				var col := bg.lerp(rim, edge / disc).lerp(ink, mark / disc)
				col.a = disc / n
				img.set_pixel(x, y, col)
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _in_mark(kind: String, p: Vector2) -> bool:
	match kind:
		"cross":
			var q := p.rotated(PI / 4.0)
			return (absf(q.x) < 0.085 and absf(q.y) < 0.52) or (absf(q.y) < 0.085 and absf(q.x) < 0.52)
		"circle":
			return absf(p.length() - 0.42) < 0.075
		"square":
			var m := maxf(absf(p.x), absf(p.y))
			return m > 0.29 and m < 0.43
		"triangle":
			var a := Vector2(0, -0.5)
			var b := Vector2(0.47, 0.31)
			var c := Vector2(-0.47, 0.31)
			return _seg(p, a, b) < 0.07 or _seg(p, b, c) < 0.07 or _seg(p, c, a) < 0.07
		"stick":
			return p.length() < 0.34 or absf(p.length() - 0.6) < 0.06
		"dpad":
			return (absf(p.x) < 0.17 and absf(p.y) < 0.56) or (absf(p.y) < 0.17 and absf(p.x) < 0.56)
	return false


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0))


# ------------------------------------------------------------------ the ring
## a gold frame that glides from one button to the next and breathes
class Ring extends Control:
	var pad: Node
	var target: Control
	var _r := Rect2()
	var _shown := 0.0
	var _t := 0.0
	var _sb: StyleBoxFlat

	func _init() -> void:
		_sb = StyleBoxFlat.new()
		_sb.draw_center = false
		_sb.set_border_width_all(3)
		_sb.set_corner_radius_all(11)
		_sb.shadow_size = 9
		_sb.anti_aliasing = true

	func _process(delta: float) -> void:
		_t += delta
		var ok := target != null and is_instance_valid(target) and target.is_visible_in_tree()
		if ok:
			var goal: Rect2 = pad._rect(target).grow(5.0)
			if _shown < 0.05:
				_r = goal
			else:
				var k := 1.0 - exp(-24.0 * delta)
				_r = Rect2(_r.position.lerp(goal.position, k), _r.size.lerp(goal.size, k))
		_shown = move_toward(_shown, 1.0 if ok else 0.0, delta * 7.0)
		queue_redraw()

	func _draw() -> void:
		if _shown < 0.02:
			return
		var pulse := 0.5 + 0.5 * sin(_t * 4.2)
		_sb.border_color = Color("f0c24a").lerp(Color("fff1c2"), pulse) * Color(1, 1, 1, _shown)
		_sb.shadow_color = Color(0.96, 0.76, 0.24, (0.28 + 0.3 * pulse) * _shown)
		draw_style_box(_sb, _r.grow(pulse * 1.5))
		# four small gems on the corners
		var g := Color("fff1c2", _shown)
		for c in [_r.position, Vector2(_r.end.x, _r.position.y), _r.end, Vector2(_r.position.x, _r.end.y)]:
			var q: Vector2 = c.lerp(_r.get_center(), 0.02)
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5), q + Vector2(5, 0), q + Vector2(0, 5), q + Vector2(-5, 0)]), g)
			draw_polyline(PackedVector2Array([q + Vector2(0, -5), q + Vector2(5, 0), q + Vector2(0, 5), q + Vector2(-5, 0), q + Vector2(0, -5)]), Color(0.35, 0.22, 0.06, _shown), 1.5, true)


# ------------------------------------------------------------------ Tetapan picture
## the controller, drawn: body, grips, touchpad, sticks, D-pad and the four
## shapes where a thumb finds them
class Diagram extends Control:
	const BODY := Color("2b3450")
	const LINE := Color("c9b27a")
	const DARK := Color("161b2a")

	func _init() -> void:
		custom_minimum_size = Vector2(320, 196)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var o := Vector2((size.x - 320.0) / 2.0, (size.y - 196.0) / 2.0)
		for pass_i in 2:  # outline first, then the fill: one clean edge all round
			var grow := 3.0 if pass_i == 0 else 0.0
			var col := LINE if pass_i == 0 else BODY
			_rr(Rect2(o + Vector2(58, 22), Vector2(62, 22)).grow(grow), 8, col.darkened(0.25) if pass_i == 1 else col)   # L1
			_rr(Rect2(o + Vector2(200, 22), Vector2(62, 22)).grow(grow), 8, col.darkened(0.25) if pass_i == 1 else col)  # R1
			_rr(Rect2(o + Vector2(22, 66), Vector2(84, 118)).grow(grow), 38, col)    # left grip
			_rr(Rect2(o + Vector2(214, 66), Vector2(84, 118)).grow(grow), 38, col)   # right grip
			_rr(Rect2(o + Vector2(34, 34), Vector2(252, 106)).grow(grow), 34, col)   # body
		_rr(Rect2(o + Vector2(116, 40), Vector2(88, 42)), 8, Color("3b4873"))       # touchpad
		_rr(Rect2(o + Vector2(116, 40), Vector2(88, 42)).grow(-3), 6, Color("46558a"))
		for x in [102.0, 210.0]:                                                     # Share, Options
			_rr(Rect2(o + Vector2(x, 44), Vector2(8, 16)), 4, LINE)
		# D-pad
		var d := o + Vector2(76, 78)
		draw_circle(d, 27, DARK)
		draw_rect(Rect2(d - Vector2(7, 21), Vector2(14, 42)), UI.CREAM)
		draw_rect(Rect2(d - Vector2(21, 7), Vector2(42, 14)), UI.CREAM)
		draw_rect(Rect2(d - Vector2(4, 4), Vector2(8, 8)), Color("b8ae94"))
		# the four shapes
		var b := o + Vector2(244, 78)
		draw_circle(b, 31, DARK)
		for k in [["triangle", Vector2(0, -19)], ["circle", Vector2(19, 0)], ["cross", Vector2(0, 19)], ["square", Vector2(-19, 0)]]:
			draw_texture_rect(pad_tex(k[0]), Rect2(b + k[1] - Vector2(11, 11), Vector2(22, 22)), false)
		# sticks
		for c in [o + Vector2(122, 114), o + Vector2(198, 114)]:
			draw_circle(c, 21, DARK)
			draw_circle(c, 15, Color("3b4873"))
			draw_arc(c, 15, 0, TAU, 32, LINE, 2.0, true)
			draw_circle(c, 7, Color("4c5c93"))

	func pad_tex(kind: String) -> Texture2D:
		return load("res://scripts/ui/pad.gd").tex(kind)

	func _rr(r: Rect2, radius: int, col: Color) -> void:
		var s := StyleBoxFlat.new()
		s.bg_color = col
		s.set_corner_radius_all(radius)
		s.anti_aliasing = true
		draw_style_box(s, r)
