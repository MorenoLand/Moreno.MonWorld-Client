class_name OpenMMOGameProtocol
extends RefCounted

const JOIN: int = 0x01
const REQUEST_CHARACTERS: int = 0x02
const SELECT_CHARACTER: int = 0x04
const REQUEST_PLAYER: int = 0x05
const MOVEMENT: int = 0x06
const FACE_DIRECTION: int = 0x07
const DIALOG_STATE: int = 0x0E
const LOAD_MAP: int = 0x10
const NPC_UPDATE: int = 0x11
const NPC_SPAWN: int = 0x12
const DIALOG_ACTION: int = 0x21
const ENTITY_INTERACT: int = 0x22
const DIALOG_CHOICE: int = 0x25
const TILE_INTERACT: int = 0x27
const MAP_TRANSITION: int = 0x1B
const RENDER_SCREEN: int = 0xB4
const NPC_ANIMATION: int = 0xB2
const ENTITY_MOVE_GBA: int = 0xEA
const ENTITY_MOVE_NDS: int = 0xE4
const ENTITY_FACE_TURN: int = 0x07
const SPECIAL_MAP_ROM_TYPES: Array[int] = [2, 3, 4, 10]

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

static func encode_request_player() -> PackedByteArray:
	return PackedByteArray()

static func encode_movement(x: int, y: int, direction: String, running: bool = false) -> PackedByteArray:
	var direction_ordinal: int = _direction_ordinal(direction)
	if direction_ordinal < 0:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s16_le(output, x)
	OpenMMOCodec.append_s16_le(output, y)
	OpenMMOCodec.append_u8(output, direction_ordinal | (0x80 if running else 0))
	return output

static func encode_face_direction(direction: String) -> PackedByteArray:
	var direction_ordinal: int = _direction_ordinal(direction)
	return PackedByteArray() if direction_ordinal < 0 else PackedByteArray([direction_ordinal])

static func encode_entity_interact(entity_id: int, token: int = 0) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s64_le(output, entity_id)
	OpenMMOCodec.append_s64_le(output, token)
	return output

static func encode_tile_interact() -> PackedByteArray:
	return PackedByteArray()

static func encode_dialog_action_response(dialogue_id: int, value: int = 0) -> PackedByteArray:
	return PackedByteArray([dialogue_id & 0xFF, value & 0xFF])

static func decode_load_map(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var flags: int = reader.read_u8()
	var rom_type: int = reader.read_u8()
	var bank_id: int = reader.read_u8()
	var map_id: int = reader.read_u8()
	var region_id: int = reader.read_u8()
	var result: Dictionary = {"delete_cache": flags & 1 != 0, "reload_player": flags & 2 != 0, "rom_type": rom_type, "bank_id": bank_id, "map_id": map_id, "region_id": region_id, "key": map_key(rom_type, region_id, bank_id, map_id)}
	if rom_type in SPECIAL_MAP_ROM_TYPES:
		result["special"] = true
		result["map_matrix_id"] = reader.read_u16_le()
		var borders: Dictionary = {}
		for _index in reader.read_u8():
			var border_key: int = reader.read_u16_le()
			var border_value: int = reader.read_u16_le()
			borders[border_key] = border_value
		result["border_connections"] = borders
		result["lighting"] = reader.read_u8()
		result["weather"] = reader.read_u8()
		result["map_type"] = reader.read_u8()
	else:
		result["special"] = false
		result["width"] = reader.read_s32_le()
		result["height"] = reader.read_s32_le()
		result["palette_index_1"] = reader.read_s32_le()
		result["palette_index_2"] = reader.read_s32_le()
		var border_width: int = reader.read_u8()
		var border_height: int = reader.read_u8()
		result["border_width"] = border_width
		result["border_height"] = border_height
		result["unknown_short"] = reader.read_s16_le()
		result["unknown_byte"] = reader.read_u8()
		result["lighting"] = reader.read_u8()
		result["weather"] = reader.read_u8()
		result["map_type"] = reader.read_u8()
		result["encounter_type"] = reader.read_u8()
		var border_tiles: Array = []
		var border_count: int = border_width * border_height
		if border_count < 0 or border_count > reader.remaining() / 2:
			reader.failed = true
		else:
			for _index in border_count:
				var packed: int = reader.read_u16_le()
				border_tiles.append({"material": packed & 0x3FF, "collision": packed >> 10 & 0x3F})
		result["border_tiles"] = border_tiles
		var custom_map_gzip: PackedByteArray = PackedByteArray()
		if reader.read_bool():
			var compressed_size: int = reader.read_s32_le()
			if compressed_size < 0:
				reader.failed = true
			else:
				custom_map_gzip = reader.read_bytes(compressed_size)
		result["custom_map_gzip"] = custom_map_gzip
		var connections: Array = []
		for _index in reader.read_u8():
			connections.append({"direction": reader.read_u8(), "offset": reader.read_s32_le(), "bank_id": reader.read_u8(), "map_id": reader.read_u8()})
		result["connections"] = connections
		if reader.read_bool():
			result["trailer_value"] = reader.read_s64_le()
			result["trailer_text"] = reader.read_utf16_le_null()
	result["ok"] = not reader.failed and reader.remaining() == 0
	if not result.ok:
		result["error"] = "OpenMMO map packet is malformed"
	return result

static func decode_load_entity(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le()}
	reader.read_u8()
	entity["skin"] = _read_skin_set(reader, true)
	entity["name"] = reader.read_utf16_le_null()
	entity["region_id"] = reader.read_u8()
	entity["bank_id"] = reader.read_u8()
	entity["wire_map_id"] = reader.read_u8()
	entity["x"] = reader.read_s16_le()
	entity["y"] = reader.read_s16_le()
	entity["elevation"] = reader.read_u8()
	entity["facing"] = reader.read_u8()
	entity["transportation"] = reader.read_u8()
	entity["nameplate_type"] = reader.read_u8()
	var flags: int = reader.read_u8()
	entity["flags"] = flags
	if flags & 0x01:
		reader.read_s8()
	if flags & 0x02:
		reader.read_s8()
		reader.read_u16_le()
	if flags & 0x04:
		entity["follower_dex_id"] = reader.read_s16_le()
	if flags & 0x08:
		reader.read_s8()
	if flags & 0x10:
		reader.read_s32_le()
		reader.read_utf16_le_null()
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO entity packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_gba_entity_move(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "bank_id": reader.read_u8(), "wire_map_id": reader.read_u8(), "x": reader.read_u8(), "y": reader.read_u8(), "movement_mode": reader.read_u8()}
	var direction_ordinal: int = reader.read_u8()
	if direction_ordinal > 3:
		reader.failed = true
	else:
		entity["facing"] = direction_ordinal + 1
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO GBA movement packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_entity_move(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "x": reader.read_s16_le(), "y": reader.read_s16_le()}
	var direction_ordinal: int = reader.read_u8()
	if direction_ordinal > 3:
		reader.failed = true
	else:
		entity["facing"] = direction_ordinal + 1
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO movement packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_entity_face_turn(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le()}
	var direction_ordinal: int = reader.read_u8()
	if direction_ordinal > 3:
		reader.failed = true
	else:
		entity["facing"] = direction_ordinal + 1
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO face-turn packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_npc_spawn(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "sprite_region_id": reader.read_u8(), "graphics_id": reader.read_u16_le(), "unk3": reader.read_u16_le(), "unk4": reader.read_u16_le(), "region_id": reader.read_u8(), "bank_id": reader.read_u8(), "wire_map_id": reader.read_u8(), "x": reader.read_u16_le(), "y": reader.read_u16_le()}
	var raw_facing: int = reader.read_u8()
	entity["unk5"] = reader.read_u8()
	entity["facing"] = raw_facing + 1 if raw_facing <= 3 else 1
	entity["unk6"] = reader.read_u16_le()
	entity["npc"] = true
	entity["blocks_movement"] = true
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO NPC spawn packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_npc_update(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "region_id": reader.read_u8(), "bank_id": reader.read_u8(), "wire_map_id": reader.read_u8(), "x": reader.read_u16_le(), "y": reader.read_u16_le()}
	var raw_facing: int = reader.read_u8()
	entity["facing"] = raw_facing + 1 if raw_facing <= 3 else 1
	entity["unk"] = reader.read_u8()
	entity["npc"] = true
	entity["blocks_movement"] = true
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO NPC update packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_npc_animation(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "animation": reader.read_u8(), "npc": true}
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO NPC animation packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_dialog_action(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var action: Dictionary = {"flags": reader.read_s8(), "action_type": reader.read_s8(), "text_id": reader.read_s32_le(), "entity_id": reader.read_s64_le(), "context_value": reader.read_s32_le()}
	var argument_count: int = reader.read_u8()
	var message_args: Array = []
	if argument_count > 32:
		reader.failed = true
	else:
		for _index in argument_count:
			message_args.append(_read_dialog_message_arg(reader))
	action["message_args"] = message_args
	action["detail"] = reader.read_bytes(reader.remaining())
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO dialog action packet is malformed" if reader.failed or reader.remaining() != 0 else "", "action": action}

static func decode_dialog_state(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var open: bool = reader.read_bool()
	return {"ok": not reader.failed and reader.remaining() == 0, "open": open, "error": "OpenMMO dialog state packet is malformed" if reader.failed or reader.remaining() != 0 else ""}

static func _read_dialog_message_arg(reader: OpenMMOCodec.Reader) -> Dictionary:
	var tag: int = reader.read_s8()
	match tag:
		-1:
			return {"tag": "null"}
		0:
			var value: int = reader.read_s32_le()
			var count: int = reader.read_u8()
			if count > 32:
				reader.failed = true
				return {}
			var nested: Array = []
			for _index in count:
				nested.append(_read_dialog_message_arg(reader))
			return {"tag": "creature_data", "value": value, "args": nested}
		1:
			var team: int = reader.read_s8()
			var move_count: int = reader.read_u8()
			if move_count > 32:
				reader.failed = true
				return {}
			var move_ids: Array[int] = []
			for _index in move_count:
				move_ids.append(reader.read_s16_le())
			return {"tag": "creature_moves", "team": team, "move_ids": move_ids}
		2:
			return {"tag": "pokemon_species", "party_slot": reader.read_s8(), "string_variable": reader.read_s8(), "species_id": reader.read_s16_le()}
		3:
			return {"tag": "creature", "slot": reader.read_s8(), "status_id": reader.read_s8(), "value1": reader.read_s16_le(), "value2": reader.read_s16_le()}
		_:
			reader.failed = true
			return {}

static func decode_render_screen(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var visible: bool = reader.read_bool()
	return {"ok": not reader.failed and reader.remaining() == 0, "visible": visible, "error": "OpenMMO render-screen packet is malformed" if reader.failed or reader.remaining() != 0 else ""}

static func map_key(rom_type: int, region_id: int, bank_id: int, map_id: int) -> String:
	return "%d:%d:%d:%d" % [rom_type, region_id, bank_id, map_id]

static func _direction_ordinal(direction: String) -> int:
	match direction.to_lower():
		"down":
			return 0
		"up":
			return 1
		"left":
			return 2
		"right":
			return 3
	return -1

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
