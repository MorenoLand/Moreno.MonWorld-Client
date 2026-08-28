extends SceneTree

const GAME_PROTOCOL: GDScript = preload("res://scripts/net/game_protocol.gd")

func _init() -> void:
	var movement: PackedByteArray = GAME_PROTOCOL.encode_movement(12, 13, "left", true)
	if movement.size() != 5 or movement.decode_s16(0) != 12 or movement.decode_s16(2) != 13 or movement[4] != 0x82:
		push_error("OpenMMO movement encoding failed")
		quit(1)
		return
	if not GAME_PROTOCOL.encode_movement(12, 13, "invalid").is_empty() or GAME_PROTOCOL.encode_face_direction("right") != PackedByteArray([3]):
		push_error("OpenMMO direction encoding failed")
		quit(1)
		return
	var gba_payload: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s64_le(gba_payload, 123456789)
	OpenMMOCodec.append_u8(gba_payload, 3)
	OpenMMOCodec.append_u8(gba_payload, 4)
	OpenMMOCodec.append_u8(gba_payload, 12)
	OpenMMOCodec.append_u8(gba_payload, 13)
	OpenMMOCodec.append_u8(gba_payload, 2)
	OpenMMOCodec.append_u8(gba_payload, 0)
	var gba_result: Dictionary = GAME_PROTOCOL.decode_gba_entity_move(gba_payload)
	var gba_entity: Dictionary = gba_result.get("entity", {})
	if not bool(gba_result.get("ok", false)) or int(gba_entity.get("entity_id", 0)) != 123456789 or int(gba_entity.get("bank_id", 0)) != 3 or int(gba_entity.get("wire_map_id", 0)) != 4 or int(gba_entity.get("x", 0)) != 12 or int(gba_entity.get("y", 0)) != 13 or int(gba_entity.get("facing", 0)) != 1:
		push_error("OpenMMO GBA movement decoding failed")
		quit(1)
		return
	var nds_payload: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s64_le(nds_payload, 123456789)
	OpenMMOCodec.append_s16_le(nds_payload, -2)
	OpenMMOCodec.append_s16_le(nds_payload, 7)
	OpenMMOCodec.append_u8(nds_payload, 3)
	var nds_result: Dictionary = GAME_PROTOCOL.decode_entity_move(nds_payload)
	var nds_entity: Dictionary = nds_result.get("entity", {})
	if not bool(nds_result.get("ok", false)) or int(nds_entity.get("x", 0)) != -2 or int(nds_entity.get("y", 0)) != 7 or int(nds_entity.get("facing", 0)) != 4:
		push_error("OpenMMO DS movement decoding failed")
		quit(1)
		return
	quit(0)
