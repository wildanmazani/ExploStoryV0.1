extends Node2D
## Makes the overworld feel alive: butterflies, drifting leaves, cloud
## shadows, passing birds, mist on locked gates and gold dust on open ones.
## Everything is drawn or generated in code (no extra downloads).

const TILE := 16

var world: Node2D
var _butterflies: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _t := 0.0
var _bird_timer := 4.0

@onready var clouds: Node2D = $Clouds


func setup(w: Node2D, gates: Array) -> void:
	world = w
	var size := Vector2(w.terrain.width, w.terrain.height) * TILE
	# cloud shadows: big soft blobs drifting west -> east
	var tex := _soft_blob(96)
	for i in 7:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(randf_range(2.5, 4.5), randf_range(1.6, 2.6))
		s.modulate = Color(0.05, 0.1, 0.2, 0.13)
		s.position = Vector2(randf() * size.x, randf() * size.y)
		clouds.add_child(s)
	# butterflies around the island
	for i in 40:
		_butterflies.append({
			"pos": Vector2(randf() * size.x, randf() * size.y),
			"vel": Vector2.from_angle(randf() * TAU) * 10.0,
			"col": [Color("ffd84a"), Color("ff8fb1"), Color("9fd8ff"), Color.WHITE][i % 4],
			"phase": randf() * TAU,
		})
	for g in gates:
		var at := Vector2((g["pos"][0] + 2) * TILE, g["pos"][1] * TILE + 8)
		add_child(_mist(at) if not g["open"] else _gold_dust(at))
	add_child(_leaves())


func _process(delta: float) -> void:
	_t += delta
	var size := Vector2(world.terrain.width, world.terrain.height) * TILE
	for c in clouds.get_children():
		c.position.x += delta * 6.0
		if c.position.x > size.x + 200:
			c.position.x = -200
			c.position.y = randf() * size.y
	for b in _butterflies:
		b["vel"] = (b["vel"] as Vector2).rotated(randf_range(-2.5, 2.5) * delta)
		b["pos"] += b["vel"] * delta
		b["pos"] = (b["pos"] as Vector2).clamp(Vector2.ZERO, size)
	_bird_timer -= delta
	if _bird_timer <= 0:
		_bird_timer = randf_range(9.0, 16.0)
		_spawn_flock()
	for b in _birds:
		b["pos"] += b["vel"] * delta
	_birds = _birds.filter(func(b): return b["pos"].x < size.x + 60 and b["pos"].x > -60)
	queue_redraw()


func _draw() -> void:
	# butterflies: two tiny wings that flap
	for b in _butterflies:
		var p: Vector2 = (b["pos"] as Vector2).floor()
		var flap := sin(_t * 14.0 + b["phase"]) > 0
		var col: Color = b["col"]
		var w := 2 if flap else 1
		draw_rect(Rect2(p + Vector2(-w, 0), Vector2(w, 2)), col)
		draw_rect(Rect2(p + Vector2(1, 0), Vector2(w, 2)), col)
		draw_rect(Rect2(p + Vector2(0, 0), Vector2(1, 2)), Color(0.15, 0.1, 0.05))
	# birds: little "v" shapes with their shadow far below
	for b in _birds:
		var p: Vector2 = (b["pos"] as Vector2).floor()
		var up := sin(_t * 9.0 + b["phase"]) > 0
		var dy := -1 if up else 1
		var shadow := Color(0, 0, 0, 0.18)
		draw_line(p + Vector2(-3, dy) + Vector2(0, 40), p + Vector2(0, 40), shadow)
		draw_line(p + Vector2(0, 40), p + Vector2(3, dy) + Vector2(0, 40), shadow)
		draw_line(p + Vector2(-3, dy), p, Color(0.15, 0.12, 0.1))
		draw_line(p, p + Vector2(3, dy), Color(0.15, 0.12, 0.1))


func _spawn_flock() -> void:
	var size := Vector2(world.terrain.width, world.terrain.height) * TILE
	var y := randf_range(80, size.y - 80)
	for i in randi_range(3, 6):
		_birds.append({
			"pos": Vector2(-20 - i * 9, y + (i % 2) * 7 - i * 2),
			"vel": Vector2(randf_range(38, 46), randf_range(-4, 4)),
			"phase": randf() * TAU,
		})


func _mist(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _soft_blob(24)
	p.amount = 28
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 18)
	p.gravity = Vector2(4, -3)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.spread = 180.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.65, 0.95, 0.0))
	g.set_color(1, Color(0.75, 0.65, 0.95, 0.0))
	g.add_point(0.4, Color(0.78, 0.7, 0.98, 0.55))
	p.color_ramp = g
	p.z_index = 2
	return p


func _gold_dust(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 22
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(30, 6)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.55, 1))
	g.set_color(1, Color(1, 0.8, 0.3, 0))
	p.color_ramp = g
	p.z_index = 2
	return p


func _leaves() -> CPUParticles2D:
	# follows the camera so leaves are always drifting on screen
	var p := CPUParticles2D.new()
	var img := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color("6fae3a"))
	img.set_pixel(0, 1, Color("4c8a2a"))
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 10
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(200, 10)
	p.gravity = Vector2(6, 12)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.local_coords = false
	p.z_index = 3
	p.set_meta("follow_camera", true)
	p.name = "Leaves"
	return p


func _physics_process(_d: float) -> void:
	var leaves := get_node_or_null("Leaves")
	if leaves and world:
		leaves.global_position = world.player.global_position + Vector2(0, -110)


func _soft_blob(size: int) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
