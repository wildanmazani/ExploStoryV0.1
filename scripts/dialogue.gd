extends Node
## Autoload "Dialogue": world chatter in data/dialogue/*.json (natural,
## repeatable conversations). Talking to someone again moves to their next
## variant; after the last one it picks at random so it never feels scripted.
## Lines are returned in the story format used by Game.say():
##   {"s": speaker, "t": text, "e": expression, "rekaan": bool}

var _data := {}
var _seen := {}  ## id -> times played


func _ready() -> void:
	var dir := DirAccess.open("res://data/dialogue")
	if dir == null:
		push_error("data/dialogue missing")
		return
	for file in dir.get_files():
		if file.ends_with(".json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + file))
			if parsed is Dictionary:
				_data.merge(parsed, true)


func has(id: String) -> bool:
	return _data.has(id)


func lines(id: String) -> Array:
	if not _data.has(id):
		push_warning("No dialogue for '%s'" % id)
		return []
	var entry: Dictionary = _data[id]
	var variants: Array = entry["variants"]
	var n: int = _seen.get(id, 0)
	_seen[id] = n + 1
	var pick: Array = variants[n] if n < variants.size() else variants[randi_range(1 if variants.size() > 1 else 0, variants.size() - 1)]
	var out := []
	for l in pick:
		var who: String = l["who"]
		var line := {"s": who, "t": l["text"], "e": l.get("e", "")}
		if entry.get("rekaan", false) and Game.characters.get(who, {}).get("tokoh", false):
			line["rekaan"] = true
		out.append(line)
	return out
