extends Node
## Autoload "Dialogue": loads data/dialogue/*.json and hands out lines ready
## for DialogBox.play(). Talking to someone again moves to their next variant;
## after the last one it picks at random so it never feels scripted.

const SPEAKERS := {
	"alif": {"name": "Alif", "portrait": "res://assets/characters/alif/alif_south.png"},
	"pau": {"name": "Pau", "portrait": "res://assets/characters/pau.png"},
	"penjaga": {"name": "Penjaga Gerbang Masa", "portrait": "res://assets/characters/penjaga_gerbang_masa/penjaga_gerbang_masa_south.png"},
	"tunperak": {"name": "Bendahara Tun Perak", "portrait": "res://assets/characters/tun_perak/tun_perak_south.png"},
	"syahbandar": {"name": "Syahbandar", "portrait": "res://assets/characters/syahbandar/syahbandar_south.png"},
	"sapurba": {"name": "Sang Sapurba", "portrait": "res://assets/characters/sang_sapurba/sang_sapurba_south.png"},
	"demang": {"name": "Demang Lebar Daun", "portrait": "res://assets/characters/demang_lebar_daun/demang_lebar_daun_south.png"},
	"makcik": {"name": "Mak Som", "portrait": "res://assets/characters32/makcik/makcik_south.png"},
	"nelayan": {"name": "Pak Mat", "portrait": "res://assets/characters32/nelayan/nelayan_south.png"},
	"papan": {"name": "Papan tanda", "portrait": ""},
}

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


## Lines for DialogBox.play(): [{name, text, portrait, who}]
func lines(id: String) -> Array:
	if not _data.has(id):
		push_warning("No dialogue for '%s'" % id)
		return []
	var variants: Array = _data[id]["variants"]
	var n: int = _seen.get(id, 0)
	_seen[id] = n + 1
	var pick: Array = variants[n] if n < variants.size() else variants[randi_range(1 if variants.size() > 1 else 0, variants.size() - 1)]
	var out := []
	for l in pick:
		out.append(line(l["who"], l["text"]))
	return out


func line(who: String, text: String) -> Dictionary:
	var s: Dictionary = SPEAKERS.get(who, {"name": who.capitalize(), "portrait": ""})
	var portrait: Texture2D = load(s["portrait"]) if s["portrait"] != "" else null
	return {"name": s["name"], "text": text, "portrait": portrait, "who": who}
