class_name MapView
extends Control
## Draws Dunia Explo-Story from above: terrain at 1 px per tile, scaled up,
## with icons on top (Alif, next task "!", zone flags, people, landmarks).
## Used by the corner mini map and the full map overlay. Icons keep their
## screen size at every zoom so they stay easy to read.

const UI = preload("res://scripts/ui/ui.gd")
const LEGEND_PATH := "res://data/map_legend.json"

const COL_SEA := Color("3b8fc4")
const COL_SEA_D := Color("3685b9")
const COL_SAND := Color("e8d49a")
const COL_GRASS := Color("6dbb4f")
const COL_PATH := Color("c79a62")
const COL_STONE := Color("a7a39c")
const COL_TREE := Color("2f7a35")
const COL_ROOF := Color("8a4f33")
const COL_WOOD := Color("9c6a3c")
const COL_MIST := Color(0.55, 0.4, 0.75, 0.55)
const COL_DONE := Color("5fd068")
const COL_OPEN := Color("f0c24a")
const COL_LOCKED := Color("8a8a96")

var world: Node                ## world.gd
var px_per_tile: float = 5.0   ## zoom
var center: Vector2 = Vector2(40, 30)  ## view centre, in tiles
var follow_player: bool = true
var show_names: bool = false
var icon_scale: float = 1.0
var highlight: Vector2 = Vector2(-1, -1)  ## pulsing ring (legend tap)

var _t: float = 0.0
var _tex: Texture2D
var _map_size: Vector2 = Vector2(80, 60)
var _icons := {}  ## path -> Texture2D

static var _legend: Dictionary = {}


static func legend() -> Dictionary:
	if _legend.is_empty():
		_legend = JSON.parse_string(FileAccess.get_file_as_string(LEGEND_PATH))
	return _legend


## 1 px per tile picture of the world: terrain colours, trees and buildings
## darker, jetty planks, the mist area tinted purple.
static func build_texture(w: Node) -> Texture2D:
	var tw: int = w.terrain.width
	var th: int = w.terrain.height
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	var cols := {
		TerrainBuilder.SEA: COL_SEA, TerrainBuilder.SAND: COL_SAND, TerrainBuilder.GRASS: COL_GRASS,
		TerrainBuilder.PATH: COL_PATH, TerrainBuilder.STONE: COL_STONE,
	}
	for y in th:
		for x in tw:
			var c := Vector2i(x, y)
			var t: int = w.terrain.terrain_at(c)
			var col: Color = cols.get(t, COL_GRASS)
			if t == TerrainBuilder.SEA and (x + y) % 7 == 0:
				col = COL_SEA_D
			if w.walk_over.has(c):
				col = COL_WOOD
			elif w.blocked.has(c) and t != TerrainBuilder.SEA:
				col = COL_TREE if t == TerrainBuilder.GRASS else COL_ROOF
			img.set_pixelv(c, col)
	for a in w.areas:
		if a["id"] == "kabus":
			var r: Array = a["rect"]
			for y in range(r[1], r[3] + 1):
				for x in range(r[0], r[2] + 1):
					if x < tw and y < th:
						img.set_pixel(x, y, img.get_pixel(x, y).blend(COL_MIST))
	return ImageTexture.create_from_image(img)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if world:
		_tex = world.map_texture
		_map_size = Vector2(world.terrain.width, world.terrain.height)


func _process(delta: float) -> void:
	_t += delta
	if follow_player and world and is_instance_valid(world.player):
		center = Vector2(world.player.cell) + Vector2(0.5, 0.5)
	clamp_center()
	queue_redraw()


func fit_scale() -> float:
	return minf(size.x / _map_size.x, size.y / _map_size.y)


## keep the view on the map; when the map is smaller than the view, centre it
func clamp_center() -> void:
	var half := size / (2.0 * px_per_tile)
	for i in 2:
		if half[i] * 2.0 >= _map_size[i]:
			center[i] = _map_size[i] / 2.0
		else:
			center[i] = clampf(center[i], half[i], _map_size[i] - half[i])


func to_screen(tile: Vector2) -> Vector2:
	return size / 2.0 + (tile - center) * px_per_tile


func to_tile(screen: Vector2) -> Vector2:
	return center + (screen - size / 2.0) / px_per_tile


func set_zoom(ppt: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	var before := to_tile(anchor) if anchor.x >= 0 else center
	px_per_tile = clampf(ppt, fit_scale(), 24.0)
	if anchor.x >= 0:  # keep the point under the cursor still
		center += before - to_tile(anchor)
	clamp_center()


# ------------------------------------------------------------------ status
## "done" / "open" / "locked" for a Bab 1 zone
static func zone_status(zid: String) -> String:
	if Game.zone_done(zid):
		return "done"
	return "open" if Game.zone_unlocked(zid) else "locked"


static func status_color(st: String) -> Color:
	return {"done": COL_DONE, "open": COL_OPEN}.get(st, COL_LOCKED)


static func status_text(st: String) -> String:
	return {"done": "SIAP", "open": "TERBUKA", "locked": "BERKUNCI"}.get(st, "")


## Where the next task is: the visible "!" markers, else the next zone.
func objectives() -> Array:
	var out: Array = []
	if world == null:
		return out
	for id in world.runner.markers:
		if world.runner.markers[id].visible:
			out.append(spot_tile(id))
	if out.is_empty():
		var nz := Game.next_zone()
		for p in legend()["places"]:
			if str(p.get("zone", "")) == nz and nz != "":
				out.append(Vector2(p["at"][0], p["at"][1]) + Vector2(0.5, 0.5))
	return out


func spot_tile(id: String) -> Vector2:
	if world.spots.has(id):
		var sp: Dictionary = world.spots[id]
		return Vector2(sp["pos"][0] + sp["size"][0] / 2.0, sp["pos"][1] + 0.5)
	for at in world.npcs:
		if world.npcs[at].id == id:
			return Vector2(at) + Vector2(0.5, 0.5)
	return Vector2(-1, -1)


func _icon(path: String) -> Texture2D:
	if not _icons.has(path):
		_icons[path] = UI.tex(path)
	return _icons[path]


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_SEA_D)
	if _tex == null or world == null:
		return
	var origin := to_screen(Vector2.ZERO)
	draw_texture_rect(_tex, Rect2(origin, _map_size * px_per_tile), false)
	var s := icon_scale
	var ent: Dictionary = world.entities()

	if show_names:
		var font := get_theme_default_font()
		for a in world.areas:
			var r: Array = a["rect"]
			var p := to_screen(Vector2((r[0] + r[2] + 1) / 2.0, r[1] + 1.2))
			var name_s := str(a["name"]).replace("Zon ", "").to_upper()
			var fs := int(14 * s)
			var w := font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string_outline(font, p - Vector2(w / 2.0, 0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.1, 0.1, 0.15, 0.9))
			draw_string(font, p - Vector2(w / 2.0, 0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.CREAM)

	# chapter gates (locked = padlock)
	for g in ent["gates"]:
		var gp := to_screen(Vector2(g["pos"][0] + 2, g["pos"][1] + 0.5))
		if not g["open"]:
			draw_lock(self, gp, 7 * s)

	# landmarks (signs with an entry in the legend, plus spots like the arena)
	var lm: Dictionary = legend()["landmarks"]
	for sg in ent["signs"]:
		if lm.has(sg["id"]):
			var size_a: Array = sg.get("size", [1, 1])
			var c := Vector2(sg["pos"][0] + size_a[0] / 2.0, sg["pos"][1] - size_a[1] / 2.0 + 1)
			draw_badge(self, to_screen(c), _icon(lm[sg["id"]]["icon"]), 18 * s)
	for id in lm:
		if world.spots.has(id):
			draw_badge(self, to_screen(spot_tile(id)), _icon(lm[id]["icon"]), 18 * s)

	# people
	for at in world.npcs:
		var np := to_screen(Vector2(at) + Vector2(0.5, 0.5))
		draw_circle(np, 3.5 * s, Color(0.1, 0.1, 0.12))
		draw_circle(np, 2.5 * s, UI.CREAM)

	# zone flags
	for p in legend()["places"]:
		if p.has("zone"):
			var st := zone_status(str(p["zone"]))
			draw_flag(self, to_screen(Vector2(p["at"][0], p["at"][1]) + Vector2(0.5, 0.5)), status_color(st), 9 * s)

	# next task
	for o in objectives():
		var op := to_screen(o)
		op = Vector2(clampf(op.x, 10, size.x - 10), clampf(op.y, 16, size.y - 4))  # stays on the edge when off view
		draw_bang(self, op + Vector2(0, -sin(_t * 4.0) * 2.0), 8 * s)

	# legend tap highlight
	if highlight.x >= 0:
		var hp := to_screen(highlight)
		var r := (10.0 + fmod(_t * 18.0, 14.0)) * s
		draw_arc(hp, r, 0, TAU, 32, Color(1, 0.9, 0.4, 1.0 - fmod(_t * 18.0, 14.0) / 14.0), 3.0)

	# Alif (blinks so it is easy to find)
	var me := to_screen(Vector2(world.player.cell) + Vector2(0.5, 0.5))
	var on := fmod(_t, 1.0) < 0.7
	draw_circle(me, 6.0 * s, Color(0.08, 0.08, 0.12))
	draw_circle(me, 4.5 * s, Color("ff5a4a") if on else Color("ffd0c8"))
	draw_arc(me, 6.5 * s, 0, TAU, 20, Color.WHITE, 1.5)


# ------------------------------------------------------------------ symbols
## These also draw the symbols in the legend (any CanvasItem).
static func draw_flag(ci: CanvasItem, p: Vector2, col: Color, h: float) -> void:
	var base := p + Vector2(-h * 0.3, h * 0.5)
	ci.draw_rect(Rect2(base + Vector2(-1, -h * 1.6), Vector2(3, h * 1.6)), Color(0.1, 0.08, 0.06))
	var tri := PackedVector2Array([base + Vector2(1, -h * 1.6), base + Vector2(1 + h * 1.1, -h * 1.25), base + Vector2(1, -h * 0.9)])
	ci.draw_colored_polygon(tri, col)
	ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color(0.1, 0.08, 0.06), 1.5)


static func draw_bang(ci: CanvasItem, p: Vector2, h: float) -> void:
	var r := Rect2(p + Vector2(-h * 0.45, -h * 1.6), Vector2(h * 0.9, h * 1.6))
	ci.draw_rect(r.grow(1.5), Color(0.17, 0.11, 0.06))
	ci.draw_rect(r, Color(1, 0.86, 0.3))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.33, r.size.y * 0.12), Vector2(r.size.x * 0.34, r.size.y * 0.5)), Color(0.35, 0.2, 0.05))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.33, r.size.y * 0.72), Vector2(r.size.x * 0.34, r.size.y * 0.16)), Color(0.35, 0.2, 0.05))


static func draw_lock(ci: CanvasItem, p: Vector2, h: float) -> void:
	ci.draw_arc(p + Vector2(0, -h * 0.35), h * 0.45, PI, TAU, 10, Color(0.15, 0.12, 0.2), 2.5)
	ci.draw_rect(Rect2(p + Vector2(-h * 0.7, -h * 0.35), Vector2(h * 1.4, h * 1.1)), Color(0.55, 0.4, 0.75))
	ci.draw_rect(Rect2(p + Vector2(-h * 0.7, -h * 0.35), Vector2(h * 1.4, h * 1.1)), Color(0.15, 0.12, 0.2), false, 1.5)


static func draw_badge(ci: CanvasItem, p: Vector2, tex: Texture2D, d: float) -> void:
	ci.draw_circle(p, d * 0.62, Color(0.12, 0.14, 0.2, 0.9))
	ci.draw_arc(p, d * 0.62, 0, TAU, 20, UI.GOLD, 1.5)
	if tex:
		ci.draw_texture_rect(tex, Rect2(p - Vector2(d, d) * 0.4, Vector2(d, d) * 0.8), false)


## Small Control that draws one map symbol (for the legend list).
class Symbol extends Control:
	var kind := ""
	var color := Color.WHITE
	var tex: Texture2D

	func _init(k: String, c: Color = Color.WHITE, t: Texture2D = null) -> void:
		kind = k
		color = c
		tex = t
		custom_minimum_size = Vector2(36, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var p := size / 2.0
		match kind:
			"me":
				draw_circle(p, 9, Color(0.08, 0.08, 0.12))
				draw_circle(p, 7, Color("ff5a4a"))
				draw_arc(p, 9.5, 0, TAU, 20, Color.WHITE, 1.5)
			"bang": MapView.draw_bang(self, p + Vector2(0, 12), 15)
			"flag": MapView.draw_flag(self, p + Vector2(-2, 2), color, 16)
			"lock": MapView.draw_lock(self, p + Vector2(0, 2), 11)
			"npc":
				draw_circle(p, 6, Color(0.1, 0.1, 0.12))
				draw_circle(p, 4.5, UI.CREAM)
			"badge": MapView.draw_badge(self, p, tex, 28)
			"mist":
				draw_rect(Rect2(p - Vector2(14, 10), Vector2(28, 20)), COL_MIST.lerp(Color.WHITE, 0.2))
			_:
				if tex:
					draw_texture_rect(tex, Rect2(p - Vector2(14, 14), Vector2(28, 28)), false)
