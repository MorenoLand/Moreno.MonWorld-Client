extends SceneTree

func _init() -> void:
	var decoder: OpenMMORomAudio = OpenMMORomAudio.new()
	if not _test_wave_decoder(decoder):
		quit(1)
		return
	if not _test_noise_chunk_continuity(decoder):
		quit(1)
		return
	var path: String = OS.get_environment("MONWORLD_ROM")
	if path.is_empty():
		quit(0)
		return
	var result: Dictionary = MonWorldContent.from_rom_path(path)
	if not bool(result.get("ok", false)):
		push_error(str(result.get("error", "content load failed")))
		quit(1)
		return
	var content: MonWorldContent = result.get("content") as MonWorldContent
	var prepared: Dictionary = decoder.prepare_song(content, 300)
	if prepared.is_empty():
		push_error("ROM audio song 300 could not be prepared: %s" % decoder.last_error)
		quit(1)
		return
	var buffered_frames: PackedVector2Array = decoder.render_song_frames(prepared, 0, 2048)
	if buffered_frames.size() != 2048:
		push_error("ROM audio buffered renderer did not produce the requested frame count")
		quit(1)
		return
	var wrapped_frames: PackedVector2Array = decoder.render_song_frames(prepared, int(prepared.get("loop_frames", 2048)) - 1024, 2048)
	if wrapped_frames.size() != 2048:
		push_error("ROM audio buffered renderer did not wrap at the song loop")
		quit(1)
		return
	for song_id in [291, 300, 30, 241]:
		var inspect: Dictionary = decoder.inspect_song(content, int(song_id))
		if not bool(inspect.get("ok", false)) or int(inspect.get("event_count", 0)) <= 0:
			push_error("ROM audio song %d was not decoded: %s" % [song_id, str(inspect.get("error", "no events"))])
			quit(1)
			return
		var stream: AudioStreamWAV = decoder.build_song_stream(content, int(song_id)) as AudioStreamWAV
		if stream == null or stream.data.is_empty() or stream.mix_rate != 13379 or not stream.stereo:
			push_error("ROM audio song %d did not produce a stereo PCM stream" % song_id)
			quit(1)
			return
	quit(0)

func _test_wave_decoder(decoder: OpenMMORomAudio) -> bool:
	var data: PackedByteArray = PackedByteArray([1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 10, 1, 0x23])
	for _index in range(31):
		data.append(0)
	var wave: Dictionary = decoder.call("_read_wave", data, 0)
	var samples: PackedFloat32Array = wave.get("samples", PackedFloat32Array()) as PackedFloat32Array
	if samples.size() != 4:
		push_error("FireRed ADPCM regression fixture did not decode four samples")
		return false
	var expected: Array[float] = [10.0 / 128.0, 11.0 / 128.0, 15.0 / 128.0, 24.0 / 128.0]
	for index in range(expected.size()):
		if not is_equal_approx(samples[index], expected[index]):
			push_error("FireRed ADPCM regression fixture decoded sample %d incorrectly" % index)
			return false
	return true

func _test_noise_chunk_continuity(decoder: OpenMMORomAudio) -> bool:
	var prepared: Dictionary = {"ok": true, "data": PackedByteArray(), "events": [{"start": 0.0, "duration": 0.5, "key": 60, "velocity": 127, "volume": 127, "pan": 0, "tone": {"type": 4, "attack": 0, "decay": 0, "sustain": 15, "release": 0}}], "loop_frames": 8192, "duration_frames": 8192}
	var whole: PackedVector2Array = decoder.render_song_frames(prepared, 0, 4096)
	var first: PackedVector2Array = decoder.render_song_frames(prepared, 0, 2048)
	var second: PackedVector2Array = decoder.render_song_frames(prepared, 2048, 2048)
	for index in range(2048):
		if not is_equal_approx(whole[index].x, first[index].x) or not is_equal_approx(whole[index].y, first[index].y) or not is_equal_approx(whole[index + 2048].x, second[index].x) or not is_equal_approx(whole[index + 2048].y, second[index].y):
			push_error("FireRed noise renderer changed at a buffered chunk boundary")
			return false
	return true
