extends SceneTree

func _init() -> void:
	if load("res://scripts/net/session.gd") == null:
		push_error("OpenMMO session script did not load")
		quit(1)
		return
	if not _test_codec():
		quit(1)
		return
	if not _test_aes_ctr():
		quit(1)
		return
	if not _test_p256():
		quit(1)
		return
	if not _test_login_codec():
		quit(1)
		return
	if not _test_game_codec():
		quit(1)
		return
	quit(0)

func _test_codec() -> bool:
	var payload: PackedByteArray = PackedByteArray()
	OpenMMOCodec.append_u8(payload, 0x11)
	OpenMMOCodec.append_u16_le(payload, 0xCAFE)
	OpenMMOCodec.append_s32_le(payload, -1234567)
	OpenMMOCodec.append_bool(payload, true)
	OpenMMOCodec.append_utf16_le_null(payload, "OpenMMO Ω")
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(payload)
	if reader.read_u8() != 0x11 or reader.read_u16_le() != 0xCAFE or reader.read_s32_le() != -1234567 or not reader.read_bool() or reader.read_utf16_le_null() != "OpenMMO Ω" or reader.failed or reader.remaining() != 0:
		push_error("OpenMMO byte codec roundtrip failed")
		return false
	var framed: PackedByteArray = OpenMMOCodec.frame(PackedByteArray([0xAA, 0xBB, 0xCC]))
	if framed.size() != 5 or framed.decode_u16(0) != 5:
		push_error("OpenMMO inclusive frame length is incorrect")
		return false
	return true

func _test_aes_ctr() -> bool:
	var key: PackedByteArray = _hex("2b7e151628aed2a6abf7158809cf4f3c")
	var counter: PackedByteArray = _hex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
	var plaintext: PackedByteArray = _hex("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51")
	var expected: PackedByteArray = _hex("874d6191b620e3261bef6864990db6ce9806f66b7970fdff8617187bb9fffdff")
	var stream: OpenMMOAESCTR = OpenMMOAESCTR.new()
	if stream.start(key, counter) != OK:
		push_error("OpenMMO AES-CTR could not start")
		return false
	var output: PackedByteArray = stream.update(plaintext.slice(0, 7))
	output.append_array(stream.update(plaintext.slice(7)))
	stream.finish()
	if output != expected:
		push_error("OpenMMO AES-CTR does not match the NIST vector")
		return false
	return true

func _test_p256() -> bool:
	var curve: OpenMMOP256 = OpenMMOP256.new()
	var generator: PackedByteArray = curve.generator_bytes()
	var doubled: Dictionary = curve.scalar_multiply_for_test("02", generator)
	if not bool(doubled.get("ok", false)):
		push_error(str(doubled.get("error", "P-256 multiplication failed")))
		return false
	var expected: PackedByteArray = _hex("047cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc4766997807775510db8ed040293d9ac69f7430dbba7dade63ce982299e04b79d227873d1")
	if doubled.get("point") as PackedByteArray != expected:
		push_error("OpenMMO P-256 scalar multiplication does not match 2G")
		return false
	return true

func _test_login_codec() -> bool:
	var encoded: PackedByteArray = OpenMMOLoginProtocol.encode_password_login("test", "test", true, PackedByteArray([1, 2, 3]), 0)
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(encoded)
	if reader.read_utf16_le_null() != "test" or not reader.read_bool() or reader.read_u8_bytes() != PackedByteArray([1, 2, 3]) or reader.read_u8() != 0 or reader.read_utf16_le_null() != "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3" or not reader.read_bool() or reader.read_utf16_le_null() != "en" or reader.read_s32_le() != 0 or reader.read_s32_le() != 0 or reader.read_u8() != 0 or not reader.read_u8_bytes().is_empty() or reader.failed or reader.remaining() != 0:
		push_error("OpenMMO password login packet does not match the server codec")
		return false
	var response: PackedByteArray = PackedByteArray([0])
	OpenMMOCodec.append_utf16_le_null(response, "")
	var decoded: Dictionary = OpenMMOLoginProtocol.decode_login_response(response)
	if not bool(decoded.get("ok", false)) or not bool(decoded.get("authenticated", false)):
		push_error("OpenMMO authenticated login response did not decode")
		return false
	return true

func _test_game_codec() -> bool:
	var join: PackedByteArray = OpenMMOGameProtocol.encode_join(17, PackedByteArray([1, 2, 3, 4]), PackedByteArray([9, 8, 7, 6, 5, 4, 3, 2]))
	var reader: OpenMMOCodec.Reader = OpenMMOCodec.Reader.new(join)
	if reader.read_u8() != 0 or reader.read_s32_le() != 17 or reader.read_u8_bytes() != PackedByteArray([1, 2, 3, 4]) or reader.read_bytes(6) != PackedByteArray([9, 8, 7, 6, 5, 4]) or reader.read_s32_le() != 0 or reader.read_s32_le() != 0:
		push_error("OpenMMO game join authentication fields are incorrect")
		return false
	reader.read_s8()
	reader.read_s16_le()
	reader.read_s16_le()
	reader.read_s8()
	reader.read_u8()
	reader.read_u8()
	reader.read_u8()
	reader.read_u8()
	reader.read_u8()
	if not reader.read_u8_bytes().is_empty() or reader.read_bytes(32).size() != 32 or reader.failed or reader.remaining() != 0:
		push_error("OpenMMO game join metadata shape is incorrect")
		return false
	var response: PackedByteArray = PackedByteArray([1])
	OpenMMOCodec.append_utf16_le_null(response, "")
	OpenMMOCodec.append_u8(response, 0)
	for value in [1337, 420, 187, 1000, 1200]:
		OpenMMOCodec.append_s32_le(response, value)
	var decoded_join: Dictionary = OpenMMOGameProtocol.decode_join_response(response)
	if not decoded_join.ok or not decoded_join.can_join or int(decoded_join.balance) != 187:
		push_error("OpenMMO game join response did not decode")
		return false
	var decoded_characters: Dictionary = OpenMMOGameProtocol.decode_characters(_character_list_fixture())
	if not decoded_characters.ok or decoded_characters.characters.size() != 1:
		push_error("OpenMMO character list did not decode")
		return false
	var character: Dictionary = decoded_characters.characters[0]
	if int(character.id) != 42 or str(character.name) != "Hero" or int(character.money) != 123 or int(character.bank_id) != 3 or int(character.map_id) != 4 or int(character.x) != 5 or int(character.y) != 6:
		push_error("OpenMMO character fields are misaligned")
		return false
	return true

func _character_list_fixture() -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray([1])
	OpenMMOCodec.append_s64_le(output, 42)
	OpenMMOCodec.append_utf16_le_null(output, "Hero")
	OpenMMOCodec.append_utf16_le_null(output, "")
	OpenMMOCodec.append_s32_le(output, 7)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s32_le(output, 100)
	OpenMMOCodec.append_s32_le(output, 50)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_s32_le(output, 123)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	output.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s32_le(output, 0)
	output.append_array(PackedByteArray([0, 0, 0, 0]))
	output.append_array(PackedByteArray([0, 0xFF, 2, 0, 3]))
	OpenMMOCodec.append_s16_le(output, 4)
	OpenMMOCodec.append_s16_le(output, 5)
	OpenMMOCodec.append_s16_le(output, 6)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_s16_le(output, 0)
	OpenMMOCodec.append_u16_le(output, 0)
	OpenMMOCodec.append_u8(output, 0)
	OpenMMOCodec.append_u16_le(output, 0)
	OpenMMOCodec.append_u16_le(output, 0)
	OpenMMOCodec.append_bool(output, false)
	OpenMMOCodec.append_u8(output, 0)
	return output

func _hex(value: String) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	for index in range(0, value.length(), 2):
		output.append(value.substr(index, 2).hex_to_int())
	return output
