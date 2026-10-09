extends Control
## Module 3 reimagined as "Persiapan Zon": a calm briefing before each zone
## (no time pressure, UR-LO-02) plus the Kad Tokoh collection.

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _zone: Dictionary
var _guide: TextureRect
var _t: float = 0.0


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(true)
	var zid: String = params.get("zone", "1_1")
	_zone = Game.zone_data(zid)
	Game.context_hint = "Baca persoalan zon ini. Tiada had masa. Ketik Mula Meneroka bila sedia."
	add_child(UI.bg_image(str(_zone.get("background", "")), Color(0.55, 0.55, 0.62)))
	var root := UI.vbox(0)
	UI.full(root)
	root.add_child(UI.header_bar("PERSIAPAN ZON", "TOPIK: SEJARAH TINGKATAN 4 - BAB 1 (WARISAN NEGARA BANGSA)"))
	var mid := UI.hbox(30)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Control.new()
	left.custom_minimum_size = Vector2(420, 0)
	var glow := Control.new()
	glow.position = Vector2(210, 330)
	glow.draw.connect(func():
		glow.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.35))
		glow.draw_circle(Vector2.ZERO, 110, Color(0.4, 0.85, 1.0, 0.35))
		glow.draw_arc(Vector2.ZERO, 110, 0, TAU, 48, Color(0.5, 0.9, 1.0), 4.0))
	left.add_child(glow)
	var guide_id: String = _zone.get("pemandu", "pau")
	_guide = TextureRect.new()
	_guide.texture = UI.sheet_frame(Game.sprite_path(guide_id), 0, 0)
	_guide.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_guide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_guide.size = Vector2(160, 240)
	_guide.position = Vector2(130, 90)
	left.add_child(_guide)
	mid.add_child(left)

	var info := UI.panel("Glass")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := UI.vbox(10)
	_row(ic, "ZON:", "Zon %s: %s" % [_zone["no"], _zone["title"]])
	_row(ic, "SUBTOPIK:", str(_zone.get("subtopik", "")))
	_row(ic, "PERSOALAN:", str(_zone.get("persoalan", "")))
	_row(ic, "PEMANDU:", Game.char_name(guide_id))
	var g: Dictionary = _zone.get("ganjaran", {})
	_row(ic, "GANJARAN:", str(g.get("nama", "")))
	ic.get_child(ic.get_child_count() - 1).add_child(UI.icon("res://assets/icons/%s.png" % g.get("icon", "bintang"), 48))
	var speak := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(64, 56), "  Dengar")
	speak.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	speak.pressed.connect(func(): Tts.speak("Zon %s, %s. Persoalan: %s" % [_zone["no"], _zone["title"], _zone["persoalan"]]))
	ic.add_child(speak)
	if Game.zone_done(zid):
		ic.add_child(UI.label("Zon ini sudah selesai. Kau boleh main semula untuk ulang kaji.", "InkSmall", true))
	info.add_child(ic)
	mid.add_child(info)
	root.add_child(UI.margin(mid, 30, 10, 40, 0))

	# Kad Tokoh carousel
	var cards := UI.hbox(12)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in Game.characters.keys():
		var ch: Dictionary = Game.characters[id]
		if not ch.get("tokoh", false):
			continue
		var met: bool = Game.save["figures"].has(id)
		var here: bool = str(ch.get("zon", "")) == zid
		var card := UI.panel("CardSel" if here else ("Card" if met else "CardLocked"))
		card.custom_minimum_size = Vector2(150, 0)
		var cc := UI.vbox(2)
		var pic := UI.icon(Game.portrait_path(id), 76)
		if not met and not here:
			pic.modulate = Color(0, 0, 0, 0.85)
		cc.add_child(pic)
		var nm := UI.label(str(ch["name"]) if (met or here) else "BERKUNCI", "InkSmall" if (met or here) else "Small", true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(nm)
		var st := UI.label("DI ZON INI" if here else ("DITEMUI" if met else "Zon " + str(ch.get("zon", "")).replace("_", ".")), "Small")
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_theme_color_override("font_color", Color("2f6a2c") if here or met else UI.CREAM)
		cc.add_child(st)
		card.add_child(cc)
		card.tooltip_text = str(ch.get("lore", ""))
		cards.add_child(card)
	root.add_child(UI.margin(cards, 20, 0, 20, 8))

	var btns := UI.hbox(30)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("« KEMBALI KE PETA", "", 320)
	back.pressed.connect(func(): Game.goto("peta"))
	btns.add_child(back)
	var go := UI.button("MULA MENEROKA!", "Primary", 320)
	go.pressed.connect(func(): Game.goto("zone", {"zone": zid}))
	btns.add_child(go)
	root.add_child(UI.margin(btns, 0, 4, 0, 20))
	add_child(root)
	go.grab_focus()


func _row(parent: VBoxContainer, k: String, v: String) -> void:
	var r := UI.hbox(10)
	var kl := UI.label(k, "InkHeading")
	kl.custom_minimum_size.x = 190
	r.add_child(kl)
	var vl := UI.label(v, "Ink", true)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.custom_minimum_size.x = 420
	r.add_child(vl)
	parent.add_child(r)


func _process(delta: float) -> void:
	_t += delta
	if _guide:
		_guide.position.y = 90 - absf(sin(_t * 2.0)) * 8.0
