class_name CharacterFrames
extends RefCounted
## Builds SpriteFrames from the PixelLab downloads in assets/characters32/:
##   <name>/<name>_<dir>.png                 idle, one per direction
##   <name>_walk/<name>_walk_<dir>_<i>.png   walk cycle (optional)
##   <name>_hover/<name>_hover_<dir>_<i>.png  looping idle instead of the
##                                           still pose (Nirbana floats)

const DIRS := ["south", "east", "north", "west"]
const BASE := "res://assets/characters32/"

static var _cache := {}


static func build(name: String, with_walk := false) -> SpriteFrames:
	var key := "%s:%s" % [name, with_walk]
	if _cache.has(key):
		return _cache[key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for d in DIRS:
		var idle: String = "idle_" + d
		frames.add_animation(idle)
		var h := 0
		while ResourceLoader.exists("%s%s_hover/%s_hover_%s_%d.png" % [BASE, name, name, d, h]):
			frames.add_frame(idle, load("%s%s_hover/%s_hover_%s_%d.png" % [BASE, name, name, d, h]))
			h += 1
		if h == 0:
			frames.add_frame(idle, load("%s%s/%s_%s.png" % [BASE, name, name, d]))
		else:
			frames.set_animation_speed(idle, 7.0)
		if with_walk:
			var walk: String = "walk_" + d
			frames.add_animation(walk)
			frames.set_animation_speed(walk, 13.0)
			var i := 0
			while true:
				var path := "%s%s_walk/%s_walk_%s_%d.png" % [BASE, name, name, d, i]
				if not ResourceLoader.exists(path):
					break
				frames.add_frame(walk, load(path))
				i += 1
	_cache[key] = frames
	return frames


## Offset that puts the bottom-centre of the visible pixels on the node origin.
static func feet_offset(name: String) -> Vector2:
	return visible_bottom_offset(load("%s%s/%s_south.png" % [BASE, name, name]))


static func visible_bottom_offset(tex: Texture2D) -> Vector2:
	var img := tex.get_image()
	var used := img.get_used_rect()
	var size := Vector2(img.get_size())
	return (size / 2.0 - Vector2(used.position.x + used.size.x / 2.0, used.end.y)).round()


## Gelanggang (side-view brawl): animations drawn facing east (flip for west).
##   <name>_<anim>/<name>_<anim>_east_<i>.png   (tools/asset_manifest.json)
## Missing ones fall back to the east idle / walk, so a fighter always works.
const FIGHT_ANIMS := ["stance", "jab", "cross", "kick", "roundhouse", "flykick", "hurt", "fall", "getup", "pickup", "throw", "special"]


static func build_fight(name: String) -> SpriteFrames:
	var key := "%s:fight" % name
	if _cache.has(key):
		return _cache[key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var idle: Texture2D = load("%s%s/%s_east.png" % [BASE, name, name])
	for anim in ["walk"] + FIGHT_ANIMS:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, anim in ["walk", "stance"])
		frames.set_animation_speed(anim, 13.0 if anim == "walk" else 10.0)
		var i := 0
		while true:
			var path := "%s%s_%s/%s_%s_east_%d.png" % [BASE, name, anim, name, anim, i]
			if not ResourceLoader.exists(path):
				break
			frames.add_frame(anim, load(path))
			i += 1
		if i == 0:
			frames.add_frame(anim, idle)
	_cache[key] = frames
	return frames


## true when PixelLab frames exist for this fight animation
static func has_fight_anim(name: String, anim: String) -> bool:
	return ResourceLoader.exists("%s%s_%s/%s_%s_east_0.png" % [BASE, name, anim, name, anim])
