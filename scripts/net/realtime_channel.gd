class_name RealtimeChannel
extends Node
## One Supabase Realtime broadcast channel (the Phoenix websocket protocol),
## for things that must travel faster than the database: the online
## Gelanggang. Works in the web build (the browser's WebSocket).
##   open("gel-ABC123") -> joined
##   send("snap", {...}) -> everyone else on the channel gets message("snap", {...})
## Messages are not stored anywhere: if nobody listens, they are gone.

signal joined
signal message(event: String, payload: Dictionary)
signal closed

const HEARTBEAT := 25.0

var topic := ""
var is_joined := false
var _ws := WebSocketPeer.new()
var _join_ref := ""
var _ref := 0
var _hb := 0.0
var _was_open := false


func open(name: String) -> void:
	topic = "realtime:" + name
	var url := Backend.url.replace("https://", "wss://").replace("http://", "ws://")
	url += "/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % Backend.anon_key
	_ws.outbound_buffer_size = 1 << 20
	_ws.inbound_buffer_size = 1 << 20
	_ws.connect_to_url(url)


func close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()
	is_joined = false


func send(event: String, payload: Dictionary) -> void:
	if not is_joined:
		return
	_ws.send_text(JSON.stringify({"topic": topic, "event": "broadcast", "ref": null,
		"payload": {"type": "broadcast", "event": event, "payload": payload}}))


func _next_ref() -> String:
	_ref += 1
	return str(_ref)


func _process(delta: float) -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_join_ref = _next_ref()
			_ws.send_text(JSON.stringify({"topic": topic, "event": "phx_join", "ref": _join_ref, "join_ref": _join_ref,
				"payload": {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "private": false},
					"access_token": Backend.access_token if Backend.access_token != "" else Backend.anon_key}}))
		_hb += delta
		if _hb >= HEARTBEAT:
			_hb = 0.0
			_ws.send_text(JSON.stringify({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _next_ref()}))
		while _ws.get_available_packet_count() > 0:
			_read(_ws.get_packet().get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSED and _was_open:
		_was_open = false
		is_joined = false
		closed.emit()


func _read(text: String) -> void:
	var m = JSON.parse_string(text)
	if not (m is Dictionary):
		return
	match str(m.get("event", "")):
		"phx_reply":
			if str(m.get("ref", "")) == _join_ref and str(m.get("payload", {}).get("status", "")) == "ok":
				is_joined = true
				joined.emit()
		"broadcast":
			var p: Dictionary = m.get("payload", {})
			var inner = p.get("payload", {})
			message.emit(str(p.get("event", "")), inner if inner is Dictionary else {})
