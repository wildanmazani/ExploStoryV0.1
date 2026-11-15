extends Control
## What the Pesta Warisan games share (galah_panjang.gd, tarik_upih.gd, ...):
## the screen's start, and the paper cards over the game: choose a level, a
## revision question, the result. params: {"level": 0..2} skips the level
## card; {"auto": true} lets a bot play and answer (dev test).

const UI = preload("res://scripts/ui/ui.gd")
const Stage = preload("res://scripts/screens/warisan_stage.gd")

var params: Dictionary = {}
var _overlay: Control
var _questions: Array = []
var _grass := Color.BLACK
var _bg: ColorRect
var _auto := false
var stage: Node3D   ## the HD-2D view (warisan_stage.gd) when "Dunia 3D" is on, else null: plain 2D


func setup_game(background: Color) -> void:
	UI.full(self)
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


## where the mouse / finger is, in the play node's px
func pointer_on(play: Node2D) -> Vector2:
	return stage.mouse_px() if stage else play.get_local_mouse_position()


## a paper card in the middle of the screen, over everything; returns its column
func card(title: String, text: String) -> VBoxContainer:
	close_card()
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


func close_card() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


## Mudah / Biasa / Sukar; start.call(level)
func level_card(title: String, text: String, start: Callable) -> void:
	var col := card(title, text)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in WarisanRules.LEVELS.size():
		var b := UI.button(tr(WarisanRules.LEVELS[i]), "Primary" if i == 1 else "", 170)
		b.pressed.connect(start.bind(i))
		row.add_child(b)
		if i == 1:
			b.grab_focus.call_deferred()
	col.add_child(row)


## The next revision question. After the player has read the feedback and
## pressed Teruskan the card closes and done.call(answered_right) runs.
func question_card(title: String, right_text: String, wrong_text: String, done: Callable) -> void:
	if _questions.is_empty():
		done.call(false)
		return
	var q: Dictionary = _questions.pop_front()
	_questions.append(q)
	var col := card(title, str(q["q"]))
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
				Sfx.play("chime")
				feedback.text = right_text
			else:
				Sfx.play("bump", -4.0)
				feedback.text = (tr("Belum tepat. Jawapannya: %s. %s") % [str(q["options"][int(q["answer"])]), str(q.get("explain", ""))] + " " + wrong_text).strip_edges()
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
