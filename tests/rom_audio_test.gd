extends SceneTree

func _init() -> void:
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
	var decoder: MonWorldRomAudio = MonWorldRomAudio.new()
	for song_id in [291, 300, 30, 241]:
		var inspect: Dictionary = decoder.inspect_song(content, int(song_id))
		if not bool(inspect.get("ok", false)) or int(inspect.get("event_count", 0)) <= 0:
			push_error("ROM audio song %d was not decoded: %s" % [song_id, str(inspect.get("error", "no events"))])
			quit(1)
			return
		var stream: AudioStreamWAV = decoder.build_song_stream(content, int(song_id)) as AudioStreamWAV
		if stream == null or stream.data.is_empty() or stream.mix_rate != 22050 or not stream.stereo:
			push_error("ROM audio song %d did not produce a stereo PCM stream" % song_id)
			quit(1)
			return
	quit(0)
