extends Node3D
## The Pesta Warisan games in "HD-2D", like the overworld (world/hd2d_view.gd):
## a view only. A game still runs on its 2D play node (court, track, ring) and
## that node's sprites; with a stage the play node is hidden and shown again
## in 3D:
##   ground   a second copy of the play node (the "painter": its _draw without
##            the sprites) is rendered into a texture and laid flat
##   sprites  every Sprite2D / AnimatedSprite2D child of the play node gets a
##            Sprite3D card standing where its origin is. Metadata on the 2D
##            sprite: "ground_y" = the play-node y it stands at when its own
##            origin is up in the air (a rider on a sled), "order" = what is
##            drawn over what at the same spot
##   props    houses, trees, people standing about: prop() / person()
## 1 unit = 1 / K px of the play node. The cards lean back towards the camera.

const K := 1.0 / 40.0
const LEAN := deg_to_rad(16.0)

var play: Node2D
var painter: Node2D
var rect: Rect2            ## the part of the play node that is the ground picture
var cam_offset := Vector3(0, 12.0, 13.0)
var cam_look_up := 0.6     ## the camera aims this far above the focus

var _camera: Camera3D
var _focus := Vector3.ZERO
var _cards := {}           ## 2D sprite id -> {src, card, tex}
var _scan_in := 0.0


## p: play-node px (+ px above the ground) -> world
func to3(p: Vector2, up := 0.0) -> Vector3:
	return Vector3(p.x * K, up * K, p.y * K)


func setup(play_node: Node2D, ground_painter: Node2D, ground: Rect2, grass: Color) -> void:
	play = play_node
	painter = ground_painter
	rect = ground
	play.visible = false

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.50, 0.72, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.98, 0.95)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.62, 0.78, 0.92)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 0.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	# the painter draws the ground into a texture
	var vp := SubViewport.new()
	vp.size = Vector2i(rect.size.ceil())
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(painter)
	add_child(vp)
	vp.canvas_transform = Transform2D(0.0, -rect.position)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size * K
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.roughness = 1.0
	floor_mesh.material_override = mat
	floor_mesh.position = to3(rect.get_center())
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
	# grass all around
	var field := MeshInstance3D.new()
	var big := PlaneMesh.new()
	big.size = Vector2(rect.size.x * K + 160.0, rect.size.y * K + 160.0)
	field.mesh = big
	var gm := StandardMaterial3D.new()
	gm.albedo_color = grass
	gm.roughness = 1.0
	field.material_override = gm
	field.position = to3(rect.get_center()) + Vector3(0, -0.02, 0)
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.far = 200.0
	add_child(_camera)
	look_at_px(rect.get_center(), true)
	_camera.make_current()
	_scan()


## the camera follows this spot of the play node
func look_at_px(p: Vector2, at_once := false) -> void:
	_focus = to3(p)
	if at_once and _camera:
		_camera.position = _focus + cam_offset
		_camera.look_at(_focus + Vector3(0, cam_look_up, 0))


## the ground under the mouse, in play-node px
func mouse_px() -> Vector2:
	var m := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(_camera.project_ray_origin(m), _camera.project_ray_normal(m))
	return Vector2(hit.x, hit.z) / K if hit != null else rect.get_center()


func _card() -> Sprite3D:
	var s := Sprite3D.new()
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.rotation.x = -LEAN
	add_child(s)
	return s


## something standing on the ground: a house, a tree. `at` = the middle of its foot, play-node px
func prop(tex: Texture2D, at: Vector2, scale := 3.0) -> Sprite3D:
	var s := _card()
	s.texture = tex
	s.pixel_size = K * scale
	s.offset = Vector2(0, tex.get_height() / 2.0)
	s.position = to3(at)
	return s


## somebody standing about, looking `facing` (south, east, west, north)
func person(folder: String, at: Vector2, facing := "south", scale := 2.4) -> Sprite3D:
	var tex: Texture2D = CharacterFrames.build(folder, false).get_frame_texture("idle_" + facing, 0)
	var s := _card()
	s.texture = tex
	s.pixel_size = K * scale
	var feet := CharacterFrames.feet_offset(folder)
	s.offset = Vector2(feet.x, -feet.y)
	s.position = to3(at)
	return s


func _process(delta: float) -> void:
	painter.queue_redraw()
	_camera.position = _camera.position.lerp(_focus + cam_offset, minf(1.0, delta * 6.0))
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = 0.25
		_scan()
	for id in _cards.keys():
		var e: Dictionary = _cards[id]
		if not is_instance_valid(e["src"]):
			e["card"].queue_free()
			_cards.erase(id)
		else:
			_sync(e)


func _scan() -> void:
	for c in play.get_children():
		if (c is Sprite2D or c is AnimatedSprite2D) and not _cards.has(c.get_instance_id()):
			_cards[c.get_instance_id()] = {"src": c, "card": _card(), "tex": null}


func _sync(e: Dictionary) -> void:
	var src: Node2D = e["src"]
	var card: Sprite3D = e["card"]
	var tex: Texture2D
	if src is AnimatedSprite2D:
		if src.sprite_frames and src.sprite_frames.has_animation(src.animation):
			tex = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	else:
		tex = src.texture
	card.visible = tex != null and src.visible
	if not card.visible:
		return
	if tex != e["tex"]:
		e["tex"] = tex
		card.texture = tex
		card.centered = src.centered
		# 2D offsets count down from the top, a Sprite3D's up from the bottom
		card.offset = Vector2(src.offset.x, -src.offset.y - (0.0 if src.centered else float(tex.get_height())))
	card.flip_h = src.flip_h
	if src is Sprite2D:
		card.region_enabled = src.region_enabled
		card.region_rect = src.region_rect
	card.pixel_size = K * src.scale.x
	var ground: float = src.get_meta("ground_y", src.position.y)
	var order: float = src.get_meta("order", 0.0)
	# every card that stands at the same spot lies in one leaning plane, whatever the height of
	# its own origin: otherwise a rider drawn lower than his sled ends up behind it
	var up: float = (ground - src.position.y) * K
	card.position = Vector3(src.position.x * K, up + order * 0.004, ground * K - up * tan(LEAN) + order * 0.012)
	card.rotation = Vector3(-LEAN, 0.0, -src.rotation)
	card.modulate = src.modulate
	card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if src.modulate.a > 0.97 else SpriteBase3D.ALPHA_CUT_DISABLED
