extends RefCounted
## "Kaca Senja" look for the login card: a frosted glass panel (the picture
## behind is blurred through it), white text, round gold buttons.

const UI = preload("res://scripts/ui/ui.gd")

const BLUR := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float spread = 2.5;
void fragment() {
	vec4 sum = vec4(0.0);
	float w = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float k = exp(-float(x * x + y * y) / 8.0);
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * spread) * k;
			w += k;
		}
	}
	COLOR = vec4(mix(sum.rgb / w, COLOR.rgb, COLOR.a), 1.0);
}
"""
const TEXT := Color.WHITE
const SHADOW := Color(0, 0, 0, 0.5)
const GOLD_TOP := Color("ffcf5c")
const GOLD_EDGE := Color("b06f12")
const BROWN := Color("3a2205")

static var _shader: Shader


## the glass card itself
static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := UI.sb(Color(1, 0.97, 0.91, 0.2), Color(1, 0.9, 0.67, 0.7), 2, 22, 28)
	p.add_theme_stylebox_override("panel", s)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BLUR
	var m := ShaderMaterial.new()
	m.shader = _shader
	p.material = m
	return p


## white text with a soft shadow so it reads on the glass
static func text(l: Control) -> void:
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)


static func field(e: LineEdit) -> void:
	var n := UI.sb(Color(1, 0.98, 0.94, 0.94), Color(0, 0, 0, 0), 0, 12, 10)
	n.content_margin_left = 14
	var f := n.duplicate() as StyleBoxFlat
	f.border_color = UI.GOLD
	f.set_border_width_all(3)
	f.bg_color = Color.WHITE
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", f)


## the round gold button (Log masuk, Teruskan)
static func gold(b: Button) -> void:
	var n := UI.sb(GOLD_TOP, GOLD_EDGE, 0, 26, 10)
	n.border_width_bottom = 4
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color("ffdc7e")
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color("f0a92c")
	p.border_width_bottom = 1
	p.border_width_top = 3
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color(1, 0.95, 0.85, 0.35)
	d.border_color = Color(0, 0, 0, 0.15)
	_styles(b, n, h, p, d)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, BROWN)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))


## the clear outlined button (Daftar akaun baharu)
static func outline(b: Button) -> void:
	var n := UI.sb(Color(1, 1, 1, 0.12), Color(1, 0.94, 0.82, 0.85), 2, 26, 10)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(1, 1, 1, 0.24)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(1, 1, 1, 0.32)
	_styles(b, n, h, p, n)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, TEXT)


## Flat buttons and links: white, not the usual light blue
static func link(b: BaseButton) -> void:
	for k in ["font_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, TEXT)
	b.add_theme_color_override("font_hover_color", UI.GOLD)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	b.add_theme_constant_override("outline_size", 4)


static func _styles(b: Button, n: StyleBox, h: StyleBox, p: StyleBox, d: StyleBox) -> void:
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", UI.sb(Color(0, 0, 0, 0), Color.WHITE, 3, 28, 0))
