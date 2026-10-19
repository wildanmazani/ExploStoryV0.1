extends SceneTree
## Writes every west-facing frame of Alif's outfits as a mirror of the
## east-facing one, so walking left and right always match (PixelLab's two
## side views of one character can differ). Run after tools/fetch_assets.py:
##   godot --headless --path . -s tools/mirror_west.gd
## Characters listed in tools/asset_manifest.json "mirror_west".

const BASE := "res://assets/characters32/"


func _init() -> void:
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://tools/asset_manifest.json"))
	var n := 0
	for name in m.get("mirror_west", []):
		n += _mirror("%s%s/%s_east.png" % [BASE, name, name], "%s%s/%s_west.png" % [BASE, name, name])
		var i := 0
		while _mirror("%s%s_walk/%s_walk_east_%d.png" % [BASE, name, name, i], "%s%s_walk/%s_walk_west_%d.png" % [BASE, name, name, i]) == 1:
			n += 1
			i += 1
	print("mirrored %d frames" % n)
	quit()


func _mirror(from: String, to: String) -> int:
	var src := ProjectSettings.globalize_path(from)
	if not FileAccess.file_exists(src):
		return 0
	var img := Image.load_from_file(src)
	img.flip_x()
	img.save_png(ProjectSettings.globalize_path(to))
	return 1
