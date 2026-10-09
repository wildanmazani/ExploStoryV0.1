extends "res://scripts/puzzles/puzzle_base.gd"
## Engine 1: Seret dan Padankan (drag and match).
## One engine covers ordering, sorting into bins and pairing: every item
## names its correct target in JSON. Drag a card onto a target, or tap the
## card then tap the target.

const UIX = preload("res://scripts/ui/ui.gd")


class DragCard extends PanelContainer:
	var engine: Node
	var item: Dictionary
	var placed: bool = false
	var mistakes: int = 0
	var hinted: bool = false
	var _label: Label
	var _icon: TextureRect

	func _init(e: Node, it: Dictionary) -> void:
		engine = e
		item = it
		theme_type_variation = "Card"
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ip := str(it.get("icon", ""))
		if ip != "":
			_icon = UIX.icon(ip, 44)
			row.add_child(_icon)
		_label = Label.new()
		_label.text = str(it.get("label", ""))
		_label.theme_type_variation = "Ink"
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = 150
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_label)
		add_child(row)
		custom_minimum_size = Vector2(230, 56)

	func compact() -> void:
		custom_minimum_size = Vector2(0, 0)
		_label.custom_minimum_size.x = 0
		_label.theme_type_variation = "InkSmall"
		if _icon:
			_icon.custom_minimum_size = Vector2(28, 28)

	func _get_drag_data(_at: Vector2) -> Variant:
		if placed:
			return null
		var prev := PanelContainer.new()
		prev.theme = Game.theme
		prev.theme_type_variation = "CardSel"
		var l := Label.new()
		l.text = _label.text
		l.theme_type_variation = "Ink"
		prev.add_child(l)
		prev.modulate.a = 0.9
		set_drag_preview(prev)
		engine.select(self)
		return {"card": self}

	func _gui_input(event: InputEvent) -> void:
		if placed:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if not get_viewport().gui_is_dragging():
				engine.select(self)


class DropTarget extends PanelContainer:
	var engine: Node
	var tid: String
	var box: VBoxContainer
	var _base_var: String = "Slot"

	func _init(e: Node, t: Dictionary, min_w: float) -> void:
		engine = e
		tid = str(t.get("id", ""))
		theme_type_variation = "Slot"
		custom_minimum_size = Vector2(min_w, 150)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ip := str(t.get("icon", ""))
		if ip != "":
			head.add_child(UIX.icon(ip, 40))
		var l := Label.new()
		l.text = str(t.get("label", ""))
		l.theme_type_variation = "Heading"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = min_w - (70 if ip != "" else 30)
		if min_w < 300:
			l.add_theme_font_size_override("font_size", 20)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(l)
		col.add_child(head)
		if t.has("sub"):
			var s := Label.new()
			s.text = str(t["sub"])
			s.theme_type_variation = "Small"
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(s)
		box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(box)
		add_child(col)

	func set_state(v: String) -> void:
		theme_type_variation = v

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok: bool = data is Dictionary and data.has("card")
		if ok:
			set_state("SlotHot")
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		set_state(_base_var)
		engine.try_place(data["card"], self)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
			if theme_type_variation == "SlotHot":
				set_state(_base_var)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			engine.target_tapped(self)


var selected: DragCard = null
var cards: Array = []
var targets: Dictionary = {}
var pool: HFlowContainer


func _build_puzzle() -> void:
	var tdefs: Array = def.get("targets", [])
	var items: Array = def.get("items", [])
	stats["total"] = items.size()
	var trow := UI.hbox(10)
	trow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var min_w := (1160.0 - 10.0 * (tdefs.size() - 1)) / maxf(1.0, tdefs.size())
	for t in tdefs:
		var dt := DropTarget.new(self, t, min_w)
		targets[dt.tid] = dt
		trow.add_child(dt)
	body.add_child(trow)
	var pool_panel := UI.panel("Slot")
	pool_panel.add_theme_stylebox_override("panel", UI.sb(Color(0.3, 0.22, 0.14, 0.9), UI.WOOD_D, 3, 8, 10))
	var pcol := UI.vbox(4)
	var pl := UI.label("Kad untuk diseret", "Small")
	pcol.add_child(pl)
	pool = HFlowContainer.new()
	pool.add_theme_constant_override("h_separation", 10)
	pool.add_theme_constant_override("v_separation", 8)
	pcol.add_child(pool)
	pool_panel.add_child(pcol)
	body.add_child(pool_panel)
	var shuffled := items.duplicate()
	shuffled.shuffle()
	for it in shuffled:
		var c := DragCard.new(self, it)
		cards.append(c)
		pool.add_child(c)


func select(c: DragCard) -> void:
	if selected and is_instance_valid(selected) and not selected.placed:
		selected.theme_type_variation = "Card"
	selected = c
	c.theme_type_variation = "CardSel"
	say_try("Dipilih: %s. Sekarang ketik atau seret ke tempat yang betul." % c.item.get("label", ""))


func target_tapped(t: DropTarget) -> void:
	if selected and is_instance_valid(selected) and not selected.placed:
		try_place(selected, t)


func try_place(c: DragCard, t: DropTarget) -> void:
	if c.placed:
		return
	if str(c.item.get("target", "")) == t.tid:
		_place(c, t)
	else:
		c.mistakes += 1
		stats["retries"] = int(stats["retries"]) + 1
		t.set_state("SlotBad")
		shake(t)
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(t):
				t.set_state("Slot"))
		c.theme_type_variation = "Card"
		selected = null
		var tip := str(c.item.get("try", ""))
		say_try("Hmm, belum tepat. " + (tip if tip != "" else "Kad itu kembali ke tempatnya. Cuba lagi, atau ketik Pau untuk petunjuk."))


func _place(c: DragCard, t: DropTarget) -> void:
	c.placed = true
	if c.mistakes == 0 and not c.hinted:
		stats["first_try"] = int(stats["first_try"]) + 1
	c.get_parent().remove_child(c)
	t.box.add_child(c)
	c.compact()
	c.theme_type_variation = "CardGood"
	c.mouse_default_cursor_shape = Control.CURSOR_ARROW
	selected = null
	t.set_state("SlotGood")
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(t):
			t.set_state("Slot"))
	say_good("Betul! " + str(c.item.get("fact", "")))
	for k in cards:
		if not k.placed:
			return
	await get_tree().create_timer(0.9).timeout
	finish(str(def.get("done_text", "Semua kad di tempat yang betul!")))


func _first_unplaced() -> DragCard:
	for k in cards:
		if not k.placed:
			return k
	return null


func _hint(tier: int) -> void:
	var c := _first_unplaced()
	if c == null:
		return
	var t: DropTarget = targets.get(str(c.item.get("target", "")))
	match tier:
		1:
			Game.main.pau_say(str(def.get("hint", "Baca setiap kad perlahan-lahan. Fikir kenapa ia sesuai.")))
		2:
			Game.main.pau_say("Tengok kad dan tempat yang bercahaya tu.")
			pulse(c)
			if t:
				pulse(t)
		_:
			c.hinted = true
			Game.main.pau_say("Ini satu sambungan yang betul: %s." % c.item.get("label", ""))
			if t:
				_place(c, t)
