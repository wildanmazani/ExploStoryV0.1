extends "res://scripts/ui/modal.gd"
## Muzium Peribadi: a shelf with 4 artifact slots (one per zone) plus the
## Kad Tokoh collection (historical figures met in Bab 1).


func _init() -> void:
	title_text = "MUZIUM PERIBADI"
	panel_size = Vector2(1060, 620)


func _build() -> void:
	var shelf := UI.hbox(16)
	shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	for z in Game.ZONES:
		var zd := Game.zone_data(z)
		var g: Dictionary = zd.get("ganjaran", {})
		var have: bool = Game.save["artifacts"].has(str(g.get("id", "")))
		var slot := UI.panel("SlotGood" if have else "Slot")
		slot.custom_minimum_size = Vector2(230, 250)
		var c := UI.vbox(6)
		var ic := UI.icon("res://assets/icons/%s.png" % g.get("icon", "kunci") if have else "res://assets/icons/kunci.png", 110)
		if not have:
			ic.modulate = Color(1, 1, 1, 0.5)
		c.add_child(ic)
		var n := UI.label(str(g.get("nama", "?")) if have else "???", "Heading" if have else "", true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(n)
		var info := UI.label(str(g.get("info", "")) if have else "Selesaikan Misi %s" % str(zd.get("no", "")), "Small", true)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(info)
		slot.add_child(c)
		shelf.add_child(slot)
	content.add_child(shelf)
	content.add_child(UI.label("Kad Tokoh", "Heading"))
	var row := UI.hbox(10)
	for id in Game.characters.keys():
		var ch: Dictionary = Game.characters[id]
		if not ch.get("tokoh", false):
			continue
		var met: bool = Game.save["figures"].has(id)
		var card := UI.panel("Card" if met else "CardLocked")
		card.custom_minimum_size = Vector2(140, 0)
		card.tooltip_text = str(ch.get("lore", "")) if met else "Temui tokoh ini di Misi %s" % str(ch.get("zon", "")).replace("_", ".")
		var cc := UI.vbox(2)
		var pic := UI.icon(Game.portrait_path(id), 80)
		if not met:
			pic.modulate = Color(0, 0, 0, 0.85)
		cc.add_child(pic)
		var nm := UI.label(str(ch["name"]) if met else "Berkunci", "InkSmall" if met else "Small", true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(nm)
		card.add_child(cc)
		row.add_child(card)
	content.add_child(row)
