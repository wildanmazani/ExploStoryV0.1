extends Control
## Module 5: Ringkasan Zon (post-zone summary, GDS "Post-Match Summary").
## Level, EXP bar, coins, artifact earned and syllabus mastery for the subtopic.

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _exp_bar: ProgressBar
var _coin_label: Label


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(true)
	var zid: String = params.get("zone", "1_1")
	var zone := Game.zone_data(zid)
	var st := Game.zone_state(zid)
	Game.context_hint = "Tahniah! Ketik Teruskan untuk kembali ke peta."
	add_child(UI.bg_image(str(zone.get("background", "")), Color(0.5, 0.5, 0.58)))
	var root := UI.vbox(0)
	UI.full(root)
	root.add_child(UI.header_bar("RINGKASAN ZON", "Zon %s: %s" % [zone["no"], zone["title"]]))
	var card := UI.panel("Glass")
	card.custom_minimum_size = Vector2(1000, 0)
	var row := UI.hbox(40)

	# left: level, exp, coins
	var left := UI.vbox(10)
	left.custom_minimum_size.x = 360
	var lvl_panel := UI.panel()
	lvl_panel.add_theme_stylebox_override("panel", UI.sb(UI.WOOD, UI.WOOD_D, 6, 90, 20))
	lvl_panel.custom_minimum_size = Vector2(170, 170)
	lvl_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lc := UI.vbox(0)
	lc.alignment = BoxContainer.ALIGNMENT_CENTER
	var lt := UI.label("TAHAP", "Small")
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lc.add_child(lt)
	var ln := UI.label(str(Game.save["level"]), "Title")
	ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lc.add_child(ln)
	lvl_panel.add_child(lc)
	left.add_child(lvl_panel)
	var er := UI.hbox(8)
	er.add_child(UI.label("EXP:", "InkHeading"))
	var ev := UI.label("%d / %d" % [int(Game.save["exp"]) % Game.EXP_PER_LEVEL, Game.EXP_PER_LEVEL], "Ink")
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	er.add_child(ev)
	left.add_child(er)
	_exp_bar = ProgressBar.new()
	_exp_bar.theme_type_variation = "Good"
	_exp_bar.show_percentage = false
	_exp_bar.custom_minimum_size = Vector2(0, 24)
	_exp_bar.max_value = Game.EXP_PER_LEVEL
	_exp_bar.value = 0
	left.add_child(_exp_bar)
	if params.get("level_up", false):
		var up := UI.label("NAIK TAHAP!", "InkHeading")
		up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(up)
	var cr := UI.hbox(10)
	cr.add_child(UI.icon("res://assets/icons/syiling.png", 64))
	var cc := UI.vbox(0)
	cc.add_child(UI.label("JUMLAH SYILING:", "InkSmall"))
	_coin_label = UI.label("0", "InkHeading")
	_coin_label.add_theme_font_size_override("font_size", 44)
	cc.add_child(_coin_label)
	cr.add_child(cc)
	left.add_child(cr)
	row.add_child(left)

	# right: mastery + artifact
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mt := UI.label("PENGUASAAN SUKATAN KSSM", "InkHeading")
	right.add_child(mt)
	right.add_child(UI.label(str(zone.get("subtopik", "")), "Ink", true))
	var total := maxi(1, int(st.get("total", 0)))
	_bar(right, "Betul cubaan pertama", int(st.get("first_try", 0)), total, "Good")
	_bar(right, "Cubaan semula", int(st.get("retries", 0)), maxi(total, int(st.get("retries", 0))), "Warn")
	right.add_child(UI.label("Petunjuk Pau digunakan: %d" % int(st.get("hints", 0)), "InkSmall"))
	right.add_child(UI.label("Penguasaan: %d%%" % int(Game.mastery_percent(zid)), "Ink"))
	var g: Dictionary = zone.get("ganjaran", {})
	var art := UI.hbox(12)
	art.add_child(UI.icon("res://assets/icons/%s.png" % g.get("icon", "bintang"), 72))
	var at := UI.vbox(2)
	at.add_child(UI.label("GANJARAN: " + str(g.get("nama", "")), "InkHeading"))
	at.add_child(UI.label(str(g.get("info", "")), "InkSmall", true))
	at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.add_child(at)
	right.add_child(art)
	if not params.get("first_time", true):
		right.add_child(UI.label("Main semula: ganjaran sudah diterima sebelum ini.", "InkSmall"))
	row.add_child(right)
	card.add_child(row)
	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(card)
	root.add_child(mid)

	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("« KEMBALI KE PETA", "", 300)
	back.pressed.connect(_continue)
	btns.add_child(back)
	var nota := UI.icon_button("res://assets/icons/nota.png", "", Vector2(200, 64), " NOTA")
	nota.pressed.connect(func(): Game.main.open_nota())
	btns.add_child(nota)
	var muz := UI.icon_button("res://assets/icons/muzium.png", "", Vector2(200, 64), " MUZIUM")
	muz.pressed.connect(func(): Game.main.open_muzium())
	btns.add_child(muz)
	var st_b := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(64, 64))
	st_b.pressed.connect(func(): Game.main.open_settings())
	btns.add_child(st_b)
	var go := UI.button("TERUSKAN »", "Primary", 260)
	go.pressed.connect(_continue)
	btns.add_child(go)
	root.add_child(UI.margin(btns, 0, 0, 0, 24))
	add_child(root)
	go.grab_focus()

	var tw := create_tween()
	tw.tween_property(_exp_bar, "value", float(int(Game.save["exp"]) % Game.EXP_PER_LEVEL), 1.2).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(func(v: float): _coin_label.text = str(int(v)), 0.0, float(Game.save["coins"]), 1.2)


func _bar(parent: VBoxContainer, text: String, v: int, mx: int, variation: String) -> void:
	var r := UI.hbox(10)
	var l := UI.label(text, "Ink")
	l.custom_minimum_size.x = 260
	r.add_child(l)
	var b := ProgressBar.new()
	b.theme_type_variation = variation
	b.show_percentage = false
	b.max_value = mx
	b.value = v
	b.custom_minimum_size = Vector2(200, 22)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(b)
	r.add_child(UI.label(str(v), "InkHeading"))
	parent.add_child(r)


func _continue() -> void:
	var zid: String = params.get("zone", "1_1")
	if zid == "1_4" and params.get("first_time", true) and not Game.chapter_done(1):
		Game.goto("penutup")
	else:
		Game.goto("peta")
