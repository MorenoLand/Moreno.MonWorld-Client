class_name OpenMMOAESCTR
extends RefCounted

var context: AESContext
var counter: PackedByteArray
var key_stream: PackedByteArray = PackedByteArray()
var key_stream_offset: int = 16
var started: bool = false

func start(key: PackedByteArray, initial_counter: PackedByteArray) -> Error:
	if key.size() != 16 or initial_counter.size() != 16:
		return ERR_INVALID_PARAMETER
	context = AESContext.new()
	var error: Error = context.start(AESContext.MODE_ECB_ENCRYPT, key)
	if error != OK:
		return error
	counter = initial_counter.duplicate()
	key_stream = PackedByteArray()
	key_stream_offset = 16
	started = true
	return OK

func update(input: PackedByteArray) -> PackedByteArray:
	if not started:
		return PackedByteArray()
	var output: PackedByteArray = PackedByteArray()
	output.resize(input.size())
	for index in input.size():
		if key_stream_offset >= 16:
			key_stream = context.update(counter)
			_increment_counter()
			key_stream_offset = 0
		output[index] = input[index] ^ key_stream[key_stream_offset]
		key_stream_offset += 1
	return output

func finish() -> void:
	if started:
		context.finish()
	started = false

func _increment_counter() -> void:
	for index in range(counter.size() - 1, -1, -1):
		counter[index] = (counter[index] + 1) & 0xFF
		if counter[index] != 0:
			return
