extends SceneTree

func _init() -> void:
	var public_key: PackedByteArray = _hex("0460fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb67903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299")
	var signature: PackedByteArray = _hex("efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8")
	var digest: PackedByteArray = _sha256("sample".to_utf8_buffer())
	var verifier: OpenMMOP256 = OpenMMOP256.new()
	if not verifier.verify_signature(public_key, digest, signature):
		push_error("RFC 6979 P-256 signature verification failed")
		quit(1)
		return
	digest[0] ^= 1
	if verifier.verify_signature(public_key, digest, signature):
		push_error("Tampered P-256 signature verification succeeded")
		quit(1)
		return
	quit(0)

func _sha256(data: PackedByteArray) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return PackedByteArray()
	return context.finish()

func _hex(value: String) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	for index in range(0, value.length(), 2):
		output.append(value.substr(index, 2).hex_to_int())
	return output
