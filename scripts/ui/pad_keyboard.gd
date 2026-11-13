extends Control
## On-screen keyboard for a controller: ✕ on a text box opens it (ui/pad.gd).
## D-pad moves over the keys, ✕ types, ▢ deletes, △ capitals, Options = Siap
## (the same as Enter in that box), ◯ closes. It sits at the bottom so the
## form stays in view, and shows what is being typed (a password as stars).
## A mouse can click the keys too.

const UI = preload("res://scripts/ui/ui.gd")
const LETTERS := ["1234567890", "qwertyuiop", "asdfghjkl@", "zxcvbnm._-"]
const SYMBOLS := ["1234567890", "!?#$%&*+=/", "()[]{}<>:;", "',~^|`@._-"]
const KEY := Vector2(62, 50)

var target: LineEdit
var _caps := false
var _sym := false
var _keys: Array[Button] = []
var _preview: Label
var _caps_btn: Button
var _sym_btn: Button
var _t := 0.0


func _ready() -> void:
	UI.full(self)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	var frame := UI.panel()
	frame.add_theme_stylebox_override("panel", _frame_style())
	var col := UI.vbox(8)
	var box := UI.panel()
	box.add_theme_stylebox_override("panel", UI.sb(Color.WHITE, UI.GOLD, 3, 6, 9))
	_preview = UI.label("", "Ink")
	_preview.clip_text = true
	_preview.custom_minimum_size.y = 30
	_preview.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_preview)
	col.add_child(box)
	for r in LETTERS.size():
		var row := UI.hbox(6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in LETTERS[r].length():
			var b := _key("", KEY.x)
			b.pressed.connect(_type.bind(_keys.size()))
			_keys.append(b)
			row.add_child(b)
		col.add_child(row)
	var last := UI.hbox(6)
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	_caps_btn = _key("ABC", 100)
	_caps_btn.pressed.connect(_toggle_caps)
	last.add_child(_caps_btn)
	_sym_btn = _key("!#?", 100)
	_sym_btn.pressed.connect(_toggle_sym)
	last.add_child(_sym_btn)
	var space := _key(tr("Ruang"), 196)
	space.pressed.connect(_add.bind(" "))
	last.add_child(space)
	var del := _key(tr("Padam"), 120)
	del.pressed.connect(_delete)
	last.add_child(del)
	var done := _key(tr("Siap"), 120)
	done.theme_type_variation = "Primary"
	done.pressed.connect(_done)
	last.add_child(done)
	col.add_child(last)
	frame.add_child(col)
	add_child(frame)
	frame.reset_size()
	frame.position = Vector2((Game.screen_w() - frame.size.x) / 2.0, 720.0 - frame.size.y - 46.0)
	_refresh()
	Sfx.play("pop", -8.0)
	frame.modulate.a = 0.0
	var y := frame.position.y
	frame.position.y = y + 18.0
	var tw := create_tween().set_parallel()
	tw.tween_property(frame, "modulate:a", 1.0, 0.15)
	tw.tween_property(frame, "position:y", y, 0.15)


func _frame_style() -> StyleBoxFlat:
	var s := UI.sb(Color(0.09, 0.11, 0.17, 0.97), UI.GOLD, 3, 12, 14)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	return s


func _key(text: String, w: float) -> Button:
	var b := UI.button(text)
	b.custom_minimum_size = Vector2(w, KEY.y)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return b


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(target) or not target.is_inside_tree():
		close()
		return
	var shown := "*".repeat(target.text.length()) if target.secret else target.text
	_preview.text = shown + ("|" if fmod(_t, 1.0) < 0.55 else " ")


func _refresh() -> void:
	var rows := SYMBOLS if _sym else LETTERS
	var n := 0
	for r: String in rows:
		for i in r.length():
			var ch: String = r[i]
			_keys[n].text = ch.to_upper() if _caps and not _sym else ch
			n += 1
	_caps_btn.theme_type_variation = "Blue" if _caps else ""
	_caps_btn.disabled = _sym
	_sym_btn.theme_type_variation = "Blue" if _sym else ""
	_sym_btn.text = "abc" if _sym else "!#?"


func _type(i: int) -> void:
	_add(_keys[i].text)


func _add(ch: String) -> void:
	if not is_instance_valid(target):
		return
	if target.max_length > 0 and target.text.length() >= target.max_length:
		Sfx.play("bump", -8.0)
		return
	_write(target.text + ch)
	Sfx.play("blip", -10.0, 1.2)


func _delete() -> void:
	if is_instance_valid(target) and target.text != "":
		_write(target.text.substr(0, target.text.length() - 1))
		Sfx.play("blip", -10.0, 0.8)


func _write(text: String) -> void:
	target.text = text
	target.caret_column = text.length()
	target.text_changed.emit(text)  # forms check what is typed as they do for keys


func _toggle_caps() -> void:
	_caps = not _caps
	_refresh()


func _toggle_sym() -> void:
	_sym = not _sym
	_refresh()


## Siap: what Enter does in that box (the next box, or log in)
func _done() -> void:
	var t := target
	close()
	if is_instance_valid(t):
		t.text_submitted.emit(t.text)


func close() -> void:
	if not is_queued_for_deletion():
		queue_free()


# ------------------------------------------------------------------ controller
func pad_first() -> Control:
	return _keys[10]  # q


func pad_cancel() -> bool:
	close()
	return true


func pad_hints() -> Array:
	return [["cross", "Taip"], ["square", "Padam"], ["triangle", "Huruf besar"], ["options", "Siap"], ["circle", "Tutup"]]


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton) or not event.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
		return
	get_viewport().set_input_as_handled()  # not Lari, Pau or Menu while typing
	if not event.pressed:
		return
	match event.button_index:
		JOY_BUTTON_X: _delete()
		JOY_BUTTON_Y:
			if not _sym:
				_toggle_caps()
		JOY_BUTTON_START: _done()
