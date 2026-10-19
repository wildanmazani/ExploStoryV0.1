extends "res://scripts/puzzles/puzzle_base.gd"
## Soalan objektif: one question at a time, four answers (A-D), one correct.
## A wrong answer just greys out and the player tries again (no timer, no
## penalty). After the right answer a short explanation shows the why.
## Pau's hints: 1 = nudge, 2 and 3 = remove one wrong answer.
##
## def: {"type": "objektif", "title", "instruction", "hint", "done_text",
##       "questions": [{"q", "options": [4 strings], "answer": index, "explain", "hint"}]}

const LETTERS := ["A", "B", "C", "D"]

var questions: Array = []
var qi: int = 0
var _buttons: Array[Button] = []
var _wrong_here: bool = false
var _q_label: Label
var _count: Label
var _next: Button
var _answered: bool = false


func _build_puzzle() -> void:
	questions = def.get("questions", [])
	stats["total"] = questions.size()
	var top := UI.hbox(10)
	_count = UI.label("", "Small")
	top.add_child(_count)
	body.add_child(top)
	var qp := UI.panel("Paper")
	var qrow := UI.hbox(10)
	_q_label = UI.label("", "InkHeading", true)
	_q_label.custom_minimum_size.x = 1040
	_q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_q_label)
	var sp := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(60, 52))
	sp.tooltip_text = "Baca soalan"
	sp.pressed.connect(func(): Tts.speak(_q_text()))
	qrow.add_child(sp)
	qp.add_child(qrow)
	body.add_child(qp)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 4:
		var b := UI.button("")
		b.custom_minimum_size = Vector2(570, 92)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_pick.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	body.add_child(grid)
	_next = UI.button("Soalan seterusnya »", "Primary", 280)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.visible = false
	_next.pressed.connect(_advance)
	body.add_child(_next)
	_show_question()


func _q() -> Dictionary:
	return questions[qi]


func _q_text() -> String:
	var t := str(_q()["q"])
	var opts: Array = _q()["options"]
	for i in opts.size():
		t += ". %s, %s" % [LETTERS[i], opts[i]]
	return t


func _show_question() -> void:
	_answered = false
	_wrong_here = false
	hint_presses = 0
	_next.visible = false
	_count.text = tr("Soalan %d / %d") % [qi + 1, questions.size()]
	_q_label.text = str(_q()["q"])
	var opts: Array = _q()["options"]
	for i in _buttons.size():
		var b := _buttons[i]
		b.visible = i < opts.size()
		if b.visible:
			b.text = "%s.  %s" % [LETTERS[i], opts[i]]
			b.disabled = false
			b.theme_type_variation = ""
			b.modulate = Color.WHITE
	say_try("Pilih satu jawapan. Tiada had masa.")
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(_q_text())


func _pick(i: int) -> void:
	if _answered:
		return
	if i == int(_q()["answer"]):
		_answered = true
		if not _wrong_here:
			stats["first_try"] = int(stats["first_try"]) + 1
		_buttons[i].theme_type_variation = "Primary"
		for j in _buttons.size():
			if j != i:
				_buttons[j].disabled = true
		Sfx.play("chime", -6.0)
		MusicDirector.stinger("st_correct")
		pulse(_buttons[i])
		say_good(tr("Betul! ") + str(_q().get("explain", "")))
		if qi + 1 < questions.size():
			_next.visible = true
			_next.grab_focus()
		else:
			await get_tree().create_timer(1.6).timeout
			finish(str(def.get("done_text", "")))
	else:
		_wrong_here = true
		stats["retries"] = int(stats["retries"]) + 1
		_buttons[i].disabled = true
		_buttons[i].modulate = Color(1, 1, 1, 0.5)
		shake(_buttons[i])
		Sfx.play("bump", -4.0)
		say_try(["Hampir! Cuba jawapan lain.", "Belum tepat. Baca soalan sekali lagi.", "Tak apa, cuba lagi."].pick_random())


func _advance() -> void:
	qi += 1
	Sfx.play("select")
	_show_question()


func _hint(tier: int) -> void:
	if _answered:
		Game.main.pau_say("Dah betul! Tekan Soalan seterusnya.")
		return
	if tier == 1:
		Game.main.pau_say(str(_q().get("hint", def.get("hint", "Baca soalan perlahan-lahan. Cari kata kunci."))))
		return
	# remove one wrong answer that is still on screen
	for i in _buttons.size():
		if i != int(_q()["answer"]) and _buttons[i].visible and not _buttons[i].disabled:
			_buttons[i].disabled = true
			_buttons[i].modulate = Color(1, 1, 1, 0.35)
			Game.main.pau_say(tr("Aku buang satu jawapan yang salah: %s.") % LETTERS[i])
			return
	Game.main.pau_say("Tinggal satu je lagi. Kau boleh!")
