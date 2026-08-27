class_name MonWorldProtocol
extends RefCounted

const VERSION := 1
const MAGIC := 0x4D57
const HEADER_SIZE := 14
const MAX_PAYLOAD := 1024 * 1024
const AUTHENTICATE := 1
const HELLO := 2
const CHARACTER_LIST := 3
const SELECT_CHARACTER := 4
const WORLD_SNAPSHOT := 5
const ENTITY_UPDATE := 6
const INPUT := 7
const CHAT := 8
const BATTLE_START := 9
const BATTLE_ACTION := 10
const BATTLE_EVENT := 11
const ERROR := 255

static func encode_json(message_type: int, sequence: int, value: Variant) -> PackedByteArray:
	return encode(message_type, sequence, JSON.stringify(value).to_utf8_buffer())

static func encode(message_type: int, sequence: int, payload: PackedByteArray, flags: int = 0) -> PackedByteArray:
	if payload.size() > MAX_PAYLOAD:
		return PackedByteArray()
	var data := PackedByteArray()
	data.resize(HEADER_SIZE)
	data.encode_u16(0, MAGIC)
	data.encode_u8(2, VERSION)
	data.encode_u8(3, flags)
	data.encode_u16(4, message_type)
	data.encode_u32(6, sequence)
	data.encode_u32(10, payload.size())
	data.append_array(payload)
	return data

static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < HEADER_SIZE:
		return {"ok": false, "error": "frame is shorter than header"}
	if data.decode_u16(0) != MAGIC:
		return {"ok": false, "error": "invalid frame magic"}
	if data.decode_u8(2) != VERSION:
		return {"ok": false, "error": "unsupported frame version"}
	var payload_size := data.decode_u32(10)
	if payload_size > MAX_PAYLOAD or payload_size != data.size() - HEADER_SIZE:
		return {"ok": false, "error": "invalid frame payload length"}
	var payload := data.slice(HEADER_SIZE)
	var value: Variant = JSON.parse_string(payload.get_string_from_utf8())
	return {"ok": true, "version": data.decode_u8(2), "flags": data.decode_u8(3), "type": data.decode_u16(4), "sequence": data.decode_u32(6), "payload": payload, "value": value}
