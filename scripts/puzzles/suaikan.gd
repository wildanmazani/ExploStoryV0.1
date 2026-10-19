extends "res://scripts/puzzles/puzzle_base.gd"
## Suaikan (matching): tap an item on the left, then its partner on the
## right. A correct pair is joined by a gold line and shows its fact; a wrong
## one shakes and nothing is lost. Tapping works on phones (no dragging).
## Pau's hints: 1 = nudge, 2 = glow one pair, 3 = join one pair.
##
## def: {"type": "suaikan", "title", "instruction", "hint", "done_text",
##       "left_title", "right_title",
##       "pairs": [{"left", "right", "fact", "icon"?}]}

var pairs: Array = []
var _left: Array[Button] = []
var _right: Array[Button] = []   ## shuffled; _right_pair[i] = pair index
var _right_pair: Array[int] = []
var _sel: int = -1               ## selected left pair index
var _done := {}                  ## pair index -> true
var _missed := {}                ## pair index -> true (had a wrong try)
var _lines: Control


func _build_puzzle() -> void:
	pairs = def.get("pairs", [])
	stats["total"] = pairs.size()
	var row := UI.hbox(0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lcol := UI.vbox(10)
	var rcol := UI.vbox(10)
	for c in [lcol, rcol]:
		c.custom_minimum_size.x = 470
		c.alignment = BoxContainer.ALIGNMENT_CENTER
	var lt := UI.label(str(def.get("left_title", "")), "Heading")
	lcol.add_child(lt)
	var rt := UI.label(str(def.get("right_title", "")), "Heading")
	rcol.add_child(rt)
	for i in pairs.size():
		var b := _item_button(str(pairs[i]["left"]), str(pairs[i].get("icon", "")))
		b.pressed.connect(_tap_left.bind(i))
		lcol.add_child(b)
		_left.append(b)
	var order := range(pairs.size())
	order.shuffle()
	if order == range(pairs.size()) and pairs.size() > 1:  # never already solved
		order.reverse()
	for k in order.size():
		var i: int = order[k]
		var b := _item_button(str(pairs[i]["right"]), "")
		b.pressed.connect(_tap_right.bind(k))
		rcol.add_child(b)
		_right.append(b)
		_right_pair.append(i)
	row.add_child(lcol)
	var gap := Control.new()
	gap.custom_minimum_size.x = 220
	row.add_child(gap)
	row.add_child(rcol)
	body.add_child(UI.center(row))
	_lines = Lines.new()
	_lines.owner_puzzle = self
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	UI.full(_lines)
	say_try("Ketik satu di kiri, kemudian pasangannya di kanan.")


func _item_button(text: String, icon_path: String) -> Button:
	var b := UI.button(text)
	b.custom_minimum_size = Vector2(470, 64)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.toggle_mode = false
	if icon_path != "":
		b.icon = UI.tex(icon_path)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 44)
	return b


func _tap_left(i: int) -> void:
	if _done.has(i):
		return
	_sel = i
	Sfx.play("select", -6.0)
	for j in _left.size():
		if not _done.has(j):
			_left[j].theme_type_variation = "Blue" if j == i else ""
	say_try(tr("Sekarang ketik pasangan untuk: %s") % str(pairs[i]["left"]))


func _tap_right(k: int) -> void:
	var i := _right_pair[k]
	if _done.has(i):
		return
	if _sel < 0:
		say_try("Pilih dulu satu di sebelah kiri.")
		pulse(_left[_first_open()])
		return
	try_match(_sel, k)


## used by taps, Pau's tier-3 hint and the autotest
func try_match(left_i: int, right_k: int) -> void:
	if _right_pair[right_k] == left_i:
		_done[left_i] = true
		if not _missed.has(left_i):
			stats["first_try"] = int(stats["first_try"]) + 1
		for b in [_left[left_i], _right[right_k]]:
			b.theme_type_variation = "Primary"  # stays green; taps on it are ignored
			b.focus_mode = Control.FOCUS_NONE
			pulse(b)
		_sel = -1
		Sfx.play("chime", -8.0)
		say_good(str(pairs[left_i].get("fact", "Betul!")))
		_lines.queue_redraw()
		if _done.size() == pairs.size():
			MusicDirector.stinger("st_correct")
			await get_tree().create_timer(1.4).timeout
			finish(str(def.get("done_text", "")))
	else:
		_missed[left_i] = true
		stats["retries"] = int(stats["retries"]) + 1
		shake(_right[right_k])
		Sfx.play("bump", -4.0)
		say_try(["Bukan pasangan itu. Cuba lagi.", "Hampir! Fikir sekali lagi.", "Tak apa, cuba yang lain."].pick_random())


func _first_open() -> int:
	for i in pairs.size():
		if not _done.has(i):
			return i
	return 0


func _right_of(i: int) -> int:
	return _right_pair.find(i)


func _hint(tier: int) -> void:
	var i := _sel if _sel >= 0 else _first_open()
	match tier:
		1: Game.main.pau_say(str(def.get("hint", "Cari kata yang sama maksud di kedua-dua belah.")))
		2:
			pulse(_left[i])
			pulse(_right[_right_of(i)])
			Game.main.pau_say("Tengok dua yang bercahaya tu. Mereka sepasang.")
		_:
			Game.main.pau_say(tr("Aku tolong satu: %s.") % str(pairs[i]["left"]))
			try_match(i, _right_of(i))


## Gold lines between matched pairs (drawn over the buttons' edges).
class Lines extends Control:
	var owner_puzzle: Node

	func _draw() -> void:
		var p = owner_puzzle
		for i in p._done:
			var a: Button = p._left[i]
			var b: Button = p._right[p._right_of(i)]
			var from := a.get_global_rect().position + Vector2(a.size.x, a.size.y / 2.0) - global_position
			var to := b.get_global_rect().position + Vector2(0, b.size.y / 2.0) - global_position
			draw_line(from, to, Color(0.1, 0.08, 0.05), 7.0)
			draw_line(from, to, UI.GOLD, 4.0)
			draw_circle(from, 6, UI.GOLD)
			draw_circle(to, 6, UI.GOLD)
