extends RefCounted
## Shared UI kit: colours, theme and small widget helpers.
## Look follows the GDS v0.2 mockups: navy panels, wooden borders,
## chunky pixel headings and green primary buttons.

const NAVY := Color("1e2433")
const NAVY2 := Color("2b3450")
const NAVY_T := Color(0.117, 0.141, 0.2, 0.94)
const WOOD := Color("8a5a34")
const WOOD_D := Color("5a381e")
const WOOD_L := Color("b07a48")
const CREAM := Color("f6efdc")
const CREAM_D := Color("e6dcc0")
const INK := Color("2b2420")
const GOLD := Color("f0c24a")
const GREEN := Color("4f9a45")
const GREEN_D := Color("2f6a2c")
const RED := Color("c94a4a")
const BLUE := Color("3f7fc4")
const GREY := Color("8a8a96")

const FONTS := {
	"lexend": ["res://assets/fonts/lexend-latin-400-normal.woff2", "res://assets/fonts/lexend-latin-700-normal.woff2"],
	"atkinson": ["res://assets/fonts/atkinson-hyperlegible-latin-400-normal.woff2", "res://assets/fonts/atkinson-hyperlegible-latin-700-normal.woff2"],
	"opendyslexic": ["res://assets/fonts/opendyslexic-latin-400-normal.woff2", "res://assets/fonts/opendyslexic-latin-700-normal.woff2"],
}
const FONT_NAMES := {"lexend": "Lexend", "atkinson": "Atkinson Hyperlegible", "opendyslexic": "OpenDyslexic"}
const PIXEL_FONT := "res://assets/fonts/pixelify-sans-latin-700-normal.woff2"
const SIZES := [18, 22, 26]


static func sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 6, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s


static func _btn_styles(theme: Theme, type: String, base: Color, dark: Color, light: Color) -> void:
	var normal := sb(base, dark, 3, 6, 10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 0
	normal.shadow_offset = Vector2(0, 3)
	normal.border_width_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = light
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = dark
	pressed.border_width_bottom = 3
	pressed.border_width_top = 6
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.45, 0.45, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.34)
	var focus := sb(Color(0, 0, 0, 0), GOLD, 3, 8, 0)
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)
	theme.set_stylebox("focus", type, focus)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_color("font_color", type, CREAM)
	theme.set_color("font_hover_color", type, Color.WHITE)
	theme.set_color("font_pressed_color", type, CREAM)
	theme.set_color("font_focus_color", type, CREAM)
	theme.set_color("font_disabled_color", type, Color(0.82, 0.82, 0.85))
	theme.set_color("icon_normal_color", type, CREAM)


static func build_theme(settings: Dictionary) -> Theme:
	var t := Theme.new()
	# Panels
	var dark := sb(NAVY_T, WOOD, 4, 8, 18)
	dark.shadow_color = Color(0, 0, 0, 0.4)
	dark.shadow_size = 6
	t.set_stylebox("panel", "PanelContainer", dark)
	t.set_stylebox("panel", "Panel", dark)
	t.set_type_variation("Paper", "PanelContainer")
	var paper := sb(CREAM, WOOD, 4, 8, 18)
	paper.shadow_color = Color(0, 0, 0, 0.35)
	paper.shadow_size = 6
	t.set_stylebox("panel", "Paper", paper)
	t.set_type_variation("Bar", "PanelContainer")
	var bar := sb(NAVY, WOOD_D, 0, 0, 10)
	bar.border_width_bottom = 4
	bar.content_margin_left = 24
	bar.content_margin_right = 24
	t.set_stylebox("panel", "Bar", bar)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", sb(CREAM, WOOD_D, 3, 6, 8))
	t.set_type_variation("CardGood", "PanelContainer")
	t.set_stylebox("panel", "CardGood", sb(Color("dff0d4"), GREEN_D, 3, 6, 8))
	t.set_type_variation("CardSel", "PanelContainer")
	t.set_stylebox("panel", "CardSel", sb(Color("fff3c4"), GOLD, 4, 6, 8))
	t.set_type_variation("CardLocked", "PanelContainer")
	t.set_stylebox("panel", "CardLocked", sb(Color(0.25, 0.25, 0.3, 0.9), Color(0.15, 0.15, 0.18), 3, 6, 8))
	t.set_type_variation("Slot", "PanelContainer")
	t.set_stylebox("panel", "Slot", sb(Color(0.17, 0.2, 0.3, 0.92), Color("7d6a4c"), 3, 8, 10))
	t.set_type_variation("SlotHot", "PanelContainer")
	t.set_stylebox("panel", "SlotHot", sb(Color(0.22, 0.27, 0.38, 0.95), GOLD, 4, 8, 10))
	t.set_type_variation("SlotBad", "PanelContainer")
	t.set_stylebox("panel", "SlotBad", sb(Color(0.35, 0.18, 0.2, 0.95), RED, 4, 8, 10))
	t.set_type_variation("SlotGood", "PanelContainer")
	t.set_stylebox("panel", "SlotGood", sb(Color(0.16, 0.3, 0.2, 0.95), GREEN, 4, 8, 10))
	t.set_type_variation("Glass", "PanelContainer")
	t.set_stylebox("panel", "Glass", sb(Color(0.96, 0.92, 0.86, 0.9), WOOD, 4, 10, 22))
	t.set_type_variation("Bubble", "PanelContainer")
	t.set_stylebox("panel", "Bubble", sb(Color(1, 1, 1, 0.97), INK, 3, 12, 12))
	# Buttons
	_btn_styles(t, "Button", WOOD, WOOD_D, WOOD_L)
	t.set_type_variation("Primary", "Button")
	_btn_styles(t, "Primary", GREEN, GREEN_D, Color("63b358"))
	t.set_type_variation("Blue", "Button")
	_btn_styles(t, "Blue", BLUE, Color("2a5a90"), Color("5596da"))
	t.set_type_variation("Flat", "Button")
	t.set_stylebox("normal", "Flat", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6))
	t.set_stylebox("hover", "Flat", sb(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 6, 6))
	t.set_stylebox("pressed", "Flat", sb(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 0, 6, 6))
	t.set_stylebox("focus", "Flat", StyleBoxEmpty.new())
	t.set_color("font_color", "Flat", Color("9fd0ff"))
	t.set_color("font_hover_color", "Flat", Color.WHITE)
	# Inputs
	var le := sb(CREAM, WOOD_D, 3, 6, 10)
	t.set_stylebox("normal", "LineEdit", le)
	var lef := sb(Color.WHITE, GOLD, 3, 6, 10)
	t.set_stylebox("focus", "LineEdit", lef)
	var led := sb(CREAM_D, GREY, 3, 6, 10)
	t.set_stylebox("read_only", "LineEdit", led)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.4, 0.36, 0.32))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_type_variation("Invalid", "LineEdit")
	t.set_stylebox("normal", "Invalid", sb(Color("fbe3e0"), RED, 3, 6, 10))
	t.set_stylebox("focus", "Invalid", sb(Color("fbe3e0"), RED, 4, 6, 10))
	# Progress
	t.set_stylebox("background", "ProgressBar", sb(Color(0.08, 0.1, 0.16), Color(0.05, 0.05, 0.08), 2, 4, 0))
	t.set_stylebox("fill", "ProgressBar", sb(Color("4aa3e8"), Color(0, 0, 0, 0), 0, 4, 0))
	t.set_type_variation("Good", "ProgressBar")
	t.set_stylebox("fill", "Good", sb(Color("62b85a"), Color(0, 0, 0, 0), 0, 4, 0))
	t.set_type_variation("Warn", "ProgressBar")
	t.set_stylebox("fill", "Warn", sb(Color("e0a040"), Color(0, 0, 0, 0), 0, 4, 0))
	# Labels
	t.set_color("font_color", "Label", CREAM)
	t.set_type_variation("Title", "Label")
	t.set_color("font_color", "Title", GOLD)
	t.set_color("font_outline_color", "Title", Color(0.08, 0.06, 0.1))
	t.set_constant("outline_size", "Title", 10)
	t.set_type_variation("Logo", "Label")
	t.set_color("font_color", "Logo", GOLD)
	t.set_color("font_outline_color", "Logo", Color(0.08, 0.06, 0.1))
	t.set_constant("outline_size", "Logo", 10)
	t.set_type_variation("Heading", "Label")
	t.set_color("font_color", "Heading", GOLD)
	t.set_type_variation("Ink", "Label")
	t.set_color("font_color", "Ink", INK)
	t.set_type_variation("InkSmall", "Label")
	t.set_color("font_color", "InkSmall", Color(0.3, 0.26, 0.22))
	t.set_type_variation("InkHeading", "Label")
	t.set_color("font_color", "InkHeading", WOOD_D)
	t.set_type_variation("Small", "Label")
	t.set_color("font_color", "Small", Color(0.85, 0.85, 0.88))
	t.set_type_variation("Good", "Label")
	t.set_color("font_color", "Good", Color("8fe08a"))
	t.set_type_variation("Bad", "Label")
	t.set_color("font_color", "Bad", Color("ff9a8a"))
	for typ in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", typ, CREAM)
		t.set_color("font_hover_color", typ, Color.WHITE)
		t.set_color("font_pressed_color", typ, GOLD)
		t.set_stylebox("focus", typ, StyleBoxEmpty.new())
	t.set_color("font_color", "LinkButton", Color("9fd0ff"))
	t.set_color("font_hover_color", "LinkButton", Color.WHITE)
	t.set_stylebox("panel", "PopupMenu", sb(NAVY, WOOD, 3, 6, 8))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_stylebox("panel", "TooltipPanel", sb(NAVY, GOLD, 2, 4, 8))
	apply_settings(t, settings)
	return t


static func apply_settings(t: Theme, settings: Dictionary) -> void:
	var key: String = settings.get("font", "lexend")
	if not FONTS.has(key):
		key = "lexend"
	var reg: Font = load(FONTS[key][0])
	var bold: Font = load(FONTS[key][1])
	var pixel: Font = load(PIXEL_FONT)
	var size_idx: int = clampi(int(settings.get("text_size", 1)), 0, 2)
	var base: int = SIZES[size_idx]
	t.default_font = reg
	t.default_font_size = base
	for typ in ["Button", "Primary", "Blue", "Flat", "CheckBox", "CheckButton", "OptionButton", "LinkButton"]:
		t.set_font("font", typ, bold)
		t.set_font_size("font_size", typ, base)
	# headings and big numbers use the chosen reading font: the pixel font's
	# digits (5 vs S) were hard to read; it stays only on the game logo
	t.set_font("font", "Logo", pixel)
	t.set_font_size("font_size", "Logo", int(base * 2.4))
	t.set_font("font", "Title", bold)
	t.set_font_size("font_size", "Title", int(base * 2.2))
	t.set_font("font", "Heading", bold)
	t.set_font_size("font_size", "Heading", int(base * 1.25))
	t.set_font("font", "InkHeading", bold)
	t.set_font_size("font_size", "InkHeading", int(base * 1.25))
	t.set_font_size("font_size", "Small", int(base * 0.8))
	t.set_font_size("font_size", "InkSmall", int(base * 0.8))
	t.set_font("font", "Good", bold)
	t.set_font("font", "Bad", bold)


# ------------------------------------------------------------------ widgets
static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, variation: String = "", min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func icon(path: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(path)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep: int = 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func spacer(h: bool = true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	full(cc)
	cc.add_child(c)
	return cc


static func dim(alpha: float = 0.55) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.04, 0.08, alpha)
	full(r)
	return r


static func bg_image(path: String, modulate_col: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.modulate = modulate_col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(r)
	return r


## Top bar used on menu screens (mockup: "EXPLO-STORY | TITLE").
static func header_bar(title: String, subtitle: String = "") -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var bar := panel("Bar")
	var row := hbox(24)
	var brand := label("EXPLO-STORY", "Heading")
	brand.add_theme_color_override("font_color", Color("f0a060"))
	row.add_child(brand)
	var t := label(title, "Heading")
	t.add_theme_color_override("font_color", CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(t)
	var pad := Control.new()
	pad.custom_minimum_size.x = brand.get_minimum_size().x + 60
	row.add_child(pad)
	bar.add_child(row)
	col.add_child(bar)
	if subtitle != "":
		var sub := panel("Bar")
		var sl := label(subtitle, "Small")
		sl.add_theme_color_override("font_color", GOLD)
		sub.add_child(sl)
		col.add_child(sub)
	return col


## Sprite-sheet frame (characters are 3x4 sheets of 16x24).
static func sheet_frame(sheet_path: String, col: int = 0, row: int = 0, w: int = 16, h: int = 24) -> Texture2D:
	var base := tex(sheet_path)
	if base == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = base
	a.region = Rect2(col * w, row * h, w, h)
	return a


static func icon_button(icon_path: String, variation: String = "", size: Vector2 = Vector2(72, 64), text: String = "") -> Button:
	var b := button(text, variation)
	b.icon = tex(icon_path)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = size
	return b
