extends RefCounted
## Shared layout for the login and register screens: the EXPLO-STORY logo and
## tagline on the left, the card (the game's usual panel) on the right, plus a
## few small pieces that keep both cards tidy and alike.

const UI = preload("res://scripts/ui/ui.gd")
const LOGO := "res://assets/ui/logo_explostory.png"


## the EXPLO-STORY logo (same picture as the title screen) and the tagline, top left
static func logo(width: float = 540.0) -> Control:
	var box := UI.vbox(6)
	box.position = Vector2(56, 70)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(LOGO):
		var l := TextureRect.new()
		l.name = "Logo"
		l.texture = load(LOGO)
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		l.custom_minimum_size = Vector2(width, width * 224.0 / 720.0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	else:
		box.add_child(UI.label("EXPLO-STORY", "Logo"))
	var tag := UI.label("Terokai Sejarah & Warisan Malaysia", "Heading")
	tag.add_theme_color_override("font_color", Color.WHITE)
	tag.add_theme_color_override("font_outline_color", Color(0.23, 0.12, 0.05))
	tag.add_theme_constant_override("outline_size", 10)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size.x = width
	box.add_child(tag)
	return box


## holds the card centred in a strip on the right
static func right(card: Control, strip: float) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	c.offset_left = -strip
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(card)
	return c


## the card's title, centred, with a thin gold rule under it
static func heading(col: VBoxContainer, text: String) -> void:
	var t := UI.label(text, "Heading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(rule(UI.GOLD, 0.6))


## a thin line across the card
static func rule(c: Color, alpha: float = 0.35) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(c, alpha)
	r.custom_minimum_size.y = 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## "──── atau ────" between the main button and the others
static func or_line(text: String = "atau") -> HBoxContainer:
	var row := UI.hbox(10)
	for i in 2:
		var r := rule(UI.CREAM)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
		if i == 0:
			row.add_child(UI.label(text, "Small"))
	return row


## a field label above its box: small, in the card's gold
static func field_label(text: String) -> Label:
	var l := UI.label(text, "Small")
	l.add_theme_color_override("font_color", Color(UI.GOLD, 0.9))
	return l
