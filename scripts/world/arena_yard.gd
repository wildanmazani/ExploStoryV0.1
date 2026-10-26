extends RefCounted
## The yard in front of an Arena Ulang Kaji (entities.json "arenas"): other
## players spar in pairs with the Gelanggang fight frames, a "Aina VS Irfan"
## tag over each match, next to wooden training dummies (Jurus Ingatan). Talking to a
## fighter offers the lobby; a dummy wobbles and opens Jurus Ingatan.

const TILE := 16
const DUMMY := "res://assets/objects/patung_latihan.png"
## shop outfits and classmates: every one has Gelanggang fight frames
const LOOKS := ["alif", "alif_sukan", "alif_pengakap", "alif_melayu", "alif_pahlawan", "alif_bomba",
	"rakan_aisyah", "rakan_daniel", "rakan_meiling", "rakan_ravi"]
const NAMES := ["Aina", "Irfan", "WeiJie", "Kavitha", "Danish", "Sofea", "Arjun", "Nurul",
	"Haziq", "MeiLing", "Farah", "Zul", "Priya", "Adam", "Hana", "Iman", "Syafiq", "Ravi"]
const ATTACKS := ["jab", "cross", "kick", "roundhouse"]


## spawn one yard's fighters and dummies into the world (cells blocked,
## interactions registered); returns the dummy sprites by cell
static func build(world: Node, def: Dictionary) -> Dictionary:
	var dummies := {}
	for p in def.get("pairs", []):
		var pair := Pair.new()
		world.objects.add_child(pair)
		var looks: Array = LOOKS.duplicate()
		looks.shuffle()
		for i in 2:
			var c := Vector2i(int(p[i][0]), int(p[i][1]))
			var f := Fighter.new()
			f.setup(looks[i], c, i == 1)
			world.objects.add_child(f)
			pair.fighters.append(f)
			world.blocked[c] = true
			world.interact[c] = {"type": "talk", "id": "pemain_arena"}
		pair.add_tag()
	for d in def.get("dummies", []):
		var c := Vector2i(int(d[0]), int(d[1]))
		var s := Sprite2D.new()
		s.texture = dummy_texture()
		s.offset = CharacterFrames.visible_bottom_offset(s.texture)
		s.position = Vector2((c.x + 0.5) * TILE, (c.y + 1) * TILE)
		world.objects.add_child(s)
		world.blocked[c] = true
		world.interact[c] = {"type": "talk", "id": "patung_latihan"}
		dummies[c] = s
	return dummies


## a hit on the dummy: it rocks on its base and settles
static func wobble(s: Sprite2D) -> void:
	var tw := s.create_tween()
	for a in [0.28, -0.2, 0.12, -0.06, 0.0]:
		tw.tween_property(s, "rotation", a, 0.09)


## assets/objects/patung_latihan.png when it exists, else a wooden silat
## dummy drawn in pixels (post, arms, padded head, base)
static func dummy_texture() -> Texture2D:
	if ResourceLoader.exists(DUMMY):
		return load(DUMMY)
	const ROWS := [
		"....####....", "...#hhhh#...", "...#hhhh#...", "...#hHhh#...", "....####....",
		".....#w#....", "###########.", "#aaaaaaaaa#.", "###########.", ".....#w#....",
		"....#www#...", "....#wpw#...", "....#wpw#...", "....#www#...", ".....#w#....",
		".....#w#....", ".....#w#....", "...#######..", "..#bbbbbbb#.", "..#########.",
	]
	var cols := {"#": Color("3a2414"), "h": Color("c9a26b"), "H": Color("e8c890"), "w": Color("9c6a3c"),
		"a": Color("b5824c"), "p": Color("d24a3c"), "b": Color("6e4a2c")}
	var img := Image.create(12, 20, false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		for x in ROWS[y].length():
			if cols.has(ROWS[y][x]):
				img.set_pixel(x, y, cols[ROWS[y][x]])
	return ImageTexture.create_from_image(img)


## two fighters facing each other: one attacks (a random strike), the other
## takes it or steps back, then a pause; who attacks changes each round
class Pair extends Node2D:
	var fighters: Array = []
	var _wait := randf_range(0.4, 2.0)
	var _target: Fighter

	## the match's name tag, centred over both fighters
	func add_tag() -> void:
		position = (fighters[0].position + fighters[1].position) / 2.0
		var names: Array = NAMES.duplicate()
		names.shuffle()
		var tag := Label.new()
		tag.text = "%s VS %s" % [names[0], names[1]]
		tag.theme = Game.theme
		tag.add_theme_font_size_override("font_size", 26)
		tag.add_theme_color_override("font_color", Color("fff3c4"))
		tag.add_theme_color_override("font_outline_color", Color("1b1408"))
		tag.add_theme_constant_override("outline_size", 10)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(240, 40)
		tag.scale = Vector2(0.2, 0.2)   # drawn big, shown small: stays sharp under the zoomed camera
		tag.position = Vector2(-24, -40)
		tag.z_index = 6
		add_child(tag)

	func _process(delta: float) -> void:
		if fighters.size() < 2:
			return
		_wait -= delta
		if _wait > 0.0:
			return
		if _target:  # the strike lands
			if randf() < 0.65:
				_target.play("hurt")
			else:
				_target.step_back()
			_target = null
			_wait = randf_range(1.0, 2.4)
			return
		var i := randi() % 2
		fighters[i].play(ATTACKS.pick_random())
		_target = fighters[1 - i]
		_wait = 0.22


## one player on the yard: fight frames (drawn facing east, flipped when it
## faces west)
class Fighter extends Node2D:
	var _sprite: AnimatedSprite2D
	var _west := false

	func setup(look: String, at: Vector2i, west: bool) -> void:
		_west = west
		position = Player.cell_to_pos(at)
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = CharacterFrames.build_fight(look)
		_sprite.offset = CharacterFrames.feet_offset(look)
		_sprite.flip_h = west
		_sprite.animation_finished.connect(func(): _sprite.play("stance"))
		add_child(_sprite)
		_sprite.play("stance")
		_sprite.frame = randi() % maxi(1, _sprite.sprite_frames.get_frame_count("stance"))

	func play(anim: String) -> void:
		_sprite.play(anim)

	## a block: a quick hop back and in again
	func step_back() -> void:
		var tw := create_tween()
		var dx := 3.0 if _west else -3.0
		tw.tween_property(_sprite, "position:x", dx, 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "position:x", 0.0, 0.2).set_ease(Tween.EASE_IN_OUT)

	func _draw() -> void:
		draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.28))
