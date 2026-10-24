extends Control
## A phone showing a group chat, messages popping in one by one (the prologue
## cold open). It plays and closes by itself; tap / E / Space only hurries it.
##   setup({title, time, messages: [{from, text}]})  from = characters.json id,
##   "alif" is the player's own message (right side, green)

const UI = preload("res://scripts/ui/ui.gd")
const BUBBLE := Color("fbf7ec")
const MINE := Color("d6f2c4")
const NAME_COL := {"aisyah": Color("b0457a"), "ravi": Color("2f7a4a"), "meiling": Color("3f68b8"), "daniel": Color("b5651d")}

signal done

var finished := false
var _msgs: Array = []
var _i := 0
var _gap := 0.8      ## seconds until the next message pops in
var _last_at := 0.0  ## when the last message appeared (no accidental double-tap close)
var _list: VBoxContainer


func setup(d: Dictionary) -> void:
	_msgs = d.get("messages", [])
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.07, 0.94)
	UI.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var phone := PanelContainer.new()
	phone.add_theme_stylebox_override("panel", UI.sb(Color("15171f"), Color("2c2f3a"), 10, 40, 14))
	phone.position = Vector2(370, 24)
	phone.size = Vector2(540, 672)
	phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(phone)
	var col := UI.vbox(0)
	phone.add_child(col)

	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UI.sb(Color("1f6f5c"), Color(0, 0, 0, 0), 0, 18, 14))
	var hrow := UI.hbox(12)
	head.add_child(hrow)
	var title := UI.label(str(d.get("title", "")), "Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(title)
	hrow.add_child(UI.label(str(d.get("time", "")), "Small"))
	col.add_child(head)

	var chat := PanelContainer.new()
	chat.add_theme_stylebox_override("panel", UI.sb(Color("e9e2d2"), Color(0, 0, 0, 0), 0, 18, 14))
	chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat.clip_contents = true
	col.add_child(chat)
	_list = UI.vbox(10)
	_list.alignment = BoxContainer.ALIGNMENT_END
	chat.add_child(_list)


func _process(delta: float) -> void:
	if finished:
		return
	_gap -= delta
	if _gap <= 0.0:
		if _i < _msgs.size():
			_show_next()
		else:
			_close()


## next message now, or close once they have all been shown
func tap() -> void:
	if finished:
		return
	if _i < _msgs.size():
		_show_next()
	elif Time.get_ticks_msec() / 1000.0 - _last_at > 0.4:
		_close()


func _close() -> void:
	finished = true
	done.emit()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		tap()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		tap()


func _show_next() -> void:
	var m: Dictionary = _msgs[_i]
	_i += 1
	var who := str(m.get("from", ""))
	var text := str(m.get("text", ""))
	var mine := who == "alif"
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.sb(MINE if mine else BUBBLE, Color(0, 0, 0, 0.12), 1, 14, 10))
	bubble.custom_minimum_size.x = 120
	var inner := UI.vbox(2)
	bubble.add_child(inner)
	if not mine:
		row.add_child(UI.head_icon("rakan_" + who, 44))
		var sender := UI.label(Game.char_name(who), "InkSmall")
		sender.add_theme_color_override("font_color", NAME_COL.get(who, UI.WOOD_D))
		inner.add_child(sender)
	var body := UI.label(text, "Ink", true)
	body.custom_minimum_size.x = mini(360, 40 + text.length() * 12)
	inner.add_child(body)
	row.add_child(bubble)
	_list.add_child(row)
	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.2)
	Sfx.play("pop", -8.0, 1.25 if mine else 1.0)
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(text)
	_last_at = Time.get_ticks_msec() / 1000.0
	_gap = 1.0 + text.length() * 0.035  # time to read it
	if _i >= _msgs.size():
		_gap += 1.5  # linger on the last one
