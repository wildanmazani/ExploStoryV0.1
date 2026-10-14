extends "res://scripts/puzzles/puzzle_base.gd"
## Engine 2: Papan Siasatan (cause-and-effect investigation board).
## Cards sit in columns; the player links them with red yarn. Tap a card,
## then tap the related card (or drag from one card to the other).

const UIB = preload("res://scripts/ui/ui.gd")


class BoardCard extends PanelContainer:
	var engine: Node
	var cid: String
	var data: Dictionary

	func _init(e: Node, d: Dictionary) -> void:
		engine = e
		data = d
		cid = str(d.get("id", ""))
		theme_type_variation = "Card"
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0, 84)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ip := str(d.get("icon", ""))
		if ip != "":
			row.add_child(UIB.icon(ip, 40))
		var l := Label.new()
		l.text = str(d.get("text", ""))
		l.theme_type_variation = "Ink"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 160
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		add_child(row)

	func anchor() -> Vector2:
		return get_global_rect().get_center()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				engine.card_down(self)
			else:
				engine.card_up(self)
			accept_event()


class Yarn extends Control:
	var engine: Node

	func _draw() -> void:
		var origin := get_global_rect().position
		for l in engine.made:
			var a: Vector2 = engine.cards[l[0]].anchor() - origin
			var b: Vector2 = engine.cards[l[1]].anchor() - origin
			draw_line(a, b, Color(0.55, 0.08, 0.08), 7.0)
			draw_line(a, b, Color(0.85, 0.2, 0.2), 4.0)
			for p in [a, b]:
				draw_circle(p, 8, Color(0.25, 0.25, 0.3))
				draw_circle(p, 5, Color(0.95, 0.85, 0.3))
		if engine.bad.size() == 2:
			var a2: Vector2 = engine.cards[engine.bad[0]].anchor() - origin
			var b2: Vector2 = engine.cards[engine.bad[1]].anchor() - origin
			draw_dashed_line(a2, b2, Color(0.5, 0.5, 0.55), 4.0, 12.0)
		if engine.selected != null and engine.dragging:
			var a3: Vector2 = engine.selected.anchor() - origin
			draw_line(a3, get_global_mouse_position() - origin, Color(0.85, 0.2, 0.2, 0.6), 4.0)


var cards: Dictionary = {}
var links: Array = []
var made: Array = []
var bad: Array = []
var selected: BoardCard = null
var dragging: bool = false
var missed: Dictionary = {}
var hinted: Dictionary = {}
var yarn: Yarn
var tree_icon: TextureRect


func _build_puzzle() -> void:
	links = def.get("links", [])
	stats["total"] = links.size()
	var board := UI.panel()
	board.add_theme_stylebox_override("panel", UI.sb(Color("b98a58"), UI.WOOD_D, 6, 6, 14))
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(70)
	var cols: Array = def.get("columns", [])
	var col_boxes: Array = []
	for i in cols.size():
		var c := UI.vbox(10)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := UI.label(str(cols[i]), "InkHeading")
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(h)
		col_boxes.append(c)
		row.add_child(c)
	var cdefs: Array = def.get("cards", [])
	for d in cdefs:
		var card := BoardCard.new(self, d)
		cards[card.cid] = card
		var ci := clampi(int(d.get("col", 0)), 0, col_boxes.size() - 1)
		col_boxes[ci].add_child(card)
	yarn = Yarn.new()
	yarn.engine = self
	yarn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(yarn)
	board.add_child(row)
	body.add_child(board)
	if def.has("grow_on_links"):
		tree_icon = UI.icon("res://assets/proto/objects/pokok_1.png", 110)
		tree_icon.position = Vector2(1090, 470)
		tree_icon.size = Vector2(110, 110)
		tree_icon.pivot_offset = Vector2(55, 110)
		add_child(tree_icon)


func _process(_d: float) -> void:
	if yarn:
		yarn.queue_redraw()


func _key(a: String, b: String) -> String:
	for l in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return "%s|%s" % [l[0], l[1]]
	return ""


func _is_made(k: String) -> bool:
	for m in made:
		if "%s|%s" % [m[0], m[1]] == k:
			return true
	return false


func _set_sel(c: BoardCard) -> void:
	if selected and is_instance_valid(selected):
		selected.theme_type_variation = "Card"
	selected = c
	if c:
		c.theme_type_variation = "CardSel"
		say_try("Dipilih: \"%s\". Ketik kad yang berkaitan." % c.data.get("text", ""))


func card_down(c: BoardCard) -> void:
	if _finished:
		return
	if selected != null and selected != c:
		var a := selected
		_set_sel(null)
		try_link(a, c)
		return
	_set_sel(c)
	dragging = true


func card_up(c: BoardCard) -> void:
	dragging = false
	if selected != c:
		return
	var mp := get_global_mouse_position()
	for k in cards.values():
		if k != c and (k as Control).get_global_rect().has_point(mp):
			_set_sel(null)
			try_link(c, k)
			return


func try_link(a: BoardCard, b: BoardCard) -> void:
	var k := _key(a.cid, b.cid)
	if k == "":
		missed[a.cid] = true
		missed[b.cid] = true
		stats["retries"] = int(stats["retries"]) + 1
		bad = [a.cid, b.cid]
		shake(b)
		say_try("Hmm, dua kad ini tidak bersambung secara langsung. Cuba lagi.")
		get_tree().create_timer(0.8).timeout.connect(func(): bad = [])
		return
	if _is_made(k):
		say_try("Sambungan itu sudah ada.")
		return
	var pair: PackedStringArray = k.split("|")
	made.append([pair[0], pair[1]])
	var first := not missed.has(a.cid) and not missed.has(b.cid) and not hinted.has(k)
	if first:
		stats["first_try"] = int(stats["first_try"]) + 1
	for c in [a, b]:
		(c as BoardCard).theme_type_variation = "CardGood"
		var cc: BoardCard = c
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(cc):
				cc.theme_type_variation = "Card")
	var facts: Dictionary = def.get("link_facts", {})
	say_good("Bersambung! " + str(facts.get(k, "")))
	_update_tree()
	if made.size() >= links.size():
		await get_tree().create_timer(1.0).timeout
		finish(str(def.get("conclusion", "Papan siasatan lengkap!")))


func _update_tree() -> void:
	if tree_icon == null:
		return
	var grow: Array = def.get("grow_on_links", [])
	var n := 0
	for g in grow:
		if _is_made(str(g)):
			n += 1
	var stage := 1 if n < grow.size() else 2
	tree_icon.texture = UI.tex("res://assets/proto/objects/pokok_%d.png" % stage)
	pulse(tree_icon)


func _first_missing() -> Array:
	for l in links:
		if not _is_made("%s|%s" % [l[0], l[1]]):
			return l
	return []


func _hint(tier: int) -> void:
	var l := _first_missing()
	if l.is_empty():
		return
	match tier:
		1:
			Game.main.pau_say(str(def.get("hint", "Mulakan dari lajur pertama. Apa akibatnya?")))
		2:
			Game.main.pau_say("Tengok dua kad yang bercahaya. Adakah ia bersambung?")
			pulse(cards[l[0]])
			pulse(cards[l[1]])
		_:
			var k := "%s|%s" % [l[0], l[1]]
			hinted[k] = true
			Game.main.pau_say("Ini satu sambungan: \"%s\" dengan \"%s\"." % [cards[l[0]].data.get("text", ""), cards[l[1]].data.get("text", "")])
			try_link(cards[l[0]], cards[l[1]])
