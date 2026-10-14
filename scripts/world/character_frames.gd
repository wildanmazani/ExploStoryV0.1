class_name CharacterFrames
extends RefCounted
## Builds SpriteFrames from the PixelLab downloads in assets/characters32/:
##   <name>/<name>_<dir>.png                 idle, one per direction
##   <name>_walk/<name>_walk_<dir>_<i>.png   walk cycle (optional)

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
		frames.add_frame(idle, load("%s%s/%s_%s.png" % [BASE, name, name, d]))
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
