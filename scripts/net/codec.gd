class_name OpenMMOCodec
extends RefCounted

class Reader extends RefCounted:
	var data: PackedByteArray
	var offset: int = 0
	var failed: bool = false

	func _init(value: PackedByteArray) -> void:
		data = value

	func remaining() -> int:
		return data.size() - offset

	func read_u8() -> int:
		if remaining() < 1:
			failed = true
			return 0
		var value: int = data[offset]
		offset += 1
		return value

	func read_s8() -> int:
		var value: int = read_u8()
		return value - 0x100 if value >= 0x80 else value

	func read_u16_le() -> int:
		if remaining() < 2:
			failed = true
			return 0
		var value: int = data.decode_u16(offset)
		offset += 2
		return value

	func read_s16_le() -> int:
		if remaining() < 2:
			failed = true
			return 0
		var value: int = data.decode_s16(offset)
		offset += 2
		return value

	func read_s32_le() -> int:
		if remaining() < 4:
			failed = true
			return 0
		var value: int = data.decode_s32(offset)
		offset += 4
		return value

	func read_s64_le() -> int:
		if remaining() < 8:
			failed = true
			return 0
		var value: int = data.decode_s64(offset)
		offset += 8
		return value

	func read_bool() -> bool:
		return read_u8() != 0

	func read_bytes(length: int) -> PackedByteArray:
		if length < 0 or remaining() < length:
			failed = true
			return PackedByteArray()
		var value: PackedByteArray = data.slice(offset, offset + length)
		offset += length
		return value

	func read_u8_bytes() -> PackedByteArray:
		return read_bytes(read_u8())

	func read_u16_bytes() -> PackedByteArray:
		return read_bytes(read_u16_le())

	func read_utf16_le_null() -> String:
		var codepoints: PackedInt32Array = PackedInt32Array()
		while remaining() >= 2:
			var first: int = read_u16_le()
			if first == 0:
				return String.from_utf32_buffer(codepoints.to_byte_array())
			if first >= 0xD800 and first <= 0xDBFF:
				if remaining() < 2:
					failed = true
					return ""
				var second: int = read_u16_le()
				if second < 0xDC00 or second > 0xDFFF:
					failed = true
					return ""
				codepoints.append(0x10000 + ((first - 0xD800) << 10) + second - 0xDC00)
			else:
				codepoints.append(first)
		failed = true
		return ""

static func append_u8(output: PackedByteArray, value: int) -> void:
	output.append(value & 0xFF)

static func append_u16_le(output: PackedByteArray, value: int) -> void:
	var offset: int = output.size()
	output.resize(offset + 2)
	output.encode_u16(offset, value & 0xFFFF)

static func append_s16_le(output: PackedByteArray, value: int) -> void:
	var offset: int = output.size()
	output.resize(offset + 2)
	output.encode_s16(offset, value)

static func append_s32_le(output: PackedByteArray, value: int) -> void:
	var offset: int = output.size()
	output.resize(offset + 4)
	output.encode_s32(offset, value)

static func append_s64_le(output: PackedByteArray, value: int) -> void:
	var offset: int = output.size()
	output.resize(offset + 8)
	output.encode_s64(offset, value)

static func append_bool(output: PackedByteArray, value: bool) -> void:
	append_u8(output, 1 if value else 0)

static func append_u8_bytes(output: PackedByteArray, value: PackedByteArray) -> bool:
	if value.size() > 0xFF:
		return false
	append_u8(output, value.size())
	output.append_array(value)
	return true

static func append_u16_bytes(output: PackedByteArray, value: PackedByteArray) -> bool:
	if value.size() > 0xFFFF:
		return false
	append_u16_le(output, value.size())
	output.append_array(value)
	return true

static func append_utf16_le_null(output: PackedByteArray, value: String) -> void:
	for index in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint <= 0xFFFF:
			append_u16_le(output, codepoint)
		else:
			var adjusted: int = codepoint - 0x10000
			append_u16_le(output, 0xD800 | adjusted >> 10)
			append_u16_le(output, 0xDC00 | adjusted & 0x3FF)
	append_u16_le(output, 0)

static func frame(payload: PackedByteArray) -> PackedByteArray:
	var total: int = payload.size() + 2
	if total > 0xFFFF:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	output.resize(2)
	output.encode_u16(0, total)
	output.append_array(payload)
	return output
