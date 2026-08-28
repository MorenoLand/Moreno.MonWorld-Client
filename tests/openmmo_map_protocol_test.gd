extends SceneTree

const GAME_PROTOCOL: GDScript = preload("res://scripts/net/game_protocol.gd")

func _init() -> void:
	if not _test_gba_map() or not _test_special_map() or not GAME_PROTOCOL.encode_request_player().is_empty():
		quit(1)
		return
	quit(0)

func _test_gba_map() -> bool:
	var payload: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_u8(payload, 3)
	OpenMMOCodec.append_u8(payload, 0)
	OpenMMOCodec.append_u8(payload, 3)
	OpenMMOCodec.append_u8(payload, 4)
	OpenMMOCodec.append_u8(payload, 0)
	OpenMMOCodec.append_s32_le(payload, 24)
	OpenMMOCodec.append_s32_le(payload, 20)
	OpenMMOCodec.append_s32_le(payload, 11)
	OpenMMOCodec.append_s32_le(payload, 12)
	OpenMMOCodec.append_u8(payload, 2)
	OpenMMOCodec.append_u8(payload, 2)
	OpenMMOCodec.append_s16_le(payload, -7)
	OpenMMOCodec.append_u8(payload, 8)
	OpenMMOCodec.append_u8(payload, 1)
	OpenMMOCodec.append_u8(payload, 2)
	OpenMMOCodec.append_u8(payload, 3)
	OpenMMOCodec.append_u8(payload, 4)
	for material in [1, 2, 3, 4]:
		OpenMMOCodec.append_u16_le(payload, int(material) | 42 << 10)
	OpenMMOCodec.append_bool(payload, false)
	OpenMMOCodec.append_u8(payload, 1)
	OpenMMOCodec.append_u8(payload, 4)
	OpenMMOCodec.append_s32_le(payload, -12)
	OpenMMOCodec.append_u8(payload, 3)
	OpenMMOCodec.append_u8(payload, 5)
	OpenMMOCodec.append_bool(payload, true)
	OpenMMOCodec.append_s64_le(payload, 42)
	OpenMMOCodec.append_utf16_le_null(payload, "tail")
	var result: Dictionary = GAME_PROTOCOL.decode_load_map(payload)
	if not bool(result.get("ok", false)) or not bool(result.get("delete_cache", false)) or not bool(result.get("reload_player", false)) or bool(result.get("special", true)):
		push_error("OpenMMO GBA map flags failed")
		return false
	var border_tiles: Array = result.get("border_tiles", [])
	var connections: Array = result.get("connections", [])
	if int(result.get("width", 0)) != 24 or int(result.get("height", 0)) != 20 or border_tiles.size() != 4 or int(border_tiles[0].get("material", 0)) != 1 or int(border_tiles[0].get("collision", 0)) != 42 or connections.size() != 1 or int(connections[0].get("direction", 0)) != 4 or int(result.get("trailer_value", 0)) != 42 or str(result.get("trailer_text", "")) != "tail":
		push_error("OpenMMO GBA map fields failed")
		return false
	return true

func _test_special_map() -> bool:
	var payload: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_u8(payload, 0)
	OpenMMOCodec.append_u8(payload, 2)
	OpenMMOCodec.append_u8(payload, 7)
	OpenMMOCodec.append_u8(payload, 8)
	OpenMMOCodec.append_u8(payload, 9)
	OpenMMOCodec.append_u16_le(payload, 0x1234)
	OpenMMOCodec.append_u8(payload, 2)
	OpenMMOCodec.append_u16_le(payload, 1)
	OpenMMOCodec.append_u16_le(payload, 11)
	OpenMMOCodec.append_u16_le(payload, 2)
	OpenMMOCodec.append_u16_le(payload, 22)
	OpenMMOCodec.append_u8(payload, 3)
	OpenMMOCodec.append_u8(payload, 4)
	OpenMMOCodec.append_u8(payload, 5)
	var result: Dictionary = GAME_PROTOCOL.decode_load_map(payload)
	var borders: Dictionary = result.get("border_connections", {})
	if not bool(result.get("ok", false)) or not bool(result.get("special", false)) or int(result.get("map_matrix_id", 0)) != 0x1234 or int(borders.get(1, 0)) != 11 or int(borders.get(2, 0)) != 22 or int(result.get("lighting", 0)) != 3 or int(result.get("weather", 0)) != 4 or int(result.get("map_type", 0)) != 5:
		push_error("OpenMMO special map fields failed")
		return false
	return true
