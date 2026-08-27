class_name MonWorldAudio
extends Node

const MUSIC_SAMPLE_RATE: int = 22050
const MUSIC_BUFFER_LENGTH: float = 2.0
const MUSIC_BUFFER_CAPACITY_FRAMES: int = 44100
const MUSIC_TARGET_FRAMES: int = 33075
const MUSIC_MIN_FREE_FRAMES: int = MUSIC_BUFFER_CAPACITY_FRAMES - MUSIC_TARGET_FRAMES
const MUSIC_CHUNK_FRAMES: int = 4096
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var rom_audio: MonWorldRomAudio
var music_stream: AudioStreamGenerator
var music_playback: AudioStreamGeneratorPlayback
var music_state: Dictionary = {}
var music_frame: int = 0
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
	set_process(true)

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
	stop_music()
	var prepared: Dictionary = rom_audio.prepare_song(content, music_id)
	if prepared.is_empty():
		return
	current_music_key = key
	current_content_id = content.content_id()
	music_state = prepared
	music_stream = AudioStreamGenerator.new()
	music_stream.mix_rate = MUSIC_SAMPLE_RATE
	music_stream.buffer_length = MUSIC_BUFFER_LENGTH
	music_player.stream = music_stream
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_music_buffer()

func _process(_delta: float) -> void:
	_fill_music_buffer()

func _fill_music_buffer() -> void:
	if music_player == null or not music_player.playing or music_state.is_empty():
		return
	if music_playback == null:
		music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if music_playback == null:
		return
	var available: int = music_playback.get_frames_available()
	while available > MUSIC_MIN_FREE_FRAMES:
		var chunk_frames: int = mini(MUSIC_CHUNK_FRAMES, available - MUSIC_MIN_FREE_FRAMES)
		if chunk_frames <= 0:
			break
		var frames: PackedVector2Array = rom_audio.render_song_frames(music_state, music_frame, chunk_frames)
		if frames.size() != chunk_frames:
			break
		music_playback.push_buffer(frames)
		var loop_frames: int = maxi(int(music_state.get("loop_frames", music_state.get("duration_frames", 1))), 1)
		music_frame = posmod(music_frame + chunk_frames, loop_frames)
		available = music_playback.get_frames_available()

func stop_music() -> void:
	current_music_key = ""
	if music_player != null:
		music_player.stop()
	music_playback = null
	music_stream = null
	music_state = {}
	music_frame = 0

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
