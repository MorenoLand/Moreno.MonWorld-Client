class_name MonWorldWebSocket
extends Node

signal frame_received(message_type: int, value: Variant)
signal authentication_finished(result: Dictionary)
signal connection_changed(connected: bool)

var peer := WebSocketPeer.new()
var sequence := 0
var authenticating := false
var authenticated := false
var connecting := false
var _url := ""

func connect_and_auth(url: String, ticket: String, content_id: String) -> Dictionary:
	close()
	peer = WebSocketPeer.new()
	_url = url
	_pending_ticket = ticket
	_pending_content_id = content_id
	sequence = 0
	authenticating = true
	authenticated = false
	connecting = true
	var error := peer.connect_to_url(url)
	if error != OK:
		connecting = false
		authenticating = false
		return {"ok": false, "error": "WebSocket connection could not start: %s" % error}
	var result: Variant = await authentication_finished
	return result if result is Dictionary else {"ok": false, "error": "WebSocket authentication ended unexpectedly"}

func _process(_delta: float) -> void:
	if not connecting and not authenticated:
		return
	peer.poll()
	var state := peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if connecting:
			connecting = false
			sequence = 1
			var frame := MonWorldProtocol.encode_json(MonWorldProtocol.AUTHENTICATE, sequence, {"ticket": _pending_ticket, "client": "godot", "content_id": _pending_content_id})
			if frame.is_empty() or peer.send(frame, WebSocketPeer.WRITE_MODE_BINARY) != OK:
				_finish_authentication({"ok": false, "error": "authentication frame could not be sent"})
			else:
				connection_changed.emit(true)
		while peer.get_available_packet_count() > 0:
			var frame_data := peer.get_packet()
			var frame := MonWorldProtocol.decode(frame_data)
			if not frame.ok:
				_finish_authentication({"ok": false, "error": frame.error})
				close()
				return
			var value: Variant = frame.value
			frame_received.emit(frame.type, value)
			if frame.type == MonWorldProtocol.HELLO and authenticating:
				authenticated = true
				_finish_authentication({"ok": true, "hello": value})
			elif frame.type == MonWorldProtocol.ERROR and authenticating:
				_finish_authentication({"ok": false, "error": str(value.get("message", "server rejected the connection")) if value is Dictionary else "server rejected the connection"})
	elif state == WebSocketPeer.STATE_CLOSED:
		if connecting or authenticating:
			_finish_authentication({"ok": false, "error": "WebSocket closed before authentication"})
		connecting = false
		authenticated = false
		connection_changed.emit(false)

var _pending_ticket := ""
var _pending_content_id := ""

func send_json(message_type: int, value: Variant) -> bool:
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	sequence += 1
	var frame := MonWorldProtocol.encode_json(message_type, sequence, value)
	return not frame.is_empty() and peer.send(frame, WebSocketPeer.WRITE_MODE_BINARY) == OK

func close() -> void:
	if peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		peer.close()
	connecting = false
	authenticating = false
	authenticated = false

func _finish_authentication(result: Dictionary) -> void:
	if not authenticating:
		return
	authenticating = false
	authentication_finished.emit(result)
