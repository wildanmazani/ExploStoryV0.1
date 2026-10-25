extends Control
## HUD (Module 2): top-left location + a Menu button that drops down a list
## (Peta, Nota, Beg Alif, Tenang, Papan Markah, Tetapan), top-right player card
## with the head of Alif's current outfit, level, EXP bar and coins.

const UI = preload("res://scripts/ui/ui.gd")
const BegPanel = preload("res://scripts/ui/beg_panel.gd")

var location_title: String = ""
var location_sub: String = ""
var show_map_button: bool = false
var world: Node = null  ## overworld: adds the Peta (map) and Tenang (calm) buttons
var exit_action: Callable  ## rooms: shows a Keluar button that calls this

var _level: Label
var _exp: ProgressBar
var _coins: Label
var _title: Label
var _name: Label
var _avatar: TextureRect
var _sub: Label
var _menu_btn: Button
var _menu: PanelContainer   ## the expanded list under the Menu button
var _catcher: Control       ## full-screen, closes the menu when tapping outside


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
	_menu_btn = UI.button("  Menu", "", 150)
	_menu_btn.icon = _bars_icon()
	_menu_btn.custom_minimum_size.y = 56
	_menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu_btn.tooltip_text = tr("Buka menu")
	_menu_btn.pressed.connect(func(): set_menu_open(not _menu.visible))
	if exit_action.is_valid():  # rooms: a Keluar button next to Menu
		var btn_row := UI.hbox(10)
		btn_row.add_child(_menu_btn)
		var out := UI.button(tr("Keluar"), "", 150)
		out.custom_minimum_size.y = 56
		out.tooltip_text = tr("Keluar dari bilik ini")
		out.pressed.connect(func():
			if not Game.is_locked():
				set_menu_open(false)
				exit_action.call())
		btn_row.add_child(out)
		left.add_child(btn_row)
	else:
		left.add_child(_menu_btn)
	add_child(left)
	_build_menu(left)

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
	_avatar = UI.head_icon(Game.skin_folder(), 76)
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
	Game.skin_changed.connect(_refresh)
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
	_avatar.texture = UI.head(Game.skin_folder())  # always matches the outfit
	_level.text = tr("TAHAP %d") % int(Game.save["level"])
	_exp.value = int(Game.save["exp"]) % Game.EXP_PER_LEVEL
	_coins.text = tr("SYILING: %d") % int(Game.save["coins"])


# ------------------------------------------------------------------ menu
func _build_menu(_left: Control) -> void:
	_catcher = Control.new()
	UI.full(_catcher)
	_catcher.visible = false
	_catcher.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			set_menu_open(false))
	add_child(_catcher)
	move_child(_catcher, 0)
	_menu = UI.panel()
	_menu.visible = false
	_menu.z_index = 5
	var col := UI.vbox(6)
	if show_map_button:
		col.add_child(_item(UI.tex("res://assets/icons/peta.png"), "Kembali ke Peta", func(): Game.goto("peta")))
	if world:
		col.add_child(_item(UI.tex("res://assets/icons/peta.png"), "Peta Dunia  (M)", func(): Game.main.open_map(world)))
	col.add_child(_item(UI.tex("res://assets/icons/nota.png"), "Nota Alif", func(): Game.main.open_nota()))
	col.add_child(_item(BegPanel.icon(), "Beg Alif", func(): Game.main.open_beg()))
	if world:
		col.add_child(_item(UI.tex("res://assets/portraits/pau_happy.png"), "Tenang dengan Pau", func(): Game.main.open_calm()))
	col.add_child(_item(UI.tex("res://assets/icons/mahkota.png"), "Papan Markah", func(): Game.main.open_papan()))
	col.add_child(_item(UI.tex("res://assets/icons/tetapan.png"), "Tetapan", func(): Game.main.open_settings()))
	_menu.add_child(col)
	add_child(_menu)


func _item(icon: Texture2D, text: String, action: Callable) -> Button:
	var b := UI.button("  " + tr(text), "", 300)
	b.icon = icon
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.custom_minimum_size.y = 58
	b.pressed.connect(func():
		set_menu_open(false)
		Sfx.play("select", -6.0)
		action.call())
	return b


func set_menu_open(on: bool) -> void:
	if on and Game.is_locked():
		return
	_catcher.visible = on
	_menu.visible = on
	_menu_btn.theme_type_variation = "Primary" if on else ""
	if on:
		Sfx.play("pop", -8.0)
		_menu.modulate.a = 0.0
		var y: float = _menu_btn.global_position.y + _menu_btn.size.y + 6  # under the button (the location box can grow)
		_menu.position.x = 16
		_menu.position.y = y - 12
		var t := create_tween().set_parallel()
		t.tween_property(_menu, "modulate:a", 1.0, 0.15)
		t.tween_property(_menu, "position:y", y, 0.15)


func is_menu_open() -> bool:
	return _menu != null and _menu.visible


func _process(_d: float) -> void:
	if _menu and _menu.visible and Game.is_locked():
		set_menu_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if is_menu_open() and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		set_menu_open(false)
		get_viewport().set_input_as_handled()


## three bars (the "hamburger"), drawn so it needs no font glyph
static func _bars_icon() -> Texture2D:
	var img := Image.create(26, 22, false, Image.FORMAT_RGBA8)
	for bar in 3:
		img.fill_rect(Rect2i(0, bar * 9, 26, 4), Color(1, 0.95, 0.85))
	return ImageTexture.create_from_image(img)
