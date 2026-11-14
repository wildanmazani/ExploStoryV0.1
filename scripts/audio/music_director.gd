extends Node
## Autoload "MusicDirector": interactive music (tools/gen_music.py renders the
## gamelan loops). Each area has two stems that loop together:
##   base   - always on
##   melody - rises while Alif explores, settles when he stands still
## Changing area crossfades on the next bar line. Puzzles add the "fokus"
## layer. Dialogue ducks everything. Stingers play on top.
##
## The two stems are two plain players started on the same frame (not an
## AudioStreamSynchronized): on the web the browser can then play them
## itself, so the music no longer stutters when the game is busy.

const DIR := "res://assets/audio/music/"
const BPM := {
	"tajuk": 76, "bilik": 64, "permulaan": 84, "kampung": 92, "gerbang": 70,
	"pelabuhan": 108, "melaka": 80, "siguntang": 66,
	"debar": 132,  ## chases and fear: the fog in the dream, Aisyah running away
}
const AREA_TRACK := {  # world area id -> track
	"permulaan": "permulaan", "kampung": "kampung", "gerbang": "gerbang",
	"pelabuhan": "pelabuhan", "melaka": "melaka", "siguntang": "siguntang",
	"kabus": "siguntang", "balai": "melaka",
	# Lembah Kebangkitan (Bab 2) borrows the island's tracks for now
	"lembah": "kampung", "dewan": "melaka", "falsafah": "gerbang", "dermaga": "pelabuhan",
	"serantau": "pelabuhan", "tugu": "siguntang", "kompleks": "kampung", "sitc": "melaka", "menara": "gerbang",
}
const MELODY_ON := -3.0
const MELODY_OFF := -22.0

var current := ""
var _a: AudioStreamPlayer   ## base stem of the track playing
var _am: AudioStreamPlayer  ## its melody stem
var _b: AudioStreamPlayer   ## the track fading out
var _bm: AudioStreamPlayer
var _deck_db := -80.0       ## base volume now; the melody sits _melody_db under it
var _fokus: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _melody_db := MELODY_ON
var _ducked := false
var _switch_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _player()
	_am = _player()
	_b = _player()
	_bm = _player()
	_fokus = _player()
	_sting = _player()
	_sting.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	p.volume_db = -80
	add_child(p)
	return p


## 44.1 kHz Ogg Vorbis (tools/gen_music.py): clear on phone speakers, small download
func _loop(path: String) -> AudioStream:
	var s: AudioStreamOggVorbis = load(path)
	if s == null:
		return null
	s.loop = true
	return s


## Play a track ("tajuk", "bilik") or a world area id ("kampung", "balai").
func play(name: String, fade := 1.6) -> void:
	name = AREA_TRACK.get(name, name)
	if name == current or not BPM.has(name):
		return
	_switch_id += 1
	var my_id := _switch_id
	# wait for the next bar of the current track so the change feels musical
	if current != "" and _a.playing:
		var bar := 4.0 * 60.0 / float(BPM[current])
		var wait := bar - fmod(_a.get_playback_position(), bar)
		if wait < 2.5:
			await get_tree().create_timer(wait).timeout
		if my_id != _switch_id:
			return
	current = name
	var old := _a
	var old_m := _am
	_a = _b
	_am = _bm
	_b = old
	_bm = old_m
	_a.stream = _loop(DIR + name + "_base.ogg")
	_am.stream = _loop(DIR + name + "_melody.ogg")
	_deck_db = -40.0
	_apply_deck()
	_a.play()
	_am.play()
	var t := create_tween().set_parallel()
	t.tween_method(_set_deck_db, -40.0, _target_db(), fade)
	if old.playing:
		t.tween_property(old, "volume_db", -60.0, fade)
		t.tween_property(old_m, "volume_db", -60.0, fade)
		t.chain().tween_callback(func():
			old.stop()
			old_m.stop())


func stop(fade := 1.2) -> void:
	current = ""
	var t := create_tween().set_parallel()
	for p in [_a, _am, _b, _bm, _fokus]:
		if p.playing:
			t.tween_property(p, "volume_db", -60.0, fade)
	t.chain().tween_callback(func():
		for p in [_a, _am, _b, _bm, _fokus]:
			p.stop())


## melody layer up (exploring) or down (standing still)
func set_melody(on: bool) -> void:
	var target := MELODY_ON if on else MELODY_OFF
	if is_equal_approx(target, _melody_db):
		return
	var t := create_tween()
	t.tween_method(_set_melody_db, _melody_db, target, 2.5 if on else 4.0)


func _set_melody_db(v: float) -> void:
	_melody_db = v
	_apply_deck()


## the track's volume: base at _deck_db, melody _melody_db under it
func _set_deck_db(v: float) -> void:
	_deck_db = v
	_apply_deck()


func _apply_deck() -> void:
	_a.volume_db = _deck_db
	_am.volume_db = _deck_db + _melody_db


## puzzles: a quiet focused pulse joins the music
func puzzle(on: bool) -> void:
	if on and not _fokus.playing:
		_fokus.stream = _loop(DIR + "fokus.ogg")
		_fokus.volume_db = -40
		_fokus.play()
	var t := create_tween()
	t.tween_property(_fokus, "volume_db", -8.0 if on else -60.0, 1.5)
	if not on:
		t.tween_callback(_fokus.stop)
	set_melody(not on)


func duck(on: bool) -> void:
	_ducked = on
	var t := create_tween()
	t.tween_method(_set_deck_db, _deck_db, _target_db(), 0.4)


func _target_db() -> float:
	return -9.0 if _ducked else -2.0


func stinger(name: String) -> void:
	var s: AudioStream = load(DIR + name + ".ogg")
	if s == null:
		return
	_sting.stream = s
	_sting.volume_db = 0.0
	_sting.play()
	# let the stinger breathe
	var t := create_tween()
	t.tween_method(_set_deck_db, _deck_db, -14.0, 0.2)
	t.tween_interval(maxf(s.get_length() - 1.5, 0.5))
	t.tween_method(_set_deck_db, -14.0, _target_db(), 1.2)
