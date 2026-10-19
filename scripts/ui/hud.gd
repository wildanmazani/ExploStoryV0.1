extends Control
## HUD (Module 2): top-left location + menu buttons, top-right player card
## with avatar, level, EXP bar and coins (GDS mockup).

const UI = preload("res://scripts/ui/ui.gd")

var location_title: String = ""
var location_sub: String = ""
var show_map_button: bool = false
var world: Node = null  ## overworld: adds the Peta (map) and Tenang (calm) buttons

var _level: Label
var _exp: ProgressBar
var _coins: Label
var _title: Label
var _name: Label
var _avatar: TextureRect
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
	if world:
		var pm := UI.icon_button("res://assets/icons/peta.png", "", Vector2(64, 60))
		pm.tooltip_text = "Peta (M)"
		pm.pressed.connect(func(): Game.main.open_map(world))
		menu.add_child(pm)
		var calm := UI.button("", "", 0)
		calm.icon = UI.sheet_frame("res://assets/proto/sprites/pau.png", 3, 0, 16, 16)
		calm.expand_icon = true
		calm.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		calm.custom_minimum_size = Vector2(64, 60)
		calm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		calm.tooltip_text = "Bertenang bersama Pau (atau tekan lama Pau)"
		calm.pressed.connect(func(): Game.main.open_calm())
		menu.add_child(calm)
	var st := UI.icon_button("res://assets/icons/tetapan.png", "", Vector2(64, 60))
	st.tooltip_text = "Tetapan"
	st.pressed.connect(func(): Game.main.open_settings())
	menu.add_child(st)
	left.add_child(menu)
	add_child(left)

	# top-right: player card
	var card := UI.panel()
	card.position = Vector2(1280 - 16 - 360, 14)
	# tap the card: Profil & Kedai
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = tr("Profil & Kedai")
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not Game.is_locked():
			Game.main.open_profile())
	card.custom_minimum_size = Vector2(360, 0)
	var row := UI.hbox(12)
	var av := UI.panel("Slot")
	av.add_theme_stylebox_override("panel", UI.sb(UI.NAVY2, UI.GOLD, 3, 6, 4))
	_avatar = UI.icon("res://assets/portraits/%s.png" % str(Game.save["profile"].get("avatar", "pelajar_1")), 76)
	av.add_child(_avatar)
	row.add_child(av)
	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UI.label("", "Small")
	_name = name_l
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
	_pass_clicks(row)
	add_child(card)
	Game.stats_changed.connect(_refresh)
	Game.settings_changed.connect(_refresh)  # language switch
	_refresh()


func _pass_clicks(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for c in n.get_children():
		_pass_clicks(c)


func set_location(t: String, s: String = "") -> void:
	location_title = t
	location_sub = s
	if _title:
		_title.text = t
		_sub.text = s
		_sub.visible = s != ""


func _refresh() -> void:
	var prof: Dictionary = Game.save["profile"]
	_name.text = str(prof.get("display_name", prof["username"]))
	_avatar.texture = UI.tex("res://assets/portraits/%s.png" % str(prof.get("avatar", "pelajar_1")))
	_level.text = tr("TAHAP %d") % int(Game.save["level"])
	_exp.value = int(Game.save["exp"]) % Game.EXP_PER_LEVEL
	_coins.text = tr("SYILING: %d") % int(Game.save["coins"])
