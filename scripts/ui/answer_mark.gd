extends RefCounted
## After a question is answered: the right answer turns green with a tick, a
## wrong pick red with a cross, the rest fade. Same look in Pesta Warisan, the
## subtopic quizzes, the Ujian Bab, Bilik Pertarungan and the Gelanggang.
## The tick and cross are drawn (the game's fonts have no such glyphs).

const UI = preload("res://scripts/ui/ui.gd")

const GREEN := Color("3f9a3a")
const GREEN_D := Color("23601f")
const GREEN_BG := Color("e1f2da")
const RED := Color("c9433b")
const RED_D := Color("7f221c")
const RED_BG := Color("f8e0dc")
const INK_GREEN := Color("1f5a1c")
const INK_RED := Color("8e2a22")
const BADGE := "AnswerBadge"


## colour a choice button green (right) or red (wrong) and put the mark on it
static func mark(b: Button, right: bool) -> void:
	var base := GREEN if right else RED
	var dark := GREEN_D if right else RED_D
	var st := UI.sb(base, dark, 3, 6, 10)
	st.content_margin_left = 18
	st.content_margin_right = 58
	st.border_width_bottom = 6
	for s in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(s, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.modulate = Color.WHITE
	var old := b.get_node_or_null(BADGE)
	if old:
		old.free()
	var badge := Badge.new()
	badge.name = BADGE
	badge.right = right
	badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	badge.offset_left = -48
	badge.offset_right = -14
	badge.offset_top = -17
	badge.offset_bottom = 17
	b.add_child(badge)


## a choice that was neither right nor picked: still readable, but quiet
static func fade(b: Button) -> void:
	b.modulate = Color(1, 1, 1, 0.65)


## back to a plain button (the button is used again for the next question)
static func clear(b: Button) -> void:
	for s in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
		b.remove_theme_stylebox_override(s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.remove_theme_color_override(c)
	b.modulate = Color.WHITE
	var old := b.get_node_or_null(BADGE)
	if old:
		old.free()


## mark a whole set of choices: right is the answer, picked what the player chose (-1 = none)
static func reveal(buttons: Array, right: int, picked: int) -> void:
	for i in buttons.size():
		var b: Button = buttons[i]
		b.disabled = true
		if i == right:
			mark(b, true)
		elif i == picked:
			mark(b, false)
		else:
			fade(b)


## one line of a result: [tick] Jawapan betul: X  or  [cross] Jawapan kau: Y
static func row(text: String, right: bool, width: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UI.sb(GREEN_BG if right else RED_BG, GREEN if right else RED, 2, 6, 8)
	st.content_margin_left = 10
	st.content_margin_right = 12
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(10)
	var badge := Badge.new()
	badge.right = right
	badge.custom_minimum_size = Vector2(28, 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var l := UI.label(text, "Ink", true)
	l.add_theme_color_override("font_color", INK_GREEN if right else INK_RED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0.0:
		l.custom_minimum_size.x = width - 60.0
	h.add_child(l)
	p.add_child(h)
	return p


## a white disc with a green tick or a red cross
class Badge extends Control:
	var right := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		draw_circle(c, r, Color.WHITE)
		var col: Color = GREEN if right else RED
		draw_arc(c, r - 1.0, 0, TAU, 32, col, 2.0, true)
		var w := maxf(3.0, r * 0.28)
		if right:
			draw_polyline(PackedVector2Array([c + Vector2(-0.5, 0.0) * r, c + Vector2(-0.12, 0.38) * r, c + Vector2(0.52, -0.36) * r]), col, w, true)
		else:
			var k := r * 0.4
			draw_line(c + Vector2(-k, -k), c + Vector2(k, k), col, w, true)
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), col, w, true)
