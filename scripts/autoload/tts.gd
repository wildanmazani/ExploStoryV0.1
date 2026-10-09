extends Node
## Read-aloud (autoload "Tts"). Uses the platform text-to-speech
## (Web Speech API in browsers). Prefers a Malay voice, then Indonesian.

var voice_id: String = ""
var available: bool = true


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		available = false
		return
	_pick_voice()
	# desktop without a speech engine: switch read-aloud off quietly
	if voice_id == "" and OS.get_name() != "Web":
		available = false


func _pick_voice() -> void:
	for lang in ["ms", "id"]:
		var v: PackedStringArray = DisplayServer.tts_get_voices_for_language(lang)
		if v.size() > 0:
			voice_id = v[0]
			return
	var all: Array = DisplayServer.tts_get_voices()
	if all.size() > 0:
		voice_id = str(all[0].get("id", ""))


func speak(text: String) -> void:
	if not available or bool(Game.settings.get("muted", false)):
		return
	if voice_id == "":
		_pick_voice()
	if voice_id == "" and OS.get_name() != "Web":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voice_id, 90, 1.0, 0.95)


func stop() -> void:
	if available:
		DisplayServer.tts_stop()
