class_name OpenMMOLoginProtocol
extends RefCounted

const LOGIN_RESPONSE: int = 0x01
const REQUEST_SERVER_LIST: int = 0x02
const JOIN_GAME_SERVER: int = 0x03
const GAME_SERVER_NODES: int = 0x03
const SENT_CREDENTIALS: int = 0x07
const LOGIN_REQUEST: int = 0x11
const GAME_SERVER_LIST: int = 0x22

const LOGIN_STATES: Dictionary = {
	0: "authenticated", 1: "system error", 2: "invalid username or password", 3: "additional authentication required", 6: "no game server is available", 7: "account is already logged in", 8: "server is down", 9: "account issue", 16: "server is restricted to staff", 22: "IP address is banned", 23: "login is rate limited", 24: "authentication server connection failed", 25: "terms revision is invalid", 26: "IP address is blocked", 28: "IP range is blocked", 29: "game server connection failed", 30: "saved credentials are invalid", 31: "firewall connection failed", 32: "two-factor login is rate limited", 33: "two-factor code is incorrect", 34: "client is out of date", 35: "extra validation failed", 36: "account validation is required"
}

static func encode_password_login(username: String, password: String, stay_logged_in: bool, hardware_id: PackedByteArray, os_ordinal: int = 0) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_utf16_le_null(output, username)
	OpenMMOCodec.append_bool(output, true)
	if not OpenMMOCodec.append_u8_bytes(output, hardware_id):
		return PackedByteArray()
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_utf16_le_null(output, password.sha1_text())
	OpenMMOCodec.append_bool(output, stay_logged_in)
	OpenMMOCodec.append_utf16_le_null(output, "en")
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_u8(output, os_ordinal)
	OpenMMOCodec.append_u8(output, 0)
	return output

static func encode_token_login(username: String, token: PackedByteArray, hardware_id: PackedByteArray, os_ordinal: int = 0) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_utf16_le_null(output, username)
	OpenMMOCodec.append_bool(output, false)
	if not OpenMMOCodec.append_u8_bytes(output, hardware_id):
		return PackedByteArray()
	OpenMMOCodec.append_u8(output, 1)
	if not OpenMMOCodec.append_u8_bytes(output, token):
		return PackedByteArray()
	OpenMMOCodec.append_utf16_le_null(output, "en")
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_u8(output, os_ordinal)
	OpenMMOCodec.append_u8(output, 0)
	return output

static func decode_login_response(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var state_id: int = reader.read_u8()
	var result: Dictionary = {"ok": not reader.failed, "state": state_id, "message": str(LOGIN_STATES.get(state_id, "unknown login response"))}
	if state_id == 23 or state_id == 32:
		result["rate_limit_epoch"] = reader.read_s64_le()
	if state_id == 0:
		reader.read_utf16_le_null()
	result["ok"] = not reader.failed and reader.remaining() == 0
	result["authenticated"] = bool(result.get("ok", false)) and state_id == 0
	return result

static func encode_server_list_request() -> PackedByteArray:
	return PackedByteArray()

static func decode_server_list(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var count: int = reader.read_u8()
	var servers: Array = []
	if count == 0:
		reader.read_u8()
		reader.read_u8()
	else:
		reader.read_u8()
		for _index in count:
			servers.append({"id": reader.read_u8(), "name": reader.read_utf16_le_null(), "current_players": reader.read_u16_le(), "max_players": reader.read_u16_le(), "joinable": reader.read_bool()})
	return {"ok": not reader.failed and reader.remaining() == 0, "servers": servers}

static func encode_join_server(server_id: int) -> PackedByteArray:
	return PackedByteArray([server_id & 0xFF])

static func decode_sent_credentials(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var username: String = reader.read_utf16_le_null()
	var key: String = reader.read_utf16_le_null()
	return {"ok": not reader.failed and reader.remaining() == 0, "username": username, "key": key}

static func decode_game_server_nodes(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var state_id: int = reader.read_u8()
	if state_id != 0:
		return {"ok": not reader.failed, "state": state_id, "message": str(LOGIN_STATES.get(state_id, "game server join failed"))}
	var user_id: int = reader.read_s32_le()
	var session_token: PackedByteArray = reader.read_u8_bytes()
	var game_server_id: int = reader.read_u8()
	var local_address: String = _raw_ip(reader.read_u8_bytes())
	var local_hostname: String = reader.read_utf16_le_null()
	var port: int = reader.read_s32_le() & 0xFFFF
	var node_count: int = reader.read_u8()
	var nodes: Array = []
	for _index in node_count:
		reader.read_u8()
		var ipv4: String = _tagged_ip(reader)
		var ipv6: String = _tagged_ip(reader)
		var node_port: int = reader.read_u16_le()
		var weight: int = reader.read_u8()
		nodes.append({"ipv4": ipv4, "ipv6": ipv6, "port": node_port, "weight": weight})
	return {"ok": not reader.failed and reader.remaining() == 0, "state": state_id, "user_id": user_id, "session_token": session_token, "game_server_id": game_server_id, "local_address": local_address, "local_hostname": local_hostname, "port": port, "nodes": nodes}

static func _tagged_ip(reader: OpenMMOCodec.Reader) -> String:
	var kind: int = reader.read_u8()
	if kind == 4:
		var value: int = reader.read_s32_le()
		return "%d.%d.%d.%d" % [value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF]
	if kind == 6:
		var bytes: PackedByteArray = reader.read_bytes(16)
		var groups: PackedStringArray = PackedStringArray()
		for index in range(0, 16, 2):
			groups.append("%x" % (bytes[index] << 8 | bytes[index + 1]))
		return ":".join(groups)
	reader.failed = true
	return ""

static func _raw_ip(bytes: PackedByteArray) -> String:
	if bytes.size() == 4:
		return "%d.%d.%d.%d" % [bytes[0], bytes[1], bytes[2], bytes[3]]
	if bytes.size() == 16:
		var groups: PackedStringArray = PackedStringArray()
		for index in range(0, 16, 2):
			groups.append("%x" % (bytes[index] << 8 | bytes[index + 1]))
		return ":".join(groups)
	return ""
