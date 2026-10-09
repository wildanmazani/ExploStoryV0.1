extends Node2D
## Base for walkable areas (Peta Jejak + the four zones).
## Builds background, Alif, Pau follower, camera, HUD, interactables with
## "!" markers, and hosts puzzles as overlays.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/world/player.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const DragMatch = preload("res://scripts/puzzles/drag_match.gd")
const Board = preload("res://scripts/puzzles/board.gd")
const Choice = preload("res://scripts/puzzles/choice.gd")
const INTERACT_RADIUS := 110.0

var params: Dictionary = {}
var world: Node2D
var player: CharacterBody2D
var pau: Sprite2D
var camera: Camera2D
var hud: Control
var hud_layer: CanvasLayer
var puzzle_layer: CanvasLayer
var bg: Sprite2D
var area_size: Vector2 = Vector2(1280, 720)
var interactables: Array = []
var busy: bool = false
var _prompt: Button
var _prompt_target: Dictionary = {}
var _t: float = 0.0
var _pau_frames: Array[Texture2D] = []


func _ready() -> void:
	Game.main.set_pau_visible(true)
	_build()


## Override in subclasses.
func _build() -> void:
	pass


func setup_area(bg_path: String, walk: Rect2, spawn: Vector2, title: String, sub: String, map_button: bool) -> void:
	bg = Sprite2D.new()
	bg.texture = load(bg_path)
	bg.centered = false
	bg.scale = Vector2(4, 4)
	bg.z_index = -10
	add_child(bg)
	area_size = bg.texture.get_size() * 4.0
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	player = Player.new()
	player.bounds = walk
	player.position = spawn
	world.add_child(player)
	for i in 4:
		_pau_frames.append(UI.sheet_frame("res://assets/sprites/pau.png", i, 0, 16, 16))
	pau = Sprite2D.new()
	pau.texture = _pau_frames[0]
	pau.scale = Vector2(3, 3)
	pau.offset = Vector2(0, -8)
	pau.position = spawn + Vector2(-50, 4)
	world.add_child(pau)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(area_size.x)
	camera.limit_bottom = int(area_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)
	camera.make_current()

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.location_title = title
	hud.location_sub = sub
	hud.show_map_button = map_button
	hud_layer.add_child(hud)
	_prompt = UI.button("", "Primary")
	_prompt.visible = false
	_prompt.theme = Game.theme
	_prompt.position = Vector2(500, 600)
	_prompt.pressed.connect(func():
		if not _prompt_target.is_empty():
			_try_interact(_prompt_target))
	hud_layer.add_child(_prompt)
	puzzle_layer = CanvasLayer.new()
	puzzle_layer.layer = 15
	add_child(puzzle_layer)


# ------------------------------------------------------------------ objects
func add_sprite_npc(id: String, sheet_key: String, pos: Vector2, label: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = UI.sheet_frame(Game.sprite_path(sheet_key), 0, 0)
	s.scale = Vector2(4, 4)
	s.offset = Vector2(0, -11)
	s.position = pos
	world.add_child(s)
	_add_shadow(s, 22)
	add_interactable(id, s, pos, label)
	return s


func add_texture_obj(id: String, tex_path: String, pos: Vector2, sc: float, label: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = UI.tex(tex_path)
	s.scale = Vector2(sc, sc)
	if s.texture:
		s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	s.position = pos
	world.add_child(s)
	if label != "":
		add_interactable(id, s, pos, label)
	return s


func _add_shadow(parent: Node2D, r: float) -> void:
	var sh := Node2D.new()
	sh.show_behind_parent = true
	sh.draw.connect(func():
		sh.draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.35))
		sh.draw_circle(Vector2.ZERO, r / parent.scale.x * 1.0, Color(0, 0, 0, 0.28)))
	parent.add_child(sh)


func add_interactable(id: String, node: Node2D, pos: Vector2, label: String) -> Dictionary:
	var marker := Sprite2D.new()
	marker.texture = load("res://assets/objects/penanda.png")
	marker.scale = Vector2(3, 3)
	marker.visible = false
	marker.z_index = 50
	add_child(marker)
	var height := 110.0
	if node is Sprite2D and (node as Sprite2D).texture:
		height = (node as Sprite2D).texture.get_height() * node.scale.y
		if (node as Sprite2D).texture is AtlasTexture:
			height = ((node as Sprite2D).texture as AtlasTexture).region.size.y * node.scale.y
	marker.position = pos + Vector2(0, -height - 40)
	var it := {"id": id, "node": node, "pos": pos, "label": label, "active": true, "marker": marker, "marker_y": marker.position.y, "height": height}
	interactables.append(it)
	return it


func get_it(id: String) -> Dictionary:
	for it in interactables:
		if it["id"] == id:
			return it
	return {}


func set_marker(id: String, on: bool) -> void:
	var it := get_it(id)
	if not it.is_empty():
		it["marker"].visible = on


## Override: what happens when the player interacts with `it`.
func on_interact(_it: Dictionary) -> void:
	pass


func _try_interact(it: Dictionary) -> void:
	if busy or Game.is_locked():
		return
	busy = true
	_prompt.visible = false
	player.stop()
	var to: Vector2 = it["pos"] - player.global_position
	if absf(to.x) > absf(to.y):
		player.face("right" if to.x > 0 else "left")
	else:
		player.face("down" if to.y > 0 else "up")
	await on_interact(it)
	busy = false


# ------------------------------------------------------------------ loop / input
func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	# Pau follows Alif with a little bounce
	var behind := player.global_position + Vector2(-56, 6)
	pau.global_position = pau.global_position.lerp(behind, minf(1.0, delta * 4.0))
	var b := absf(sin(_t * 5.0))
	pau.offset.y = -8 - b * 3.0
	pau.texture = _pau_frames[0] if b < 0.85 else _pau_frames[2]
	for it in interactables:
		var m: Sprite2D = it["marker"]
		if m.visible:
			m.position.y = it["marker_y"] + sin(_t * 4.0) * 6.0
	# interaction prompt
	var near := _nearest()
	if near.is_empty() or busy or Game.is_locked():
		_prompt.visible = false
		_prompt_target = {}
	else:
		_prompt_target = near
		_prompt.text = "E / Ketik: %s" % near["label"]
		_prompt.visible = true
		_prompt.reset_size()
		var screen_pos := get_viewport().get_canvas_transform() * (near["pos"] as Vector2)
		_prompt.position = Vector2(clampf(screen_pos.x - _prompt.size.x / 2.0, 10, 1270 - _prompt.size.x), clampf(screen_pos.y + 16, 120, 650))


func _nearest() -> Dictionary:
	var best: Dictionary = {}
	var bd := INTERACT_RADIUS
	for it in interactables:
		if not it["active"]:
			continue
		var d := (it["pos"] as Vector2).distance_to(player.global_position)
		if d < bd:
			bd = d
			best = it
	return best


func _unhandled_input(event: InputEvent) -> void:
	if player == null or busy or Game.is_locked():
		return
	if event.is_action_pressed("interact"):
		var n := _nearest()
		if not n.is_empty():
			_try_interact(n)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu"):
		Game.main.open_settings()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var wp := get_global_mouse_position()
		for it in interactables:
			if not it["active"]:
				continue
			var p: Vector2 = it["pos"]
			var r := Rect2(p.x - 60, p.y - it["height"] - 10, 120, it["height"] + 30)
			if r.has_point(wp):
				var stand := p + Vector2(0, 50)
				if player.global_position.distance_to(p) < INTERACT_RADIUS:
					_try_interact(it)
				else:
					player.go_to(stand, func(): _try_interact(it))
				get_viewport().set_input_as_handled()
				return
		player.go_to(wp)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ puzzles
## Opens a puzzle overlay and waits. Returns stats {total, first_try, retries, hints}.
func run_puzzle(def: Dictionary, puzzle_id: String) -> Dictionary:
	var type := str(def.get("type", "drag_match"))
	var p = null
	match type:
		"board":
			p = Board.new()
		"choice":
			p = Choice.new()
		_:
			p = DragMatch.new()
	p.theme = Game.theme
	p.set("def", def)
	p.set("puzzle_id", puzzle_id)
	Game.lock_input()
	puzzle_layer.add_child(p)
	Game.active_puzzle = p
	var stats: Dictionary = await p.completed
	Game.active_puzzle = null
	Game.unlock_input()
	p.queue_free()
	return stats
