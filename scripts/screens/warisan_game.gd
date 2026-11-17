extends Control
## What the Pesta Warisan games share (galah_panjang.gd, tarik_upih.gd, ...):
## the screen's start, and the paper cards over the game: choose a level, a
## revision question, the result. params: {"level": 0..2} skips the level
## card; {"auto": true} lets a bot play and answer (dev test).
## Input is the game's own actions (Game.DEFAULT_KEYS, PAD_MOVES, PAD_DEFAULT):
## move_* (WASD, arrows, D-pad, left stick, the on-screen D-pad / joystick),
## interact (Space, Enter, E, the pad's A, the on-screen A), run (Shift, the
## pad's X / right trigger, the on-screen B). The screen is "pad_free": a
## controller plays the game itself, and only the cards take its focus ring.

const UI = preload("res://scripts/ui/ui.gd")
const Stage = preload("res://scripts/screens/warisan_stage.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const AnswerMark = preload("res://scripts/ui/answer_mark.gd")
const ControlHint = preload("res://scripts/ui/control_hint.gd")
const LETTERS := ["A", "B", "C", "D"]

var params: Dictionary = {}
var _overlay: Control
var _questions: Array = []
var _grass := Color.BLACK
var _bg: ColorRect
var _touch: CanvasLayer   ## the on-screen D-pad / joystick, in the games that walk or steer
var _auto := false
var stage: Node3D   ## the HD-2D view (warisan_stage.gd) when "Dunia 3D" is on, else null: plain 2D
var _paused := false   ## the Jeda card is open (the game itself is paused)


func setup_game(background: Color) -> void:
	UI.full(self)
	add_to_group("pad_free")
	Game.main.set_pau_visible(false)
	MusicDirector.play("kampung")
	_auto = bool(params.get("auto", false))
	_questions = WarisanRules.questions()
	_grass = background
	# clicks on the playfield are the game's (_unhandled_input): nothing behind it may swallow them
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() is Control:
		(get_parent() as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = ColorRect.new()
	_bg.color = background
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(_bg)
	add_child(_bg)
	var keys := PauseKey.new()   # Esc / Options: the Jeda card, also mid-game
	keys.game = self
	add_child(keys)


func _exit_tree() -> void:
	if _paused:
		get_tree().paused = false


## the controls as pictures (keys, controller or phone buttons), see control_hint.gd
func controls(rows: Array, on_paper := false, one_line := false) -> Control:
	return ControlHint.new(rows, on_paper, one_line)


## the side panel's way out: a button that opens the Jeda card
func exit_button() -> Button:
	var b := UI.button(tr("Jeda / Keluar"))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pause_menu)
	return b


## Jeda: the game stops; Teruskan or back to the fair. Esc / Options / ◯ resume.
func pause_menu() -> void:
	if _paused:
		_resume()
		return
	if _overlay:   # a level, question or result card is up: it has its own buttons
		return
	_paused = true
	var col := card(tr("JEDA"), "")
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var go := UI.button(tr("Teruskan"), "Primary")
	go.pressed.connect(_resume)
	col.add_child(go)
	var out := UI.button(tr("Keluar ke Pesta Warisan"))
	out.pressed.connect(func():
		get_tree().paused = false
		Game.goto("pesta"))
	col.add_child(out)
	_overlay.set_meta("pad_back", go)
	go.grab_focus.call_deferred()
	get_tree().paused = true


func _resume() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	close_card()


## Esc / the pad's Options, heard even while the tree is paused
class PauseKey extends Node:
	var game: Node

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu") and not e.is_echo():
			get_viewport().set_input_as_handled()
			game.pause_menu()


## With "Dunia 3D" on: the play node goes to a 3D stage (see warisan_stage.gd).
## `painter` is a second copy of the play node, for the ground picture; `ground`
## the part of the play node it shows. Returns the stage, or null in 2D.
func make_stage(play: Node2D, painter: Node2D, ground: Rect2) -> Node3D:
	if not Hd2dView.enabled():
		painter.free()
		return null
	_bg.visible = false   # the 3D stage shows through: nothing painted behind the game
	var host_bg := get_parent().get_node_or_null("Background")
	if host_bg:
		host_bg.visible = false
	stage = Stage.new()
	add_child(stage)
	move_child(stage, 0)
	stage.setup(play, painter, ground, _grass)
	return stage


## the on-screen D-pad / joystick of Tetapan > Kawalan (nothing on a laptop left on Automatik)
func add_touch_controls() -> void:
	_touch = TouchControls.new()
	add_child(_touch)


## show them only while the game is being played (not under a card)
func touch_controls_on(on: bool) -> void:
	if _touch:
		_touch.suspended = not on


## a press at this screen position belongs to the on-screen controls, not to the playfield
func on_touch_controls(pos: Vector2) -> bool:
	return _touch != null and _touch.owns(pos)


## which way the player pushes: keys, D-pad, stick, on-screen controls
func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## where the mouse / finger is, in the play node's px
func pointer_on(play: Node2D) -> Vector2:
	return stage.mouse_px() if stage else play.get_local_mouse_position()


## a paper card in the middle of the screen, over everything; returns its column
func card(title: String, text: String) -> VBoxContainer:
	close_card()
	_overlay = Control.new()
	_overlay.add_to_group("pad_scope")   # a controller's focus ring stays on the card
	UI.full(_overlay)
	_overlay.add_child(UI.dim(0.5))
	var p := UI.panel("Paper")
	p.custom_minimum_size = Vector2(640, 0)
	var col := UI.vbox(12)
	col.add_child(UI.label(title, "InkHeading"))
	if text != "":
		var l := UI.label(text, "Ink", true)
		l.custom_minimum_size.x = 600
		col.add_child(l)
	p.add_child(col)
	var c := UI.center(p)
	UI.full(c)
	_overlay.add_child(c)
	add_child(_overlay)
	return col


func close_card() -> void:
	if _paused and _overlay:   # a card that replaces Jeda ends the pause too
		_paused = false
		get_tree().paused = false
	if _overlay:
		_overlay.queue_free()
		_overlay = null


## Mudah / Biasa / Sukar; start.call(level). keys: the controls, as control_hint.gd rows
func level_card(title: String, text: String, start: Callable, keys: Array = []) -> void:
	var col := card(title, text)
	if not keys.is_empty():
		col.add_child(controls(keys, true))
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in WarisanRules.LEVELS.size():
		var b := UI.button(tr(WarisanRules.LEVELS[i]), "Primary" if i == 1 else "", 170)
		b.pressed.connect(start.bind(i))
		row.add_child(b)
		if i == 1:
			b.grab_focus.call_deferred()
	col.add_child(row)
	var out := UI.button(tr("Keluar ke Pesta Warisan"))
	out.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	out.pressed.connect(func(): Game.goto("pesta"))
	col.add_child(out)
	_overlay.set_meta("pad_back", out)


## The next revision question. After the player has read the feedback and
## pressed Teruskan the card closes and done.call(answered_right) runs.
func question_card(title: String, right_text: String, wrong_text: String, done: Callable) -> void:
	if _questions.is_empty():
		done.call(false)
		return
	var q: Dictionary = _questions.pop_front()
	_questions.append(q)
	var col := card(title, str(q["q"]))
	# under the choices once answered: Betul! / Belum tepat, the reason, what it costs
	var feedback := UI.vbox(6)
	feedback.visible = false
	var buttons: Array[Button] = []
	var go := UI.button(tr("Teruskan"), "Primary")
	go.visible = false
	for i in q["options"].size():
		var b := UI.button("%s.  %s" % [LETTERS[i], str(q["options"][i])])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		buttons.append(b)
		col.add_child(b)
		b.pressed.connect(func():
			var right := int(q["answer"])
			var ok: bool = i == right
			AnswerMark.reveal(buttons, right, i)
			var head := UI.label(tr("Betul!") if ok else tr("Belum tepat."), "InkHeading")
			head.add_theme_color_override("font_color", AnswerMark.INK_GREEN if ok else AnswerMark.INK_RED)
			feedback.add_child(head)
			if ok:
				Sfx.play("chime")
				var rest := right_text.trim_prefix(tr("Betul!")).strip_edges()  # the heading says it
				if rest != "":
					feedback.add_child(_ink(rest))
			else:
				Sfx.play("bump", -4.0)
				feedback.add_child(AnswerMark.row(tr("Jawapan betul: %s") % str(q["options"][right]), true, 600))
				if str(q.get("explain", "")) != "":
					feedback.add_child(_ink(str(q["explain"])))
				if wrong_text != "":
					var cost := _ink(wrong_text)
					cost.add_theme_color_override("font_color", AnswerMark.INK_RED)
					feedback.add_child(cost)
			feedback.visible = true
			go.visible = true
			go.grab_focus()
			go.pressed.connect(func():
				close_card()
				done.call(ok), CONNECT_ONE_SHOT))
	col.add_child(feedback)
	col.add_child(go)
	buttons[0].grab_focus.call_deferred()
	if _auto:  # the dev bot answers right and goes on
		await get_tree().create_timer(0.4).timeout
		buttons[int(q["answer"])].pressed.emit()
		await get_tree().create_timer(0.4).timeout
		go.pressed.emit()


func _ink(text: String) -> Label:
	var l := UI.label(text, "Ink", true)
	l.custom_minimum_size.x = 600
	return l


## the end: Main Lagi (again.call()) or back to the fair
func result_card(title: String, text: String, again: Callable) -> void:
	var col := card(title, text)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := UI.button(tr("Main Lagi"), "Primary", 200)
	b.pressed.connect(again)
	row.add_child(b)
	var back := UI.button(tr("Pesta Warisan"), "", 200)
	back.pressed.connect(func(): Game.goto("pesta"))
	row.add_child(back)
	col.add_child(row)
	b.grab_focus.call_deferred()
