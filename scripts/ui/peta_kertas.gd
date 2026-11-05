extends "res://scripts/ui/modal.gd"
## The old paper map Mak Som gives Alif: the Bab 1 island with the mission
## flags joined up in ink, in order, what lies beyond as a dark shape, and how
## to read it. Shown once, in scripts/world/kampung_intro.gd. The paper is
## tools/gen_peta_kertas.py.

const PAPER := "res://assets/ui/peta_kertas.png"
const INK := Color(0.45, 0.16, 0.1)
## the island picture as an old drawn map: the sea lets the paper show
## through, the land turns sepia ink
var OLD_MAP := _old_map()


static func _old_map() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
const vec3 PAPER = vec3(0.93, 0.85, 0.66);
const vec3 INK = vec3(0.33, 0.2, 0.1);
void fragment() {
	vec4 c = COLOR;
	float sea = smoothstep(0.18, 0.38, c.b - c.r) * step(0.4, c.b);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 land = mix(INK, PAPER * 1.04, clamp(l * 1.25, 0.0, 1.0));
	COLOR = vec4(mix(land, PAPER * 0.9, sea), c.a * (1.0 - sea * 0.8));
}
"""
	return s

var world: Node
var view: MapView


func _init() -> void:
	title_text = "PETA BAB 1"
	panel_size = Vector2(1120, 640)


func _build() -> void:
	var row := UI.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(720, 405)  # the paper's own 16:9
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(PAPER):
		var paper := TextureRect.new()
		paper.texture = load(PAPER)
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_SCALE
		paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		paper.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(paper)
	view = MapView.new()
	view.world = world
	view.follow_player = false
	view.show_names = false
	view.icon_scale = 1.3
	var ink := ShaderMaterial.new()  # drawn in ink on the paper, not a photo stuck on
	ink.shader = OLD_MAP
	view.material = ink
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 66
	view.offset_top = 50
	view.offset_right = -66
	view.offset_bottom = -50
	holder.add_child(view)
	var route := Route.new()
	route.view = view
	route.set_anchors_preset(Control.PRESET_FULL_RECT)
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(route)
	row.add_child(holder)

	var how := UI.vbox(12)
	how.custom_minimum_size = Vector2(350, 0)
	how.add_child(UI.label("Macam ni nak baca", "Heading"))
	var touch := Game.controls_on_screen()
	for line in [
		"Bendera bernombor tu misi kamu. Ikut turutan, 1.1 sampai 1.4. Satu misi, satu subtopik.",
		"Tanda seru (!) tu tugasan. Anak panah emas tunjuk jalan, ikut je.",
		"Klik peta kecil kat bucu skrin untuk peta penuh." if touch else "Klik peta kecil kat bucu skrin, atau tekan M, untuk peta penuh.",
		"Sesat? Klik Pau untuk petunjuk. Peta ni pun boleh dibuka bila-bila masa dalam Menu." if touch else "Sesat? Klik Pau atau tekan H untuk petunjuk. Peta ni pun boleh dibuka bila-bila masa dalam Menu.",
	]:
		how.add_child(UI.label(line, "", true))
	row.add_child(how)
	content.add_child(row)

	Sfx.play("whoosh", -10.0, 1.2)  # paper unfolding
	await get_tree().process_frame
	view.set_zoom(0.0)


## the mission flags joined by a dashed ink line, each with its number
class Route extends Control:
	var view: MapView

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pts: Array[Vector2] = []
		for p in MapView.legend()["places"]:
			if str(p.get("zone", "")).begins_with("1_"):
				pts.append(view.to_screen(Vector2(p["at"][0], p["at"][1]) + Vector2(0.5, 0.5)))
		for i in pts.size() - 1:
			draw_dashed_line(pts[i], pts[i + 1], Color(INK, 0.9), 3.0, 8.0)
		var font := get_theme_default_font()
		for i in pts.size():
			draw_circle(pts[i] + Vector2(14, -14), 11, Color(0.96, 0.9, 0.74))
			draw_arc(pts[i] + Vector2(14, -14), 11, 0, TAU, 24, INK, 2.0)
			draw_string(font, pts[i] + Vector2(10, -8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
