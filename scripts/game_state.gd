extends Node

const DEFAULT_ROOT_PUBLIC_KEY_PATH: String = "res://config/openmmo/game.public.pem"

signal characters_changed(characters: Array)
signal world_snapshot_received(snapshot: Dictionary)
signal entity_update_received(update: Dictionary)
signal chat_received(message: Dictionary)
signal battle_event_received(event: Dictionary)
signal map_load_received(map_load: Dictionary)
signal dialog_action_received(action: Dictionary)
signal dialog_state_received(open: bool)
signal render_screen_changed(visible: bool)
signal connection_error(message: String)
signal login_completed(result: Dictionary)
signal game_connection_completed(result: Dictionary)

const SESSION_SCRIPT = preload("res://scripts/net/session.gd")
const LOGIN_PROTOCOL_SCRIPT = preload("res://scripts/net/login_protocol.gd")
const GAME_PROTOCOL_SCRIPT = preload("res://scripts/net/game_protocol.gd")
const FLOW_TIMEOUT_MSEC: int = 15000

var login_session: Node
var game_session: Node
var content: OpenMMOContent
var user: Dictionary = {}
var characters: Array = []
var current_snapshot: Dictionary = {}
var current_character: Dictionary = {}
var login_host: String = "127.0.0.1"
var login_port: int = 2106
var root_public_key_path: String = DEFAULT_ROOT_PUBLIC_KEY_PATH
var custom_root_public_key_path: String = ""
var login_flow: String = "idle"
var game_flow: String = "idle"
var flow_deadline_msec: int = 0
var game_access: Dictionary = {}
var hardware_id: PackedByteArray = PackedByteArray()
var server_maps: Dictionary = {}
var pending_map_load: Dictionary = {}
var awaiting_local_entity: bool = false
var map_transition_pending: bool = false

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
	var settings: Dictionary = OpenMMOStorage.read_json(OpenMMOStorage.SETTINGS_FILE)
	login_host = str(settings.get("login_host", ProjectSettings.get_setting("openmmo/login_host", "127.0.0.1")))
	login_port = int(settings.get("login_port", ProjectSettings.get_setting("openmmo/login_port", 2106)))
	custom_root_public_key_path = str(settings.get("root_public_key_path", "")).strip_edges()
	if not custom_root_public_key_path.is_empty() and FileAccess.file_exists(custom_root_public_key_path):
		root_public_key_path = custom_root_public_key_path
	else:
		custom_root_public_key_path = ""
		root_public_key_path = str(ProjectSettings.get_setting("openmmo/root_public_key_path", DEFAULT_ROOT_PUBLIC_KEY_PATH))
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
	var custom_key_path: String = public_key_path.strip_edges()
	var key_path: String = DEFAULT_ROOT_PUBLIC_KEY_PATH if custom_key_path.is_empty() else custom_key_path
	if not FileAccess.file_exists(key_path):
		return {"ok": false, "error": "The bundled OpenMMO server key is missing" if custom_key_path.is_empty() else "The custom OpenMMO server key could not be found"}
	login_host = str(parsed.host)
	login_port = int(parsed.port)
	root_public_key_path = key_path
	custom_root_public_key_path = custom_key_path
	return {"ok": true}

func endpoint_text() -> String:
	return "%s:%d" % [login_host, login_port]

func public_key_override() -> String:
	return custom_root_public_key_path

func use_content(value: OpenMMOContent) -> Dictionary:
	content = value
	return {"ok": true}

func login(username: String, password: String, stay_logged_in: bool = false, saved_token: String = "") -> Dictionary:
	if login_flow != "idle" or game_flow != "idle":
		return {"ok": false, "error": "another connection is already in progress"}
	if root_public_key_path.is_empty() or not FileAccess.file_exists(root_public_key_path):
		return {"ok": false, "error": "The OpenMMO server key is unavailable; restore the bundled key or choose a custom key in Settings"}
	var token: String = saved_token.strip_edges()
	user = {"username": username, "password": password, "stay_logged_in": stay_logged_in, "saved_key": token, "login_method": "token" if not token.is_empty() else "password"}
	game_access.clear()
	login_flow = "connecting"
	flow_deadline_msec = Time.get_ticks_msec() + FLOW_TIMEOUT_MSEC
	var error: Error = login_session.connect_openmmo(login_host, login_port, root_public_key_path)
	if error != OK:
		login_flow = "idle"
		flow_deadline_msec = 0
		return {"ok": false, "error": "could not connect to OpenMMO login server (%s)" % error_string(error)}
	var result: Dictionary = await login_completed
	if bool(result.get("ok", false)):
		result["remember_token"] = str(user.get("saved_key", ""))
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
	for character_value in characters:
		if character_value is Dictionary and int(character_value.get("id", 0)) == character_id:
			current_character = (character_value as Dictionary).duplicate(true)
			break
	return game_session.send_packet(GAME_PROTOCOL_SCRIPT.SELECT_CHARACTER, GAME_PROTOCOL_SCRIPT.encode_select_character(character_id))

func complete_map_load(load_key: String) -> bool:
	if pending_map_load.is_empty() or str(pending_map_load.get("key", "")) != load_key:
		return false
	awaiting_local_entity = true
	if not game_session.send_packet(GAME_PROTOCOL_SCRIPT.REQUEST_PLAYER, GAME_PROTOCOL_SCRIPT.encode_request_player()):
		awaiting_local_entity = false
		return false
	pending_map_load.clear()
	return true

func send_input(direction: String, source_x: int = -1, source_y: int = -1, running: bool = false) -> bool:
	var x: int = source_x if source_x >= 0 else int(current_character.get("x", -1))
	var y: int = source_y if source_y >= 0 else int(current_character.get("y", -1))
	if x < 0 or y < 0:
		return false
	var payload: PackedByteArray = GAME_PROTOCOL_SCRIPT.encode_movement(x, y, direction, running)
	return not payload.is_empty() and game_session.send_packet(GAME_PROTOCOL_SCRIPT.MOVEMENT, payload)

func send_entity_interact(entity_id: int, token: int = 0) -> bool:
	return game_session.send_packet(GAME_PROTOCOL_SCRIPT.ENTITY_INTERACT, GAME_PROTOCOL_SCRIPT.encode_entity_interact(entity_id, token))

func send_tile_interact() -> bool:
	return game_session.send_packet(GAME_PROTOCOL_SCRIPT.TILE_INTERACT, GAME_PROTOCOL_SCRIPT.encode_tile_interact())

func send_dialogue_action_response(dialogue_id: int, value: int = 0) -> bool:
	return game_session.send_packet(GAME_PROTOCOL_SCRIPT.DIALOG_ACTION, GAME_PROTOCOL_SCRIPT.encode_dialog_action_response(dialogue_id, value))

func send_chat(text: String, channel: String = "Normal") -> bool:
	if channel != "Normal":
		return false
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed.begins_with("/"):
		var command_payload: PackedByteArray = GAME_PROTOCOL_SCRIPT.encode_chat_send(4, "", trimmed)
		return not command_payload.is_empty() and game_session.send_packet(GAME_PROTOCOL_SCRIPT.CHAT_SEND, command_payload)
	var payload: PackedByteArray = GAME_PROTOCOL_SCRIPT.encode_chat_message(trimmed, 0, 0)
	return not payload.is_empty() and game_session.send_packet(GAME_PROTOCOL_SCRIPT.CHAT_MESSAGE, payload)

func send_battle_action(_battle_id: String, _action: String) -> bool:
	return false

func disconnect_game() -> void:
	pending_map_load.clear()
	server_maps.clear()
	awaiting_local_entity = false
	map_transition_pending = false
	game_session.close()

func _on_login_established() -> void:
	if login_flow != "connecting":
		return
	login_flow = "response"
	var saved_token: PackedByteArray = Marshalls.base64_to_raw(str(user.get("saved_key", "")))
	var payload: PackedByteArray = LOGIN_PROTOCOL_SCRIPT.encode_token_login(str(user.get("username", "")), saved_token, hardware_id, _os_ordinal()) if user.get("login_method", "password") == "token" and not saved_token.is_empty() else LOGIN_PROTOCOL_SCRIPT.encode_password_login(str(user.get("username", "")), str(user.get("password", "")), bool(user.get("stay_logged_in", false)), hardware_id, _os_ordinal())
	if payload.is_empty() or not login_session.send_packet(LOGIN_PROTOCOL_SCRIPT.LOGIN_REQUEST, payload):
		_finish_login({"ok": false, "error": "OpenMMO login request could not be sent"})

func _on_login_packet(opcode: int, payload: PackedByteArray) -> void:
	if login_flow == "response" and opcode == LOGIN_PROTOCOL_SCRIPT.LOGIN_RESPONSE:
		var response: Dictionary = LOGIN_PROTOCOL_SCRIPT.decode_login_response(payload)
		if not response.ok or not bool(response.get("authenticated", false)):
			if int(response.get("state", -1)) == 30 and user.get("login_method", "password") == "token" and not str(user.get("password", "")).is_empty():
				user["login_method"] = "password"
				var password_payload: PackedByteArray = LOGIN_PROTOCOL_SCRIPT.encode_password_login(str(user.get("username", "")), str(user.get("password", "")), bool(user.get("stay_logged_in", false)), hardware_id, _os_ordinal())
				if not password_payload.is_empty() and login_session.send_packet(LOGIN_PROTOCOL_SCRIPT.LOGIN_REQUEST, password_payload):
					return
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
		game_flow = "characters"
		if not game_session.send_packet(GAME_PROTOCOL_SCRIPT.REQUEST_CHARACTERS, GAME_PROTOCOL_SCRIPT.encode_request_characters()):
			_finish_game_connection({"ok": false, "error": "OpenMMO character-list request could not be sent"})
	elif opcode == GAME_PROTOCOL_SCRIPT.REQUEST_CHARACTERS:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_characters(payload)
		if response.ok:
			characters = response.characters
			characters_changed.emit(characters)
			if game_flow == "characters":
				_finish_game_connection({"ok": true, "data": {"characters": characters}})
		else:
			var message: String = str(response.get("error", "OpenMMO character list is malformed"))
			if game_flow == "characters":
				_finish_game_connection({"ok": false, "error": message})
			else:
				connection_error.emit(message)
	elif opcode == GAME_PROTOCOL_SCRIPT.CHAT_MESSAGE:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_chat_message(payload)
		if response.ok:
			chat_received.emit(response.message)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO chat message is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.SERVER_NOTICE:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_server_notice(payload)
		if response.ok:
			var notice: Dictionary = response.notice
			notice["channel"] = "Local"
			notice["system"] = true
			chat_received.emit(notice)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO server notice is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.MAP_TRANSITION:
		map_transition_pending = true
		pending_map_load.clear()
		awaiting_local_entity = false
		render_screen_changed.emit(false)
	elif opcode == GAME_PROTOCOL_SCRIPT.LOAD_MAP:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_load_map(payload)
		if not response.ok:
			connection_error.emit(str(response.get("error", "OpenMMO map packet is malformed")))
			return
		server_maps[str(response.key)] = response
		if bool(response.get("reload_player", false)):
			var active_map_load: bool = map_transition_pending or (pending_map_load.is_empty() and not awaiting_local_entity)
			if not active_map_load:
				return
			map_transition_pending = false
			if content == null:
				connection_error.emit("Select a local ROM before entering the OpenMMO world")
				return
			var local_map_id: String = content.map_id_for_location(int(response.get("bank_id", -1)), int(response.get("map_id", -1)))
			if content.map_data(local_map_id).is_empty():
				connection_error.emit("The selected ROM does not contain OpenMMO map %d/%d" % [int(response.get("bank_id", -1)), int(response.get("map_id", -1))])
				return
			response["local_map_id"] = local_map_id
			pending_map_load = response
			map_load_received.emit(response)
	elif opcode == GAME_PROTOCOL_SCRIPT.NPC_SPAWN:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_npc_spawn(payload)
		if not response.ok:
			connection_error.emit(str(response.get("error", "OpenMMO NPC spawn packet is malformed")))
			return
		var npc: Dictionary = response.entity
		npc["map_id"] = content.map_id_for_location(int(npc.get("bank_id", -1)), int(npc.get("wire_map_id", -1))) if content != null else ""
		entity_update_received.emit({"player": npc, "local": false})
	elif opcode == GAME_PROTOCOL_SCRIPT.NPC_UPDATE:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_npc_update(payload)
		if response.ok:
			_emit_entity_update(response.entity)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO NPC update packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.NPC_ANIMATION:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_npc_animation(payload)
		if response.ok:
			_emit_entity_update(response.entity)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO NPC animation packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.DIALOG_ACTION:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_dialog_action(payload)
		if response.ok:
			dialog_action_received.emit(response.action)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO dialog action packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.DIALOG_STATE:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_dialog_state(payload)
		if response.ok:
			dialog_state_received.emit(bool(response.open))
		else:
			connection_error.emit(str(response.get("error", "OpenMMO dialog state packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.REQUEST_PLAYER:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_load_entity(payload)
		if not response.ok:
			connection_error.emit(str(response.get("error", "OpenMMO entity packet is malformed")))
			return
		var player: Dictionary = response.entity
		player["map_id"] = content.map_id_for_location(int(player.get("bank_id", -1)), int(player.get("wire_map_id", -1))) if content != null else ""
		player["character_id"] = int(player.get("entity_id", 0))
		var is_local: bool = awaiting_local_entity
		if is_local:
			awaiting_local_entity = false
			player["user_id"] = int(current_character.get("user_id", 0))
			current_character["x"] = int(player.get("x", 0))
			current_character["y"] = int(player.get("y", 0))
			current_character["region_id"] = int(player.get("region_id", 0))
			current_character["bank_id"] = int(player.get("bank_id", 0))
			current_character["map_id"] = int(player.get("wire_map_id", 0))
		entity_update_received.emit({"player": player, "local": is_local})
	elif opcode == GAME_PROTOCOL_SCRIPT.ENTITY_MOVE_GBA:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_gba_entity_move(payload)
		if response.ok:
			_emit_entity_update(response.entity)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO GBA movement packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.ENTITY_MOVE_NDS:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_entity_move(payload)
		if response.ok:
			_emit_entity_update(response.entity)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO movement packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.ENTITY_FACE_TURN:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_entity_face_turn(payload)
		if response.ok:
			_emit_entity_update(response.entity)
		else:
			connection_error.emit(str(response.get("error", "OpenMMO face-turn packet is malformed")))
	elif opcode == GAME_PROTOCOL_SCRIPT.RENDER_SCREEN:
		var response: Dictionary = GAME_PROTOCOL_SCRIPT.decode_render_screen(payload)
		if response.ok:
			render_screen_changed.emit(bool(response.visible))
		else:
			connection_error.emit(str(response.error))

func _emit_entity_update(entity: Dictionary) -> void:
	var entity_id: int = int(entity.get("entity_id", 0))
	entity["character_id"] = entity_id
	if content != null and entity.has("bank_id") and entity.has("wire_map_id"):
		entity["map_id"] = content.map_id_for_location(int(entity.get("bank_id", -1)), int(entity.get("wire_map_id", -1)))
	if entity_id == int(current_character.get("id", 0)):
		for key in ["x", "y", "facing", "bank_id", "wire_map_id", "map_id"]:
			if entity.has(key):
				current_character[key] = entity[key]
	entity_update_received.emit({"player": entity, "local": entity_id == int(current_character.get("id", 0))})

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
	OpenMMOStorage.write_json(OpenMMOStorage.SETTINGS_FILE, settings)
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
