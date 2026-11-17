extends Control
## Pesta Warisan: the traditional-games fair in Kampung Jejak (the festival
## board by the road, west of the Arena). One card per game; the ones not built yet say
## AKAN DATANG. Each game is its own screen (Game.SCREENS), takes its
## questions from the battle bank (WarisanRules.questions) and pays coins and
## EXP through WarisanRules.finish().

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("kampung")
	var bg := ColorRect.new()
	bg.color = Color("2f5d3a")
	UI.full(bg)
	add_child(bg)
	var root := UI.vbox(12)
	UI.full(root)
	add_child(root)
	root.add_child(UI.header_bar("PESTA WARISAN", tr("Permainan tradisional kita. Jawab soalan Sejarah untuk dapat Semangat, menang untuk dapat syiling.")))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for g in WarisanRules.GAMES:
		grid.add_child(_card(g))
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var centre := UI.center(grid)
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	root.add_child(scroll)

	var back := UI.button("« Kembali ke Kampung", "", 320)
	back.pressed.connect(func(): Game.goto("world"))
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(back)
	root.add_child(UI.margin(row, 0, 0, 0, 16))
	back.grab_focus.call_deferred()


func _card(g: Dictionary) -> Control:
	var p := UI.panel("Paper")
	p.custom_minimum_size = Vector2(380, 230)
	var col := UI.vbox(6)
	var top := UI.hbox(14)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/warisan/%s.png" % g["icon"])
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(tr(g["name"]), "InkHeading"))
	var desc := UI.label(tr(g["desc"]), "InkSmall", true)
	desc.custom_minimum_size.x = 240
	text.add_child(desc)
	top.add_child(text)
	col.add_child(top)
	col.add_child(UI.spacer(false))
	var ready: bool = Game.SCREENS.has(str(g["id"]))
	var stat: Dictionary = Game.save.get("warisan", {}).get(g["id"], {})
	if int(stat.get("menang", 0)) > 0:
		col.add_child(UI.label(tr("Menang %d kali") % int(stat["menang"]), "InkSmall"))
	var b := UI.button(tr("MAIN") if ready else tr("AKAN DATANG"), "Primary" if ready else "")
	b.disabled = not ready
	if ready:
		b.pressed.connect(func(): Game.goto(str(g["id"])))
	col.add_child(b)
	p.add_child(col)
	return p
