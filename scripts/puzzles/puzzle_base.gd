extends Control
## Shared frame for both puzzle engines: header with title, instruction and
## read-aloud, feedback line, Pau's 3-level hints, and the finish card.
## No timer, no penalty: wrong answers just return the card.

const UI = preload("res://scripts/ui/ui.gd")

signal completed(stats: Dictionary)

var def: Dictionary = {}
var puzzle_id: String = ""
var stats := {"total": 0, "first_try": 0, "retries": 0, "hints": 0}
var hint_presses: int = 0
var body: VBoxContainer
var feedback: Label
var _feedback_panel: PanelContainer
var _frame: PanelContainer
var _finished: bool = false


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.dim(0.72))
	_frame = UI.panel()
	_frame.position = Vector2(30, 24)
	_frame.size = Vector2(1220, 672)
	_frame.custom_minimum_size = Vector2(1220, 672)
	add_child(_frame)
	var col := UI.vbox(10)
	_frame.add_child(col)
	var head := UI.hbox(12)
	var tcol := UI.vbox(2)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_child(UI.label(str(def.get("title", "")), "Heading"))
	var ins := UI.label(str(def.get("instruction", "")), "", true)
	ins.custom_minimum_size.x = 900
	tcol.add_child(ins)
	head.add_child(tcol)
	var speak := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(64, 56))
	speak.tooltip_text = "Baca arahan"
	speak.pressed.connect(func(): Tts.speak(str(def.get("instruction", ""))))
	head.add_child(speak)
	col.add_child(head)
	body = UI.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_feedback_panel = UI.panel("Paper")
	_feedback_panel.add_theme_stylebox_override("panel", UI.sb(UI.CREAM, UI.WOOD, 3, 6, 8))
	feedback = UI.label("Tiada had masa. Cuba seberapa banyak kali yang kau mahu.", "Ink", true)
	feedback.custom_minimum_size.x = 1100
	_feedback_panel.add_child(feedback)
	col.add_child(_feedback_panel)
	_build_puzzle()
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(str(def.get("instruction", "")))


func _build_puzzle() -> void:
	pass


func say_good(text: String) -> void:
	feedback.text = text
	_feedback_panel.add_theme_stylebox_override("panel", UI.sb(Color("dff0d4"), UI.GREEN_D, 3, 6, 8))
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(text)


func say_try(text: String) -> void:
	feedback.text = text
	_feedback_panel.add_theme_stylebox_override("panel", UI.sb(Color("fff0d8"), Color("c08a30"), 3, 6, 8))


func show_pau_hint(text: String) -> void:
	feedback.text = "Pau: " + text
	_feedback_panel.add_theme_stylebox_override("panel", UI.sb(Color("e4f0fb"), UI.BLUE, 3, 6, 8))
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(text)


func request_hint() -> void:
	if _finished:
		Game.main.pau_say("Dah siap! Ketik Teruskan.")
		return
	hint_presses += 1
	var tier := mini(hint_presses, 3)
	stats["hints"] = int(stats["hints"]) + 1
	Game.log_hint(puzzle_id, tier)
	_hint(tier)


## Override: tier 1 = general nudge, 2 = highlight, 3 = show one connection.
func _hint(tier: int) -> void:
	Game.main.pau_say(str(def.get("hint", "Cuba tengok artifak yang bercahaya tu.")))


func pulse(c: CanvasItem) -> void:
	var tw := create_tween().set_loops(3)
	tw.tween_property(c, "modulate", Color(1.6, 1.4, 0.6), 0.35)
	tw.tween_property(c, "modulate", Color.WHITE, 0.35)


func shake(c: Control) -> void:
	var orig := c.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(c, "position", orig + Vector2(8 if i % 2 == 0 else -8, 0), 0.04)
	tw.tween_property(c, "position", orig, 0.04)


func finish(done_text: String) -> void:
	_finished = true
	var cover := UI.dim(0.5)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(720, 0)
	var c := UI.vbox(14)
	var star := UI.icon("res://assets/icons/bintang.png", 96)
	c.add_child(star)
	var t := UI.label("SYABAS!", "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var d := UI.label(done_text, "Ink", true)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(d)
	var s := UI.label("Betul cubaan pertama: %d / %d    Petunjuk Pau: %d" % [stats["first_try"], stats["total"], stats["hints"]], "InkSmall", true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.visible = int(stats["total"]) > 0
	c.add_child(s)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var sp := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(64, 56))
	sp.pressed.connect(func(): Tts.speak(done_text))
	row.add_child(sp)
	var go := UI.button("Teruskan »", "Primary", 220)
	go.pressed.connect(func(): completed.emit(stats))
	row.add_child(go)
	c.add_child(row)
	card.add_child(c)
	add_child(UI.center(card))
	card.scale = Vector2(0.8, 0.8)
	card.pivot_offset = Vector2(360, 160)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	go.grab_focus()
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(done_text)
