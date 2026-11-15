class_name Hd2dView
extends Node3D
## The overworld shown in "HD-2D": a 3D world with the 2D pixel-art sprites
## standing in it. On by default: Tetapan > Paparan switches it off ("hd2d" in
## the settings), and on the command line  -- --2d  forces it off, -- --hd2d
## forces it on (add --day for daylight). N switches day / night.
##
## It is only a *view*. world.gd still runs the whole game on its 2D nodes
## (player, NPCs, missions, dialogue, portals); those nodes are taken off the
## screen with canvas layers and this node shows them again in 3D, every frame:
##   ground     the 2D ground (tiles, water shader, flat decor, Kabus Lupa) is
##              rendered into a texture and laid flat. 1 world unit = 1 tile
##   objects    every Sprite2D / AnimatedSprite2D under world.objects gets a
##              Sprite3D "card", leaning back a little towards the camera
##   markers    "!" quest markers, mission-sign numbers, clue glints
##   light      sun / moon, and a warm lamp at every pelita, lamp post and house
## world.to_screen() / mouse_world() ask this node where things are on screen.
## Not shown yet: chickens and ducks, smoke / butterflies / birds (drawn by 2D
## code or particles). Rooms (interiors) are still 2D.

const KluAisyah = preload("res://scripts/world/klu_aisyah.gd")
const PX := 1.0 / 16.0
const LEAN := deg_to_rad(18.0)  ## cards lean back so the camera sees more of them
const CHUNK := 8                ## ground is cut into chunks: GL Compatibility lights 8 lamps per mesh
const CAM_OFFSET := Vector3(0, 13.0, 15.5)
const L_WORLD := 8      ## canvas layer of the 2D world: the screen skips it
const L_OBJECTS := 4    ## ... of world.objects: the ground texture skips it too
const L_FOG := 16       ## ... of the Kabus Lupa: on the ground texture, not on the map picture
## object char -> [lamp height, range, energy]: things that glow at night
const LAMPS := {
	"l": [1.3, 6.0, 2.2], "z": [2.2, 7.0, 2.4],
	"H": [1.4, 7.0, 1.6], "U": [1.4, 7.0, 1.8], "M": [1.2, 6.0, 1.8],
	"h": [1.6, 7.0, 1.6], "6": [1.6, 8.0, 1.8], "7": [1.6, 8.0, 1.8], "I": [2.0, 10.0, 2.2],
}
const WARM := Color(1.0, 0.72, 0.38)
const FOG_TINT := Color(0.62, 0.64, 0.70)  ## cards inside the Kabus Lupa

var world: Node2D
var night := 1.0  ## 1 = night, 0 = day

var _camera: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _lamps: Array[OmniLight3D] = []
var _lamp_energy: Array[float] = []
var _glows: Array[MeshInstance3D] = []
var _glow_tex: GradientTexture2D
var _hero: OmniLight3D  ## a little light that walks with Alif, so he reads at night
var _cards := {}       ## source node id -> {src, card, kind, entity, tex, fog} (card null = nothing to show)
var _old_mask := 0
var _scan_in := 0.0
var _t := 0.0


static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--2d" in args:
		return false
	return "--hd2d" in args or bool(Game.settings.get("hd2d", true))


func setup(w: Node2D) -> void:
	world = w


func _ready() -> void:
	if "--day" in OS.get_cmdline_user_args():
		night = 0.0
	_build_light()
	_build_ground()
	_build_lamps()
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.far = 140.0
	add_child(_camera)
	_camera.position = _focus() + CAM_OFFSET
	_camera.look_at(_focus() + Vector3(0, 0.8, 0))
	_camera.make_current()
	# off the screen, still in the 2D world: see the header
	world.visibility_layer = L_WORLD
	world.objects.visibility_layer = L_OBJECTS
	world.get_node("Ambience").visibility_layer = L_OBJECTS
	var vp := get_viewport()
	_old_mask = vp.canvas_cull_mask
	vp.canvas_cull_mask = _old_mask & ~(L_WORLD | L_OBJECTS | L_FOG)
	_apply_time()
	_scan()


func _exit_tree() -> void:
	if _old_mask != 0 and get_viewport():
		get_viewport().canvas_cull_mask = _old_mask  # rooms and screens are 2D
	if is_instance_valid(world) and not world.is_queued_for_deletion():  # switched off in Tetapan: plain 2D again
		world.visibility_layer = 1
		world.objects.visibility_layer = 1
		world.get_node("Ambience").visibility_layer = 1
		if world._fog:
			world._fog.visibility_layer = 1


# ---------------------------------------------------------------- world <-> screen

## world pixels (+ pixels above the ground) -> screen
func to_screen(px: Vector2, lift := 0.0) -> Vector2:
	var p := Vector3(px.x * PX, lift * PX, px.y * PX)
	if _camera.is_position_behind(p):  # south of the camera: far off that way
		var me: Vector2 = world.player.global_position
		return _camera.unproject_position(_focus()) + (px - me).normalized() * 4000.0
	return _camera.unproject_position(p)


## the ground under the mouse, in world pixels
func mouse_world() -> Vector2:
	var m := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(m)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, _camera.project_ray_normal(m))
	if hit == null:
		return world.player.global_position
	return Vector2(hit.x, hit.z) / PX


## what the camera follows: Alif, plus the 2D camera's offset (the Arena reveal glides it)
func _focus() -> Vector3:
	var p: Vector2 = world.player.global_position + world.camera.offset
	return Vector3(p.x * PX, 0, p.y * PX)


# ---------------------------------------------------------------- light

func _build_light() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, 28, 0)  # from the south-east, onto the fronts of the cards
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 45.0
	add_child(_sun)

	_hero = OmniLight3D.new()
	_hero.light_color = Color(1.0, 0.9, 0.78)
	_hero.omni_range = 4.5
	_hero.omni_attenuation = 1.2
	add_child(_hero)

	_glow_tex = GradientTexture2D.new()
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow_tex.gradient = g


## a soft additive halo (lamps, clue glints)
func _halo(size: float, colour: Color) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	q.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _glow_tex
	m.albedo_color = colour
	m.disable_fog = true
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	return q


func _build_lamps() -> void:
	var rows := FileAccess.get_file_as_string("res://data/world/objects.txt").split("\n", false)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if not LAMPS.has(row[x]):
				continue
			var lamp: Array = LAMPS[row[x]]
			var foot: Vector2i = world.OBJECTS[row[x]]["foot"]
			var l := OmniLight3D.new()
			l.position = Vector3(x + foot.x / 2.0, lamp[0], y + 1.6)
			l.light_color = WARM
			l.omni_range = lamp[1]
			l.omni_attenuation = 1.4
			add_child(l)
			_lamps.append(l)
			_lamp_energy.append(lamp[2])
			var halo := _halo(2.2, WARM)
			halo.position = l.position
			_glows.append(halo)


## day <-> night: sky, ambient, sun / moon, and the lamps come on
func _apply_time() -> void:
	var n := night
	_env.background_color = Color(0.50, 0.72, 0.92).lerp(Color(0.02, 0.03, 0.07), n)
	_env.ambient_light_color = Color(1.0, 0.98, 0.95).lerp(Color(0.30, 0.38, 0.72), n)
	_env.ambient_light_energy = lerpf(0.42, 0.16, n)
	_env.fog_density = lerpf(0.002, 0.012, n)
	_env.fog_light_color = Color(0.62, 0.78, 0.92).lerp(Color(0.03, 0.05, 0.11), n)
	_env.glow_bloom = lerpf(0.0, 0.15, n)
	_env.glow_intensity = lerpf(0.2, 0.6, n)
	_sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(0.55, 0.66, 1.0), n)
	_sun.light_energy = lerpf(0.62, 0.16, n)
	_hero.light_energy = 0.9 * n
	_hero.visible = n > 0.02
	for i in _lamps.size():
		_lamps[i].light_energy = _lamp_energy[i] * n
		_lamps[i].visible = n > 0.02
		_glows[i].visible = n > 0.02
		(_glows[i].material_override as StandardMaterial3D).albedo_color = Color(WARM, 0.75 * n)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			night = v
			_apply_time(), night, 0.0 if night > 0.5 else 1.0, 1.6)


# ---------------------------------------------------------------- ground

## A second camera on the same 2D world, looking at the whole island from
## above, sees only the ground layers; the 3D ground wears its picture.
func _build_ground() -> void:
	var w: int = world.terrain.width
	var h: int = world.terrain.height
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h) * 16
	vp.world_2d = world.get_viewport().world_2d
	vp.disable_3d = true
	vp.canvas_cull_mask = 1 | L_WORLD | L_FOG
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # the water shimmers, the fog drifts
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	vp.add_child(cam)
	add_child(vp)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for cy in range(0, h, CHUNK):
		for cx in range(0, w, CHUNK):
			var x1 := minf(cx + CHUNK, w)
			var z1 := minf(cy + CHUNK, h)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in [Vector2(cx, cy), Vector2(x1, cy), Vector2(x1, z1), Vector2(cx, cy), Vector2(x1, z1), Vector2(cx, z1)]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(p.x / w, p.y / h))
				st.add_vertex(Vector3(p.x, 0, p.y))
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
	# open sea all around the island
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 160, h + 160)
	sea.mesh = plane
	var sm := StandardMaterial3D.new()
	sm.albedo_color = world.map_sea
	sm.roughness = 1.0
	sea.material_override = sm
	sea.position = Vector3(w / 2.0, -0.02, h / 2.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


# ---------------------------------------------------------------- the 2D nodes, in 3D

func _process(delta: float) -> void:
	_t += delta
	_scan_in -= delta
	if _scan_in <= 0.0:  # new arrivals (NPCs, markers, clue glints), and who stands in the fog
		_scan_in = 0.25
		_scan()
	_camera.position = _camera.position.lerp(_focus() + CAM_OFFSET, minf(1.0, delta * 6.0))
	var hero: Vector2 = world.player.global_position
	_hero.position = Vector3(hero.x * PX, 1.6, hero.y * PX + 1.6)
	for id in _cards.keys():
		var e: Dictionary = _cards[id]
		if not is_instance_valid(e["src"]):
			if e["card"]:
				e["card"].queue_free()
			_cards.erase(id)
		elif e["card"]:
			match e["kind"]:
				"sprite": _sync_sprite(e)
				"marker": _sync_marker(e)
				_: e["card"].visible = e["src"].is_visible_in_tree()


func _scan() -> void:
	if world._fog and world._fog.visibility_layer != L_FOG:
		world._fog.visibility_layer = L_FOG  # (the map photo moves it to layer 2)
	_walk(world.objects, null)
	var rects: Array = world.fog_rects()
	for e in _cards.values():
		if e["kind"] == "sprite" and is_instance_valid(e["src"]):
			var g: Vector2 = e["entity"].global_position
			var inside := false
			for r in rects:
				if g.x >= r.x and g.y >= r.y and g.x <= r.x + r.z and g.y <= r.y + r.w:
					inside = true
					break
			e["fog"] = inside


func _walk(parent: Node, entity: Node) -> void:
	for c in parent.get_children():
		var ent: Node = entity if entity else c
		if not _cards.has(c.get_instance_id()):
			_cards[c.get_instance_id()] = _mirror(c, ent)
		if c.get_child_count() > 0:
			_walk(c, ent)


## the 3D stand-in for one 2D node (card null: nothing to show for it)
func _mirror(src: Node, entity: Node) -> Dictionary:
	var e := {"src": src, "card": null, "kind": "", "entity": entity, "tex": null, "fog": false}
	if src is Sprite2D or src is AnimatedSprite2D:
		var s := Sprite3D.new()
		s.pixel_size = PX
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = true
		s.double_sided = true
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.rotation.x = -LEAN
		if src is Sprite2D:
			s.hframes = src.hframes
			s.vframes = src.vframes
			s.region_enabled = src.region_enabled
			s.region_rect = src.region_rect
		e["card"] = s
		e["kind"] = "sprite"
	elif src is ZoneRunner.Marker:
		var m := Label3D.new()
		m.text = "!"
		m.font = Game.theme.default_font
		m.font_size = 120
		m.pixel_size = 0.0075
		m.modulate = Color(1, 0.86, 0.3)
		m.outline_modulate = Color(0.17, 0.11, 0.06)
		m.outline_size = 28
		m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true  # never hidden behind a roof
		e["card"] = m
		e["kind"] = "marker"
	elif src is KluAisyah.Glint:
		var halo := _halo(1.4, Color(1, 0.95, 0.7, 0.9))
		halo.position = Vector3(src.global_position.x * PX, 0.35, src.global_position.y * PX)
		e["card"] = halo
		e["kind"] = "glint"
		return e
	elif src is Label:
		# a number painted on a sign: it stands where the sign stands
		var l := Label3D.new()
		var sc: Vector2 = src.get_global_transform().get_scale()
		var centre: Vector2 = src.global_position + src.size * sc / 2.0
		var ground := ceilf(centre.y / 16.0) * 16.0
		l.text = src.text
		l.font = src.get_theme_font("font")
		l.font_size = src.get_theme_font_size("font_size")
		l.pixel_size = PX * sc.x
		l.modulate = src.get_theme_color("font_color")
		l.outline_size = 0
		l.rotation.x = -LEAN
		l.position = Vector3(centre.x * PX, (ground - centre.y) * PX, ground * PX + 0.08)
		e["card"] = l
		e["kind"] = "label"
	if e["card"]:
		add_child(e["card"])
	return e


func _sync_sprite(e: Dictionary) -> void:
	var src: Node2D = e["src"]
	var card: Sprite3D = e["card"]
	var tex: Texture2D
	if src is AnimatedSprite2D:
		if src.sprite_frames and src.sprite_frames.has_animation(src.animation):
			tex = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	else:
		tex = src.texture
		if card.hframes * card.vframes > 1:
			card.frame = src.frame
	card.visible = tex != null and src.is_visible_in_tree()
	if not card.visible:
		return
	if tex != e["tex"] or card.offset.x != src.offset.x:
		e["tex"] = tex
		card.texture = tex
		card.centered = src.centered
		# 2D offsets count down from the top, a Sprite3D's up from the bottom
		card.offset = Vector2(src.offset.x, -src.offset.y - (0.0 if src.centered else float(tex.get_height())))
	card.flip_h = src.flip_h
	card.flip_v = src.flip_v
	# where it stands; inside a character, "up the screen" is up in the air (Pau's hop)
	var ent: Node2D = e["entity"]
	var g := src.global_position
	var up := 0.0
	if ent != src:
		up = ent.global_position.y - g.y
		g.y = ent.global_position.y
	# later siblings and higher z_index are drawn over (Alif's bag), as in 2D
	var bias := 0.006 * src.get_index() + 0.02 * src.z_index if ent != src else 0.0
	card.position = Vector3(g.x * PX, up * PX, g.y * PX + bias)
	var sc := src.global_scale
	card.scale = Vector3(sc.x, sc.y, 1.0)
	var m := src.modulate * src.self_modulate
	var p := src.get_parent()
	while p != world.objects and p is CanvasItem:
		m *= p.modulate
		p = p.get_parent()
	if e["fog"]:
		m = Color(m.r * FOG_TINT.r, m.g * FOG_TINT.g, m.b * FOG_TINT.b, m.a)
	card.modulate = m
	card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if m.a > 0.97 else SpriteBase3D.ALPHA_CUT_DISABLED


## "!" over a place or a person: the 2D marker floats 34-38 px above the feet
func _sync_marker(e: Dictionary) -> void:
	var src: Node2D = e["src"]
	var card: Label3D = e["card"]
	card.visible = src.is_visible_in_tree()
	var g := src.global_position + Vector2(0, 36)
	card.position = Vector3(g.x * PX, 36 * PX + 0.45 + sin(_t * 4.0 + g.x) * 0.12, g.y * PX)
