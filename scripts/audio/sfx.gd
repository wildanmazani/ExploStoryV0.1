extends Node
## Autoload "Sfx": retro sound effects synthesised in code (no audio files),
## so they cost nothing to download on the web. Sfx.play("tick").

const RATE := 22050
const POOL := 8
## dialogue sounds, rendered once to WAV (tools/gen_dialog_sfx.py) so nothing
## is computed in the game: babble_a..u (talking), taip_1..4 + taip_space (narrator)
const DIALOG_DIR := "res://assets/audio/sfx/"
const DIALOG_SOUNDS := ["babble_a", "babble_e", "babble_i", "babble_o", "babble_u", "taip_1", "taip_2", "taip_3", "taip_4", "taip_space"]

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _voice: Array[AudioStreamPlayer] = []
var _vnext := 0


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(p)
		_players.append(p)
	_sounds = {
		"tick": _make(0.05, func(t, _i): return _noise() * exp(-t * 120.0) * 0.5 + sin(TAU * 2200 * t) * exp(-t * 90.0) * 0.4),
		"tock": _make(0.06, func(t, _i): return _noise() * exp(-t * 110.0) * 0.4 + sin(TAU * 1500 * t) * exp(-t * 80.0) * 0.4),
		"heartbeat": _make(0.5, func(t, _i): return _thump(t, 0.0) + _thump(t, 0.18) * 0.7),
		"squish": _make(0.22, func(t, _i): return sin(TAU * (520.0 - 380.0 * t / 0.22) * t) * exp(-t * 9.0) * 0.5),
		"whoosh": _make(1.2, func(t, _i): return _noise() * sin(PI * t / 1.2) * 0.35),
		"chime": _make(1.6, func(t, _i): return (sin(TAU * 880 * t) + sin(TAU * 1320 * t) * 0.6 + sin(TAU * 1760 * t) * 0.3) * exp(-t * 2.4) * 0.25),
		"sparkle": _make(0.9, func(t, _i): return sin(TAU * (1200.0 + 1400.0 * fmod(t * 6.0, 1.0)) * t) * exp(-t * 3.5) * 0.18),
		"pop": _make(0.12, func(t, _i): return sin(TAU * (300.0 + 900.0 * t / 0.12) * t) * exp(-t * 25.0) * 0.5),
		"bump": _make(0.1, func(t, _i): return sin(TAU * 90 * t) * exp(-t * 30.0) * 0.7),
		"blip": _make(0.04, func(t, _i): return signf(sin(TAU * 620 * t)) * exp(-t * 60.0) * 0.12),
		"select": _make(0.08, func(t, _i): return signf(sin(TAU * (880.0 if t < 0.04 else 1320.0) * t)) * 0.12 * (1.0 - t / 0.08)),
		"step_grass": _make(0.07, func(t, _i): return _noise() * exp(-t * 60.0) * 0.18),
		"step_sand": _make(0.09, func(t, _i): return _noise() * exp(-t * 40.0) * 0.14),
		"step_stone": _make(0.05, func(t, _i): return (_noise() * 0.5 + sin(TAU * 180 * t)) * exp(-t * 90.0) * 0.2),
		"step_wood": _make(0.08, func(t, _i): return (sin(TAU * 140 * t) + _noise() * 0.3) * exp(-t * 50.0) * 0.25),
		# Gelanggang (brawl): cartoon hits, never gory
		"punch": _make(0.12, func(t, _i): return (sin(TAU * (180.0 - 600.0 * t) * t) * 0.8 + _noise() * 0.5) * exp(-t * 38.0) * 0.6),
		"kick": _make(0.16, func(t, _i): return (sin(TAU * (120.0 - 300.0 * t) * t) + _noise() * 0.6) * exp(-t * 26.0) * 0.6),
		"swish": _make(0.14, func(t, _i): return _noise() * sin(PI * t / 0.14) * 0.22),
		"thwack": _make(0.14, func(t, _i): return (signf(sin(TAU * 330 * t)) * 0.4 + _noise() * 0.6) * exp(-t * 34.0) * 0.45),
		# gedebuk: a body hitting the road (deep thud + dust), then a smaller second bump
		"gedebuk": _make(0.6, func(t, _i): return _thud(t, 0.0) + _thud(t, 0.22) * 0.45 + _noise() * exp(-t * 22.0) * 0.18),
		"fall": _make(0.3, func(t, _i): return _thump(t, 0.0) * 0.9 + _noise() * exp(-t * 18.0) * 0.25),
		"bell": _make(1.4, func(t, _i): return (sin(TAU * 660 * t) + sin(TAU * 1650 * t) * 0.5 + sin(TAU * 2310 * t) * 0.25) * exp(-t * 3.0) * 0.28),
	}
	for n in DIALOG_SOUNDS:
		if ResourceLoader.exists(DIALOG_DIR + n + ".wav"):
			_sounds[n] = load(DIALOG_DIR + n + ".wav")
	# the dialogue has its own players, so fast talking never cuts off other sounds
	for i in 3:
		var v := AudioStreamPlayer.new()
		v.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master"
		add_child(v)
		_voice.append(v)


## bus: "SFX", or "Voice" for the dialogue voice blips (own volume slider)
func play(name: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	p.stream = _sounds[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## dialogue talking / typing (Voice bus, its own players)
func voice(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sounds.has(name) or _voice.is_empty():
		return
	var p := _voice[_vnext]
	_vnext = (_vnext + 1) % _voice.size()
	p.stream = _sounds[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## same sound with a little random pitch so repeats never sound looped
func play_varied(name: String, volume_db := 0.0, spread := 0.08) -> void:
	play(name, volume_db, 1.0 + randf_range(-spread, spread))


func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(fn.call(float(i) / RATE, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s


func _noise() -> float:
	return randf() * 2.0 - 1.0


## heavier and lower than _thump: something big landing on the ground
func _thud(t: float, start: float) -> float:
	var u := t - start
	if u < 0.0:
		return 0.0
	return (sin(TAU * (42.0 + 70.0 * exp(-u * 25.0)) * u) + sin(TAU * 85.0 * u) * 0.35) * exp(-u * 9.0) * 0.95


func _thump(t: float, start: float) -> float:
	var u := t - start
	if u < 0.0:
		return 0.0
	return sin(TAU * (60.0 + 40.0 * exp(-u * 30.0)) * u) * exp(-u * 14.0) * 0.9
