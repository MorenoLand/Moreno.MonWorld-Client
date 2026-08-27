class_name MonWorldAudio
extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var music_streams: Dictionary = {}
var sfx_streams: Dictionary = {}
var current_music_key: String = ""
var current_content_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -14.0
	add_child(music_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -6.0
	add_child(sfx_player)

func play_map_music(content: MonWorldContent, map_id: String) -> void:
	if content == null or map_id.is_empty() or music_player == null:
		return
	var map: Dictionary = content.map_data(map_id)
	if map.is_empty():
		return
	var music_id: int = int(map.get("music_id", 0))
	var key: String = "%s:%d" % [content.content_id(), music_id]
	if key == current_music_key and music_player.playing:
		return
	current_music_key = key
	current_content_id = content.content_id()
	var stream: AudioStream = _load_external_music(current_content_id, music_id)
	if stream == null:
		if not music_streams.has(key):
			music_streams[key] = _build_music_stream(music_id)
		stream = music_streams[key] as AudioStream
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	current_music_key = ""
	if music_player != null:
		music_player.stop()

func play_effect(effect: String) -> void:
	if sfx_player == null or effect.is_empty():
		return
	var key: String = "%s:%s" % [current_content_id, effect]
	var stream: AudioStream = _load_external_effect(current_content_id, effect)
	if stream == null:
		if not sfx_streams.has(key):
			sfx_streams[key] = _build_effect_stream(effect)
		stream = sfx_streams[key] as AudioStream
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()

func _load_external_music(content_id: String, music_id: int) -> AudioStream:
	for extension in ["ogg", "wav", "mp3"]:
		var path: String = MonWorldStorage.audio_path(content_id, "music-%d" % music_id, extension)
		if not FileAccess.file_exists(path):
			continue
		match extension:
			"ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			"wav":
				return AudioStreamWAV.load_from_file(path)
			"mp3":
				return AudioStreamMP3.load_from_file(path)
	return null

func _load_external_effect(content_id: String, effect: String) -> AudioStream:
	for extension in ["wav", "ogg", "mp3"]:
		var path: String = MonWorldStorage.audio_path(content_id, "sfx-%s" % effect, extension)
		if not FileAccess.file_exists(path):
			continue
		match extension:
			"wav":
				return AudioStreamWAV.load_from_file(path)
			"ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				return AudioStreamMP3.load_from_file(path)
	return null

func _build_music_stream(music_id: int) -> AudioStreamWAV:
	var roots: Array = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]
	var offset: int = posmod(music_id, roots.size())
	var notes: Array = []
	for index in range(8):
		notes.append(float(roots[(index + offset) % roots.size()]))
	return _build_pcm_stream(notes, 4.0, 0.11, true)

func _build_effect_stream(effect: String) -> AudioStreamWAV:
	match effect:
		"door":
			return _build_pcm_stream([392.0, 523.25, 659.25, 783.99], 0.28, 0.2, false)
		"dialogue":
			return _build_pcm_stream([659.25, 783.99], 0.08, 0.14, false)
		"step":
			return _build_pcm_stream([196.0], 0.045, 0.08, false)
	return _build_pcm_stream([261.63], 0.06, 0.1, false)

func _build_pcm_stream(notes: Array, duration: float, volume: float, looped: bool) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var sample_count: int = maxi(int(duration * sample_rate), 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time: float = float(sample_index) / float(sample_rate)
		var note_index: int = int(floor(time * 2.0)) % maxi(notes.size(), 1)
		var frequency: float = float(notes[note_index]) if not notes.is_empty() else 261.63
		var envelope: float = 1.0
		if not looped:
			envelope = minf(time * 80.0, 1.0) * minf((duration - time) * 28.0, 1.0)
		var sample: int = int(clampf(sin(PI * 2.0 * frequency * time) * volume * envelope, -1.0, 1.0) * 32767.0)
		var packed_sample: int = sample if sample >= 0 else sample + 65536
		data[sample_index * 2] = packed_sample & 0xFF
		data[sample_index * 2 + 1] = (packed_sample >> 8) & 0xFF
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream
