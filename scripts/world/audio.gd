class_name MonWorldAudio
extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
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
		music_player.stop()
		return
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	current_music_key = ""
	if music_player != null:
		music_player.stop()

func play_effect(effect: String) -> void:
	if sfx_player == null or effect.is_empty():
		return
	var stream: AudioStream = _load_external_effect(current_content_id, effect)
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
