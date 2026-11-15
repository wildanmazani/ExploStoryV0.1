extends Control
## What the Pesta Warisan games share (galah_panjang.gd, tarik_upih.gd, ...):
## the screen's start, and the paper cards over the game: choose a level, a
## revision question, the result. params: {"level": 0..2} skips the level
## card; {"auto": true} lets a bot play and answer (dev test).

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _overlay: Control
var _questions: Array = []
var _auto := false


func setup_game(background: Color) -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("kampung")
	_auto = bool(params.get("auto", false))
	_questions = WarisanRules.questions()
	var bg := ColorRect.new()
	bg.color = background
	UI.full(bg)
	add_child(bg)


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
