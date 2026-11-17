extends BoxContainer
## The controls of a game as pictures, one row per action: [key] Lari.
## Shows what this player holds: a controller (pad glyphs from pad.gd), the
## on-screen buttons of a phone, or the keyboard. Rebuilds itself when that
## changes (a pad plugged in, Tetapan > Kawalan changed).
##
## rows: [[action, label], ...]; action is one of ACTIONS.

const UI = preload("res://scripts/ui/ui.gd")
const Pad = preload("res://scripts/ui/pad.gd")

## per device: the glyphs of an action. Pad glyph names come from pad.gd;
## anything else is drawn as a key cap.
const ACTIONS := {
	"move": {"pad": ["stick"], "touch": ["D-pad"], "keys": ["W", "A", "S", "D"]},
	"run": {"pad": ["r2"], "touch": ["B"], "keys": ["Shift"]},
	"interact": {"pad": ["cross"], "touch": ["A"], "keys": ["Space"]},
	"left_right": {"pad": ["dpad"], "touch": ["KIRI", "KANAN"], "keys": ["A", "D"]},
	"pick": {"pad": ["dpad", "cross"], "touch": ["Ketik"], "keys": ["Klik"]},
	"pause": {"pad": ["options"], "touch": [], "keys": ["Esc"]},
}

var rows: Array = []
var ink := false   ## dark text, for a paper card
var across := false   ## all rows on one line (a top bar)
var _device := ""


func _init(r: Array = [], on_paper := false, one_line := false) -> void:
	rows = r
	ink = on_paper
	across = one_line
	vertical = not one_line
	add_theme_constant_override("separation", 18 if one_line else 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


func _process(_d: float) -> void:
	if device() != _device:
		_build()


static func device() -> String:
	if Game.pad_mode():
		return "pad"
	if Game.controls_on_screen():
		return "touch"
	return "keys"


func _build() -> void:
	_device = device()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for r in rows:
		var glyphs: Array = ACTIONS[r[0]][_device]
		if glyphs.is_empty():
			continue
		var row := UI.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caps := UI.hbox(4)
		if not across:
			caps.custom_minimum_size.x = 132
		caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for g in glyphs:
			caps.add_child(Pad.glyph(g, 30) if _device == "pad" else key_cap(g))
		row.add_child(caps)
		var l := UI.label(tr(str(r[1])), "Ink" if ink else "")
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		add_child(row)


## a keyboard key or an on-screen button: a light plate with its name
static func key_cap(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := UI.sb(UI.CREAM, Color("9a8a6a"), 2, 5, 2)
	sb.border_width_bottom = 4
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(28, 30)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = TranslationServer.translate(text)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UI.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static var _arrows := {}


## a filled triangle pointing "left", "right", "up" or "down" (the fonts have no ◀ ▶ ▾)
static func arrow(dir: String, px: int = 22, col: Color = UI.CREAM) -> Texture2D:
	var key := "%s%d%s" % [dir, px, col.to_html()]
	if _arrows.has(key):
		return _arrows[key]
	var pts: Array = {"right": [Vector2(0.2, 0.1), Vector2(0.9, 0.5), Vector2(0.2, 0.9)],
		"left": [Vector2(0.8, 0.1), Vector2(0.1, 0.5), Vector2(0.8, 0.9)],
		"down": [Vector2(0.1, 0.25), Vector2(0.9, 0.25), Vector2(0.5, 0.85)],
		"up": [Vector2(0.1, 0.75), Vector2(0.9, 0.75), Vector2(0.5, 0.15)]}[dir]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	const SS := 4
	for y in px:
		for x in px:
			var hit := 0
			for sy in SS:
				for sx in SS:
					var p := Vector2(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS) / px
					if Geometry2D.point_is_inside_triangle(p, pts[0], pts[1], pts[2]):
						hit += 1
			if hit > 0:
				img.set_pixel(x, y, Color(col, col.a * hit / float(SS * SS)))
	var t := ImageTexture.create_from_image(img)
	_arrows[key] = t
	return t
