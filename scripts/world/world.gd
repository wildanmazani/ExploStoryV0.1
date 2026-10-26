extends Node2D
## Dunia Explo-Story overworld. Builds itself from data/world/ (made by
## tools/gen_world.py): terrain tiles, props with collision, NPCs, signs, flag
## gates and the Bab 1 puzzle spots. Zone logic (from the first prototype)
## runs through ZoneRunner; this script shows its results in the world.

const TILE := 16
const SWAY := preload("res://shaders/sway.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const KABUS := preload("res://shaders/kabus_lupa.gdshader")
const UI = preload("res://scripts/ui/ui.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const ZonePrep = preload("res://scripts/screens/zone_prep.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")
const ObjectiveArrow = preload("res://scripts/ui/objective_arrow.gd")
const ArenaYard = preload("res://scripts/world/arena_yard.gd")
const HOLD_TIME := 0.6  ## long-press Pau = calm moment
const LEMBAH_X := 82   ## columns from here on are Lembah Kebangkitan (Bab 2)

## char -> texture in assets/objects/ (an Array = variants, see
## object_texture), footprint (w, h) in cells, sway = wind shader, flat = drawn
## under characters with no collision, walk = footprint cells become walkable
## (jetty, bridges), open = walkable columns
const OBJECTS := {
	"P": {"tex": "palm", "foot": Vector2i(1, 1), "sway": 1.2},
	"T": {"tex": ["tree", "tree_mempelam", "tree_ketapang", "tree_round", "tree", "tree_rambutan", "tree_round"], "foot": Vector2i(2, 1), "sway": 1.0},
	"B": {"tex": ["bush", "bush_bunga"], "foot": Vector2i(2, 1), "sway": 0.6},
	"R": {"tex": "rocks", "foot": Vector2i(2, 1)},
	"F": {"tex": ["bunga_kuning", "bunga_merah_jambu"], "foot": Vector2i(2, 1), "flat": true, "sway": 0.5},
	"f": {"tex": "pagar", "foot": Vector2i(1, 1)},
	"H": {"tex": ["rumah_biru", "rumah_merah", "rumah_hijau"], "foot": Vector2i(6, 3), "talk": "house", "order": true},
	"U": {"tex": "rumah_alif", "fallback": "rumah_biru", "foot": Vector2i(6, 3)},  # Rumah Alif
	"M": {"tex": ["gerai_buah", "gerai_rempah"], "foot": Vector2i(4, 2), "order": true},
	"D": {"tex": "gudang", "foot": Vector2i(6, 3)},
	"n": {"tex": "jambatan", "foot": Vector2i(5, 2), "flat": true, "walk": true},
	"l": {"tex": "pelita", "foot": Vector2i(1, 1)},
	"w": {"tex": "perigi", "foot": Vector2i(2, 1)},
	"j": {"tex": "tempayan", "foot": Vector2i(1, 1)},
	"k": {"tex": "tong", "foot": Vector2i(1, 1)},
	"c": {"tex": "peti", "foot": Vector2i(2, 1)},
	"g": {"tex": "kayu_balak", "foot": Vector2i(2, 1)},
	"u": {"tex": "tunggul", "foot": Vector2i(1, 1)},
	"e": {"tex": "bangku", "foot": Vector2i(2, 1)},
	"x": {"tex": "kayu_api", "foot": Vector2i(2, 1)},
	"p": {"tex": "teratai", "foot": Vector2i(1, 1), "flat": true},
	"q": {"tex": "rumput_air", "foot": Vector2i(1, 1), "flat": true, "sway": 0.8},
	"K": {"tex": "monument", "foot": Vector2i(4, 2)},
	"Y": {"tex": "banyan", "foot": Vector2i(6, 2), "sway": 0.8},
	"G": {"tex": "gate_open", "foot": Vector2i(4, 1), "open": [1, 2]},
	"L": {"tex": "gate_locked", "foot": Vector2i(4, 1)},
	"S": {"tex": "sign", "foot": Vector2i(1, 1)},
	"I": {"tex": "istana", "foot": Vector2i(10, 4)},
	"J": {"tex": "jetty", "foot": Vector2i(2, 6), "flat": true, "walk": true},
	"X": {"tex": "ship", "foot": Vector2i(6, 4)},
	# Lembah Kebangkitan (Bab 2)
	"O": {"tex": "dewan", "foot": Vector2i(8, 4)},
	"V": {"tex": "rumah_falsafah", "foot": Vector2i(6, 3)},
	"E": {"tex": "balai_serantau", "foot": Vector2i(6, 3)},
	"N": {"tex": "madrasah", "foot": Vector2i(6, 3)},
	"C": {"tex": "jelutong_press", "foot": Vector2i(6, 3)},
	"h": {"tex": ["kedai_merah", "kedai_biru"], "foot": Vector2i(6, 3), "order": true},
	"m": {"tex": "sitc", "foot": Vector2i(10, 4)},
	"t": {"tex": "menara", "foot": Vector2i(6, 4)},
	"y": {"tex": "tugu_pahlawan", "foot": Vector2i(3, 2)},
	"a": {"tex": "papan_notis", "foot": Vector2i(2, 1)},
	"o": {"tex": "rak_buku", "foot": Vector2i(2, 1)},
	"d": {"tex": "meja_pengarang", "foot": Vector2i(2, 1)},
	"v": {"tex": "pintu_kabus", "foot": Vector2i(4, 1), "open": [1, 2]},
	"z": {"tex": "lampu_kolonial", "foot": Vector2i(1, 1)},
	# Lembah Kebangkitan, a 1920s town (data/world/lembah_layout.json)
	"6": {"tex": "kedai_deret_a", "foot": Vector2i(8, 3)},
	"7": {"tex": "kedai_deret_b", "foot": Vector2i(8, 3)},
	"8": {"tex": "menara_jam", "foot": Vector2i(3, 2)},
	"9": {"tex": "wakaf_padang", "foot": Vector2i(5, 3)},
	"@": {"tex": "kapal_wap", "foot": Vector2i(8, 3)},
	"$": {"tex": "gerai_akhbar", "foot": Vector2i(2, 1)},
	"!": {"tex": "papan_misi", "foot": Vector2i(2, 1)},
	"%": {"tex": "pokok_angsana", "foot": Vector2i(2, 1), "sway": 0.8},
	"&": {"tex": "pokok_getah", "foot": Vector2i(2, 1), "sway": 1.0},
	"+": {"tex": "tiang_telegraf", "foot": Vector2i(1, 1)},
	"0": {"tex": "basikal", "foot": Vector2i(2, 1)},
	"#": {"tex": "pagar_besi", "foot": Vector2i(2, 1)},
	"b": {"tex": "perahu", "foot": Vector2i(3, 1)},
	"1": {"tex": "gate_funan", "foot": Vector2i(3, 1)},
	"2": {"tex": "gate_champa", "foot": Vector2i(3, 1)},
	"3": {"tex": "gate_srivijaya", "foot": Vector2i(3, 1)},
	"4": {"tex": "gate_melaka", "foot": Vector2i(3, 1)},
	"5": {"tex": "gate_johor", "foot": Vector2i(3, 1)},
	"A": {"tex": "tiang_runtuh", "foot": Vector2i(4, 1)},
	"Q": {"tex": "panji_turun", "foot": Vector2i(1, 1)},
	"W": {"tex": "arena", "foot": Vector2i(6, 2)},
	"Z": {"tex": "batu_renungan", "foot": Vector2i(2, 1)},
}
const KINGDOM := {"1": "funan", "2": "champa", "3": "srivijaya", "4": "melaka", "5": "johor"}
## buildings you can walk into as story / museum rooms:
## id -> [scene, card title, card subtitle, Pau's line at the door]
const ROOMS := {
	"rumah_alif": ["res://scenes/interior/bilik_alif.tscn", "BILIK ALIF", "Rumah Alif, Kampung Jejak", "Bilik kau! Jom masuk kejap."],
	"sitc": ["res://scenes/interior/sitc.tscn", "MAKTAB SITC", "Tanjung Malim, 1922", "Ni Maktab Perguruan Sultan Idris. Jom jenguk kelas dia."],
	"jelutong_press": ["res://scenes/interior/jelutong.tscn", "JELUTONG PRESS", "Pulau Pinang, 1927", "Bunyi mesin cetak! Jom tengok dalam."],
}
const AREA_ZONE := {"gerbang": "1_1", "pelabuhan": "1_2", "siguntang": "1_4"}
const LABELS := {
	"house": "Rumah", "rumah_alif": "Rumah Alif", "monument": "Peta Jejak", "istana": "Istana Melaka",
	"sign_start": "Papan tanda", "sign_sea": "Papan tanda", "t5": "Papan tanda",
	"arena": "Arena Ulang Kaji", "gate_locked": "Gerbang berkunci", "gate_open_1": "Gerbang Bab 1",
	"gate_open_2": "Pintu Kabus Bab 2", "portal_balik": "Pintu Kabus", "dewan": "Dewan Kedaulatan Rakyat",
	"madrasah": "Madrasah", "sitc": "Maktab Perguruan Sultan Idris", "sign_lembah": "Papan tanda",
	"arena_lembah": "Arena Ulang Kaji", "papan_markah": "Papan Markah", "patung_latihan": "Patung Latihan",
	"pemain_arena": "Pemain lain",
}

var terrain := TerrainBuilder.new()
var blocked := {}      ## Vector2i -> true
var walk_over := {}    ## Vector2i -> true (jetty planks over water)
var interact := {}     ## Vector2i -> {type, id}
var npcs := {}         ## Vector2i -> Npc
var portals := {}      ## Vector2i -> {to, facing}: step in and you cross to the other island
var houses: Array[Sprite2D] = []   ## kampung houses (chickens and kitchen smoke)
var critters: Array[Node2D] = []   ## chickens and ducks (looks only)
var spots := {}        ## spot id -> {pos, size}
var spot_sprites := {} ## spot id -> Sprite2D
var gate_sprites := {} ## kingdom -> Sprite2D
var areas: Array = []
var current_area := ""
var busy := false
var runner := ZoneRunner.new()
var hud: Control
var minimap: Control
var map_texture: Texture2D  ## picture of the whole world for the maps (see _capture_map)
var map_sea := Color("3b8fc4")  ## sea colour around the map picture
var _ent: Dictionary
var _last_move := 0.0
var _thread: Line2D
var _pau_press := -1.0  ## time Pau was pressed (long-press), -1 = not pressed
var _ujian_cells := {}  ## chapter -> cell where its Ujian Bab boss waits
var _goal := {}         ## objective() of this frame (the maps and the arrow all ask)
var _goal_frame := -1
var _dummies := {}      ## cell -> training dummy sprite (Arena Ulang Kaji yards)

@onready var ground: TileMapLayer = $Ground
@onready var decor: Node2D = $Decor
@onready var objects: Node2D = $Objects
@onready var player: Player = $Objects/Player
@onready var pau: Pau = $Objects/Pau
@onready var camera: Camera2D = $Objects/Player/Camera2D
@onready var emote: Label = $HUD/Emote
@onready var title_card: Control = $HUD/TitleCard  ## area title card (_area_intro)
@onready var prompt: Button = $HUD/Prompt


func _ready() -> void:
	_ent = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/entities.json"))
	terrain.load_layout("res://data/world/terrain.txt")
	terrain.paint(ground)
	var water := ShaderMaterial.new()
	water.shader = WATER
	ground.material = water

	spots = _ent["spots"]
	_build_objects()
	_build_entities()
	map_texture = MapView.build_texture(self)
	$Ambience.setup(self, _ent["gates"])
	_spawn_critters()
	_build_kabus()

	camera.limit_right = terrain.width * TILE
	camera.limit_bottom = terrain.height * TILE

	hud = Hud.new()
	hud.world = self
	$HUD.add_child(hud)
	$HUD.move_child(hud, 0)
	# the mini map takes the Pau button's corner (with on-screen controls it
	# moves up: the thumbs own the bottom corners)
	minimap = Minimap.new()
	minimap.world = self
	$HUD.add_child(minimap)
	_place_minimap()
	Game.settings_changed.connect(_place_minimap)
	minimap.open_requested.connect(open_map)
	var arrow := ObjectiveArrow.new()
	arrow.world = self
	$HUD.add_child(arrow)
	$HUD.move_child(arrow, 1)  # under the HUD panels and the mini map
	prompt.pressed.connect(func(): _interact(player.facing_cell()))
	prompt.theme = Game.theme

	player.world = self
	player.step_finished.connect(_on_step_finished)
	player.step_finished.connect(_footstep)
	player.step_started.connect(func(_a, _b, _c): _last_move = Time.get_ticks_msec() / 1000.0)
	player.bumped.connect(func(_c): Sfx.play_varied("bump", -4.0))
	pau.follow(player)
	var spawn := Vector2i(_ent["spawn"][0], _ent["spawn"][1])
	if GameState.spawn_cell != null:
		spawn = GameState.spawn_cell
	elif Game.save.get("map_pos", []).size() == 2:
		spawn = Vector2i(Game.save["map_pos"][0], Game.save["map_pos"][1])
	GameState.spawn_cell = null
	if not is_walkable(spawn):  # an old save inside something built since (arena yards)
		spawn = _nearest_walkable(spawn)
	player.place_at(spawn, GameState.spawn_facing)
	pau.place_at(_free_neighbour(spawn))
	camera.reset_smoothing()

	add_child(runner)
	runner.setup(self)
	_capture_map()
	if GameState.flags.get("just_crossed", false):
		GameState.flags["just_crossed"] = false
		_arrive_lembah.call_deferred()
	_on_step_finished(spawn)
	_controls_tip()


## once, on a phone: Pau points at Tetapan > Kawalan
func _controls_tip() -> void:
	if not DisplayServer.is_touchscreen_available() or "tip_kawalan" in Game.save["seen"]:
		return
	await get_tree().create_timer(4.0).timeout
	if busy or runner.busy or Game.is_locked():
		return
	Game.save["seen"].append("tip_kawalan")
	Main.pau_say("Susah nak gerak? Tukar kawalan dalam Tetapan > Kawalan. Ada joystick pun!", 8.0)


## bottom-right normally; under the player card with on-screen controls, or
## under the menu buttons for left-handed players (the pad is on the right)
func _place_minimap() -> void:
	if not Game.controls_on_screen():
		minimap.position = Vector2(1280 - 16 - minimap.size.x, 720 - 16 - minimap.size.y)
	elif Game.settings.get("left_handed", false):
		minimap.position = Vector2(16, 166)
	else:
		minimap.position = Vector2(1280 - 16 - minimap.size.x, 150)


func _process(_delta: float) -> void:
	# mini map in the corner while exploring; the Pau button comes back for
	# puzzle hints (puzzle_base.gd talks to it)
	var in_puzzle := Game.active_puzzle != null
	Main.pau_button.visible = in_puzzle
	minimap.visible = hud.visible and not in_puzzle
	if _pau_press >= 0.0 and Time.get_ticks_msec() / 1000.0 - _pau_press >= HOLD_TIME:
		_pau_press = -1.0
		if not (busy or runner.busy or Game.is_locked()):
			pau.hop()
			Main.open_calm()
	if emote.visible:  # keep the "!" / "z z" bubble above Alif's head on screen
		var screen := get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, -38))
		emote.position = screen - emote.size / 2.0
	_update_prompt()
	# the melody layer breathes with you: up while exploring, down when still
	MusicDirector.set_melody(Time.get_ticks_msec() / 1000.0 - _last_move < 6.0)


# --- building -----------------------------------------------------------
func _build_objects() -> void:
	var rows := FileAccess.get_file_as_string("res://data/world/objects.txt").split("\n", false)
	var count := {}  ## char -> how many placed so far (for "order" variants)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if OBJECTS.has(ch):
				_spawn_object(ch, Vector2i(x, y), count.get(ch, 0))
				count[ch] = count.get(ch, 0) + 1


## Texture name for an object. Variants go in turn ("order": houses, stalls)
## or by a stable hash of the cell (trees, flowers), so the island looks the
## same every run.
static func object_texture(def: Dictionary, anchor: Vector2i, nth: int) -> String:
	var tex = def["tex"]
	if tex is String:
		return tex
	var i: int = nth if def.get("order", false) else absi((anchor.x * 73856093) ^ (anchor.y * 19349663)) % 1009
	return tex[i % tex.size()]


func _spawn_object(ch: String, anchor: Vector2i, nth := 0) -> void:
	var def: Dictionary = OBJECTS[ch]
	var foot: Vector2i = def["foot"]
	var path := "res://assets/objects/%s.png" % object_texture(def, anchor, nth)
	if not ResourceLoader.exists(path) and def.has("fallback"):  # new art not dropped in yet
		path = "res://assets/objects/%s.png" % def["fallback"]
	var tex: Texture2D = load(path)
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = CharacterFrames.visible_bottom_offset(tex)
	s.position = Vector2((anchor.x + foot.x / 2.0) * TILE, (anchor.y + 1) * TILE)  # bottom-centre
	if def.has("sway"):
		var m := ShaderMaterial.new()
		m.shader = SWAY
		m.set_shader_parameter("strength", def["sway"])
		s.material = m
	if def.get("flat", false):
		decor.add_child(s)
	else:
		objects.add_child(s)
	if ch == "H":
		houses.append(s)
	if ch == "L":
		gate_sprites["L%d_%d" % [anchor.x, anchor.y]] = s
	if KINGDOM.has(ch):
		gate_sprites[KINGDOM[ch]] = s
	for id in spots:
		if Vector2i(spots[id]["pos"][0], spots[id]["pos"][1]) == anchor:
			spot_sprites[id] = s

	var open: Array = def.get("open", [])
	for dy in foot.y:
		for dx in foot.x:
			var c := Vector2i(anchor.x + dx, anchor.y - dy)
			if def.get("walk", false):
				walk_over[c] = true
			elif not def.get("flat", false) and not (dx in open):
				blocked[c] = true
			if def.has("talk"):
				interact[c] = {"type": "talk", "id": def["talk"]}


func _build_entities() -> void:
	for s in _ent["signs"]:
		var size: Array = s.get("size", [1, 1])
		for dy in size[1]:
			for dx in size[0]:
				interact[Vector2i(s["pos"][0] + dx, s["pos"][1] - dy)] = {"type": "talk", "id": s["id"]}
	for g in _ent["gates"]:
		var ch := int(g["chapter"])
		# a chapter gate opens once the chapter before it is finished
		var open: bool = g["open"] or (not Game.chapter_zones(ch).is_empty() and Game.chapter_done(ch - 1))
		g["open"] = open
		var id := "gate_open_%d" % ch if open else "gate_locked"
		for dx in 4:
			interact[Vector2i(g["pos"][0] + dx, g["pos"][1])] = {"type": "talk", "id": id}
		var s: Sprite2D = gate_sprites.get("L%d_%d" % [int(g["pos"][0]), int(g["pos"][1])])
		if open and s:  # the misty gate becomes the portal: walk through its middle
			s.texture = load("res://assets/objects/pintu_kabus.png")
			s.offset = CharacterFrames.visible_bottom_offset(s.texture)
			for dx in [1, 2]:
				blocked.erase(Vector2i(int(g["pos"][0]) + dx, int(g["pos"][1])))
	for pt in _ent.get("portals", []):
		if Game.chapter_zones(int(pt["chapter"])).is_empty() or not Game.chapter_done(int(pt["chapter"]) - 1):
			continue
		for c in pt["cells"]:
			portals[Vector2i(c[0], c[1])] = pt
	for id in spots:
		var sp: Dictionary = spots[id]
		for dy in sp["size"][1]:
			for dx in sp["size"][0]:
				interact[Vector2i(sp["pos"][0] + dx, sp["pos"][1] - dy)] = {"type": "spot", "id": id}
	for n in _ent["npcs"]:
		var npc := Npc.new()
		var at := Vector2i(n["pos"][0], n["pos"][1])
		npc.setup(n["id"], at, n["facing"])
		objects.add_child(npc)
		if n.get("wander", true) and not blocked.has(at):
			npc.enable_wander(self, int(n.get("radius", 2)))
		npcs[at] = npc
		blocked[at] = true
		interact[at] = {"type": "npc", "id": n["id"]}
	for a in _ent.get("arenas", []):
		_dummies.merge(ArenaYard.build(self, a))
	areas = _ent["areas"]
	_build_misi_signs()
	_spawn_ujian()
	_spawn_gabenor()


## Misi 2.8: Gabenor Sekatan 1941 guards the Menara until he is beaten.
const GABENOR_CELL := Vector2i(129, 30)
var _gabenor: Npc


func _spawn_gabenor() -> void:
	if not Game.zone_unlocked("2_8") or Game.zone_state("2_8")["steps"].has("gabenor"):
		return
	if not is_walkable(GABENOR_CELL):
		return
	_gabenor = Npc.new()
	_gabenor.setup("gabenor", GABENOR_CELL, "south")
	objects.add_child(_gabenor)
	npcs[GABENOR_CELL] = _gabenor
	blocked[GABENOR_CELL] = true
	interact[GABENOR_CELL] = {"type": "npc", "id": "gabenor"}


## Numbered mission signposts in Lembah ("2.1" ... "2.8"): the number is
## written on the board; talking to one says where that mission stands.
func _build_misi_signs() -> void:
	for m in _ent.get("misi_signs", []):
		var at := Vector2i(int(m["pos"][0]), int(m["pos"][1]))
		var lbl := Label.new()
		lbl.text = str(m["no"])
		lbl.theme = Game.theme
		lbl.add_theme_font_size_override("font_size", 40)
		lbl.add_theme_color_override("font_color", Color("4a2c14"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(120, 52)
		lbl.scale = Vector2(0.2, 0.2)   # drawn big, shown small: stays sharp under the zoomed camera
		lbl.position = Vector2((at.x + 1) * TILE - 12, (at.y + 1) * TILE - 27)
		lbl.z_index = 5
		objects.add_child(lbl)
		for dx in 2:
			interact[at + Vector2i(dx, 0)] = {"type": "talk", "id": "misi_" + str(m["no"])}


## Ujian Bab: once a chapter's missions are done, its boss waits on the map
## (data/ujian.json) until the final test is passed.
func _spawn_ujian() -> void:
	for n in range(1, 11):
		if not Game.ujian_pending(n):
			continue
		var cfg := Game.ujian_def(n)
		var at := Vector2i(int(cfg["pos"][0]), int(cfg["pos"][1]))
		if not is_walkable(at):
			for r in range(1, 4):
				for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
					if is_walkable(at + d):
						at += d
						break
				if is_walkable(at):
					break
		var npc := Npc.new()
		npc.setup(str(cfg["npc"]), at, "south")
		objects.add_child(npc)
		npcs[at] = npc
		blocked[at] = true
		interact[at] = {"type": "ujian", "id": str(n)}
		_ujian_cells[n] = at
		var m := ZoneRunner.Marker.new()
		m.position = Player.cell_to_pos(at) + Vector2(0, -38)
		objects.add_child(m)


## Photographs the whole island once (every tile, tree, house and boat) for the
## mini map and the full map. People, Pau and quest marks are left out: the
## maps draw them as live icons. Headless runs keep the simple 1 px map.
func _capture_map() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sub := SubViewport.new()
	sub.size = Vector2i(terrain.width * TILE, terrain.height * TILE)
	sub.world_2d = get_viewport().world_2d  # same world, own camera
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sub.canvas_cull_mask = 1  # characters live on layer 2 too: this camera skips them
	for n in [player, pau, $Ambience] + npcs.values() + runner.markers.values() + critters + ([_fog] if _fog else []):
		_to_layer2(n)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	sub.add_child(cam)
	add_child(sub)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	sub.queue_free()
	if img == null or img.is_empty():
		return
	map_sea = img.get_pixel(2, 2)  # open sea in the corner
	img.generate_mipmaps()
	map_texture = ImageTexture.create_from_image(img)


## Kabus Lupa: every mission place starts grey and misty, on both islands, and
## gets its colour back when its mission is done (the town comes back to
## life). One fog over the whole world; the mini map and full map draw the
## same rects (fog_rects()).
const KABUS_AREAS := {"gerbang": "1_1", "pelabuhan": "1_2", "melaka": "1_3", "siguntang": "1_4"}
var _fog: ColorRect
var _fog_rects := {}   ## zid -> Vector4 (world px) still under the fog


func _build_kabus() -> void:
	for a in areas:
		var zid: String = str(a.get("zone", KABUS_AREAS.get(str(a["id"]), "")))
		if zid != "" and not Game.zone_done(zid) and not _fog_rects.has(zid):
			_fog_rects[zid] = _area_px(a)
	if _fog_rects.is_empty():
		return
	_fog = ColorRect.new()
	_fog.size = Vector2(terrain.width, terrain.height) * TILE
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.z_index = 19   # under the "!" quest markers (20)
	var m := ShaderMaterial.new()
	m.shader = KABUS
	m.set_shader_parameter("origin", Vector2.ZERO)
	m.set_shader_parameter("size", _fog.size)
	_fog.material = m
	add_child(_fog)
	_push_fog()


## the fogged places, in world pixels (for the maps)
func fog_rects() -> Array:
	return _fog_rects.values()


func _area_px(a: Dictionary) -> Vector4:
	var r: Array = a["rect"]
	return Vector4(r[0] * TILE, r[1] * TILE, (r[2] - r[0] + 1) * TILE, (r[3] - r[1] + 1) * TILE)


func _push_fog() -> void:
	var arr: Array = _fog_rects.values().slice(0, 16)
	var count := arr.size()
	while arr.size() < 16:
		arr.append(Vector4.ZERO)
	_fog.material.set_shader_parameter("clear_rects", arr)
	_fog.material.set_shader_parameter("clear_count", count)


## the fog over a finished place shrinks into its centre and the colour floods back
func _clear_kabus(zid: String) -> void:
	if _fog == null or not _fog_rects.has(zid):
		return
	var full: Vector4 = _fog_rects[zid]
	var centre := Vector2(full.x + full.z / 2.0, full.y + full.w / 2.0)
	Sfx.play("sparkle")
	var t := create_tween()
	t.tween_method(func(v: float):
		_fog_rects[zid] = Vector4(centre.x - full.z * v / 2.0, centre.y - full.w * v / 2.0, full.z * v, full.w * v)
		_push_fog(), 1.0, 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	await t.finished
	_fog_rects.erase(zid)
	_push_fog()


func _to_layer2(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).visibility_layer = 2
	for c in n.get_children():
		_to_layer2(c)


func entities() -> Dictionary:
	return _ent


## Chickens peck around the house yards, ducks paddle where the water is deep
## (the spring pond and the wide river). Same places every run.
func _spawn_critters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for h in houses:
		var base := Vector2i((h.position / TILE).floor())
		for i in 2:
			for tries in 12:
				var c := base + Vector2i(rng.randi_range(-4, 4), rng.randi_range(0, 3))
				if is_walkable(c) and not interact.has(c):
					_add_critter("ayam", c)
					break
	var deep: Array[Vector2i] = []
	for y in terrain.height:
		for x in terrain.width:
			var c := Vector2i(x, y)
			if terrain.terrain_at(c) != TerrainBuilder.RIVER or walk_over.has(c):
				continue
			var all_water := true
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if terrain.terrain_at(c + d) != TerrainBuilder.RIVER:
					all_water = false
			if all_water:
				deep.append(c)
	var placed: Array[Vector2i] = []
	for i in deep.size():
		var c: Vector2i = deep[rng.randi_range(0, deep.size() - 1)]
		if placed.all(func(p): return (p - c).length() > 5.0):
			placed.append(c)
			_add_critter("itik", c)
		if placed.size() >= 4:
			break


func _add_critter(kind: String, c: Vector2i) -> void:
	var k := Critter.new()
	k.setup(self, kind, c)
	objects.add_child(k)
	critters.append(k)


# --- ZoneRunner host API -------------------------------------------------------
func spot_ids() -> Array:
	var ids := spots.keys()
	for n in _ent["npcs"]:
		ids.append(n["id"])
	return ids


# --- wandering NPCs (Npc.enable_wander) -------------------------------------
## NPCs only stroll while nothing is happening and Alif isn't close by, so the
## one you're walking up to (or talking to) stays put.
func npc_may_wander(npc: Npc) -> bool:
	if busy or runner.busy or Game.is_locked():
		return false
	var d := npc.cell - player.cell
	return absi(d.x) + absi(d.y) > 4


func npc_cell_free(c: Vector2i) -> bool:
	if not is_walkable(c) or c == player.cell or c == pau.cell:
		return false
	# keep doors, signs, spots and portals clear
	return not interact.has(c) and not portals.has(c)


func move_npc(npc: Npc, to: Vector2i) -> void:
	var from := npc.cell
	var it: Dictionary = interact.get(from, {"type": "npc", "id": npc.id})
	npcs.erase(from)
	blocked.erase(from)
	interact.erase(from)
	npcs[to] = npc
	blocked[to] = true
	interact[to] = it


func npc_node(id: String) -> Npc:
	for at in npcs:
		if npcs[at].id == id:
			return npcs[at]
	return null


func marker_pos(id: String) -> Vector2:
	if spots.has(id):
		var sp: Dictionary = spots[id]
		var s: Sprite2D = spot_sprites.get(id)
		var h := 40.0
		if s:
			h = s.texture.get_image().get_used_rect().size.y + 4
		return Vector2((sp["pos"][0] + sp["size"][0] / 2.0) * TILE, (sp["pos"][1] + 1) * TILE - h)
	for at in npcs:
		if npcs[at].id == id:
			return Player.cell_to_pos(at) + Vector2(0, -34)
	return Vector2.ZERO


func return_cell() -> Vector2i:
	return player.cell


# --- navigation arrow (anak panah penunjuk) ---------------------------------
## Where Alif should go next, for the arrows on the maps and at the screen
## edge: {"tile": Vector2 (tile units, centre), "name": String}, or {} when
## there is nothing to do. In order: the current mission's nearest "!" (a step
## may set "target": [x, y] to point somewhere else), a waiting Ujian Bab boss,
## then the next mission's place (zone "target", else its map legend spot).
## A target on the other island points at the Pintu Kabus instead.
func objective() -> Dictionary:
	if _goal_frame != Engine.get_process_frames():
		_goal_frame = Engine.get_process_frames()
		_goal = _find_objective()
	return _goal


func _find_objective() -> Dictionary:
	var out := {}
	for zid in Game.ZONES:
		var best := Vector2(-1, -1)
		for id in runner.markers:
			if not runner.markers[id].visible:
				continue
			var f: Dictionary = runner.step_at(id)
			if f.is_empty() or f["zid"] != zid:
				continue
			var t: Array = f["step"].get("target", [])
			var tile := Vector2(t[0], t[1]) + Vector2(0.5, 0.5) if t.size() == 2 else _spot_tile(id)
			if tile.x >= 0 and (best.x < 0 or tile.distance_to(Vector2(player.cell)) < best.distance_to(Vector2(player.cell))):
				best = tile
		if best.x >= 0:
			out = {"tile": best, "name": _misi_name(zid)}
			break
	if out.is_empty():
		for n in _ujian_cells:
			out = {"tile": Vector2(_ujian_cells[n]) + Vector2(0.5, 0.5), "name": tr("Ujian Bab %d") % n}
			break
	if out.is_empty():
		var nz := Game.next_zone()
		if nz != "" and Game.zone_unlocked(nz):
			var t: Array = Game.zone_data(nz).get("target", [])
			if t.size() == 2:
				out = {"tile": Vector2(t[0], t[1]) + Vector2(0.5, 0.5), "name": _misi_name(nz)}
			for p in MapView.legend()["places"]:
				if out.is_empty() and str(p.get("zone", "")) == nz:
					out = {"tile": Vector2(p["at"][0], p["at"][1]) + Vector2(0.5, 0.5), "name": _misi_name(nz)}
	if out.is_empty():
		return out
	# the other island: first the Pintu Kabus on this side
	var here_lembah := player.cell.x >= LEMBAH_X
	if (out["tile"].x >= LEMBAH_X) != here_lembah:
		var door := Vector2(-1, -1)
		for c in portals:
			if (c.x >= LEMBAH_X) == here_lembah and (door.x < 0 or Vector2(c).distance_to(Vector2(player.cell)) < door.distance_to(Vector2(player.cell))):
				door = Vector2(c) + Vector2(0.5, 0.5)
		if door.x >= 0:
			out = {"tile": door, "name": tr("Pintu Kabus"), "then": out["name"]}
	return out


func _misi_name(zid: String) -> String:
	return tr("Misi %s") % zid.replace("_", ".")


## centre of a spot (object) or an NPC, in tiles
func _spot_tile(id: String) -> Vector2:
	if spots.has(id):
		var sp: Dictionary = spots[id]
		return Vector2(sp["pos"][0] + sp["size"][0] / 2.0, sp["pos"][1] + 0.5)
	var n := npc_node(id)
	return Vector2(n.cell) + Vector2(0.5, 0.5) if n else Vector2(-1, -1)


func apply_after(zid: String, s: Dictionary, animate: bool) -> void:
	var pid: String = s["puzzle"]
	var at: String = s["at"]
	if pid == "susun_gerbang":
		_arrange_gates(animate)
	elif at == "tiang":
		_swap(spot_sprites.get("tiang"), "tiang_berdiri", animate)
	elif at.begins_with("p_"):
		_swap(spot_sprites.get(at), "panji_naik", animate)
	if zid == "1_4":
		_update_tree(animate)
	if pid == "gabenor" and _gabenor:  # beaten: he fades into the mist
		var g := _gabenor
		_gabenor = null
		npcs.erase(GABENOR_CELL)
		blocked.erase(GABENOR_CELL)
		interact.erase(GABENOR_CELL)
		if animate:
			var t := create_tween()
			t.tween_property(g, "modulate:a", 0.0, 1.2)
			await t.finished
		g.queue_free()


func on_zone_complete(zid: String) -> void:
	if _fog_rects.has(zid):
		await _clear_kabus(zid)
	if zid == "1_2":  # the envoy ship sails in and docks
		var ship: Sprite2D = spot_sprites.get("kapal")
		if ship:
			var t := create_tween()
			t.tween_property(ship, "position", ship.position + Vector2(-28, -36), 2.5).set_trans(Tween.TRANS_SINE)
			Sfx.play("whoosh", -6.0)
			await t.finished


func _swap(s: Sprite2D, tex_name: String, animate: bool) -> void:
	if s == null:
		return
	var tex: Texture2D = load("res://assets/objects/%s.png" % tex_name)
	s.texture = tex
	s.offset = CharacterFrames.visible_bottom_offset(tex)
	if animate:
		Sfx.play("sparkle")
		s.scale = Vector2(1.0, 0.6)
		var t := create_tween()
		t.tween_property(s, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(s, "modulate", Color(1.6, 1.5, 0.9), 0.2)
		t.tween_property(s, "modulate", Color.WHITE, 0.6)


## Misi 1.1: the five kingdom gates glide into time order and a golden
## thread of heritage runs through them.
func _arrange_gates(animate: bool) -> void:
	var kg: Dictionary = _ent["kingdom_gates"]
	var pts := PackedVector2Array()
	for i in kg["order"].size():
		var s: Sprite2D = gate_sprites.get(kg["order"][i])
		if s == null:
			continue
		var to := Vector2((kg["slots"][i] + 1.5) * TILE, (kg["row"] + 1) * TILE)
		pts.append(to + Vector2(0, -30))
		if animate:
			create_tween().tween_property(s, "position", to, 1.2).set_trans(Tween.TRANS_SINE).set_delay(i * 0.15)
		else:
			s.position = to
	_thread = Line2D.new()
	_thread.points = pts
	_thread.width = 3
	_thread.default_color = Color(1, 0.85, 0.3)
	_thread.z_index = 15
	var glow := Line2D.new()
	glow.points = pts
	glow.width = 8
	glow.default_color = Color(1, 0.8, 0.3, 0.3)
	_thread.add_child(glow)
	add_child(_thread)
	if animate:
		Sfx.play("chime")
		_thread.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(1.6)
		t.tween_property(_thread, "modulate:a", 1.0, 1.0)


## Misi 1.4: the banyan (pohon = raja, akar = rakyat) wilts in the storm and
## grows healthy again as the Waadat is understood.
func _update_tree(animate: bool) -> void:
	var tree: Sprite2D = spot_sprites.get("pokok")
	if tree == null:
		return
	var stage := 0
	for s in Game.zone_data("1_4").get("steps", []):
		if Game.zone_state("1_4")["steps"].has(s["puzzle"]) and s.has("tree"):
			stage = maxi(stage, int(s["tree"]))
	if Game.zone_done("1_4"):
		stage = 2
	var col: Color = [Color(0.72, 0.62, 0.42), Color(0.88, 0.85, 0.66), Color.WHITE][stage]
	if animate:
		var t := create_tween()
		t.tween_property(tree, "modulate", Color(1.5, 1.4, 0.8), 0.3)
		t.tween_property(tree, "modulate", col, 0.9)
		Sfx.play("sparkle")
	else:
		tree.modulate = col
	if tree.material:
		tree.material.set_shader_parameter("strength", [0.25, 0.5, 0.8][stage])


# --- queries used by Player ------------------------------------------------
func is_walkable(c: Vector2i) -> bool:
	if blocked.has(c):
		return false
	if walk_over.has(c):
		return true
	return not terrain.is_water(c)


func _free_neighbour(c: Vector2i) -> Vector2i:
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_walkable(c + d):
			return c + d
	return c


# --- interaction ---------------------------------------------------------------
func _input_blocked() -> bool:
	return busy or runner.busy or Game.is_locked() or player.moving


func _unhandled_input(event: InputEvent) -> void:
	if busy or runner.busy or Game.is_locked():
		return
	if event.is_action_pressed("interact") and not player.moving:
		get_viewport().set_input_as_handled()
		_interact(player.facing_cell())
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		Main.open_settings()
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		open_map()
	elif event.is_action_pressed("pau"):
		get_viewport().set_input_as_handled()
		_talk_to_pau()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if $TouchControls.owns(event.position):
			return  # a thumb on the D-pad / joystick, not a tap on the map
		var cell :=Vector2i((get_global_mouse_position() / TILE).floor())
		var on_pau := cell == pau.cell or cell == pau.cell + Vector2i(0, -1)
		if event.pressed and on_pau:
			_pau_press = Time.get_ticks_msec() / 1000.0  # tap = talk, hold = calm
		elif not event.pressed and _pau_press >= 0.0:
			_pau_press = -1.0
			_talk_to_pau()
		elif event.pressed:
			_tap(cell)


func open_map() -> void:
	if busy or runner.busy or Game.is_locked():
		return
	Sfx.play("select", -6.0)
	Main.open_map(self)


## tap-to-walk (phones): path to the tapped tile, or next to a tapped
## person / object and then talk to it
func _tap(cell: Vector2i) -> void:
	var target := cell
	if interact.has(cell + Vector2i(0, 1)) and not interact.has(cell):
		target = cell + Vector2i(0, 1)  # tapped the tall part of an object
	if interact.has(target) and not is_walkable(target):
		var path := Pathfind.to_neighbour(self, player.cell, target)
		if path.is_empty() and (player.cell - target).length() <= 1.01:
			player.face_cell(target)
			_interact(target)
		elif not path.is_empty():
			player.walk_path(path, func():
				player.face_cell(target)
				_interact(target))
	elif is_walkable(cell):
		player.walk_path(Pathfind.find(self, player.cell, cell))


func _interact(c: Vector2i) -> void:
	if _input_blocked():
		return
	if c == pau.cell:
		_talk_to_pau()
		return
	if not interact.has(c):
		return
	var it: Dictionary = interact[c]
	var id: String = it["id"]
	if it["type"] == "ujian":
		busy = true
		npcs[c].face_towards(player.cell)
		var cfg := Game.ujian_def(int(id))
		await Game.say(str(cfg.get("npc_talk", "")))
		_save_pos()
		Game.goto("ujian", {"chapter": int(id)})
		return
	if it["type"] == "npc":
		npcs[c].face_towards(player.cell)
	busy = true
	var handled := false
	if runner.owns(id):
		handled = await runner.handle(id)
	if not handled:
		await _talk_or_act(id)
	busy = false


func _talk_or_act(id: String) -> void:
	if id.begins_with("misi_"):
		var zid := id.substr(5).replace(".", "_")
		var z := Game.zone_data(zid)
		var state := "Dah selesai. Syabas!" if Game.zone_done(zid) else ("Tanda seru (!) tunggu kat sini." if Game.zone_unlocked(zid) else "Belum dibuka. Habiskan Misi %s dulu." % Game.prev_zone(zid).replace("_", "."))
		await Game.say([{"s": "papan", "t": "Misi %s: %s. %s" % [zid.replace("_", "."), z.get("title", ""), state]}])
		return
	if id == "gate_open_2" or id == "portal_balik":
		var g: Vector2i = player.cell
		for c in portals:
			if (c - g).length() <= 3.0:
				if id == "portal_balik":
					await Game.say("bab2_back")
				_cross_portal(portals[c])
				return
	if ROOMS.has(id) and (id != "jelutong_press" or Game.zone_done("2_6")):
		var room: Array = ROOMS[id]
		await Game.say([{"s": "pau", "t": room[3]}])
		busy = true
		_save_pos()
		Sfx.play("step_wood", -2.0)
		GameState.go_to(room[0], Color.BLACK, tr(room[1]), tr(room[2]))
		return
	if id == "istana":
		if not Game.zone_unlocked("1_3"):
			await Game.say([{"s": "pau", "t": "Pintu balai masih tertutup. Habiskan Pelabuhan Melaka dulu."}])
			return
		await Game.say(Dialogue.lines("istana"))
		busy = true
		_save_pos()
		GameState.go_to("res://scenes/interior/balai.tscn", Color.BLACK, tr("BALAI PENGHADAPAN"), tr("Istana Melaka, abad ke-15"))
		return
	var key := id
	if id.begins_with("p_"):
		key = "panji"
	if Dialogue.has(key):
		await Game.say(Dialogue.lines(key))
	elif Game.story.has(key):
		await Game.say(key)
	match id:
		"monument":  # Peta Jejak: the Arka & Zon screen (Tingkatan / Bab)
			_leave_to("")
			Game.goto("arka")
		"arena", "arena_lembah":
			GameState.spawn_cell = player.cell
			Game.goto("lobby")
		"pemain_arena":
			if await Main.ask(tr("Masuk Arena dan cari lawan?"), "Jom!", "Nanti dulu"):
				GameState.spawn_cell = player.cell
				Game.goto("lobby")
		"papan_markah":
			Game.main.open_papan()
		"patung_latihan":
			var near: Array = _dummies.keys()
			near.sort_custom(func(x, y): return (x - player.cell).length() < (y - player.cell).length())
			if not near.is_empty():
				ArenaYard.wobble(_dummies[near[0]])
			Sfx.play("bump", -4.0)
			await _jurus_ingatan(player.cell.x < LEMBAH_X)
		"guru_silat":
			await _jurus_ingatan()


## Arena Ulang Kaji side task: Guru Jalal's Jurus Ingatan, three revision
## questions from the missions already finished (a reward the first time,
## then for practice). Opens once the first Serpihan is found. In Lembah
## (no Guru Jalal there) Pau has the last word.
func _jurus_ingatan(guru := true) -> void:
	var done_z: Array = Game.ZONES.filter(func(z): return Game.zone_done(z))
	if done_z.is_empty():
		await Game.say(Dialogue.lines("silat_jurus_belum"))
		return
	var first: bool = not Game.save["seen"].has("jurus_ingatan")
	var q := tr("Belajar Jurus Ingatan dengan Guru Jalal? Tiga soalan ulang kaji, tiada penalti.") if first 		else tr("Ulang Jurus Ingatan? Untuk ulang kaji sahaja.")
	if not await Main.ask(q, "Jom!", "Nanti dulu"):
		return
	var qs: Array = []
	for n in range(1, Game.current_chapter() + 1):
		qs.append_array(Game.ujian_questions(n, 99, done_z))
	qs.shuffle()
	await runner.run_puzzle({
		"type": "objektif", "title": tr("Jurus Ingatan"),
		"instruction": tr("Jawab macam buka langkah: tenang, satu-satu."),
		"hint": "Ingat balik apa yang kau belajar dalam misi tadi.",
		"done_text": tr("Langkah demi langkah. Itulah Jurus Ingatan!"),
		"questions": qs.slice(0, 3),
	}, "silat_jurus")
	if first:
		Game.save["seen"].append("jurus_ingatan")
		if Game.add_reward(30, 15):
			Game.toast(tr("NAIK TAHAP! Tahap %d") % int(Game.save["level"]), Color("8fe08a"))
		Game.persist()
		Game.toast("+30 EXP   +15 Syiling")
		MusicDirector.stinger("st_item")
	await Game.say(Dialogue.lines("silat_jurus_lepas" if guru else "patung_lepas"))


## Pintu Kabus: Kampung Jejak <-> Lembah Kebangkitan (the world scene reloads
## with Alif on the other island)
func _cross_portal(pt: Dictionary) -> void:
	busy = true
	var to := Vector2i(int(pt["to"][0]), int(pt["to"][1]))
	var going_in := to.x >= LEMBAH_X
	if going_in:
		await Game.say("bab2_portal")
	Sfx.play("whoosh")
	GameState.spawn_cell = to
	GameState.spawn_facing = str(pt.get("facing", "south"))
	GameState.flags["just_crossed"] = going_in
	Game.save["map_pos"] = [to.x, to.y]
	Game.persist()
	if going_in:
		GameState.go_to(scene_file_path, Color(0.85, 0.9, 1.0), tr("LEMBAH KEBANGKITAN"), tr("Tanah Melayu, awal 1900-an hingga 1941"))
	else:
		GameState.go_to(scene_file_path, Color(0.85, 0.9, 1.0), tr("KAMPUNG JEJAK"), tr("Kembali ke Bab 1: Warisan Negara Bangsa"))


## Jalan Pintas (Beg Alif and the full map): every place of data/map_legend.json
## as {place, ok, why}. A Misi opens with its mission, Lembah once Bab 1 is
## done (like the Pintu Kabus); the mist gate itself is not a destination.
func travel_places() -> Array:
	var out: Array = []
	var lembah_open := not Game.chapter_zones(2).is_empty() and Game.chapter_done(1)
	for p in MapView.legend()["places"]:
		if str(p["id"]) == "kabus":
			continue
		var why := ""
		if int(p["at"][0]) >= LEMBAH_X and not lembah_open:
			why = tr("Selesaikan Bab 1 dulu")
		elif p.has("zone") and not Game.zone_unlocked(str(p["zone"])):
			why = tr("Selesaikan Misi %s dulu") % Game.prev_zone(str(p["zone"])).replace("_", ".")
		out.append({"place": p, "ok": why == "", "why": why})
	return out


## jump to a place from travel_places(): the world reloads with Alif on the
## nearest free tile there (crossing to Lembah plays its arrival, as the portal does)
func fast_travel(p: Dictionary) -> bool:
	if busy or runner.busy or Game.is_locked():
		return false
	var at := _nearest_walkable(Vector2i(int(p["at"][0]), int(p["at"][1])))
	busy = true
	Sfx.play("whoosh")
	GameState.spawn_cell = at
	GameState.spawn_facing = "south"
	GameState.flags["just_crossed"] = at.x >= LEMBAH_X and player.cell.x < LEMBAH_X
	Game.save["map_pos"] = [at.x, at.y]
	Game.persist()
	GameState.go_to(scene_file_path, Color(0.85, 0.9, 1.0), tr(str(p["name"])).to_upper(), tr("Jalan Pintas"))
	return true


## the walkable tile closest to c (rings outwards), away from doors and portals
func _nearest_walkable(c: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := c + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and is_walkable(t) and not interact.has(t) and not portals.has(t):
					return t
	return c


func _arrive_lembah() -> void:
	busy = true
	await get_tree().create_timer(0.6).timeout
	await Game.say("bab2_arrive")
	busy = false
	_enter_area_at(player.cell)


func _enter_area_at(c: Vector2i) -> void:
	current_area = ""
	_on_step_finished(c)


func _leave_to(scene: String) -> void:
	busy = true
	Sfx.play("select")
	_save_pos()
	if scene != "":
		GameState.go_to(scene)


func _save_pos() -> void:
	Game.save["map_pos"] = [player.cell.x, player.cell.y]
	Game.persist()


func _talk_to_pau() -> void:
	if busy or Game.is_locked():
		return
	busy = true
	pau.hop()
	Sfx.play("squish", -6.0, 1.3)
	# a bit of Pau, then the hint the corner Pau button used to give
	var lines: Array = Dialogue.lines("pau_tap")
	if Game.context_hint != "":
		lines.append({"s": "pau", "t": Game.context_hint})
	await Game.say(lines)
	busy = false


func _update_prompt() -> void:
	var c := player.facing_cell()
	var label := ""
	if not _input_blocked() and not Main.is_dialogue_open():
		if c == pau.cell:
			label = "Pau"
		elif interact.has(c):
			var it: Dictionary = interact[c]
			label = _label_for(it)
	prompt.visible = label != ""
	if prompt.visible:
		prompt.text = tr("E / Ketik: ") + tr(label)
		prompt.reset_size()
		var screen := get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, 14))
		prompt.position = Vector2(clampf(screen.x - prompt.size.x / 2.0, 10, 1270 - prompt.size.x), clampf(screen.y + 8, 120, 640))


func _label_for(it: Dictionary) -> String:
	var id: String = it["id"]
	if it["type"] == "npc":
		return Game.char_name(id)
	if LABELS.has(id):
		return LABELS[id]
	if id.begins_with("misi_"):
		return "Papan Misi " + id.substr(5)
	for zid in Game.ZONES:
		for o in Game.zone_data(zid).get("objects", []):
			if str(o["id"]) == id and o.has("label"):
				return str(o["label"])
	return "Lihat"


const STEP_SOUNDS := {
	TerrainBuilder.SAND: "step_sand", TerrainBuilder.GRASS: "step_grass",
	TerrainBuilder.MEADOW: "step_grass", TerrainBuilder.PATH: "step_sand", TerrainBuilder.JALAN: "step_sand",
}


func _footstep(c: Vector2i) -> void:
	var sound: String = "step_wood" if walk_over.has(c) else STEP_SOUNDS.get(terrain.terrain_at(c), "step_grass")
	Sfx.play_varied(sound, -6.0, 0.12)


# --- areas ---------------------------------------------------------------
func _on_step_finished(c: Vector2i) -> void:
	if portals.has(c) and not busy:
		_cross_portal(portals[c])
		return
	for a in areas:
		var r: Array = a["rect"]
		if c.x >= r[0] and c.x <= r[2] and c.y >= r[1] and c.y <= r[3]:
			if a["id"] != current_area:
				current_area = a["id"]
				_enter_area(a)
			return


func _enter_area(a: Dictionary) -> void:
	var sub := ""
	var zid: String = str(a.get("zone", AREA_ZONE.get(a["id"], "")))
	if zid != "":
		sub = str(Game.zone_data(zid).get("subtopik", ""))
	hud.set_location(str(a["name"]).to_upper(), sub)
	var t := create_tween()
	t.tween_property(hud, "modulate", Color(1.4, 1.3, 0.8), 0.15)
	t.tween_property(hud, "modulate", Color.WHITE, 0.5)
	MusicDirector.play(a["id"])
	_save_pos()
	if busy:
		return
	if not Game.save["seen"].has("area_" + str(a["id"])):
		await _area_intro(a)
	if zid != "" and not busy:
		_zone_welcome(zid)


var _area_intros := {}


## First visit to a place: a big title card (name + era), then a line or two
## on why Alif and Pau are here, so arriving never feels random.
func _area_intro(a: Dictionary) -> void:
	if _area_intros.is_empty():
		_area_intros = Game.load_json("res://data/area_intro.json")
	var info: Dictionary = _area_intros.get(str(a["id"]), {})
	Game.save["seen"].append("area_" + str(a["id"]))
	Game.persist()
	if info.is_empty():
		return
	busy = true
	var title: Label = title_card.get_node("Title")
	var sub: Label = title_card.get_node("Subtitle")
	var old := [title.text, sub.text]
	var nm := str(a["name"])
	title.text = nm.substr(nm.find(": ") + 2) if nm.begins_with("Misi ") else nm
	title.add_theme_font_size_override("font_size", 84 if title.text.length() <= 22 else 64)
	sub.text = (nm.substr(0, nm.find(":")) + "  ·  " if nm.begins_with("Misi ") else "") + str(info.get("era", ""))
	Sfx.play("chime", -8.0, 0.8)
	var t := create_tween()
	t.tween_property(title_card, "modulate:a", 1.0, 0.5)
	t.tween_interval(1.6)
	t.tween_property(title_card, "modulate:a", 0.0, 0.6)
	await t.finished
	title.text = old[0]
	sub.text = old[1]
	title.add_theme_font_size_override("font_size", 84)
	var lines: Array = info.get("lines", [])
	if not lines.is_empty():
		await Game.say(lines)
	busy = false


## First visit to an open zone: the prototype's "Persiapan Misi" briefing,
## then the zone's intro conversation.
func _zone_welcome(zid: String) -> void:
	if not Game.zone_unlocked(zid):
		var prev := Game.prev_zone(zid)
		var need := ("Misi " + prev.replace("_", ".")) if prev != "" else ("Bab %d" % (Game.chapter_of(zid) - 1))
		Main.pau_say("Tempat ni untuk Misi %s. Kita kena habiskan %s dulu." % [zid.replace("_", "."), need], 5.0)
		return
	if Game.zone_done(zid) or not Game.zone_state(zid)["steps"].is_empty():
		return
	if GameState.flags.get("welcomed_" + zid, false):
		return
	GameState.flags["welcomed_" + zid] = true
	busy = true
	var prep := ZonePrep.new()
	prep.set("params", {"zone": zid})
	Main.overlay_root().add_child(prep)
	await prep.closed
	await Game.say(str(Game.zone_data(zid).get("intro", "")))
	runner.refresh()
	busy = false
