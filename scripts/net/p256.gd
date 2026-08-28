class_name OpenMMOP256
extends RefCounted

const LIMBS: int = 16
const MASK: int = 0xFFFF
const FIELD_BYTES: int = 32

var modulus: PackedInt64Array
var order: PackedInt64Array
var modulus_minus_two: PackedInt64Array
var order_minus_two: PackedInt64Array
var r_squared: PackedInt64Array
var one_montgomery: PackedInt64Array
var curve_b: PackedInt64Array
var generator_x: PackedInt64Array
var generator_y: PackedInt64Array

func _init() -> void:
	modulus = _from_hex("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF")
	order = _from_hex("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")
	modulus_minus_two = _from_hex("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD")
	order_minus_two = _from_hex("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63254F")
	r_squared = _from_hex("00000004FFFFFFFDFFFFFFFFFFFFFFFEFFFFFFFBFFFFFFFF0000000000000003")
	one_montgomery = _from_hex("00000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001")
	curve_b = _to_montgomery(_from_hex("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B"))
	generator_x = _to_montgomery(_from_hex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"))
	generator_y = _to_montgomery(_from_hex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5"))

func generate_handshake(peer_public: PackedByteArray) -> Dictionary:
	var scalar_bytes: PackedByteArray = PackedByteArray()
	var scalar: PackedInt64Array = PackedInt64Array()
	while true:
		scalar_bytes = Crypto.new().generate_random_bytes(FIELD_BYTES)
		scalar = _from_bytes(scalar_bytes)
		if not _is_zero(scalar) and _compare(scalar, order) < 0:
			break
	var peer_result: Dictionary = _decode_point(peer_public)
	if not bool(peer_result.get("ok", false)):
		return peer_result
	var public_point: Dictionary = _scalar_multiply(scalar, generator_x, generator_y)
	var shared_point: Dictionary = _scalar_multiply(scalar, peer_result.get("x") as PackedInt64Array, peer_result.get("y") as PackedInt64Array)
	if _is_infinity(public_point) or _is_infinity(shared_point):
		return {"ok": false, "error": "P-256 key agreement produced the point at infinity"}
	var public_affine: Dictionary = _to_affine(public_point)
	var shared_affine: Dictionary = _to_affine(shared_point)
	var encoded_public: PackedByteArray = PackedByteArray([4])
	encoded_public.append_array(_to_bytes(public_affine.get("x") as PackedInt64Array))
	encoded_public.append_array(_to_bytes(public_affine.get("y") as PackedInt64Array))
	return {"ok": true, "public": encoded_public, "secret": _to_bytes(shared_affine.get("x") as PackedInt64Array)}

func generate_verified_handshake(peer_public: PackedByteArray, root_public: PackedByteArray, digest: PackedByteArray, signature: PackedByteArray) -> Dictionary:
	if not verify_signature(root_public, digest, signature):
		return {"ok": false, "error": "OpenMMO server signature is invalid"}
	return generate_handshake(peer_public)

func verify_signature(public_key: PackedByteArray, digest: PackedByteArray, signature: PackedByteArray) -> bool:
	if digest.size() != FIELD_BYTES or signature.size() != FIELD_BYTES * 2:
		return false
	var public_result: Dictionary = _decode_point(public_key)
	if not bool(public_result.get("ok", false)):
		return false
	var r: PackedInt64Array = _from_bytes(signature.slice(0, FIELD_BYTES))
	var s: PackedInt64Array = _from_bytes(signature.slice(FIELD_BYTES))
	if _is_zero(r) or _is_zero(s) or _compare(r, order) >= 0 or _compare(s, order) >= 0:
		return false
	var z: PackedInt64Array = _from_bytes(digest)
	if _compare(z, order) >= 0:
		z = _subtract_with_high(z, order, 0)
	var inverse_s: PackedInt64Array = _scalar_pow(s, order_minus_two)
	var u1: PackedInt64Array = _scalar_multiply_mod(z, inverse_s)
	var u2: PackedInt64Array = _scalar_multiply_mod(r, inverse_s)
	var first: Dictionary = _scalar_multiply(u1, generator_x, generator_y)
	var second: Dictionary = _scalar_multiply(u2, public_result.get("x") as PackedInt64Array, public_result.get("y") as PackedInt64Array)
	if _is_infinity(second):
		return false
	var second_affine: Dictionary = _to_affine(second)
	var sum: Dictionary = _add_mixed(first, _to_montgomery(second_affine.get("x") as PackedInt64Array), _to_montgomery(second_affine.get("y") as PackedInt64Array))
	if _is_infinity(sum):
		return false
	var x: PackedInt64Array = _to_affine(sum).get("x") as PackedInt64Array
	if _compare(x, order) >= 0:
		x = _subtract_with_high(x, order, 0)
	return _compare(x, r) == 0

func scalar_multiply_for_test(scalar_hex: String, point: PackedByteArray) -> Dictionary:
	var scalar: PackedInt64Array = _from_hex(scalar_hex)
	var decoded: Dictionary = _decode_point(point)
	if not bool(decoded.get("ok", false)):
		return decoded
	var result: Dictionary = _scalar_multiply(scalar, decoded.get("x") as PackedInt64Array, decoded.get("y") as PackedInt64Array)
	if _is_infinity(result):
		return {"ok": false, "error": "point at infinity"}
	var affine: Dictionary = _to_affine(result)
	var encoded: PackedByteArray = PackedByteArray([4])
	encoded.append_array(_to_bytes(affine.get("x") as PackedInt64Array))
	encoded.append_array(_to_bytes(affine.get("y") as PackedInt64Array))
	return {"ok": true, "point": encoded}

func generator_bytes() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray([4])
	result.append_array(_to_bytes(_from_montgomery(generator_x)))
	result.append_array(_to_bytes(_from_montgomery(generator_y)))
	return result

func _decode_point(encoded: PackedByteArray) -> Dictionary:
	if encoded.size() != 65 or encoded[0] != 4:
		return {"ok": false, "error": "OpenMMO P-256 public key is malformed"}
	var x_normal: PackedInt64Array = _from_bytes(encoded.slice(1, 33))
	var y_normal: PackedInt64Array = _from_bytes(encoded.slice(33, 65))
	if _compare(x_normal, modulus) >= 0 or _compare(y_normal, modulus) >= 0:
		return {"ok": false, "error": "OpenMMO P-256 public key is outside the field"}
	var x: PackedInt64Array = _to_montgomery(x_normal)
	var y: PackedInt64Array = _to_montgomery(y_normal)
	var y_squared: PackedInt64Array = _multiply(y, y)
	var x_squared: PackedInt64Array = _multiply(x, x)
	var x_cubed: PackedInt64Array = _multiply(x_squared, x)
	var three_x: PackedInt64Array = _add(_add(x, x), x)
	var expected: PackedInt64Array = _add(_subtract(x_cubed, three_x), curve_b)
	if _compare(y_squared, expected) != 0:
		return {"ok": false, "error": "OpenMMO P-256 public key is not on secp256r1"}
	return {"ok": true, "x": x, "y": y}

func _scalar_multiply(scalar: PackedInt64Array, point_x: PackedInt64Array, point_y: PackedInt64Array) -> Dictionary:
	var result: Dictionary = _infinity()
	for bit_index in range(255, -1, -1):
		result = _double(result)
		if _bit(scalar, bit_index):
			result = _add_mixed(result, point_x, point_y)
	return result

func _double(point: Dictionary) -> Dictionary:
	if _is_infinity(point):
		return point
	var x: PackedInt64Array = point.get("x") as PackedInt64Array
	var y: PackedInt64Array = point.get("y") as PackedInt64Array
	var z: PackedInt64Array = point.get("z") as PackedInt64Array
	if _is_zero(y):
		return _infinity()
	var delta: PackedInt64Array = _multiply(z, z)
	var gamma: PackedInt64Array = _multiply(y, y)
	var beta: PackedInt64Array = _multiply(x, gamma)
	var alpha: PackedInt64Array = _multiply_small(_multiply(_subtract(x, delta), _add(x, delta)), 3)
	var x3: PackedInt64Array = _subtract(_multiply(alpha, alpha), _multiply_small(beta, 8))
	var z3: PackedInt64Array = _subtract(_subtract(_multiply(_add(y, z), _add(y, z)), gamma), delta)
	var y3: PackedInt64Array = _subtract(_multiply(alpha, _subtract(_multiply_small(beta, 4), x3)), _multiply_small(_multiply(gamma, gamma), 8))
	return {"x": x3, "y": y3, "z": z3}

func _add_mixed(point: Dictionary, point_x: PackedInt64Array, point_y: PackedInt64Array) -> Dictionary:
	if _is_infinity(point):
		return {"x": point_x.duplicate(), "y": point_y.duplicate(), "z": one_montgomery.duplicate()}
	var x: PackedInt64Array = point.get("x") as PackedInt64Array
	var y: PackedInt64Array = point.get("y") as PackedInt64Array
	var z: PackedInt64Array = point.get("z") as PackedInt64Array
	var z_squared: PackedInt64Array = _multiply(z, z)
	var u2: PackedInt64Array = _multiply(point_x, z_squared)
	var s2: PackedInt64Array = _multiply(point_y, _multiply(z, z_squared))
	var h: PackedInt64Array = _subtract(u2, x)
	var y_delta: PackedInt64Array = _subtract(s2, y)
	if _is_zero(h):
		return _double(point) if _is_zero(y_delta) else _infinity()
	var hh: PackedInt64Array = _multiply(h, h)
	var i: PackedInt64Array = _multiply_small(hh, 4)
	var j: PackedInt64Array = _multiply(h, i)
	var r: PackedInt64Array = _multiply_small(y_delta, 2)
	var v: PackedInt64Array = _multiply(x, i)
	var x3: PackedInt64Array = _subtract(_subtract(_multiply(r, r), j), _multiply_small(v, 2))
	var y3: PackedInt64Array = _subtract(_multiply(r, _subtract(v, x3)), _multiply_small(_multiply(y, j), 2))
	var z_plus_h: PackedInt64Array = _add(z, h)
	var z3: PackedInt64Array = _subtract(_subtract(_multiply(z_plus_h, z_plus_h), z_squared), hh)
	return {"x": x3, "y": y3, "z": z3}

func _to_affine(point: Dictionary) -> Dictionary:
	var x: PackedInt64Array = point.get("x") as PackedInt64Array
	var y: PackedInt64Array = point.get("y") as PackedInt64Array
	var z: PackedInt64Array = point.get("z") as PackedInt64Array
	var inverse: PackedInt64Array = _inverse(z)
	var inverse_squared: PackedInt64Array = _multiply(inverse, inverse)
	var affine_x: PackedInt64Array = _from_montgomery(_multiply(x, inverse_squared))
	var affine_y: PackedInt64Array = _from_montgomery(_multiply(y, _multiply(inverse_squared, inverse)))
	return {"x": affine_x, "y": affine_y}

func _inverse(value: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = one_montgomery.duplicate()
	for bit_index in range(255, -1, -1):
		result = _multiply(result, result)
		if _bit(modulus_minus_two, bit_index):
			result = _multiply(result, value)
	return result

func _scalar_pow(value: PackedInt64Array, exponent: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	result[0] = 1
	for bit_index in range(255, -1, -1):
		result = _scalar_multiply_mod(result, result)
		if _bit(exponent, bit_index):
			result = _scalar_multiply_mod(result, value)
	return result

func _scalar_multiply_mod(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var addend: PackedInt64Array = left.duplicate()
	for bit_index in 256:
		if _bit(right, bit_index):
			result = _scalar_add_mod(result, addend)
		addend = _scalar_add_mod(addend, addend)
	return result

func _scalar_add_mod(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var carry: int = 0
	for index in LIMBS:
		var sum: int = left[index] + right[index] + carry
		result[index] = sum & MASK
		carry = sum >> 16
	if carry > 0 or _compare(result, order) >= 0:
		result = _subtract_with_high(result, order, carry)
	return result

func _multiply_small(value: PackedInt64Array, multiplier: int) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var addend: PackedInt64Array = value
	var remaining: int = multiplier
	while remaining > 0:
		if remaining & 1:
			result = _add(result, addend)
		remaining >>= 1
		if remaining > 0:
			addend = _add(addend, addend)
	return result

func _multiply(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var temporary: PackedInt64Array = PackedInt64Array()
	temporary.resize(LIMBS + 2)
	for right_index in LIMBS:
		var carry: int = 0
		for left_index in LIMBS:
			var product: int = temporary[left_index] + left[left_index] * right[right_index] + carry
			temporary[left_index] = product & MASK
			carry = product >> 16
		var upper: int = temporary[LIMBS] + carry
		temporary[LIMBS] = upper & MASK
		temporary[LIMBS + 1] += upper >> 16
		var factor: int = temporary[0] & MASK
		carry = 0
		var first: int = temporary[0] + factor * modulus[0]
		carry = first >> 16
		for modulus_index in range(1, LIMBS):
			var reduced: int = temporary[modulus_index] + factor * modulus[modulus_index] + carry
			temporary[modulus_index - 1] = reduced & MASK
			carry = reduced >> 16
		var reduced_upper: int = temporary[LIMBS] + carry
		temporary[LIMBS - 1] = reduced_upper & MASK
		temporary[LIMBS] = (reduced_upper >> 16) + temporary[LIMBS + 1]
		temporary[LIMBS + 1] = 0
	var result: PackedInt64Array = temporary.slice(0, LIMBS)
	if temporary[LIMBS] > 0 or _compare(result, modulus) >= 0:
		result = _subtract_with_high(result, modulus, temporary[LIMBS])
	return result

func _add(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var carry: int = 0
	for index in LIMBS:
		var sum: int = left[index] + right[index] + carry
		result[index] = sum & MASK
		carry = sum >> 16
	if carry > 0 or _compare(result, modulus) >= 0:
		result = _subtract_with_high(result, modulus, carry)
	return result

func _subtract(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var borrow: int = 0
	for index in LIMBS:
		var difference: int = left[index] - right[index] - borrow
		if difference < 0:
			difference += 0x10000
			borrow = 1
		else:
			borrow = 0
		result[index] = difference
	if borrow != 0:
		var carry: int = 0
		for index in LIMBS:
			var corrected: int = result[index] + modulus[index] + carry
			result[index] = corrected & MASK
			carry = corrected >> 16
	return result

func _subtract_with_high(left: PackedInt64Array, right: PackedInt64Array, high: int) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var borrow: int = 0
	for index in LIMBS:
		var difference: int = left[index] - right[index] - borrow
		if difference < 0:
			difference += 0x10000
			borrow = 1
		else:
			borrow = 0
		result[index] = difference
	var remaining_high: int = high - borrow
	if remaining_high != 0:
		push_error("P-256 Montgomery reduction overflow")
	return result

func _to_montgomery(value: PackedInt64Array) -> PackedInt64Array:
	return _multiply(value, r_squared)

func _from_montgomery(value: PackedInt64Array) -> PackedInt64Array:
	var one: PackedInt64Array = _zero()
	one[0] = 1
	return _multiply(value, one)

func _from_hex(value: String) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var normalized: String = value.strip_edges().trim_prefix("0x")
	var cursor: int = normalized.length()
	var limb: int = 0
	while cursor > 0 and limb < LIMBS:
		var start: int = maxi(cursor - 4, 0)
		result[limb] = normalized.substr(start, cursor - start).hex_to_int()
		cursor = start
		limb += 1
	return result

func _from_bytes(value: PackedByteArray) -> PackedInt64Array:
	var result: PackedInt64Array = _zero()
	var byte_index: int = value.size() - 1
	var limb_index: int = 0
	while byte_index >= 0 and limb_index < LIMBS:
		var low: int = value[byte_index]
		var high: int = value[byte_index - 1] if byte_index > 0 else 0
		result[limb_index] = low | high << 8
		byte_index -= 2
		limb_index += 1
	return result

func _to_bytes(value: PackedInt64Array) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(FIELD_BYTES)
	for limb_index in LIMBS:
		var output_index: int = FIELD_BYTES - 2 - limb_index * 2
		result[output_index] = int(value[limb_index] >> 8) & 0xFF
		result[output_index + 1] = int(value[limb_index]) & 0xFF
	return result

func _compare(left: PackedInt64Array, right: PackedInt64Array) -> int:
	for index in range(LIMBS - 1, -1, -1):
		if left[index] < right[index]:
			return -1
		if left[index] > right[index]:
			return 1
	return 0

func _bit(value: PackedInt64Array, index: int) -> bool:
	return bool((value[index >> 4] >> (index & 15)) & 1)

func _is_zero(value: PackedInt64Array) -> bool:
	for limb in value:
		if limb != 0:
			return false
	return true

func _is_infinity(point: Dictionary) -> bool:
	return _is_zero(point.get("z") as PackedInt64Array)

func _infinity() -> Dictionary:
	return {"x": _zero(), "y": one_montgomery.duplicate(), "z": _zero()}

func _zero() -> PackedInt64Array:
	var result: PackedInt64Array = PackedInt64Array()
	result.resize(LIMBS)
	return result
