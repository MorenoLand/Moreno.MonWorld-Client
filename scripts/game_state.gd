extends Node

signal characters_changed(characters: Array)
signal world_snapshot_received(snapshot: Dictionary)
signal entity_update_received(update: Dictionary)
signal chat_received(message: Dictionary)
signal battle_event_received(event: Dictionary)
signal connection_error(message: String)

var api: MonWorldAPI
var socket: MonWorldWebSocket
var content_pack: MonWorldContentPack
var server_manifest: Dictionary = {}
var access_token := ""
var refresh_token := ""
var user: Dictionary = {}
var characters: Array = []
var current_snapshot: Dictionary = {}
var current_character: Dictionary = {}

func _ready() -> void:
	api = MonWorldAPI.new()
	add_child(api)
	socket = MonWorldWebSocket.new()
	add_child(socket)
	socket.frame_received.connect(_on_frame)
	socket.connection_changed.connect(_on_connection_changed)
	socket.authentication_finished.connect(_on_authentication_finished)
	api.configure(str(ProjectSettings.get_setting("monworld/server_url", "http://127.0.0.1:8443")))
	content_pack = MonWorldContentPack.development()

func configure_server(url: String) -> void:
	api.configure(url)

func refresh_content() -> Dictionary:
	var result := await api.get_content()
	if result.ok:
		server_manifest = result.data
		if content_pack == null or content_pack.content_id() == "development-empty":
			if str(server_manifest.get("content_id", "")) == "development-empty":
				content_pack = MonWorldContentPack.development()
	return result

func use_content_pack(pack: MonWorldContentPack) -> Dictionary:
	if not server_manifest.is_empty() and pack.content_id() != str(server_manifest.get("content_id", "")):
		return {"ok": false, "error": "content pack does not match the server content_id"}
	content_pack = pack
	return {"ok": true}

func login(username: String, password: String) -> Dictionary:
	var result := await api.login(username, password)
	if result.ok:
		_apply_tokens(result.data)
		user = {"username": username}
	return result

func register(username: String, email: String, password: String) -> Dictionary:
	return await api.register(username, email, password)

func _apply_tokens(data: Dictionary) -> void:
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))

func connect_game() -> Dictionary:
	if access_token.is_empty():
		return {"ok": false, "error": "login is required"}
	var session := await api.create_game_session(access_token)
	if not session.ok:
		return session
	var ticket := str(session.data.get("ticket", ""))
	var content_id := str(session.data.get("content_id", ""))
	if ticket.is_empty() or content_pack == null or content_pack.content_id() != content_id:
		return {"ok": false, "error": "a matching local content pack is required"}
	var websocket_url := str(session.data.get("websocket_url", ""))
	if websocket_url.is_empty():
		websocket_url = _websocket_url()
	return await socket.connect_and_auth(websocket_url, ticket, content_id)

func _websocket_url() -> String:
	var url := api.base_url
	if url.begins_with("https://"):
		return "wss://" + url.trim_prefix("https://") + "/ws/game"
	return "ws://" + url.trim_prefix("http://") + "/ws/game"

func list_characters() -> Dictionary:
	var result := await api.list_characters(access_token)
	if result.ok:
		characters = result.data if result.data is Array else []
		characters_changed.emit(characters)
	return result

func create_character(name: String) -> Dictionary:
	var result := await api.create_character(name, access_token)
	if result.ok:
		await list_characters()
	return result

func select_character(character_id: int) -> bool:
	return socket.send_json(MonWorldProtocol.SELECT_CHARACTER, {"character_id": character_id})

func send_input(direction: String) -> bool:
	return socket.send_json(MonWorldProtocol.INPUT, {"direction": direction})

func send_chat(text: String) -> bool:
	return socket.send_json(MonWorldProtocol.CHAT, {"text": text})

func send_battle_action(battle_id: String, action: String) -> bool:
	return socket.send_json(MonWorldProtocol.BATTLE_ACTION, {"battle_id": battle_id, "action": action})

func disconnect_game() -> void:
	socket.close()

func _on_connection_changed(connected: bool) -> void:
	if not connected and not access_token.is_empty():
		connection_error.emit("game connection closed")

func _on_authentication_finished(result: Dictionary) -> void:
	if not result.ok:
		connection_error.emit(str(result.error))

func _on_frame(message_type: int, value: Variant) -> void:
	if message_type == MonWorldProtocol.CHARACTER_LIST:
		characters = value if value is Array else []
		characters_changed.emit(characters)
	elif message_type == MonWorldProtocol.WORLD_SNAPSHOT and value is Dictionary:
		current_snapshot = value
		world_snapshot_received.emit(value)
	elif message_type == MonWorldProtocol.ENTITY_UPDATE and value is Dictionary:
		entity_update_received.emit(value)
	elif message_type == MonWorldProtocol.CHAT and value is Dictionary:
		chat_received.emit(value)
	elif message_type == MonWorldProtocol.BATTLE_EVENT and value is Dictionary:
		battle_event_received.emit(value)
	elif message_type == MonWorldProtocol.ERROR and value is Dictionary:
		connection_error.emit(str(value.get("message", "server error")))
