class_name TerrainBuilder
extends RefCounted
## Builds a TileSet from the PixelLab Wang tilesets and paints a TileMapLayer
## from data/world/terrain.txt.
##
## Terrain lives on cell *corners* (vertices). Each vertex takes the highest
## terrain of the 4 cells around it, then every cell picks the tile whose
## NW/NE/SW/SE corners match. tools/gen_world.py guarantees only legal pairs
## meet (sea-sand, sand-grass, grass-path, grass-stone).

enum { SEA, SAND, GRASS, PATH, STONE }

const CHARS := {"~": SEA, "s": SAND, ".": GRASS, "=": PATH, "#": STONE}
const PAIRS := {  # [lower, upper] -> tileset name in assets/tiles/
	Vector2i(SEA, SAND): "sea_sand",
	Vector2i(SAND, GRASS): "sand_grass",
	Vector2i(GRASS, PATH): "grass_path",
	Vector2i(GRASS, STONE): "grass_stone",
}
const TILE := 16

var tile_set := TileSet.new()
var cells: Array = []  ## cells[y][x] = terrain id
var width := 0
var height := 0

var _wang := {}  ## Vector2i pair -> {source_id, coords: Dictionary wang_index -> Vector2i}


func _init() -> void:
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source_id := 0
	for pair in PAIRS:
		var name: String = PAIRS[pair]
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/%s_metadata.json" % name))
		var src := TileSetAtlasSource.new()
		src.texture = load("res://assets/tiles/%s_image.png" % name)
		src.texture_region_size = Vector2i(TILE, TILE)
		var coords := {}
		for t in meta["tileset_data"]["tiles"]:
			var box: Dictionary = t["bounding_box"]
			var at := Vector2i(int(box["x"]) / TILE, int(box["y"]) / TILE)
			if not src.has_tile(at):
				src.create_tile(at)
			var c: Dictionary = t["corners"]
			var idx := _bit(c["NW"]) * 8 + _bit(c["NE"]) * 4 + _bit(c["SW"]) * 2 + _bit(c["SE"])
			coords[idx] = at
		tile_set.add_source(src, source_id)
		_wang[pair] = {"source": source_id, "coords": coords}
		source_id += 1


func _bit(corner: String) -> int:
	return 1 if corner == "upper" else 0


func load_layout(path: String) -> void:
	cells.clear()
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		line = line.strip_edges(false, true)  # Windows checkouts end lines with \r
		if line == "":
			continue
		var row: Array[int] = []
		for ch in line:
			row.append(CHARS.get(ch, GRASS))
		cells.append(row)
	height = cells.size()
	width = cells[0].size() if height > 0 else 0


func terrain_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return SEA
	return cells[cell.y][cell.x]


func paint(layer: TileMapLayer) -> void:
	layer.tile_set = tile_set
	layer.clear()
	# vertex terrain = highest of the 4 surrounding cells
	var v: Array = []
	for y in height + 1:
		var row: Array[int] = []
		for x in width + 1:
			var best := SEA
			for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var cx: int = clampi(x + d.x, 0, width - 1)
				var cy: int = clampi(y + d.y, 0, height - 1)
				best = maxi(best, cells[cy][cx])
			row.append(best)
		v.append(row)

	for y in height:
		for x in width:
			var corners := [v[y][x], v[y][x + 1], v[y + 1][x], v[y + 1][x + 1]]
			_place(layer, Vector2i(x, y), corners, cells[y][x])


func _place(layer: TileMapLayer, cell: Vector2i, corners: Array, own: int) -> void:
	var lo: int = corners.min()
	var hi: int = corners.max()
	if lo == hi:
		_place_base(layer, cell, lo)
		return
	var pair := Vector2i(lo, hi)
	if not _wang.has(pair) or _has_third(corners, lo, hi):
		_place_base(layer, cell, own)  # illegal mix; fall back to the cell's own terrain
		return
	var idx := 0
	for i in 4:
		if corners[i] == hi:
			idx |= 8 >> i
	var w: Dictionary = _wang[pair]
	layer.set_cell(cell, w["source"], w["coords"][idx])


func _has_third(corners: Array, lo: int, hi: int) -> bool:
	for c in corners:
		if c != lo and c != hi:
			return true
	return false


func _place_base(layer: TileMapLayer, cell: Vector2i, terrain: int) -> void:
	for pair in _wang:
		if pair.x == terrain:
			layer.set_cell(cell, _wang[pair]["source"], _wang[pair]["coords"][0])
			return
		if pair.y == terrain:
			layer.set_cell(cell, _wang[pair]["source"], _wang[pair]["coords"][15])
			return
