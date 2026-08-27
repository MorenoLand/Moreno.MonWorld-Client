class_name MonWorldAudio
extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var rom_audio: MonWorldRomAudio
var current_music_key: String = ""
var current_content_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rom_audio = MonWorldRomAudio.new()
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
	var stream: AudioStream = rom_audio.build_song_stream(content, music_id)
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
	var song_id: int = _effect_song_id(effect)
	if song_id < 0 or GameState.content == null:
		return
	var stream: AudioStream = rom_audio.build_song_stream(GameState.content, song_id)
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()

func _effect_song_id(effect: String) -> int:
	match effect:
		"door":
			return 241
		"dialogue":
			return 30
		"ledge":
			return 10
		"warp":
			return 39
		"step":
			return -1
	return -1
