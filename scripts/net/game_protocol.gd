class_name OpenMMOGameProtocol
extends RefCounted

const JOIN: int = 0x01
const REQUEST_CHARACTERS: int = 0x02
const SELECT_CHARACTER: int = 0x04
const REQUEST_PLAYER: int = 0x05
const MOVEMENT: int = 0x06
const MAP_LOADED_ACK: int = 0x33
const FACE_DIRECTION: int = 0x07
const CHAT_SEND: int = 0x08
const ENTITY_LEAVE: int = 0x08
const CHAT_MESSAGE: int = 0x09
const WORLD_FLAG_TABLE_RESET: int = 0x0A
const WORLD_FLAG_SET: int = 0x0B
const LOCAL_CHARACTER_DELTA: int = 0x0C
const POKEMON_STORAGE: int = 0x13
const POKEMON_CONTAINER_PARTY: int = 1
const ENTITY_MOVE_SEQUENCE: int = 0x0D
const DIALOG_STATE: int = 0x0E
const SERVER_NOTICE: int = 0x74
const LOAD_MAP: int = 0x10
const NPC_UPDATE: int = 0x11
const NPC_SPAWN: int = 0x12
const ENTITY_MOVE_PP: int = 0x1A
const DIALOG_ACTION: int = 0x21
const ENTITY_INTERACT: int = 0x22
const SHOP_CATALOG: int = 0x23
const SHOP_BUY: int = 0x23
const SHOP_SELL: int = 0x24
const DIALOG_CHOICE: int = 0x25
const TILE_INTERACT: int = 0x27
const STORY_FLAG_UPDATE: int = 0x2A
const MAP_TRANSITION: int = 0x1B
const RENDER_SCREEN: int = 0xB4
const NPC_ANIMATION: int = 0xB2
const ENTITY_MOVE_GBA: int = 0xEA
const ENTITY_MOVE_NDS: int = 0xE4
const ENTITY_FACE_TURN: int = 0x07
const ENTITY_PRESENCE: int = 0x0F
const BATTLE_ENTITY_DELTA: int = 0x16
const BATTLE_ACTION_SELECT: int = 0x32
const BATTLE_FIELD_STATE: int = 0x30
const BATTLE_BULK_STATE: int = 0x31
const BATTLE_QUEUED_EVENT: int = 0x32
const BATTLE_MOVE_EVENT: int = 0x33
const BATTLE_SLOT_EVENT: int = 0x34
const BATTLE_SWITCH_IN: int = 0x35
const BATTLE_SLOT_FLAG: int = 0x36
const BATTLE_LIST_EVENT: int = 0x37
const BATTLE_SIDE_PARTY: int = 0x40
const BATTLE_SIDE_ADD_POKEMON: int = 0x42
const BATTLE_STAT_COUNTERS: int = 0x79
const BATTLE_SIDE: int = 0x6B
const BATTLE_PROMPT: int = 0x9D
const BATTLE_TILE_MAP: int = 0xC4
const BATTLE_START_SCENE: int = 0xCA
const LOCAL_PLAYER_STATE: int = 0xF3
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

static func encode_map_loaded_ack() -> PackedByteArray:
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

static func encode_chat_send(mode: int, target: String, message: String = "") -> PackedByteArray:
	if mode < 0 or mode > 127:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_u8(output, mode)
	OpenMMOCodec.append_utf16_le_null(output, target)
	if mode == 4:
		OpenMMOCodec.append_utf16_le_null(output, message)
	return output

static func encode_chat_message(text: String, chat_type: int = 0, language: int = 0) -> PackedByteArray:
	if chat_type < 0 or chat_type > 255 or language < 0 or language > 255:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_u8(output, chat_type)
	OpenMMOCodec.append_s64_le(output, 0)
	OpenMMOCodec.append_utf16_le_null(output, "")
	OpenMMOCodec.append_u8(output, language)
	OpenMMOCodec.append_u8(output, 255)
	OpenMMOCodec.append_utf16_le_null(output, text)
	return output

static func encode_battle_action_select(action: int, move_or_item_id: int = 0, target_entity_id: int = 0, extra_flag: int = 0, slot_ref: int = 0) -> PackedByteArray:
	if action < 0 or action > 3:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray([slot_ref & 0xFF, action & 0xFF])
	match action:
		0:
			OpenMMOCodec.append_s16_le(output, move_or_item_id)
			OpenMMOCodec.append_u8(output, extra_flag)
		1:
			OpenMMOCodec.append_s16_le(output, move_or_item_id)
			OpenMMOCodec.append_s64_le(output, target_entity_id)
			OpenMMOCodec.append_u8(output, extra_flag)
		2:
			OpenMMOCodec.append_s16_le(output, move_or_item_id)
		3:
			pass
	return output

static func encode_shop_buy(item_id: int, quantity: int, exchange_type_index: int = 0) -> PackedByteArray:
	if item_id < -0x8000 or item_id > 0x7FFF or quantity <= 0 or quantity > 0x7FFF or exchange_type_index < -0x80 or exchange_type_index > 0x7F:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s16_le(output, item_id)
	OpenMMOCodec.append_s16_le(output, quantity)
	OpenMMOCodec.append_u8(output, exchange_type_index)
	return output

static func encode_shop_sell(item_entity_id: int, quantity: int) -> PackedByteArray:
	if item_entity_id == 0 or quantity <= 0 or quantity > 0x7FFF:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_s64_le(output, item_entity_id)
	OpenMMOCodec.append_s16_le(output, quantity)
	return output

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

static func decode_world_flag_table_reset(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var group_count: int = reader.read_u8()
	var groups: Array = []
	if group_count > 32:
		reader.failed = true
	else:
		for _index in group_count:
			groups.append(reader.read_u16_bytes())
	var result: Dictionary = {"groups": groups, "ok": not reader.failed and reader.remaining() == 0}
	result["error"] = "OpenMMO world flag table packet is malformed" if not result.ok else ""
	return result

static func decode_world_flag_set(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var result: Dictionary = {"group": reader.read_s8(), "index": reader.read_s16_le(), "value": reader.read_s8()}
	result["ok"] = not reader.failed and reader.remaining() == 0
	result["error"] = "OpenMMO world flag packet is malformed" if not result.ok else ""
	return result

static func decode_story_flag_update(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var result: Dictionary = {"region_id": reader.read_s8(), "flag_id": reader.read_s16_le() & 0xFFFF, "enabled": reader.read_s16_le() != 0}
	result["ok"] = not reader.failed and reader.remaining() == 0
	result["error"] = "OpenMMO story flag packet is malformed" if not result.ok else ""
	return result

static func decode_local_player_state(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var state: Dictionary = {"region": reader.read_s8(), "map_id": reader.read_s16_le(), "move_speed": reader.read_f32_le(), "x": reader.read_s16_le(), "y": reader.read_s16_le(), "z": reader.read_s16_le(), "money": reader.read_s32_le(), "gender": reader.read_s8(), "skin_tone": reader.read_s16_le(), "hair_color": reader.read_s16_le(), "playtime": reader.read_f64_le(), "flags": reader.read_s8()}
	state["party_dex"] = _read_s16_list(reader, reader.read_u16_le(), 6)
	state["party_forms"] = _read_s8_list(reader, reader.read_u8(), 6)
	state["pokedex_seen"] = _read_s16_list(reader, reader.read_u16_le(), 4096)
	state["pokedex_caught"] = _read_s16_list(reader, reader.read_u16_le(), 4096)
	state["badges"] = _read_s16_list(reader, reader.read_u8(), 64)
	var variable_count: int = reader.read_u16_le()
	var variables: Array = []
	if variable_count > 1024:
		reader.failed = true
	else:
		for _index in variable_count:
			variables.append({"key": reader.read_s8(), "value": reader.read_s16_le()})
	state["variables"] = variables
	var result: Dictionary = {"state": state, "ok": not reader.failed and reader.remaining() == 0}
	result["error"] = "OpenMMO local player state packet is malformed" if not result.ok else ""
	return result

static func _read_s16_list(reader: OpenMMOCodec.Reader, count: int, max_count: int) -> Array:
	if count < 0 or count > max_count:
		reader.failed = true
		return []
	var values: Array = []
	for _index in count:
		values.append(reader.read_s16_le())
	return values

static func _read_s8_list(reader: OpenMMOCodec.Reader, count: int, max_count: int) -> Array:
	if count < 0 or count > max_count:
		reader.failed = true
		return []
	var values: Array = []
	for _index in count:
		values.append(reader.read_s8())
	return values

static func decode_shop_catalog(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var kind: int = reader.read_s8()
	var result: Dictionary = {"open": kind == 0, "kind": kind, "items": []}
	if kind == 0:
		result["shop_id"] = reader.read_s16_le()
		result["exchange_value"] = reader.read_s32_le()
		result["npc_entity_id"] = reader.read_s64_le()
		var count: int = reader.read_u16_le()
		if count > 512:
			reader.failed = true
		for _index in mini(count, 512):
			(result["items"] as Array).append({"item_id": reader.read_s16_le(), "exchange_type_index": reader.read_s16_le(), "stock": reader.read_s16_le(), "price": reader.read_s32_le()})
	elif kind != -1:
		reader.failed = true
	result["ok"] = not reader.failed and reader.remaining() == 0
	if not bool(result.get("ok", false)):
		result["error"] = "OpenMMO shop catalog packet is malformed"
	return result

static func decode_local_character_delta(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var mask: int = reader.read_u16_le()
	var updates: Dictionary = {}
	if mask & 0x1:
		updates["money"] = reader.read_s32_le()
	if mask & 0x2:
		updates["map_id"] = reader.read_s16_le()
		updates["map_flag"] = reader.read_s8()
	if mask & 0x4:
		updates["value_4"] = reader.read_s16_le()
	if mask & 0x8:
		updates["value_8"] = [reader.read_s8(), reader.read_s8(), reader.read_s8()]
	if mask & 0x10:
		updates["value_16"] = [reader.read_s16_le(), reader.read_s16_le()]
	if mask & 0x20:
		updates["value_32"] = reader.read_s32_le()
	if mask & 0x40:
		var kind: int = reader.read_s8()
		updates["value_64"] = {"kind": kind}
		if kind != 0:
			updates["value_64"]["a"] = reader.read_s16_le()
			updates["value_64"]["b"] = reader.read_s16_le()
	if mask & 0x80:
		var status_count: int = reader.read_u8()
		updates["status_conditions"] = []
		if status_count > 64:
			reader.failed = true
		for _index in mini(status_count, 64):
			(updates["status_conditions"] as Array).append(reader.read_s8())
	if mask & 0x100:
		updates["value_256"] = reader.read_s8()
	var result: Dictionary = {"mask": mask, "updates": updates, "ok": not reader.failed and reader.remaining() == 0}
	if not bool(result.get("ok", false)):
		result["error"] = "OpenMMO local character delta packet is malformed"
	return result

static func decode_pokemon_storage(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var container: int = reader.read_u8()
	var flags: int = reader.read_u8()
	var deleted: bool = flags & 0x2 != 0
	var pokemon: Array = []
	if not deleted:
		var count: int = reader.read_u8()
		for _index in count:
			pokemon.append(_read_pokemon(reader))
	var result: Dictionary = {"container": container, "has_change": flags & 0x1 != 0, "delete": deleted, "pokemon": pokemon, "ok": not reader.failed and reader.remaining() == 0}
	if not bool(result.get("ok", false)):
		result["error"] = "OpenMMO Pokemon storage packet is malformed"
	return result

static func decode_battle_side_party(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var side: int = reader.read_s8()
	var replace: bool = reader.read_u8() == 1
	var count: int = reader.read_u16_le()
	var entries: Array = []
	if count > 512:
		reader.failed = true
	for _index in mini(count, 512):
		entries.append(_read_battle_party_entry(reader))
	var result: Dictionary = {"side": side, "replace": replace, "entries": entries, "ok": not reader.failed and reader.remaining() == 0}
	if not bool(result.get("ok", false)):
		result["error"] = "OpenMMO battle-side party packet is malformed"
	return result

static func decode_battle_side_add_pokemon(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var side: int = reader.read_s8()
	var entry: Dictionary = _read_battle_party_entry(reader)
	var result: Dictionary = {"side": side, "entry": entry, "ok": not reader.failed and reader.remaining() == 0}
	if not bool(result.get("ok", false)):
		result["error"] = "OpenMMO battle-side add packet is malformed"
	return result

static func _read_battle_party_entry(reader: OpenMMOCodec.Reader) -> Dictionary:
	var flags: int = reader.read_u8()
	var entry: Dictionary = {"flags": flags, "entity_id": reader.read_s64_le()}
	if flags & 0x1:
		entry["linked_entity_id"] = reader.read_s64_le()
	entry["front_sprite_id"] = reader.read_s16_le()
	entry["back_sprite_id"] = reader.read_s16_le()
	entry["side"] = reader.read_s8()
	if flags & 0x2:
		entry["value_2"] = reader.read_s8()
	entry["slot"] = reader.read_s8() if flags & 0x4 else 0
	entry["party_index"] = reader.read_s8() if flags & 0x8 else -1
	if flags & 0x10:
		entry["status"] = {"duration": reader.read_s32_le(), "type": reader.read_s8(), "source_slot": reader.read_s8()}
	return entry

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
	var raw_facing: int = reader.read_u8()
	if raw_facing > 3:
		reader.failed = true
	else:
		entity["facing"] = raw_facing + 1
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

static func decode_entity_move_sequence(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity_id: int = reader.read_s64_le()
	var running: bool = reader.read_u8() == 1
	var count: int = reader.read_u8()
	var steps: PackedByteArray = reader.read_bytes(reader.remaining())
	if count > 64 or steps.size() != count:
		reader.failed = true
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO scripted movement packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity_id": entity_id, "running": running, "steps": steps}

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

static func decode_entity_leave(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le()}
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO entity-leave packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_npc_spawn(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "sprite_region_id": reader.read_u8(), "graphics_id": reader.read_u16_le(), "unk3": reader.read_u16_le(), "unk4": reader.read_u16_le(), "region_id": reader.read_u8(), "bank_id": reader.read_u8(), "wire_map_id": reader.read_u8(), "x": reader.read_u16_le(), "y": reader.read_u16_le()}
	entity["unk5"] = reader.read_u8()
	var raw_facing: int = reader.read_u8()
	entity["facing"] = raw_facing + 1 if raw_facing <= 3 else 1
	entity["unk6"] = reader.read_u16_le()
	entity["npc"] = true
	entity["blocks_movement"] = true
	return {"ok": not reader.failed and reader.remaining() == 0, "error": "OpenMMO NPC spawn packet is malformed" if reader.failed or reader.remaining() != 0 else "", "entity": entity}

static func decode_npc_update(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity: Dictionary = {"entity_id": reader.read_s64_le(), "region_id": reader.read_u8(), "bank_id": reader.read_u8(), "wire_map_id": reader.read_u8(), "x": reader.read_u16_le(), "y": reader.read_u16_le()}
	entity["movement_mode"] = reader.read_u8()
	var raw_facing: int = reader.read_u8()
	entity["facing"] = raw_facing + 1 if raw_facing <= 3 else 1
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

static func decode_chat_message(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var chat_type: int = reader.read_u8()
	var message: Dictionary = {"type": chat_type, "channel": _chat_channel(chat_type), "text": "", "message": "", "sender": "", "name": "", "system": chat_type >= 16}
	if chat_type == 8 or chat_type == 11:
		message["text"] = reader.read_utf16_le_null()
		message["message"] = message["text"]
	else:
		reader.read_s64_le()
		var sender: String = reader.read_utf16_le_null()
		message["sender"] = sender
		message["name"] = sender
		message["language"] = reader.read_u8()
		reader.read_s8()
		message["text"] = reader.read_utf16_le_null()
		message["message"] = message["text"]
	var result: Dictionary = {"ok": not reader.failed and reader.remaining() == 0, "message": message}
	if not result.ok:
		result["error"] = "OpenMMO chat message is malformed"
	return result

static func decode_server_notice(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var notice: Dictionary = {"type": reader.read_s16_le(), "id": reader.read_s32_le(), "text": reader.read_utf16_le_null()}
	var result: Dictionary = {"ok": not reader.failed and reader.remaining() == 0, "notice": notice}
	if not result.ok:
		result["error"] = "OpenMMO server notice is malformed"
	return result

static func decode_entity_presence(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var presence: Dictionary = {"entity_id": reader.read_s64_le(), "status": reader.read_s8()}
	return _battle_decode_result(reader, {"presence": presence}, "OpenMMO entity presence packet is malformed")

static func decode_battle_side(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	return _battle_decode_result(reader, {"side": reader.read_s8()}, "OpenMMO battle-side packet is malformed")

static func decode_battle_field_state(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	reader.read_bytes(5)
	var background: int = reader.read_s8()
	reader.read_bytes(17)
	var opposing: int = reader.read_s8()
	reader.read_bytes(4)
	var player_name: String = reader.read_utf16_le_null()
	reader.read_u8()
	var player_id: int = reader.read_s64_le()
	reader.read_s8()
	reader.read_bytes(14)
	reader.read_bytes(5)
	reader.read_u8()
	var player_count: int = reader.read_u8()
	reader.read_u8()
	var player_party: Array = []
	if player_count > 6:
		reader.failed = true
	for _index in mini(player_count, 6):
		player_party.append(_read_battle_mon_full(reader))
		reader.read_s8()
	var active: Dictionary = _read_battle_active(reader)
	reader.read_s8()
	reader.read_u8()
	reader.read_u8()
	var trainer_id: int = 0
	if opposing == 4:
		trainer_id = reader.read_s16_le()
	reader.read_bytes(4)
	if opposing == 4:
		reader.read_bytes(2)
	reader.read_u8()
	var opponent_count: int = reader.read_u8()
	reader.read_u8()
	var opponent_party: Array = []
	if opponent_count > 6:
		reader.failed = true
	for _index in mini(opponent_count, 6):
		opponent_party.append(_read_battle_opponent(reader))
		reader.read_s8()
	var opponent_active: Dictionary = _read_battle_active(reader)
	reader.read_bytes(4)
	var state: Dictionary = {"background": background, "trainer": opposing == 4, "opposing": opposing, "trainer_id": trainer_id, "player_name": player_name, "player_id": player_id, "player_party": player_party, "active_slot": int(active.get("slot", 0)), "active": active, "opponent_party": opponent_party, "opponent_active_slot": int(opponent_active.get("slot", 0)), "opponent_active": opponent_active}
	return _battle_decode_result(reader, {"state": state}, "OpenMMO battle field state is malformed")

static func decode_battle_bulk_state(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var phase: int = reader.read_s8()
	_skip_battle_serialized_group(reader)
	_skip_battle_serialized_group(reader)
	var prize_money: int = reader.read_s32_le()
	var value_b: int = reader.read_s32_le()
	var flag: int = reader.read_s8()
	_skip_battle_serialized_group(reader)
	return _battle_decode_result(reader, {"phase": phase, "prize_money": prize_money, "value_b": value_b, "flag": flag}, "OpenMMO battle bulk state is malformed")

static func decode_battle_queued_event(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var packed: int = reader.read_s8()
	return _battle_decode_result(reader, {"packed": packed, "value": packed & 0x7F, "prompt": packed & 0x80 != 0}, "OpenMMO battle queued event is malformed")

static func decode_battle_move_event(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var source_entity: int = reader.read_s64_le()
	var source_move: int = reader.read_s16_le()
	var kind: int = reader.read_s8()
	var target_count: int = reader.read_u8()
	var targets: Array = []
	if target_count > 8:
		reader.failed = true
	for _index in mini(target_count, 8):
		var target: Dictionary = {"entity_id": reader.read_s64_le(), "target_move": reader.read_s16_le(), "events": []}
		var event_count: int = reader.read_u8()
		if event_count > 16:
			reader.failed = true
		for _event_index in mini(event_count, 16):
			var event_type: int = reader.read_u8()
			var aux: int = reader.read_u8()
			var event: Dictionary = {"type": event_type, "aux": aux}
			if aux & 1 != 0:
				event["entity_a"] = reader.read_s64_le()
			if aux & 2 != 0:
				event["entity_b"] = reader.read_s64_le()
			match event_type:
				0:
					event["current_hp"] = reader.read_s16_le()
				1:
					event["change_type"] = reader.read_s8()
					event["stat"] = reader.read_s8()
					event["stage_delta"] = reader.read_s8()
					reader.read_u8()
				4:
					pass
				5:
					event["faint"] = reader.read_bool()
				0x40:
					event["failed_move"] = reader.read_s16_le()
				_:
					reader.failed = true
			(target["events"] as Array).append(event)
		targets.append(target)
	return _battle_decode_result(reader, {"source_entity": source_entity, "source_move": source_move, "kind": kind, "targets": targets}, "OpenMMO battle move event is malformed")

static func decode_battle_switch_in(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var side: int = reader.read_s8()
	reader.read_u8()
	var new_slot: int = reader.read_u8()
	var old_slot: int = reader.read_u8()
	var full_block: bool = reader.remaining() > 21
	var mon: Dictionary = _read_battle_mon_full(reader) if full_block else {}
	if full_block:
		reader.read_s8()
	var active: Dictionary = _read_battle_active(reader)
	return _battle_decode_result(reader, {"side": side, "new_slot": new_slot, "old_slot": old_slot, "full_block": full_block, "mon": mon, "active": active}, "OpenMMO battle switch-in packet is malformed")

static func decode_battle_slot_event(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	return _battle_decode_result(reader, {"slot": reader.read_s8(), "event_type": reader.read_s8()}, "OpenMMO battle slot event is malformed")

static func decode_battle_slot_flag(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	return _battle_decode_result(reader, {"slot": reader.read_s8(), "flag": reader.read_bool(), "immediate": reader.read_bool()}, "OpenMMO battle slot flag event is malformed")

static func decode_battle_list_event(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var event: Dictionary = {"kind": reader.read_s8(), "value": reader.read_s16_le(), "sub_kind": reader.read_s8()}
	if int(event.get("sub_kind", 0)) == 4:
		event["detail"] = {"list_type": reader.read_s8(), "value": reader.read_s16_le()}
	return _battle_decode_result(reader, {"event": event}, "OpenMMO battle list event is malformed")

static func decode_battle_stat_counters(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity_id: int = reader.read_s64_le()
	var base_counter: int = reader.read_s32_le()
	var flags: int = reader.read_u8()
	var counters: Array = []
	for index in 6:
		counters.append(reader.read_s32_le() if flags & (1 << index) != 0 else null)
	return _battle_decode_result(reader, {"entity_id": entity_id, "base_counter": base_counter, "counters": counters}, "OpenMMO battle stat counters are malformed")

static func decode_battle_start_scene(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	return _battle_decode_result(reader, {"battle_type": reader.read_s8(), "double_battle": reader.read_bool(), "perspective": reader.read_s8()}, "OpenMMO battle start scene is malformed")

static func decode_battle_entity_delta(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var entity_id: int = reader.read_s64_le()
	var mask: int = reader.read_s32_le()
	var updates: Dictionary = {}
	if mask & 0x1 != 0:
		updates["experience_level"] = reader.read_s8()
		updates["experience_points"] = reader.read_s32_le()
	if mask & 0x2 != 0:
		var stats: Array = []
		for _index in 6:
			stats.append(reader.read_s16_le())
		updates["stats"] = stats
	if mask & 0x4 != 0:
		var moves: Array = []
		for _index in 4:
			moves.append({"id": reader.read_s16_le(), "pp": reader.read_s8()})
		updates["moves"] = moves
		updates["pp_ups"] = reader.read_s8()
	if mask & 0x8 != 0:
		updates["current_hp"] = reader.read_s16_le()
	if mask & 0x10 != 0:
		updates["faint_flag"] = reader.read_s8()
	if mask & 0x20 != 0:
		updates["species"] = reader.read_s16_le()
		updates["forme"] = reader.read_s8()
	if mask & 0x40 != 0:
		updates["listing_type"] = reader.read_s8()
		updates["listing_sort_key"] = reader.read_s16_le()
	if mask & 0x80 != 0:
		var evs: Array = []
		for _index in 6:
			evs.append(reader.read_s16_le())
		updates["evs"] = evs
	if mask & 0x100 != 0:
		updates["level"] = reader.read_s16_le()
	if mask & 0x200 != 0:
		updates["happiness"] = reader.read_s16_le()
	if mask & 0x400 != 0:
		updates["position"] = {"x": reader.read_s32_le(), "y": reader.read_s32_le(), "flag_a": reader.read_s8(), "flag_b": reader.read_s8(), "flag_c": reader.read_s8()}
	if mask & 0x800 != 0:
		updates["status_flags"] = reader.read_s16_le()
	if mask & 0x1000 != 0:
		updates["map_position"] = {"x": reader.read_s16_le(), "y": reader.read_s16_le()}
	if mask & 0x2000 != 0:
		updates["nature"] = reader.read_s8()
	if mask & 0x4000 != 0:
		updates["value64"] = reader.read_s64_le()
	if mask & 0x200000 != 0:
		updates["packed_ivs"] = reader.read_s32_le()
	if mask & 0x8000 != 0:
		var origin_evs: Array = []
		for _index in 4:
			origin_evs.append(reader.read_s16_le())
		updates["origin_evs"] = origin_evs
		updates["origin_species"] = reader.read_s64_le()
		updates["origin_trainer"] = reader.read_utf16_le_null()
		updates["origin_trainer_id"] = reader.read_s32_le()
	if mask & 0x10000 != 0:
		updates["shininess_type"] = reader.read_s8()
	if mask & 0x20000 != 0:
		updates["gender"] = reader.read_s8()
	if mask & 0x40000 != 0:
		var ivs: Array = []
		for _index in 5:
			ivs.append(reader.read_s16_le())
		updates["ivs"] = ivs
	if mask & 0x80000 != 0:
		updates["caught_ball"] = reader.read_s8()
	if mask & 0x100000 != 0:
		updates["status_flags_2"] = reader.read_s16_le()
	if mask & 0x400000 != 0:
		var status_count: int = reader.read_u8()
		if status_count > 32:
			reader.failed = true
		var statuses: Array = []
		for _index in mini(status_count, 32):
			statuses.append(reader.read_s8())
		updates["status_list"] = statuses
	if mask & 0x800000 != 0:
		updates["status"] = reader.read_s8()
	return _battle_decode_result(reader, {"entity_id": entity_id, "mask": mask, "updates": updates}, "OpenMMO battle entity delta is malformed")

static func decode_entity_move_pp(payload: PackedByteArray) -> Dictionary:
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	var result: Dictionary = {"entity_id": reader.read_s64_le(), "move_slot": reader.read_s8(), "pp": reader.read_s8()}
	result["ok"] = not reader.failed and reader.remaining() == 0
	if not bool(result.get("ok", false)):
		result["error"] = "OpenMMO move PP packet is malformed"
	return result

static func _read_battle_mon_full(reader: OpenMMOCodec.Reader) -> Dictionary:
	var mon: Dictionary = {"slot": reader.read_s8()}
	reader.read_u8()
	mon["entity_id"] = reader.read_s64_le()
	mon["species"] = reader.read_s16_le()
	mon["level"] = reader.read_s8()
	reader.read_bytes(2)
	mon["gender"] = reader.read_s8()
	reader.read_bytes(3)
	mon["current_hp"] = reader.read_s16_le()
	mon["max_hp"] = reader.read_s16_le()
	reader.read_bytes(5)
	mon["moves_present"] = reader.read_bool()
	mon["ability_id"] = reader.read_s16_le() if bool(mon.get("moves_present", false)) else 0
	var move_ids: Array = []
	for _index in 4:
		move_ids.append(reader.read_s16_le() if bool(mon.get("moves_present", false)) else 0)
	mon["move_ids"] = move_ids
	mon["revealed"] = true
	return mon

static func _read_battle_opponent(reader: OpenMMOCodec.Reader) -> Dictionary:
	var slot: int = reader.read_s8()
	var kind: int = reader.read_s8()
	if kind != 1:
		return {"slot": slot, "revealed": false, "species": 0, "level": 0, "current_hp": 0, "max_hp": 0}
	var mon: Dictionary = {"slot": slot, "revealed": true, "entity_id": reader.read_s64_le(), "species": reader.read_s16_le(), "level": reader.read_s8()}
	reader.read_bytes(2)
	mon["gender"] = reader.read_s8()
	reader.read_bytes(3)
	mon["current_hp"] = reader.read_s16_le()
	mon["max_hp"] = reader.read_s16_le()
	reader.read_bytes(5)
	reader.read_u8()
	return mon

static func _read_battle_active(reader: OpenMMOCodec.Reader) -> Dictionary:
	reader.read_u8()
	var active: Dictionary = {"slot": reader.read_s8(), "species": reader.read_s16_le(), "level": reader.read_s8()}
	reader.read_bytes(4)
	active["gender"] = reader.read_s8()
	reader.read_u8()
	reader.read_bytes(10)
	return active

static func _skip_battle_serialized_group(reader: OpenMMOCodec.Reader) -> void:
	var count: int = reader.read_u8()
	if count > 64:
		reader.failed = true
	for _index in mini(count, 64):
		_skip_battle_serialized_entry(reader)

static func _skip_battle_serialized_entry(reader: OpenMMOCodec.Reader) -> void:
	match reader.read_s8():
		-1:
			return
		0:
			reader.read_s32_le()
			var arg_count: int = reader.read_u8()
			if arg_count > 64:
				reader.failed = true
			for _index in mini(arg_count, 64):
				_skip_battle_message_arg(reader)
		1:
			reader.read_s8()
			var move_count: int = reader.read_u8()
			if move_count > 64:
				reader.failed = true
			reader.read_bytes(mini(move_count, 64) * 2)
		2:
			reader.read_s16_le()
			reader.read_s8()
			reader.read_s8()
		3:
			reader.read_s8()
			reader.read_s8()
			reader.read_s16_le()
			reader.read_s16_le()
		_:
			pass

static func _skip_battle_message_arg(reader: OpenMMOCodec.Reader) -> void:
	reader.read_s8()
	var raw_type: int = reader.read_s8()
	if raw_type & 0x80 != 0:
		reader.read_s8()
	var type_id: int = raw_type & 0x7F
	match type_id:
		5, 18:
			reader.read_utf16_le_null()
		28:
			pass
		30:
			reader.read_s64_le()
		9, 10, 17:
			reader.read_s32_le()
		_:
			var value_count: int = reader.read_u8()
			if value_count > 64:
				reader.failed = true
			reader.read_bytes(mini(value_count, 64) * 2)

static func _battle_decode_result(reader: OpenMMOCodec.Reader, result: Dictionary, error: String) -> Dictionary:
	result["ok"] = not reader.failed and reader.remaining() == 0
	if not bool(result.get("ok", false)):
		result["error"] = error
	return result

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

static func _chat_channel(chat_type: int) -> String:
	match chat_type:
		4:
			return "Whispers"
		5:
			return "Trade"
		6:
			return "Global"
		18:
			return "Battle"
	return "Local"

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
