class_name OpenMMOGameProtocol
extends RefCounted

const JOIN: int = 0x01
const REQUEST_CHARACTERS: int = 0x02
const SELECT_CHARACTER: int = 0x04
const LOAD_MAP: int = 0x10

static func encode_join(user_id: int, session_token: PackedByteArray, hardware_id: PackedByteArray) -> PackedByteArray:
	if session_token.is_empty() or session_token.size() > 0xFF:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s32_le(output, user_id)
	if not OpenMMOCodec.append_u8_bytes(output, session_token):
		return PackedByteArray()
	var mac: PackedByteArray = hardware_id.slice(0, mini(hardware_id.size(), 6))
	mac.resize(6)
	output.append_array(mac)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_u8(output, _platform_ordinal())
	OpenMMOCodec.append_u8(output, _architecture_ordinal())
	OpenMMOCodec.append_u8(output, _bitness_ordinal())
	OpenMMOCodec.append_u8(output, 0)
	var trailing: PackedByteArray = PackedByteArray()
	trailing.resize(32)
	output.append_array(trailing)
	return output

static func decode_join_response(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var can_join: bool = reader.read_bool()
	if not can_join:
		return {"ok": not reader.failed and reader.remaining() == 0, "can_join": false, "error": "game server rejected the session"}
	reader.read_utf16_le_null()
	reader.read_s8()
	var result: Dictionary = {"can_join": true, "playtime": reader.read_s32_le(), "reward_points": reader.read_s32_le(), "balance": reader.read_s32_le(), "server_day_start": reader.read_s32_le(), "server_time": reader.read_s32_le()}
	result["ok"] = not reader.failed and reader.remaining() == 0
	if not result.ok:
		result["error"] = "game join response is malformed"
	return result

static func encode_request_characters() -> PackedByteArray:
	return PackedByteArray()

static func encode_select_character(character_id: int, character_id_hash: int = 0) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s64_le(output, character_id)
	OpenMMOCodec.append_s64_le(output, character_id_hash)
	return output

static func decode_characters(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var count: int = reader.read_u8()
	var characters: Array = []
	for _index in count:
		var character: Dictionary = _read_character_info(reader)
		character["skin"] = _read_skin_set(reader, true)
		character["secondary_skin"] = _read_skin_set(reader, false)
		if reader.read_bool():
			character["guild_name"] = reader.read_utf16_le_null()
			character["guild_id"] = reader.read_s32_le()
		var party: Array = []
		var party_count: int = reader.read_u8()
		if party_count > 6:
			reader.failed = true
		for _party_index in party_count:
			party.append(_read_pokemon(reader))
		character["party"] = party
		characters.append(character)
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "character list is malformed" if reader.failed or reader.remaining() != 0 else "", "characters": characters}

static func _read_character_info(reader: OpenMMOCodec.Reader) -> Dictionary:
	var result: Dictionary = {"id": reader.read_s64_le(), "name": reader.read_utf16_le_null(), "name_prefix": reader.read_utf16_le_null(), "user_id": reader.read_s32_le(), "rival_sex": reader.read_s8(), "last_login": reader.read_s32_le(), "created_at": reader.read_s32_le()}
	reader.read_s32_le()
	reader.read_s8()
	reader.read_s32_le()
	result["money"] = reader.read_s32_le()
	reader.read_s16_le()
	reader.read_s32_le()
	result["permissions"] = reader.read_u8()
	reader.read_s8()
	reader.read_s8()
	reader.read_s32_le()
	reader.read_bytes(8)
	result["remaining_safari_steps"] = reader.read_s16_le()
	result["remaining_safari_balls"] = reader.read_s8()
	reader.read_s32_le()
	result["pc_extra_slots"] = reader.read_s8()
	result["battle_box_extra_slots"] = reader.read_s8()
	result["template_amount"] = reader.read_s8()
	reader.read_s8()
	reader.read_s8()
	reader.read_s8()
	reader.read_s8()
	result["region_id"] = reader.read_s8()
	result["bank_id"] = reader.read_s8()
	result["map_id"] = reader.read_s16_le() & 0xFF
	result["x"] = reader.read_s16_le()
	result["y"] = reader.read_s16_le()
	reader.read_s8()
	result["repel_left"] = reader.read_s16_le()
	result["repel_item_id"] = reader.read_s16_le()
	reader.read_s8()
	result["lure_item_id"] = reader.read_s16_le()
	result["lure_left"] = reader.read_s16_le()
	reader.read_u16_bytes()
	return result

static func _read_skin_set(reader: OpenMMOCodec.Reader, with_region: bool) -> Dictionary:
	var region_selection_index: int = reader.read_u8() if with_region else 0
	var mask: int = reader.read_u16_le()
	var skins: Array = []
	for slot in 12:
		if mask & (1 << slot) == 0:
			continue
		var packed: int = reader.read_u16_le()
		skins.append({"slot": slot, "type": packed & 0x3FF, "color": packed >> 10 & 0x3F})
	return {"region_selection_index": region_selection_index, "mask": mask, "skins": skins}

static func _read_pokemon(reader: OpenMMOCodec.Reader) -> Dictionary:
	var result: Dictionary = {"id": reader.read_s64_le()}
	reader.read_bytes(2)
	result["owner_id"] = reader.read_s64_le()
	reader.read_s64_le()
	reader.read_bytes(1)
	result["container_slot"] = reader.read_s16_le()
	result["dex_id"] = reader.read_u16_le()
	result["seed"] = reader.read_s32_le()
	reader.read_s64_le()
	result["ot"] = reader.read_utf16_le_null()
	result["nickname"] = reader.read_utf16_le_null()
	reader.read_bytes(2)
	result["level"] = reader.read_s8()
	result["hp"] = reader.read_s16_le()
	reader.read_bytes(2)
	result["xp"] = reader.read_s32_le()
	reader.read_bytes(3)
	var moves: Array = []
	for _index in 4:
		moves.append({"id": reader.read_s16_le()})
	for index in 4:
		moves[index]["pp"] = reader.read_s8()
	result["moves"] = moves
	reader.read_bytes(4)
	result["evs"] = {"hp": reader.read_u8(), "attack": reader.read_u8(), "defense": reader.read_u8(), "speed": reader.read_u8(), "special_attack": reader.read_u8(), "special_defense": reader.read_u8()}
	reader.read_bytes(19)
	result["iv_bits"] = reader.read_s32_le()
	reader.read_u8()
	reader.read_s64_le()
	result["rarity_bits"] = reader.read_u16_le()
	result["caught_at"] = reader.read_s32_le()
	result["is_egg"] = reader.read_bool()
	reader.read_bytes(5)
	return result

static func _platform_ordinal() -> int:
	match OS.get_name():
		"Windows": return 0
		"Linux": return 1
		"macOS": return 2
		"iOS": return 3
		"Android": return 4
	return 0xFF

static func _architecture_ordinal() -> int:
	var architecture: String = Engine.get_architecture_name().to_lower()
	if architecture.contains("arm") or architecture.contains("aarch"):
		return 1
	if architecture.contains("riscv"):
		return 2
	if architecture.contains("loong"):
		return 3
	return 0

static func _bitness_ordinal() -> int:
	return 0 if Engine.get_architecture_name().contains("32") else 1
