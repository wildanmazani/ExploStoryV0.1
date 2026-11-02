extends "res://scripts/ui/modal.gd"
## The carved stone map Mak Som gives Alif: the Bab 1 island with the mission
## flags joined up in order, what lies beyond as a dark shape, and how to read it.
## Shown once, in scripts/world/kampung_intro.gd.

const SLAB := "res://assets/ui/peta_batu.png"

var world: Node
var view: MapView


func _init() -> void:
	title_text = "PETA BATU BAB 1"
	panel_size = Vector2(1120, 640)


func _build() -> void:
	var row := UI.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(720, 405)  # the slab's own 16:9
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(SLAB):
		var slab := TextureRect.new()
		slab.texture = load(SLAB)
		slab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slab.stretch_mode = TextureRect.STRETCH_SCALE
		slab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slab.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(slab)
	view = MapView.new()
	view.world = world
	view.follow_player = false
	view.show_names = false
	view.icon_scale = 1.3
	view.modulate = Color(0.8, 0.8, 0.72)  # carved, not printed
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

	Sfx.play("whoosh", -10.0, 0.8)
	await get_tree().process_frame
	view.set_zoom(0.0)


## the mission flags joined by a dashed gold line, each with its number
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
			draw_dashed_line(pts[i], pts[i + 1], Color(1, 0.85, 0.3, 0.9), 3.0, 8.0)
		var font := get_theme_default_font()
		for i in pts.size():
			draw_circle(pts[i] + Vector2(14, -14), 10, Color(0.1, 0.1, 0.14))
			draw_string(font, pts[i] + Vector2(10, -8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5))
