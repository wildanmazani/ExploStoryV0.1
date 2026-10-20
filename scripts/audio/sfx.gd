extends Node
## Autoload "Sfx": retro sound effects synthesised in code (no audio files),
## so they cost nothing to download on the web. Sfx.play("tick").

const RATE := 22050
const POOL := 8

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


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
		"fall": _make(0.3, func(t, _i): return _thump(t, 0.0) * 0.9 + _noise() * exp(-t * 18.0) * 0.25),
		"bell": _make(1.4, func(t, _i): return (sin(TAU * 660 * t) + sin(TAU * 1650 * t) * 0.5 + sin(TAU * 2310 * t) * 0.25) * exp(-t * 3.0) * 0.28),
	}


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


func _thump(t: float, start: float) -> float:
	var u := t - start
	if u < 0.0:
		return 0.0
	return sin(TAU * (60.0 + 40.0 * exp(-u * 30.0)) * u) * exp(-u * 14.0) * 0.9
