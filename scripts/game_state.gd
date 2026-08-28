extends Node

signal characters_changed(characters: Array)
signal world_snapshot_received(snapshot: Dictionary)
signal entity_update_received(update: Dictionary)
signal chat_received(message: Dictionary)
signal battle_event_received(event: Dictionary)
signal connection_error(message: String)
signal login_completed(result: Dictionary)
signal game_connection_completed(result: Dictionary)

const SESSION_SCRIPT = preload("res://scripts/net/session.gd")
const LOGIN_PROTOCOL_SCRIPT = preload("res://scripts/net/login_protocol.gd")
const GAME_PROTOCOL_SCRIPT = preload("res://scripts/net/game_protocol.gd")
const FLOW_TIMEOUT_MSEC: int = 15000

var login_session: Node
var game_session: Node
var content: MonWorldContent
var user: Dictionary = {}
var characters: Array = []
var current_snapshot: Dictionary = {}
var current_character: Dictionary = {}
var login_host: String = "127.0.0.1"
var login_port: int = 2106
var root_public_key_path: String = ""
var login_flow: String = "idle"
var game_flow: String = "idle"
var flow_deadline_msec: int = 0
var game_access: Dictionary = {}
var hardware_id: PackedByteArray = PackedByteArray()

func _ready() -> void:
	login_session = SESSION_SCRIPT.new()
	login_session.name = "LoginSession"
	add_child(login_session)
	game_session = SESSION_SCRIPT.new()
	game_session.name = "GameSession"
	add_child(game_session)
	login_session.established.connect(_on_login_established)
	login_session.packet_received.connect(_on_login_packet)
	login_session.failed.connect(_on_login_failed)
	game_session.established.connect(_on_game_established)
	game_session.packet_received.connect(_on_game_packet)
	game_session.failed.connect(_on_game_failed)
	var settings: Dictionary = MonWorldStorage.read_json(MonWorldStorage.SETTINGS_FILE)
	login_host = str(settings.get("login_host", ProjectSettings.get_setting("openmmo/login_host", "127.0.0.1")))
	login_port = int(settings.get("login_port", ProjectSettings.get_setting("openmmo/login_port", 2106)))
	root_public_key_path = str(settings.get("root_public_key_path", ProjectSettings.get_setting("openmmo/root_public_key_path", "")))
	hardware_id = _load_hardware_id(settings)
	set_process(true)

func _process(_delta: float) -> void:
	if flow_deadline_msec <= 0 or Time.get_ticks_msec() < flow_deadline_msec:
		return
	if login_flow != "idle":
		_finish_login({"ok": false, "error": "OpenMMO login timed out"})
	elif game_flow != "idle":
		_finish_game_connection({"ok": false, "error": "OpenMMO game connection timed out"})

func configure_server(endpoint: String, public_key_path: String) -> Dictionary:
	var parsed: Dictionary = _parse_endpoint(endpoint, 2106)
	if not parsed.ok:
		return parsed
	var key_path: String = public_key_path.strip_edges()
	if key_path.is_empty() or not FileAccess.file_exists(key_path):
		return {"ok": false, "error": "Select the OpenMMO server public key PEM file"}
	login_host = str(parsed.host)
	login_port = int(parsed.port)
	root_public_key_path = key_path
	return {"ok": true}

func endpoint_text() -> String:
	return "%s:%d" % [login_host, login_port]

func use_content(value: MonWorldContent) -> Dictionary:
	content = value
	return {"ok": true}

func login(username: String, password: String, stay_logged_in: bool = false) -> Dictionary:
	if login_flow != "idle" or game_flow != "idle":
		return {"ok": false, "error": "another connection is already in progress"}
	if root_public_key_path.is_empty() or not FileAccess.file_exists(root_public_key_path):
		return {"ok": false, "error": "Select the OpenMMO server public key PEM file"}
	user = {"username": username, "password": password, "stay_logged_in": stay_logged_in}
	game_access.clear()
	login_flow = "connecting"
	flow_deadline_msec = Time.get_ticks_msec() + FLOW_TIMEOUT_MSEC
	var error: Error = login_session.connect_openmmo(login_host, login_port, root_public_key_path)
	if error != OK:
		login_flow = "idle"
		flow_deadline_msec = 0
		return {"ok": false, "error": "could not connect to OpenMMO login server (%s)" % error_string(error)}
	var result: Dictionary = await login_completed
	return result

func connect_game() -> Dictionary:
	if game_access.is_empty():
		return {"ok": false, "error": "OpenMMO login did not provide a game server"}
	if game_flow != "idle":
		return {"ok": false, "error": "game connection is already in progress"}
	var endpoint: Dictionary = _game_endpoint(game_access)
	if not endpoint.ok:
		return endpoint
	game_flow = "connecting"
	flow_deadline_msec = Time.get_ticks_msec() + FLOW_TIMEOUT_MSEC
	var error: Error = game_session.connect_openmmo(str(endpoint.host), int(endpoint.port), root_public_key_path, true)
	if error != OK:
		game_flow = "idle"
		flow_deadline_msec = 0
		return {"ok": false, "error": "could not connect to OpenMMO game server (%s)" % error_string(error)}
	var result: Dictionary = await game_connection_completed
	return result

func list_characters() -> Dictionary:
	if not game_session.send_packet(GAME_PROTOCOL_SCRIPT.REQUEST_CHARACTERS, GAME_PROTOCOL_SCRIPT.encode_request_characters()):
		return {"ok": false, "error": "game connection is not ready"}
	return {"ok": true, "data": characters}

func create_character(_name: String) -> Dictionary:
	return {"ok": false, "error": "OpenMMO character creation is not wired yet"}

func select_character(character_id: int) -> bool:
	return game_session.send_packet(GAME_PROTOCOL_SCRIPT.SELECT_CHARACTER, GAME_PROTOCOL_SCRIPT.encode_select_character(character_id))

func send_input(_direction: String) -> bool:
	return false

func send_chat(_text: String) -> bool:
	return false

func send_battle_action(_battle_id: String, _action: String) -> bool:
	return false

func disconnect_game() -> void:
	game_session.close()

func _on_login_established() -> void:
	if login_flow != "connecting":
		return
	login_flow = "response"
	var payload: PackedByteArray = LOGIN_PROTOCOL_SCRIPT.encode_password_login(str(user.get("username", "")), str(user.get("password", "")), bool(user.get("stay_logged_in", false)), hardware_id, _os_ordinal())
	if payload.is_empty() or not login_session.send_packet(LOGIN_PROTOCOL_SCRIPT.LOGIN_REQUEST, payload):
		_finish_login({"ok": false, "error": "OpenMMO login request could not be sent"})

func _on_login_packet(opcode: int, payload: PackedByteArray) -> void:
	if login_flow == "response" and opcode == LOGIN_PROTOCOL_SCRIPT.LOGIN_RESPONSE:
		var response: Dictionary = LOGIN_PROTOCOL_SCRIPT.decode_login_response(payload)
		if not response.ok or not bool(response.get("authenticated", false)):
			_finish_login({"ok": false, "error": str(response.get("message", "OpenMMO login failed"))})
			return
		login_flow = "server_list"
		if not login_session.send_packet(LOGIN_PROTOCOL_SCRIPT.REQUEST_SERVER_LIST, LOGIN_PROTOCOL_SCRIPT.encode_server_list_request()):
			_finish_login({"ok": false, "error": "OpenMMO server-list request could not be sent"})
	elif login_flow == "server_list" and opcode == LOGIN_PROTOCOL_SCRIPT.GAME_SERVER_LIST:
		var response: Dictionary = LOGIN_PROTOCOL_SCRIPT.decode_server_list(payload)
		if not response.ok:
			_finish_login({"ok": false, "error": "OpenMMO server list is malformed"})
			return
		var server_id: int = -1
		for server in response.servers:
			if bool(server.get("joinable", false)):
				server_id = int(server.get("id", -1))
				break
		if server_id < 0:
			_finish_login({"ok": false, "error": "no joinable OpenMMO game server is available"})
			return
		login_flow = "nodes"
		if not login_session.send_packet(LOGIN_PROTOCOL_SCRIPT.JOIN_GAME_SERVER, LOGIN_PROTOCOL_SCRIPT.encode_join_server(server_id)):
			_finish_login({"ok": false, "error": "OpenMMO game-server request could not be sent"})
	elif login_flow == "nodes" and opcode == LOGIN_PROTOCOL_SCRIPT.GAME_SERVER_NODES:
		var response: Dictionary = LOGIN_PROTOCOL_SCRIPT.decode_game_server_nodes(payload)
		if not response.ok or int(response.get("state", -1)) != 0:
			_finish_login({"ok": false, "error": str(response.get("message", "OpenMMO game-server handoff failed"))})
			return
		game_access = response
		_finish_login({"ok": true, "data": response})
	elif opcode == LOGIN_PROTOCOL_SCRIPT.SENT_CREDENTIALS:
		var credentials: Dictionary = LOGIN_PROTOCOL_SCRIPT.decode_sent_credentials(payload)
		if credentials.ok:
			user["saved_key"] = credentials.key

func _on_game_established() -> void:
	if game_flow != "connecting":
		return
	game_flow = "join"
	var session_token: PackedByteArray = game_access.get("session_token", PackedByteArray())
	var payload: PackedByteArray = GAME_PROTOCOL_SCRIPT.encode_join(int(game_access.get("user_id", 0)), session_token, hardware_id)
	if payload.is_empty() or not game_session.send_packet(GAME_PROTOCOL_SCRIPT.JOIN, payload):
		_finish_game_connection({"ok": false, "error": "OpenMMO game join could not be sent"})

func _on_game_packet(opcode: int, payload: PackedByteArray) -> void:
	if game_flow == "join" and opcode == GAME_PROTOCOL_SCRIPT.JOIN:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_join_response(payload)
		if not response.ok or not bool(response.get("can_join", false)):
			_finish_game_connection({"ok": false, "error": str(response.get("error", "OpenMMO game join failed"))})
			return
		user["playtime"] = int(response.get("playtime", 0))
		user["reward_points"] = int(response.get("reward_points", 0))
		user["balance"] = int(response.get("balance", 0))
		game_session.send_packet(GAME_PROTOCOL_SCRIPT.REQUEST_CHARACTERS, GAME_PROTOCOL_SCRIPT.encode_request_characters())
		_finish_game_connection({"ok": true, "data": response})
	elif opcode == GAME_PROTOCOL_SCRIPT.REQUEST_CHARACTERS:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_characters(payload)
		if response.ok:
			characters = response.characters
			characters_changed.emit(characters)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO character list is malformed")))

func _on_login_failed(message: String) -> void:
	if login_flow != "idle":
		_finish_login({"ok": false, "error": message})

func _on_game_failed(message: String) -> void:
	if game_flow != "idle":
		_finish_game_connection({"ok": false, "error": message})
	else:
		connection_error.emit(message)

func _finish_login(result: Dictionary) -> void:
	login_flow = "idle"
	flow_deadline_msec = 0
	login_session.close()
	login_completed.emit(result)

func _finish_game_connection(result: Dictionary) -> void:
	game_flow = "idle"
	flow_deadline_msec = 0
	game_connection_completed.emit(result)

func _game_endpoint(access: Dictionary) -> Dictionary:
	var local_address: String = str(access.get("local_address", ""))
	var local_hostname: String = str(access.get("local_hostname", ""))
	var port: int = int(access.get("port", 0))
	if _is_loopback(login_host):
		var host: String = local_address
		if host.is_empty() or host == "0.0.0.0":
			host = local_hostname if not local_hostname.is_empty() else login_host
		if port > 0:
			return {"ok": true, "host": host, "port": port}
	for node in access.get("nodes", []):
		var host: String = str(node.get("ipv4", ""))
		if not host.is_empty() and int(node.get("port", 0)) > 0:
			return {"ok": true, "host": host, "port": int(node.get("port", 0))}
	return {"ok": false, "error": "OpenMMO did not provide a usable game-server endpoint"}

func _parse_endpoint(value: String, default_port: int) -> Dictionary:
	var text: String = value.strip_edges().trim_prefix("tcp://")
	if text.is_empty():
		return {"ok": false, "error": "Enter an OpenMMO login server"}
	var host: String = text
	var port: int = default_port
	if text.begins_with("["):
		var close_index: int = text.find("]")
		if close_index < 0:
			return {"ok": false, "error": "OpenMMO login endpoint is invalid"}
		host = text.substr(1, close_index - 1)
		if close_index + 1 < text.length():
			if text[close_index + 1] != ":":
				return {"ok": false, "error": "OpenMMO login endpoint is invalid"}
			port = text.substr(close_index + 2).to_int()
	elif text.count(":") == 1:
		var separator: int = text.rfind(":")
		host = text.left(separator)
		port = text.substr(separator + 1).to_int()
	if host.is_empty() or port <= 0 or port > 65535:
		return {"ok": false, "error": "OpenMMO login endpoint is invalid"}
	return {"ok": true, "host": host, "port": port}

func _load_hardware_id(settings: Dictionary) -> PackedByteArray:
	var encoded: String = str(settings.get("hardware_id", ""))
	var value: PackedByteArray = _decode_hex(encoded)
	if value.size() == 16:
		return value
	value = Crypto.new().generate_random_bytes(16)
	settings["hardware_id"] = value.hex_encode()
	MonWorldStorage.write_json(MonWorldStorage.SETTINGS_FILE, settings)
	return value

func _decode_hex(value: String) -> PackedByteArray:
	if value.length() % 2 != 0:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	for index in range(0, value.length(), 2):
		var byte_text: String = value.substr(index, 2)
		if not byte_text.is_valid_hex_number(false):
			return PackedByteArray()
		output.append(byte_text.hex_to_int())
	return output

func _os_ordinal() -> int:
	match OS.get_name():
		"Windows": return 0
		"Linux": return 1
		"macOS": return 2
		"iOS": return 3
		"Android": return 4
	return 0xFF

func _is_loopback(host: String) -> bool:
	return host.to_lower() in ["127.0.0.1", "localhost", "::1"]
