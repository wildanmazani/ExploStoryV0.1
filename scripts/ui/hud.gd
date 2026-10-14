extends Control
## HUD (Module 2): top-left location + menu buttons, top-right player card
## with avatar, level, EXP bar and coins (GDS mockup).

const UI = preload("res://scripts/ui/ui.gd")

var location_title: String = ""
var location_sub: String = ""
var show_map_button: bool = false

var _level: Label
var _exp: ProgressBar
var _coins: Label
var _title: Label
var _sub: Label


func _ready() -> void:
	UI.full(self)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# top-left: location + menu
	var left := UI.vbox(8)
	left.position = Vector2(16, 14)
	var loc := UI.panel()
	var lc := UI.vbox(0)
	_title = UI.label(location_title, "Heading")
	lc.add_child(_title)
	_sub = UI.label(location_sub, "Small")
	_sub.visible = location_sub != ""
	lc.add_child(_sub)
	loc.add_child(lc)
	left.add_child(loc)
	var menu := UI.hbox(8)
	if show_map_button:
		var m := UI.icon_button("res://assets/icons/peta.png", "", Vector2(64, 60))
		m.tooltip_text = "Kembali ke Peta"
		m.pressed.connect(func(): Game.goto("peta"))
		menu.add_child(m)
	var nota := UI.icon_button("res://assets/icons/nota.png", "", Vector2(64, 60))
	nota.tooltip_text = "Nota Alif"
	nota.pressed.connect(func(): Game.main.open_nota())
	menu.add_child(nota)
	var muz := UI.icon_button("res://assets/icons/muzium.png", "", Vector2(64, 60))
	muz.tooltip_text = "Muzium"
	muz.pressed.connect(func(): Game.main.open_muzium())
	menu.add_child(muz)
	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(64, 60))
	st.tooltip_text = "Tetapan"
	st.pressed.connect(func(): Game.main.open_settings())
	menu.add_child(st)
	left.add_child(menu)
	add_child(left)

	# top-right: player card
	var card := UI.panel()
	card.position = Vector2(1280 - 16 - 360, 14)
	card.custom_minimum_size = Vector2(360, 0)
	var row := UI.hbox(12)
	var av := UI.panel("Slot")
	av.add_theme_stylebox_override("panel", UI.sb(UI.NAVY2, UI.GOLD, 3, 6, 4))
	av.add_child(UI.icon("res://assets/portraits/%s.png" % str(Game.save["profile"].get("avatar", "pelajar_1")), 76))
	row.add_child(av)
	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UI.label(str(Game.save["profile"]["username"]), "Small")
	name_l.clip_text = true
	info.add_child(name_l)
	_level = UI.label("", "Heading")
	info.add_child(_level)
	var exp_row := UI.hbox(6)
	var el := UI.label("EXP", "Small")
	el.add_theme_color_override("font_color", Color("7cc4ff"))
	exp_row.add_child(el)
	_exp = ProgressBar.new()
	_exp.show_percentage = false
	_exp.custom_minimum_size = Vector2(150, 16)
	_exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_exp.max_value = Game.EXP_PER_LEVEL
	exp_row.add_child(_exp)
	info.add_child(exp_row)
	var coin_row := UI.hbox(6)
	coin_row.add_child(UI.icon("res://assets/icons/syiling.png", 26))
	_coins = UI.label("", "Small")
	_coins.add_theme_color_override("font_color", UI.GOLD)
	coin_row.add_child(_coins)
	info.add_child(coin_row)
	row.add_child(info)
	card.add_child(row)
	add_child(card)
	Game.stats_changed.connect(_refresh)
	_refresh()


func set_location(t: String, s: String = "") -> void:
	location_title = t
	location_sub = s
	if _title:
		_title.text = t
		_sub.text = s
		_sub.visible = s != ""


func _refresh() -> void:
	_level.text = "TAHAP %d" % int(Game.save["level"])
	_exp.value = int(Game.save["exp"]) % Game.EXP_PER_LEVEL
	_coins.text = "SYILING: %d" % int(Game.save["coins"])
